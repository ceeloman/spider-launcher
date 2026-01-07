-- scripts-sa/equipment-grid-fill.lua
-- Feature to auto-fill equipment grid ghosts from inventory
-- Future Feature - allow vehicles to fill their own equipment when they have items in their own inventory?

-- Bug 1 if in cheat mode many normal, you can fill equipment remotely because you have opened the equipment grid
-- Possible fix - force open render mode if opening equipment grid in not render mode

local vehicles_list = require("scripts.vehicles-list")
local map_gui = require("scripts.map-gui")

local equipment_grid_fill = {}

-- Button name constants
equipment_grid_fill.BUTTON_NAME = "spider_launcher_equipment_fill_button"
equipment_grid_fill.CARGO_POD_BUTTON_NAME = "spider_launcher_equipment_cargo_pod_button"
equipment_grid_fill.EQUIPMENT_TOOLBAR_NAME = "spider_launcher_equipment_toolbar"

-- Check if opened is an equipment grid for a vehicle item
-- Returns: grid, inventory, stack_index if valid, nil otherwise
function equipment_grid_fill.get_equipment_grid_context(player)
    if not player or not player.valid then
        return nil, nil, nil
    end
    
    local opened = player.opened
    if not opened or not opened.valid then
        -- game.print("[EQUIP FILL CONTEXT] player.opened is nil or invalid")
        return nil, nil, nil
    end
    
    -- Check if opened is an equipment grid
    -- Equipment grids have equipment property
    local success, has_equipment = pcall(function()
        return opened.equipment ~= nil
    end)
    
    -- game.print("[EQUIP FILL CONTEXT] opened type check: success=" .. tostring(success) .. ", has_equipment=" .. tostring(has_equipment))
    
    if not success or not has_equipment then
        -- game.print("[EQUIP FILL CONTEXT] Not an equipment grid")
        return nil, nil, nil
    end
    
    -- game.print("[EQUIP FILL CONTEXT] Valid equipment grid found")
    
    -- It's an equipment grid - use itemstack_owner to find the item stack
    local grid = opened
    
    -- Get the item stack that owns this grid
    local success_owner, itemstack_owner = pcall(function()
        return grid.itemstack_owner
    end)
    
    if not success_owner or not itemstack_owner then
        -- game.print("[EQUIP FILL CONTEXT] Could not get itemstack_owner")
        return grid, nil, nil
    end
    
    -- game.print("[EQUIP FILL CONTEXT] Found itemstack_owner: " .. tostring(itemstack_owner.name))
    
    -- Verify it's a vehicle item
    if not vehicles_list.is_vehicle(itemstack_owner.name) then
        -- game.print("[EQUIP FILL CONTEXT] Itemstack owner is not a vehicle")
        return grid, nil, nil
    end
    
    -- Get the entity owner to find which inventory contains this stack
    local success_entity, entity_owner = pcall(function()
        return grid.entity_owner
    end)
    
    if success_entity and entity_owner and entity_owner.valid then
        -- game.print("[EQUIP FILL CONTEXT] Found entity_owner: " .. tostring(entity_owner.name))
        
        -- Try to get inventory from entity (could be a container, vehicle, etc.)
        local inventory_types = {
            defines.inventory.chest,
            defines.inventory.car_trunk,
            defines.inventory.spider_trunk,
            defines.inventory.cargo_wagon
        }
        
        for _, inv_type in ipairs(inventory_types) do
            local success_inv, inventory = pcall(function()
                return entity_owner.get_inventory(inv_type)
            end)
            if success_inv and inventory then
                -- Find the stack index in this inventory
                for i = 1, #inventory do
                    local stack = inventory[i]
                    if stack == itemstack_owner then
                        -- game.print("[EQUIP FILL CONTEXT] Found stack at index " .. i .. " in entity inventory")
                        return grid, inventory, i
                    end
                end
            end
        end
    end
    
    -- If entity_owner didn't work, try player_owner
    local success_player, player_owner = pcall(function()
        return grid.player_owner
    end)
    
    if success_player and player_owner and player_owner.valid then
        -- game.print("[EQUIP FILL CONTEXT] Found player_owner")
        
        -- Check player's main inventory
        local success_main, main_inv = pcall(function()
            return player_owner.get_inventory(defines.inventory.player_main)
        end)
        if success_main and main_inv then
            for i = 1, #main_inv do
                local stack = main_inv[i]
                if stack == itemstack_owner then
                    -- game.print("[EQUIP FILL CONTEXT] Found stack at index " .. i .. " in player main inventory")
                    return grid, main_inv, i
                end
            end
        end
        
        -- Check player's cursor
        local cursor_stack = player_owner.cursor_stack
        if cursor_stack == itemstack_owner then
            -- game.print("[EQUIP FILL CONTEXT] Found stack in player cursor")
            -- For cursor, return player's main inventory for searching
            if success_main and main_inv then
                return grid, main_inv, nil
            end
        end
    end
    
    -- If we still haven't found it, return grid with nil inventory
    -- game.print("[EQUIP FILL CONTEXT] Could not find inventory containing the item stack")
    return grid, nil, nil
end

-- Get ghost equipment from a grid
-- Returns: table of {ghost_name, position, base_equipment_name}
function equipment_grid_fill.get_ghost_equipment(grid)
    if not grid or not grid.valid then
        return {}
    end
    
    local ghosts = {}
    
    for _, equipment in pairs(grid.equipment) do
        local is_ghost = false
        local base_equipment_name = nil
        
        -- Check if it's a ghost by prototype type first (most reliable)
        if equipment.prototype and equipment.prototype.type == "equipment-ghost" then
            is_ghost = true
            -- Get the base equipment name from ghost_name property
            if equipment.ghost_name then
                base_equipment_name = equipment.ghost_name
            else
                -- Fallback: try stripping suffix
                local equipment_name = equipment.name
                if equipment_name and equipment_name ~= "equipment-ghost" and equipment_name:match("%-ghost$") then
                    base_equipment_name = equipment_name:gsub("%-ghost$", "")
                end
            end
        -- Check if it's a ghost by name pattern
        elseif equipment.name and equipment.name:match("%-ghost$") and equipment.name ~= "equipment-ghost" then
            is_ghost = true
            base_equipment_name = equipment.name:gsub("%-ghost$", "")
        -- Check if name is just "equipment-ghost"
        elseif equipment.name == "equipment-ghost" then
            is_ghost = true
            if equipment.ghost_name then
                base_equipment_name = equipment.ghost_name
            end
        end
        
        if is_ghost and base_equipment_name then
            -- Get quality directly from equipment object (it's a LuaQualityPrototype/userdata)
            -- Store the quality object directly - don't try to extract the name here
            local ghost_quality = nil
            if equipment.quality then
                ghost_quality = equipment.quality
            end
            
            table.insert(ghosts, {
                ghost_name = equipment.name,
                base_equipment_name = base_equipment_name,
                position = {x = equipment.position.x, y = equipment.position.y},
                equipment = equipment,
                quality = ghost_quality  -- Store the quality object directly (userdata)
            })
        end
    end
    
    return ghosts
end

-- Find items in inventory that match ghost equipment
-- Returns: table mapping base_equipment_name -> {stack, index, count, item_name, quality}
-- This searches for items that have place_as_equipment_result matching the ghost equipment
function equipment_grid_fill.find_matching_items(inventory, ghosts)
    if not inventory then
        return {}
    end
    
    local matches = {}
    
    -- Build a set of needed equipment names from ghosts
    local needed_equipment = {}
    for _, ghost in ipairs(ghosts) do
        if not needed_equipment[ghost.base_equipment_name] then
            needed_equipment[ghost.base_equipment_name] = {
                count = 0,
                quality = ghost.quality
            }
        end
        needed_equipment[ghost.base_equipment_name].count = needed_equipment[ghost.base_equipment_name].count + 1
    end
    
    -- Search inventory for items that place the needed equipment
    for i = 1, #inventory do
        local stack = inventory[i]
        if stack and stack.valid_for_read then
            local item_prototype = prototypes.item[stack.name]
            if item_prototype and item_prototype.place_as_equipment_result then
                local place_result = item_prototype.place_as_equipment_result
                local result_equipment_name = nil
                
                -- Extract equipment name from place_result
                if type(place_result) == "string" then
                    result_equipment_name = place_result
                elseif place_result and place_result.name then
                    result_equipment_name = place_result.name
                end
                
                -- Check if this item places equipment we need
                if result_equipment_name and needed_equipment[result_equipment_name] then
                    -- Check quality match if ghost has quality
                    local quality_match = true
                    local ghost_data = needed_equipment[result_equipment_name]
                    if ghost_data.quality then
                        -- Extract stack quality name
                        local stack_quality = "normal"
                        if stack.quality then
                            local success, name = pcall(function()
                                return stack.quality.name
                            end)
                            if success and name then
                                stack_quality = string.lower(name)
                            elseif type(stack.quality) == "string" then
                                stack_quality = string.lower(stack.quality)
                            end
                        end
                        
                        -- Extract ghost quality name (use pcall for userdata)
                        local ghost_quality_name = "normal"
                        local success, name = pcall(function()
                            return ghost_data.quality.name
                        end)
                        if success and name then
                            ghost_quality_name = string.lower(name)
                        elseif type(ghost_data.quality) == "string" then
                            ghost_quality_name = string.lower(ghost_data.quality)
                        end
                        
                        quality_match = (stack_quality == ghost_quality_name)
                    end
                    
                    if quality_match then
                        if not matches[result_equipment_name] then
                            matches[result_equipment_name] = {
                                stack = stack,
                                index = i,
                                count = 0,
                                item_name = stack.name,
                                quality = stack.quality
                            }
                        end
                        matches[result_equipment_name].count = matches[result_equipment_name].count + stack.count
                    end
                end
            end
        end
    end
    
    return matches
end

-- Find all equipment items in inventory (not just matching ghosts)
-- Returns: array of {item_name, equipment_name, stack, index, count, quality}
function equipment_grid_fill.find_all_equipment_items(inventory)
    if not inventory then
        return {}
    end
    
    local equipment_items = {}
    local equipment_map = {}  -- Map equipment_name:quality -> index in equipment_items
    
    -- Search inventory for all items that place equipment
    for i = 1, #inventory do
        local stack = inventory[i]
        if stack and stack.valid_for_read then
            local item_prototype = prototypes.item[stack.name]
            if item_prototype and item_prototype.place_as_equipment_result then
                local place_result = item_prototype.place_as_equipment_result
                local result_equipment_name = nil
                
                -- Extract equipment name from place_result
                if type(place_result) == "string" then
                    result_equipment_name = place_result
                elseif place_result and place_result.name then
                    result_equipment_name = place_result.name
                end
                
                if result_equipment_name then
                    -- Create unique key for equipment name + quality
                    local stack_quality = "Normal"
                    if stack.quality then
                        stack_quality = stack.quality.name
                    end
                    local key = result_equipment_name .. ":" .. stack_quality
                    
                    if not equipment_map[key] then
                        -- First time seeing this equipment+quality combo
                        local item_data = {
                            item_name = stack.name,
                            equipment_name = result_equipment_name,
                            stack = stack,
                            index = i,
                            count = stack.count,
                            quality = stack.quality
                        }
                        table.insert(equipment_items, item_data)
                        equipment_map[key] = #equipment_items
                    else
                        -- Update count for existing equipment
                        local idx = equipment_map[key]
                        equipment_items[idx].count = equipment_items[idx].count + stack.count
                    end
                end
            end
        end
    end
    
    return equipment_items
end

-- Add this helper function before get_or_create_fill_button
local function create_equipment_toolbar_content(equipment_table, equipment_items, gui_type, relative_gui)
    -- Group equipment by equipment_name, then sort by quality level
    local equipment_groups = {}
    for _, item_data in ipairs(equipment_items) do
        local equipment_name = item_data.equipment_name
        if not equipment_groups[equipment_name] then
            equipment_groups[equipment_name] = {}
        end
        table.insert(equipment_groups[equipment_name], item_data)
    end
    
    -- Sort each group by quality level (normal first, then increasing)
    local function get_quality_level(quality)
        if not quality then
            return 0  -- Normal quality
        end
        if type(quality) == "table" and quality.level then
            return quality.level
        end
        return 0  -- Default to normal
    end
    
    local function sort_by_quality(a, b)
        local level_a = get_quality_level(a.quality)
        local level_b = get_quality_level(b.quality)
        return level_a < level_b
    end
    
    -- Sort equipment names for consistent ordering
    local sorted_equipment_names = {}
    for equipment_name, _ in pairs(equipment_groups) do
        table.insert(sorted_equipment_names, equipment_name)
    end
    table.sort(sorted_equipment_names)
    
    -- Calculate max items per row for table column count
    local max_items_per_row = 0
    for _, equipment_name in ipairs(sorted_equipment_names) do
        local group = equipment_groups[equipment_name]
        if #group > max_items_per_row then
            max_items_per_row = #group
        end
    end
    
    -- Create a row for each equipment type
    for _, equipment_name in ipairs(sorted_equipment_names) do
        local group = equipment_groups[equipment_name]
        table.sort(group, sort_by_quality)
        
        -- Add buttons for each quality variant in this row
        for idx, item_data in ipairs(group) do
            local item_prototype = prototypes.item[item_data.item_name]
            
            if item_prototype then
                local icon_sprite = "item/" .. item_data.item_name
                
                local tooltip_text = item_prototype.localised_name or item_data.item_name
                if item_data.count > 1 then
                    tooltip_text = {"", tooltip_text, " - ", item_data.count, "x"}
                end
                
                local quality_suffix = "normal"
                if item_data.quality then
                    quality_suffix = item_data.quality.name or "normal"
                end
                local button_name = equipment_grid_fill.EQUIPMENT_TOOLBAR_NAME .. "_" .. item_data.equipment_name .. "_" .. quality_suffix
                
                local quality_name_for_tag = "Normal"
                local quality_name_lower = "normal"
                
                if item_data.quality then
                    local success, name = pcall(function()
                        return item_data.quality.name
                    end)
                    
                    if success and name then
                        quality_name_for_tag = name
                        quality_name_lower = string.lower(name)
                    elseif type(item_data.quality) == "string" then
                        quality_name_for_tag = item_data.quality
                        quality_name_lower = string.lower(item_data.quality)
                    end
                end
                
                local is_last_column = (idx == max_items_per_row)

                local icon_container = equipment_table.add{
                    type = "flow"
                }
                icon_container.style.width = 40
                icon_container.style.height = 40
                icon_container.style.padding = 0
                icon_container.style.margin = 0
                icon_container.style.horizontally_stretchable = false
                icon_container.style.vertically_stretchable = false

                if is_last_column and quality_name_lower ~= "normal" then
                    icon_container.style.right_margin = 14
                end
                
                local equipment_button = icon_container.add{
                    type = "sprite-button",
                    name = button_name,
                    sprite = icon_sprite,
                    tooltip = tooltip_text,
                    enabled = true,
                    tags = {
                        equipment_name = item_data.equipment_name,
                        item_name = item_data.item_name,
                        inventory_index = item_data.index,
                        quality = item_data.quality,
                        quality_name = quality_name_for_tag
                    }
                }
                equipment_button.style.size = 40
                equipment_button.style.padding = 0
                equipment_button.style.margin = 0

                if quality_name_lower ~= "normal" then
                    local overlay_name = "sl-" .. quality_name_lower
                    
                    local success, quality_overlay = pcall(function()
                        return icon_container.add{
                            type = "sprite",
                            sprite = overlay_name,
                            tooltip = quality_name_for_tag .. " quality"
                        }
                    end)
                    
                    if success and quality_overlay then
                        quality_overlay.style.size = 14
                        quality_overlay.style.top_padding = 23
                        quality_overlay.style.left_padding = -40
                    end
                end
            end
        end

        local items_in_row = #group
        if items_in_row < max_items_per_row then
            for i = items_in_row + 1, max_items_per_row do
                equipment_table.add{
                    type = "empty-widget"
                }
            end
        end
    end
    
    return max_items_per_row
end

-- Get or create the fill button for equipment grid GUI
function equipment_grid_fill.get_or_create_fill_button(player)
    -- game.print("[EQUIP FILL] get_or_create_fill_button called")
    if not player or not player.valid then
        -- game.print("[EQUIP FILL] Player invalid")
        return nil
    end
    
    local grid, inventory, stack_index = equipment_grid_fill.get_equipment_grid_context(player)
    -- game.print("[EQUIP FILL] get_equipment_grid_context returned: grid=" .. tostring(grid ~= nil) .. ", inventory=" .. tostring(inventory ~= nil))
    if not grid or not grid.valid then
        -- Not an equipment grid - remove button if it exists
        -- game.print("[EQUIP FILL] No valid grid found, removing button")
        equipment_grid_fill.remove_fill_button(player)
        return nil
    end
    
    -- Get ghost equipment (for counting and matching, but button will show regardless)
    local ghosts = equipment_grid_fill.get_ghost_equipment(grid)
    -- game.print("[EQUIP FILL] Found " .. #ghosts .. " ghost equipment")
    
    -- Use the inventory from get_equipment_grid_context
    -- This should now be correctly found using itemstack_owner
    local target_inventory = inventory  -- From get_equipment_grid_context
    
    if not target_inventory then
        -- game.print("[EQUIP FILL] Could not find inventory containing the vehicle item")
        equipment_grid_fill.remove_fill_button(player)
        return nil
    end
    
    -- game.print("[EQUIP FILL] Using inventory from context")
    
    -- Find matching items in the target inventory (for display purposes, but button shows regardless)
    local matches = equipment_grid_fill.find_matching_items(target_inventory, ghosts)
    -- game.print("[EQUIP FILL] Found " .. (matches and next(matches) and "some" or "no") .. " matching items in target inventory")
    
    -- Button will show even if no ghosts or no matches - user can still click it
    
    -- Get the relative GUI
    local relative_gui = player.gui.relative
    -- game.print("[EQUIP FILL] relative_gui=" .. tostring(relative_gui ~= nil))
    if not relative_gui then
        -- game.print("[EQUIP FILL] No relative GUI available")
        return nil
    end
    
    -- Find all equipment items in the inventory (needed for both new and existing buttons)
    local equipment_items = equipment_grid_fill.find_all_equipment_items(target_inventory)
    
    -- Check if button already exists
    local button = relative_gui[equipment_grid_fill.BUTTON_NAME]
    if button and button.valid then
        -- Button exists - refresh equipment toolbar if needed
        local equipment_toolbar = relative_gui[equipment_grid_fill.EQUIPMENT_TOOLBAR_NAME]
        if equipment_toolbar and equipment_toolbar.valid then
            -- Toolbar exists, destroy it so it can be recreated with updated counts
            equipment_toolbar.destroy()
        end
        
        -- Recreate equipment toolbar if we have equipment items
        if #equipment_items > 0 then
            -- Reuse the gui_type detection from earlier in the function
            local gui_type = nil
            local gui_type_names = {
                "equipment_grid_gui",
                "equipment_gui",
                "grid_gui"
            }
            
            for _, name in ipairs(gui_type_names) do
                if defines.relative_gui_type[name] then
                    gui_type = defines.relative_gui_type[name]
                    break
                end
            end
            
            -- Create equipment toolbar (same code as below, but extracted for reuse)
            local equipment_anchor = nil
            if gui_type then
                equipment_anchor = {
                    gui = gui_type,
                    position = defines.relative_gui_position.right
                }
            end
            
            local equipment_frame_config = {
                type = "frame",
                name = equipment_grid_fill.EQUIPMENT_TOOLBAR_NAME,
                style = "frame"
            }
            
            if equipment_anchor then
                equipment_frame_config.anchor = equipment_anchor
            end
            
            local success_equip, equipment_toolbar_frame = pcall(function()
                return relative_gui.add(equipment_frame_config)
            end)
            
            if not success_equip or not equipment_toolbar_frame then
                equipment_frame_config.anchor = nil
                success_equip, equipment_toolbar_frame = pcall(function()
                    return relative_gui.add(equipment_frame_config)
                end)
            end
            
            if success_equip and equipment_toolbar_frame then
                -- Apply style modifications
                equipment_toolbar_frame.style.horizontally_stretchable = false
                equipment_toolbar_frame.style.vertically_stretchable = false
                equipment_toolbar_frame.style.top_padding = 6
                equipment_toolbar_frame.style.bottom_padding = 6
                equipment_toolbar_frame.style.left_padding = 6
                equipment_toolbar_frame.style.right_padding = 6
                
                -- Create button_frame for equipment
                local equipment_button_frame = equipment_toolbar_frame.add{
                    type = "frame",
                    name = "button_frame",
                    direction = "vertical",
                    style = "inside_shallow_frame"
                }
                
                equipment_button_frame.style.vertically_stretchable = false
                
                -- Create scroll pane for equipment items
                local equipment_scroll = equipment_button_frame.add{
                    type = "scroll-pane",
                    name = "equipment_scroll",
                    horizontal_scroll_policy = "auto",
                    vertical_scroll_policy = "auto"
                }
                equipment_scroll.style.maximal_height = 300
                equipment_scroll.style.minimal_width = 20
                equipment_scroll.style.maximal_width = 200
                
                -- Group equipment by equipment_name, then sort by quality level
                local equipment_groups = {}
                for _, item_data in ipairs(equipment_items) do
                    local equipment_name = item_data.equipment_name
                    if not equipment_groups[equipment_name] then
                        equipment_groups[equipment_name] = {}
                    end
                    table.insert(equipment_groups[equipment_name], item_data)
                end
                
                -- Sort each group by quality level (normal first, then increasing)
                local function get_quality_level(quality)
                    if not quality then
                        return 0  -- Normal quality
                    end
                    if type(quality) == "table" and quality.level then
                        return quality.level
                    end
                    return 0  -- Default to normal
                end
                
                local function sort_by_quality(a, b)
                    local level_a = get_quality_level(a.quality)
                    local level_b = get_quality_level(b.quality)
                    return level_a < level_b
                end
                
                -- Sort equipment names for consistent ordering
                local sorted_equipment_names = {}
                for equipment_name, _ in pairs(equipment_groups) do
                    table.insert(sorted_equipment_names, equipment_name)
                end
                table.sort(sorted_equipment_names)
                
                -- Calculate max items per row for table column count
                local max_items_per_row = 0
                for _, equipment_name in ipairs(sorted_equipment_names) do
                    local group = equipment_groups[equipment_name]
                    if #group > max_items_per_row then
                        max_items_per_row = #group
                    end
                end
                equipment_scroll.style.maximal_width = 220

                -- Create table with filter_slot_table style for grid background
                local equipment_table = equipment_scroll.add{
                    type = "table",
                    name = "equipment_table",
                    column_count = max_items_per_row,
                    style = "filter_slot_table"
                }

                -- Create a row for each equipment type
                for _, equipment_name in ipairs(sorted_equipment_names) do
                    local group = equipment_groups[equipment_name]
                    table.sort(group, sort_by_quality)
                    
                    -- Add buttons for each quality variant in this row
                    for idx, item_data in ipairs(group) do
                        local item_prototype = prototypes.item[item_data.item_name]
                        
                        if item_prototype then
                            local icon_sprite = "item/" .. item_data.item_name
                            
                            local tooltip_text = item_prototype.localised_name or item_data.item_name
                            if item_data.count > 1 then
                                tooltip_text = {"", tooltip_text, " - ", item_data.count, "x"}
                            end
                            
                            local quality_suffix = "normal"
                            if item_data.quality then
                                quality_suffix = item_data.quality.name or "normal"
                            end
                            local button_name = equipment_grid_fill.EQUIPMENT_TOOLBAR_NAME .. "_" .. item_data.equipment_name .. "_" .. quality_suffix
                            
                            local quality_name_for_tag = "Normal"
                            local quality_name_lower = "normal"
                            
                            if item_data.quality then
                                local success, name = pcall(function()
                                    return item_data.quality.name
                                end)
                                
                                if success and name then
                                    quality_name_for_tag = name
                                    quality_name_lower = string.lower(name)
                                elseif type(item_data.quality) == "string" then
                                    quality_name_for_tag = item_data.quality
                                    quality_name_lower = string.lower(item_data.quality)
                                end
                            end
                            
                            local is_last_column = (idx == max_items_per_row)

                            local icon_container = equipment_table.add{
                                type = "flow"
                            }
                            icon_container.style.width = 40
                            icon_container.style.height = 40
                            icon_container.style.padding = 0
                            icon_container.style.margin = 0
                            icon_container.style.horizontally_stretchable = false
                            icon_container.style.vertically_stretchable = false

                            if is_last_column and quality_name_lower ~= "normal" then
                                icon_container.style.right_margin = 14
                            end
                            
                            local equipment_button = icon_container.add{
                                type = "sprite-button",
                                name = button_name,
                                sprite = icon_sprite,
                                tooltip = tooltip_text,
                                enabled = true,
                                tags = {
                                    equipment_name = item_data.equipment_name,
                                    item_name = item_data.item_name,
                                    inventory_index = item_data.index,
                                    quality = item_data.quality,
                                    quality_name = quality_name_for_tag
                                }
                            }
                            equipment_button.style.size = 40
                            equipment_button.style.padding = 0
                            equipment_button.style.margin = 0

                            if quality_name_lower ~= "normal" then
                                local overlay_name = "sl-" .. quality_name_lower
                                
                                local success, quality_overlay = pcall(function()
                                    return icon_container.add{
                                        type = "sprite",
                                        sprite = overlay_name,
                                        tooltip = quality_name_for_tag .. " quality"
                                    }
                                end)
                                
                                if success and quality_overlay then
                                    quality_overlay.style.size = 14
                                    quality_overlay.style.top_padding = 23
                                    quality_overlay.style.left_padding = -40
                                end
                            end
                        end
                    end

                    local items_in_row = #group
                    if items_in_row < max_items_per_row then
                        for i = items_in_row + 1, max_items_per_row do
                            equipment_table.add{
                                type = "empty-widget"
                            }
                        end
                    end
                end
            end
        end
        
        return button
    end
    -- game.print("[EQUIP FILL] Creating new button")
    
    -- Try to find equipment grid GUI type
    -- Equipment grids might use different GUI types depending on Factorio version
    local gui_type = nil
    local gui_type_names = {
        "equipment_grid_gui",
        "equipment_gui",
        "grid_gui"
    }
    
    for _, name in ipairs(gui_type_names) do
        if defines.relative_gui_type[name] then
            gui_type = defines.relative_gui_type[name]
            -- game.print("[EQUIP FILL] Found GUI type: " .. name .. " = " .. tostring(gui_type))
            break
        end
    end
    
    if not gui_type then
        -- game.print("[EQUIP FILL] No GUI type found, will try without anchor")
    end
    
    -- Create anchor to the right of the equipment grid GUI
    local anchor = nil
    if gui_type then
        anchor = {
            gui = gui_type,
            position = defines.relative_gui_position.right
        }
        -- game.print("[EQUIP FILL] Created anchor with gui_type=" .. tostring(gui_type) .. ", position=right")
    end
    
    -- Create button frame (like shared_toolbar)
    local frame_style = "frame"
    local inner_frame_style = "inside_shallow_frame"
    
    local frame_config = {
        type = "frame",
        name = equipment_grid_fill.BUTTON_NAME,
        style = frame_style
    }
    
    if anchor then
        frame_config.anchor = anchor
    end
    
    local success, toolbar_frame = pcall(function()
        return relative_gui.add(frame_config)
    end)
    
    -- game.print("[EQUIP FILL] Frame creation attempt 1: success=" .. tostring(success) .. ", frame=" .. tostring(toolbar_frame ~= nil))
    
    -- If creation failed with anchor, try without anchor
    if not success or not toolbar_frame then
        -- game.print("[EQUIP FILL] Trying without anchor")
        frame_config.anchor = nil
        success, toolbar_frame = pcall(function()
            return relative_gui.add(frame_config)
        end)
        -- game.print("[EQUIP FILL] Frame creation attempt 2: success=" .. tostring(success) .. ", frame=" .. tostring(toolbar_frame ~= nil))
    end
    
    if not success or not toolbar_frame then
        -- game.print("[EQUIP FILL] Failed to create frame")
        return nil
    end
    
    -- game.print("[EQUIP FILL] Frame created successfully")
    
    -- Apply style modifications
    toolbar_frame.style.horizontally_stretchable = false
    toolbar_frame.style.vertically_stretchable = false
    toolbar_frame.style.top_padding = 6
    toolbar_frame.style.bottom_padding = 6
    toolbar_frame.style.left_padding = 6
    toolbar_frame.style.right_padding = 6
    
    -- Create button_frame
    local button_frame = toolbar_frame.add{
        type = "frame",
        name = "button_frame",
        direction = "vertical",
        style = inner_frame_style
    }
    
    button_frame.style.vertically_stretchable = false
    
    -- Create button_flow
    local button_flow = button_frame.add{
        type = "flow",
        name = "button_flow",
        direction = "vertical"
    }
    
    -- Count total ghosts that can be filled
    local fillable_count = 0
    for _, ghost in ipairs(ghosts) do
        if matches[ghost.base_equipment_name] and matches[ghost.base_equipment_name].count > 0 then
            fillable_count = fillable_count + 1
        end
    end
    
    -- Create sprite-button with utility sprite
    -- Button always shows, but tooltip indicates how many can be filled
    local tooltip_text = ""
    if fillable_count > 0 then
        tooltip_text = {"string-mod-setting.fill-ghosts", fillable_count}
    elseif #ghosts > 0 then
        tooltip_text = {"string-mod-setting.no-matching-items", #ghosts}
    else
        tooltip_text = {"string-mod-setting.confirm-loadout"}
    end
    
    local fill_button = button_flow.add{
        type = "sprite-button",
        name = equipment_grid_fill.BUTTON_NAME .. "_btn",
        sprite = "utility/confirm_slot",
        style = "slot_sized_button",
        tooltip = tooltip_text,
        enabled = true  -- Always enabled - validation happens on click
    }
    
    -- Create cargo pod button
    local cargo_pod_button = button_flow.add{
        type = "sprite-button",
        name = equipment_grid_fill.CARGO_POD_BUTTON_NAME .. "_btn",
        sprite = "ovd_cargo_pod",
        style = "slot_sized_button",
        tooltip = "Open Orbital Deployment Menu",
        enabled = true
    }
    
    -- game.print("[EQUIP FILL] Button created successfully, fillable_count=" .. fillable_count .. ", total_ghosts=" .. #ghosts)
    
    -- Find all equipment items in the inventory
    local equipment_items = equipment_grid_fill.find_all_equipment_items(target_inventory)
    
    -- Create separate equipment toolbar below the buttons if we have equipment items
    if #equipment_items > 0 then
        -- Create separate frame for equipment toolbar
        -- Anchor it to the same GUI type - since it's created second, it will naturally be below
        local equipment_anchor = nil
        if gui_type then
            equipment_anchor = {
                gui = gui_type,
                position = defines.relative_gui_position.right
            }
        end
        
        local equipment_frame_config = {
            type = "frame",
            name = equipment_grid_fill.EQUIPMENT_TOOLBAR_NAME,
            style = frame_style
        }
        
        if equipment_anchor then
            equipment_frame_config.anchor = equipment_anchor
        end
        
        local success_equip, equipment_toolbar_frame = pcall(function()
            return relative_gui.add(equipment_frame_config)
        end)
        
        if not success_equip or not equipment_toolbar_frame then
            equipment_frame_config.anchor = nil
            success_equip, equipment_toolbar_frame = pcall(function()
                return relative_gui.add(equipment_frame_config)
            end)
        end
        
        if success_equip and equipment_toolbar_frame then
            -- Apply style modifications
            equipment_toolbar_frame.style.horizontally_stretchable = false
            equipment_toolbar_frame.style.vertically_stretchable = false
            equipment_toolbar_frame.style.top_padding = 6
            equipment_toolbar_frame.style.bottom_padding = 6
            equipment_toolbar_frame.style.left_padding = 6
            equipment_toolbar_frame.style.right_padding = 6
            
            -- Since both toolbars are anchored to the same GUI type at the same position,
            -- the second one (equipment toolbar) will naturally be positioned below the first one
            
            -- Create button_frame for equipment
            local equipment_button_frame = equipment_toolbar_frame.add{
                type = "frame",
                name = "button_frame",
                direction = "vertical",
                style = inner_frame_style
            }
            
            equipment_button_frame.style.vertically_stretchable = false
            
            -- Create scroll pane for equipment items
            local equipment_scroll = equipment_button_frame.add{
                type = "scroll-pane",
                name = "equipment_scroll",
                horizontal_scroll_policy = "auto",
                vertical_scroll_policy = "auto"
            }
            -- Setting maximal_height and maximal_width with scroll_policy = "auto" means
            -- the scroll-pane will only be scrollable when content exceeds these dimensions.
            equipment_scroll.style.maximal_height = 300
            equipment_scroll.style.minimal_width = 20
            equipment_scroll.style.maximal_width = 200
            
            -- Group equipment by equipment_name, then sort by quality level
            local equipment_groups = {}
            for _, item_data in ipairs(equipment_items) do
                local equipment_name = item_data.equipment_name
                if not equipment_groups[equipment_name] then
                    equipment_groups[equipment_name] = {}
                end
                table.insert(equipment_groups[equipment_name], item_data)
            end
            
            -- Sort each group by quality level (normal first, then increasing)
            local function get_quality_level(quality)
                if not quality then
                    return 0  -- Normal quality
                end
                if type(quality) == "table" and quality.level then
                    return quality.level
                end
                return 0  -- Default to normal
            end
            
            local function sort_by_quality(a, b)
                local level_a = get_quality_level(a.quality)
                local level_b = get_quality_level(b.quality)
                return level_a < level_b
            end
            
            -- Sort equipment names for consistent ordering
            local sorted_equipment_names = {}
            for equipment_name, _ in pairs(equipment_groups) do
                table.insert(sorted_equipment_names, equipment_name)
            end
            table.sort(sorted_equipment_names)
            
            -- Calculate max items per row for table column count
            local max_items_per_row = 0
            for _, equipment_name in ipairs(sorted_equipment_names) do
                local group = equipment_groups[equipment_name]
                if #group > max_items_per_row then
                    max_items_per_row = #group
                end
            end
            -- Set maximal width - give plenty of room for overlays
            equipment_scroll.style.maximal_width = 220

            -- Create table with filter_slot_table style for grid background
            -- We'll put flows (with sprite buttons) in the table cells
            local equipment_table = equipment_scroll.add{
                type = "table",
                name = "equipment_table",
                column_count = max_items_per_row,
                style = "filter_slot_table"
            }

            -- Create a row for each equipment type
            for _, equipment_name in ipairs(sorted_equipment_names) do
                local group = equipment_groups[equipment_name]
                table.sort(group, sort_by_quality)
                

                -- Add buttons for each quality variant in this row
                for idx, item_data in ipairs(group) do
                    local item_prototype = prototypes.item[item_data.item_name]
                    
                    if item_prototype then
                        -- Use item name as sprite - Factorio will resolve the icon automatically
                        -- Format: "item/item-name" for item icons
                        local icon_sprite = "item/" .. item_data.item_name
                        
                        -- Create tooltip with item name and count in "name - countx" format
                        local tooltip_text = item_prototype.localised_name or item_data.item_name
                        if item_data.count > 1 then
                            tooltip_text = {"", tooltip_text, " - ", item_data.count, "x"}
                        end
                        
                        -- Create unique button name with equipment name and quality
                        local quality_suffix = "normal"
                        if item_data.quality then
                            quality_suffix = item_data.quality.name or "normal"
                        end
                        local button_name = equipment_grid_fill.EQUIPMENT_TOOLBAR_NAME .. "_" .. item_data.equipment_name .. "_" .. quality_suffix
                        
                        -- Store quality name for easier retrieval - DETERMINE THIS EARLY
                        local quality_name_for_tag = "Normal"
                        local quality_name_lower = "normal"
                        
                        if item_data.quality then
                            -- Try to access .name property using pcall (works for userdata/LuaQualityPrototype)
                            local success, name = pcall(function()
                                return item_data.quality.name
                            end)
                            
                            if success and name then
                                quality_name_for_tag = name
                                quality_name_lower = string.lower(name)
                            elseif type(item_data.quality) == "string" then
                                quality_name_for_tag = item_data.quality
                                quality_name_lower = string.lower(item_data.quality)
                            end
                        end
                        
                        -- Determine if this is in the last column of the table (rightmost position)
                        local is_last_column = (idx == max_items_per_row)

                        -- Create icon container flow for sprite button with quality overlay (similar to map GUI)
                        -- Add flow to table cell - the filter_slot_table style provides the grid background
                        local icon_container = equipment_table.add{
                            type = "flow"
                        }
                        icon_container.style.width = 40
                        icon_container.style.height = 40
                        icon_container.style.padding = 0
                        icon_container.style.margin = 0
                        icon_container.style.horizontally_stretchable = false
                        icon_container.style.vertically_stretchable = false

                        -- Add right margin ONLY to items in the last column (rightmost) if they have quality overlay
                        if is_last_column and quality_name_lower ~= "normal" then
                            icon_container.style.right_margin = 14
                        end
                        
                        -- Add sprite button inside container (no style, just explicit size like map GUI)
                        local equipment_button = icon_container.add{
                            type = "sprite-button",
                            name = button_name,
                            sprite = icon_sprite,
                            tooltip = tooltip_text,
                            enabled = true,
                            tags = {
                                equipment_name = item_data.equipment_name,
                                item_name = item_data.item_name,
                                inventory_index = item_data.index,
                                quality = item_data.quality,
                                quality_name = quality_name_for_tag
                            }
                        }
                        equipment_button.style.size = 40
                        equipment_button.style.padding = 0
                        equipment_button.style.margin = 0

                        -- Add quality overlay if quality is not Normal
                        if quality_name_lower ~= "normal" then
                            local overlay_name = "sl-" .. quality_name_lower
                            
                            local success, quality_overlay = pcall(function()
                                return icon_container.add{
                                    type = "sprite",
                                    sprite = overlay_name,
                                    tooltip = quality_name_for_tag .. " quality"
                                }
                            end)
                            
                            if success and quality_overlay then
                                quality_overlay.style.size = 14
                                quality_overlay.style.top_padding = 23
                                quality_overlay.style.left_padding = -40  -- Stay within button bounds for all items
                            end
                        end
                    end  -- Close if item_prototype then
                end  -- Close for idx, item_data in ipairs(group) do

                -- Pad the row with empty cells if needed (to maintain grid structure)
                local items_in_row = #group
                if items_in_row < max_items_per_row then
                    for i = items_in_row + 1, max_items_per_row do
                        equipment_table.add{
                            type = "empty-widget"
                        }
                    end
                end
            end  -- Close for _, equipment_name in ipairs(sorted_equipment_names) do
        end
    end  -- Close if #equipment_items > 0 then
    
    return toolbar_frame
end

-- Refresh equipment toolbar counts
function equipment_grid_fill.refresh_equipment_toolbar(player)
    if not player or not player.valid then
        return
    end
    
    -- Check if equipment grid is still open before refreshing
    local grid, inventory, stack_index = equipment_grid_fill.get_equipment_grid_context(player)
    if not grid or not grid.valid then
        -- Grid is closed, don't refresh (toolbar will be removed by remove_fill_button)
        return
    end
    
    local relative_gui = player.gui.relative
    if not relative_gui then
        return
    end
    
    -- Store whether toolbar exists before destroying
    local equipment_toolbar = relative_gui[equipment_grid_fill.EQUIPMENT_TOOLBAR_NAME]
    local toolbar_existed = equipment_toolbar and equipment_toolbar.valid
    
    -- Remove existing toolbar and recreate with new row-based structure
    if toolbar_existed then
        equipment_toolbar.destroy()
    end
    
    -- Recreate the toolbar with updated structure - this will always recreate if grid is open
    local result = equipment_grid_fill.get_or_create_fill_button(player)
    
    -- If toolbar existed but wasn't recreated, something went wrong - try again
    if toolbar_existed and result then
        local new_toolbar = relative_gui[equipment_grid_fill.EQUIPMENT_TOOLBAR_NAME]
        if not new_toolbar or not new_toolbar.valid then
            -- Toolbar wasn't recreated, try one more time
            equipment_grid_fill.get_or_create_fill_button(player)
        end
    end
end

-- Remove the fill button and equipment toolbar
function equipment_grid_fill.remove_fill_button(player)
    if not player or not player.valid then
        return
    end
    
    local relative_gui = player.gui.relative
    if not relative_gui then
        return
    end
    
    local button = relative_gui[equipment_grid_fill.BUTTON_NAME]
    if button and button.valid then
        button.destroy()
    end
    
    local equipment_toolbar = relative_gui[equipment_grid_fill.EQUIPMENT_TOOLBAR_NAME]
    if equipment_toolbar and equipment_toolbar.valid then
        equipment_toolbar.destroy()
    end
end

-- Find the item that places a given equipment (reverse lookup of place_as_equipment_result)
function equipment_grid_fill.find_item_for_equipment(equipment_name, equipment_quality)
    if not equipment_name then
        return nil
    end
    
    -- Search through all item prototypes to find one that places this equipment
    for item_name, item_prototype in pairs(prototypes.item) do
        if item_prototype and item_prototype.place_as_equipment_result then
            local place_result = item_prototype.place_as_equipment_result
            local result_equipment_name = nil
            
            -- Extract equipment name from place_result
            if type(place_result) == "string" then
                result_equipment_name = place_result
            elseif place_result and place_result.name then
                result_equipment_name = place_result.name
            end
            
            -- Check if this item places the equipment we're looking for
            if result_equipment_name == equipment_name then
                return item_name
            end
        end
    end
    
    return nil
end

-- Handle button click - fill equipment ghosts and remove marked equipment
function equipment_grid_fill.on_fill_button_click(player)
    -- game.print("[EQUIP FILL CLICK] on_fill_button_click called")
    if not player or not player.valid then
        -- game.print("[EQUIP FILL CLICK] Player invalid")
        return
    end
    
    -- game.print("[EQUIP FILL CLICK] Getting equipment grid context...")
    local grid, inventory, stack_index = equipment_grid_fill.get_equipment_grid_context(player)
    if not grid or not grid.valid then
        -- game.print("[EQUIP FILL CLICK] Could not find equipment grid")
        player.print("Could not find equipment grid")
        return
    end
    -- game.print("[EQUIP FILL CLICK] Found grid, inventory=" .. tostring(inventory ~= nil))
    
    -- Use the inventory from get_equipment_grid_context
    -- This should now be correctly found using itemstack_owner
    local target_inventory = inventory  -- From get_equipment_grid_context
    
    if not target_inventory then
        -- game.print("[EQUIP FILL CLICK] Could not find inventory")
        player.print("Could not find inventory containing the vehicle item")
        return
    end
    -- game.print("[EQUIP FILL CLICK] Found target inventory")
    
    -- First, handle equipment marked for deconstruction or removal
    -- Do this BEFORE filling ghosts
    local removed_count = 0
    
    -- Create a list of equipment marked for removal
    local equipment_to_remove = {}
    for _, equipment in pairs(grid.equipment) do
        if equipment and equipment.valid then
            -- Skip ghosts - they're handled separately
            local is_ghost = false
            if equipment.prototype and equipment.prototype.type == "equipment-ghost" then
                is_ghost = true
            elseif equipment.name and (equipment.name:match("%-ghost$") or equipment.name == "equipment-ghost") then
                is_ghost = true
            end
            
            if not is_ghost then
                -- Check if equipment is marked for removal
                -- Equipment in grids use to_be_removed, not to_be_deconstructed
                local is_marked = false
                
                local success_check, to_be_removed = pcall(function()
                    return equipment.to_be_removed
                end)
                
                if success_check and to_be_removed then
                    is_marked = true
                end
                
                -- Only add to removal list if actually marked
                if is_marked then
                    table.insert(equipment_to_remove, equipment)
                end
            end
        end
    end
    
    -- Remove marked equipment using grid.take() and add items back to inventory
    -- IMPORTANT: After grid.take(), the equipment becomes invalid, so store name first
    -- We need to check space and remove one at a time, re-checking after each removal
    local failed_removals = {}

    for _, equipment in ipairs(equipment_to_remove) do
        if equipment and equipment.valid then
            local equipment_name = equipment.name
            local equipment_quality = equipment.quality  -- CAPTURE QUALITY BEFORE REMOVAL
            
            -- Find the item that places this equipment to get the item name
            local item_name = equipment_grid_fill.find_item_for_equipment(equipment_name)
            if not item_name then
                item_name = equipment_name
            end
            
            -- Check if we can insert this item into inventory before removing
            local item_prototype = prototypes.item[item_name]
            if item_prototype then
                -- Create test item with quality
                local test_item = {name = item_name, count = 1}
                if equipment_quality then
                    test_item.quality = equipment_quality
                end
                
                -- Test if we can insert at least 1 of this item with quality
                local test_insert = target_inventory.insert(test_item)
                if test_insert == 0 then
                    -- Cannot insert - inventory is full, skip this equipment
                    table.insert(failed_removals, {
                        name = item_name,
                        equipment = equipment
                    })
                    goto continue
                end
                
                -- Remove the test item we just inserted (search by name and quality)
                for i = 1, #target_inventory do
                    local stack = target_inventory[i]
                    if stack and stack.valid_for_read and stack.name == item_name then
                        -- Check quality match
                        local stack_quality_matches = true
                        if equipment_quality then
                            local stack_quality_name = stack.quality and stack.quality.name or "normal"
                            local equip_quality_name = equipment_quality.name or "normal"
                            stack_quality_matches = (stack_quality_name == equip_quality_name)
                        elseif stack.quality then
                            stack_quality_matches = false
                        end
                        
                        if stack_quality_matches then
                            stack.count = stack.count - 1
                            break
                        end
                    end
                end
            end
            
            -- Remove the equipment (grid.take returns SimpleItemStack without quality)
            local success_take, item_result = pcall(function()
                return grid.take({equipment = equipment, by_player = player})
            end)
            
            if success_take and item_result then
                -- Successfully took the equipment (equipment is now invalid)
                -- Re-apply the quality we captured earlier
                if equipment_quality then
                    item_result.quality = equipment_quality
                end
                
                -- Try to insert into inventory with quality
                local success_insert, inserted = pcall(function()
                    return target_inventory.insert(item_result)
                end)
                
                if success_insert and inserted and inserted > 0 then
                    removed_count = removed_count + 1
                else
                    -- Failed to insert despite pre-check
                    table.insert(failed_removals, {
                        name = item_name,
                        equipment = nil
                    })
                end
            end
            
            ::continue::
        end
    end
    
    -- Notify user about items that can't be removed due to full inventory
    if #failed_removals > 0 then
        local failed_messages = {}
        for _, failed in ipairs(failed_removals) do
            table.insert(failed_messages, failed.name)
        end
        player.print("Warning: Could not remove " .. table.concat(failed_messages, ", ") .. " - inventory is full. Make space and try again.")
    end
    
    -- Get ghost equipment (validate on click)
    local ghosts = equipment_grid_fill.get_ghost_equipment(grid)
    
    if #ghosts == 0 then
        if removed_count > 0 then
            -- Refresh toolbar since items were added back to inventory
            equipment_grid_fill.refresh_equipment_toolbar(player)
        end
        return
    end
    
    -- Fill each ghost (we search per-ghost now, so we don't need pre-computed matches)
    local filled_count = 0
    for idx, ghost in ipairs(ghosts) do
        -- Get ghost quality for matching - try both stored and direct from equipment
        local ghost_quality_name = "normal"
        local quality_obj = nil
        
        -- Helper function to extract quality name from quality object
        local function get_quality_name(quality)
            if not quality then
                return "normal"
            end
            
            -- Try to access .name property (works for userdata/LuaQualityPrototype and tables)
            local success, name = pcall(function()
                return quality.name
            end)
            
            if success and name then
                return string.lower(name)
            end
            
            -- Fallback: if it's a string
            if type(quality) == "string" then
                return string.lower(quality)
            end
            
            return "normal"
        end
        
        -- First try to get quality directly from equipment object (most reliable)
        if ghost.equipment and ghost.equipment.valid and ghost.equipment.quality then
            quality_obj = ghost.equipment.quality
            ghost_quality_name = get_quality_name(quality_obj)
        -- Fallback to stored quality
        elseif ghost.quality then
            quality_obj = ghost.quality
            ghost_quality_name = get_quality_name(quality_obj)
        end
        
        -- Find a matching item with the correct quality for this specific ghost
        -- Don't rely on pre-computed matches since they might have wrong quality
        local match = nil
        local match_stack = nil
        local match_index = nil
        
        -- Search inventory for item that places this equipment with matching quality
        local checked_slots = 0
        for i = 1, #target_inventory do
            local stack = target_inventory[i]
            if stack and stack.valid_for_read then
                local item_prototype = prototypes.item[stack.name]
                if item_prototype and item_prototype.place_as_equipment_result then
                    local place_result = item_prototype.place_as_equipment_result
                    local result_equipment_name = nil
                    
                    -- Extract equipment name from place_result
                    if type(place_result) == "string" then
                        result_equipment_name = place_result
                    elseif place_result and place_result.name then
                        result_equipment_name = place_result.name
                    end
                    
                    -- Check if this item places the equipment we need
                    if result_equipment_name == ghost.base_equipment_name then
                        checked_slots = checked_slots + 1
                        local stack_quality_name = "normal"
                        if stack.quality then
                            stack_quality_name = string.lower(stack.quality.name)
                        end
                        
                        if stack_quality_name == ghost_quality_name then
                            match = {
                                item_name = stack.name,
                                quality = stack.quality,
                                count = stack.count
                            }
                            match_stack = stack
                            match_index = i
                            break
                        end
                    end
                end
            end
        end
        
        if not match or not match_stack or match.count == 0 then
            goto continue
        end
        
        -- Get the equipment name from the item's place_as_equipment_result
        local item_prototype = prototypes.item[match.item_name]
        local equipment_name = ghost.base_equipment_name
        if item_prototype and item_prototype.place_as_equipment_result then
            local place_result = item_prototype.place_as_equipment_result
            if type(place_result) == "string" then
                equipment_name = place_result
            elseif place_result and place_result.name then
                equipment_name = place_result.name
            end
        end
        
        -- First, remove the ghost equipment
        local success_remove = pcall(function()
            if ghost.equipment and ghost.equipment.valid then
                ghost.equipment.destroy()
            end
        end)
        
        -- Prepare grid.put() data with quality from the ghost
        -- grid.put() will consume the correct quality item from inventory
        local put_data = {
            name = equipment_name,
            position = ghost.position
        }
        
        -- Use the ghost's quality (inherited from the ghost, not defaulting to normal)
        if quality_obj then
            put_data.quality = quality_obj
        end
        
        -- Try to place the equipment with quality - it will consume from inventory
        local success, placed = pcall(function()
            return grid.put(put_data)
        end)
        
        if success and placed then
            -- Remove the item from inventory (grid.put() consumed it, but we need to update our tracking)
            if match_stack.count > 0 then
                match_stack.count = match_stack.count - 1
            end
            filled_count = filled_count + 1
        elseif success_remove and not placed then
            -- Ghost was removed but equipment couldn't be placed at position
            -- Try to place it anywhere in the grid with quality from ghost
            local put_data_anywhere = {
                name = equipment_name
            }
            
            -- Use the ghost's quality (inherited from the ghost)
            if quality_obj then
                put_data_anywhere.quality = quality_obj
            end
            
            local success_anywhere, placed_anywhere = pcall(function()
                return grid.put(put_data_anywhere)
            end)
            
            if success_anywhere and placed_anywhere then
                -- Remove one item from the matched stack
                if match_stack.count > 0 then
                    match_stack.count = match_stack.count - 1
                end
                filled_count = filled_count + 1
            end
        end
        
        ::continue::
    end
    
    -- game.print("[EQUIP FILL CLICK] Finished filling. Total filled: " .. filled_count)
    local messages = {}
    if removed_count > 0 then
        --table.insert(messages, "Removed " .. removed_count .. " equipment item(s)")
    end
    
    if #messages > 0 then
        player.print(table.concat(messages, ", "))
    elseif removed_count == 0 then
        --player.print("Could not fill any equipment ghosts")
    end
    
    -- Refresh the equipment toolbar to update counts
    equipment_grid_fill.refresh_equipment_toolbar(player)
end

-- Handle equipment item button click - place the correct quality item in player's hand
function equipment_grid_fill.on_equipment_item_click(player, button_name, tags)
    if not player or not player.valid then
        return
    end
    
    -- Get the inventory from equipment grid context first
    local grid, inventory, stack_index = equipment_grid_fill.get_equipment_grid_context(player)
    if not inventory then
        return
    end
    
    -- Use the inventory_index from tags to directly access the stack
    local inventory_index = tags and tags.inventory_index
    local found_stack = nil
    
    if inventory_index and inventory_index > 0 and inventory_index <= #inventory then
        local stack = inventory[inventory_index]
        if stack and stack.valid_for_read then
            -- Verify the item matches what we expect
            local expected_item_name = tags and tags.item_name
            if expected_item_name and stack.name == expected_item_name then
                found_stack = stack
            end
        end
    end
    
    -- Fallback: if direct index didn't work, search by item name and quality from button name
    if not found_stack or not found_stack.valid_for_read or found_stack.count == 0 then
        
        -- Extract quality from button name (format: toolbar_name_equipment_name_quality)
        local item_name = tags and tags.item_name
        if item_name then
            -- Extract quality from button name - it's the last part after the last underscore
            local quality_from_button = "normal"
            local parts = {}
            for part in string.gmatch(button_name, "([^_]+)") do
                table.insert(parts, part)
            end
            if #parts >= 3 then
                quality_from_button = string.lower(parts[#parts])
            end
            
            -- Search inventory for matching item and quality
            for i = 1, #inventory do
                local stack = inventory[i]
                if stack and stack.valid_for_read and stack.name == item_name then
                    local stack_quality = "normal"
                    if stack.quality then
                        stack_quality = string.lower(stack.quality.name)
                    end
                    
                    
                    if stack_quality == quality_from_button then
                        found_stack = stack
                        break
                    end
                end
            end
        end
    end
    
    if not found_stack or not found_stack.valid_for_read or found_stack.count == 0 then
        return
    end
    
    -- Clear cursor stack first (ghosts take priority but let's be safe)
    local cursor_stack = player.cursor_stack
    if cursor_stack and cursor_stack.valid and cursor_stack.valid_for_read then
        cursor_stack.clear()
    end
    
    -- Prepare ghost data with quality - use the actual stack data directly
    -- For equipment items, we use cursor_ghost so player can place it in the grid
    local ghost_data = {name = found_stack.name}
    
    -- Use the quality object directly from the stack (most reliable - actual data, not tags)
    if found_stack.quality then
        ghost_data.quality = found_stack.quality
    end
    
    -- Set cursor ghost (this allows placing equipment in the grid)
    pcall(function()
        player.cursor_ghost = ghost_data
    end)
    
    -- Note: We don't remove the item from inventory when setting a ghost
    -- The item will be consumed when the player actually places the ghost in the grid
    -- Don't refresh toolbar here - it might close the GUI, and counts don't change until item is placed
    -- The toolbar will be refreshed automatically when the equipment grid GUI is reopened
end

-- Handle cargo pod button click
function equipment_grid_fill.on_cargo_pod_button_click(player)
    if not player or not player.valid then
        return
    end
    
    -- Get the current surface before closing GUI (in case it changes)
    local current_surface = player.surface
    
    -- Close the equipment grid GUI
    if player.opened then
        player.opened = nil
    end
    
    -- Wait a tick before showing menu to ensure GUI state is stable
    -- Use pending_deployment mechanism for consistency
    storage.pending_deployment = storage.pending_deployment or {}
    
    -- Check if player is on a platform surface - switch to planet and open map GUI
    if current_surface and current_surface.platform then
        -- Extract the planet name from the platform's space_location
        local planet_name = nil
        if current_surface.platform.space_location then
            local location_str = tostring(current_surface.platform.space_location)
            planet_name = location_str:match(": ([^%(]+) %(planet%)")
        end
        
        if planet_name then
            -- Get the planet surface
            local planet_surface = game.get_surface(planet_name)
            if planet_surface then
                -- Open map view at 0,0 on the planet surface
                local target_position = {x = 0, y = 0}
                player.set_controller{
                    type = defines.controllers.remote,
                    surface = planet_surface,
                    position = target_position
                }

                -- Store data needed for next tick
                storage.pending_deployment[player.index] = {
                    planet_surface = planet_surface,
                    planet_name = planet_name
                }
                return
            end
        else
            player.print("Vehicle Deployment is not possible while the platform is in transit")
            return
        end
    end
    
    -- For non-platform surfaces, store pending deployment to show menu next tick
    -- This ensures GUI state is stable
    if current_surface then
        storage.pending_deployment[player.index] = {
            planet_surface = current_surface,
            planet_name = current_surface.name
        }
    end
end

return equipment_grid_fill

