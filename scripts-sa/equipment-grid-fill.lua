-- scripts-sa/equipment-grid-fill.lua
-- Feature to auto-fill equipment grid ghosts from inventory

local vehicles_list = require("scripts-sa.vehicles-list")

local equipment_grid_fill = {}

-- Button name constant
equipment_grid_fill.BUTTON_NAME = "spider_launcher_equipment_fill_button"

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
            table.insert(ghosts, {
                ghost_name = equipment.name,
                base_equipment_name = base_equipment_name,
                position = {x = equipment.position.x, y = equipment.position.y},
                equipment = equipment,
                quality = equipment.quality
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
                        local stack_quality = "Normal"
                        if stack.quality then
                            stack_quality = stack.quality.name
                        end
                        local ghost_quality_name = "Normal"
                        if type(ghost_data.quality) == "table" and ghost_data.quality.name then
                            ghost_quality_name = ghost_data.quality.name
                        elseif type(ghost_data.quality) == "string" then
                            ghost_quality_name = ghost_data.quality
                        end
                        -- Normalize quality names for comparison (case-insensitive)
                        stack_quality = string.lower(stack_quality)
                        ghost_quality_name = string.lower(ghost_quality_name)
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
    
    -- Check if button already exists
    local button = relative_gui[equipment_grid_fill.BUTTON_NAME]
    if button and button.valid then
        -- game.print("[EQUIP FILL] Button already exists")
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
    toolbar_frame.style.top_padding = 3
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
        tooltip_text = {"", "Fill ", fillable_count, " equipment ghost(s) from inventory"}
    elseif #ghosts > 0 then
        tooltip_text = {"", "No matching equipment items in inventory (", #ghosts, " ghost(s) need filling)"}
    else
        tooltip_text = "Fill equipment ghosts from inventory"
    end
    
    local fill_button = button_flow.add{
        type = "sprite-button",
        name = equipment_grid_fill.BUTTON_NAME .. "_btn",
        sprite = "utility/confirm_slot",
        style = "slot_sized_button",
        tooltip = tooltip_text,
        enabled = true  -- Always enabled - validation happens on click
    }
    
    -- game.print("[EQUIP FILL] Button created successfully, fillable_count=" .. fillable_count .. ", total_ghosts=" .. #ghosts)
    return toolbar_frame
end

-- Remove the fill button
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
end

-- Handle button click - fill equipment ghosts
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
    
    -- Get ghost equipment (validate on click)
    -- game.print("[EQUIP FILL CLICK] Getting ghost equipment...")
    local ghosts = equipment_grid_fill.get_ghost_equipment(grid)
    -- game.print("[EQUIP FILL CLICK] Found " .. #ghosts .. " ghost equipment")
    if #ghosts == 0 then
        -- game.print("[EQUIP FILL CLICK] No ghost equipment found")
        player.print("No ghost equipment found in grid")
        return
    end
    
    -- Use the inventory from get_equipment_grid_context
    -- This should now be correctly found using itemstack_owner
    local target_inventory = inventory  -- From get_equipment_grid_context
    
    if not target_inventory then
        -- game.print("[EQUIP FILL CLICK] Could not find inventory")
        player.print("Could not find inventory containing the vehicle item")
        return
    end
    -- game.print("[EQUIP FILL CLICK] Found target inventory")
    
    -- Find matching items (validate on click)
    -- game.print("[EQUIP FILL CLICK] Finding matching items...")
    local matches = equipment_grid_fill.find_matching_items(target_inventory, ghosts)
    if not matches or next(matches) == nil then
        -- game.print("[EQUIP FILL CLICK] No matching items found")
        player.print("No matching equipment items found in inventory")
        return
    end
    -- game.print("[EQUIP FILL CLICK] Found matching items")
    
    -- Count how many ghosts can actually be filled
    local fillable_count = 0
    for _, ghost in ipairs(ghosts) do
        if matches[ghost.base_equipment_name] and matches[ghost.base_equipment_name].count > 0 then
            fillable_count = fillable_count + 1
        end
    end
    -- game.print("[EQUIP FILL CLICK] Fillable count: " .. fillable_count)
    
    if fillable_count == 0 then
        -- game.print("[EQUIP FILL CLICK] No ghosts can be filled")
        player.print("No ghost equipment can be filled with available items")
        return
    end
    
    -- game.print("[EQUIP FILL CLICK] Starting to fill " .. fillable_count .. " ghost(s)...")
    
    -- Fill each ghost
    local filled_count = 0
    for idx, ghost in ipairs(ghosts) do
        local match = matches[ghost.base_equipment_name]
        if match and match.count > 0 then
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
            
            -- Then try to place the real equipment at the ghost's position
            local success, placed = pcall(function()
                return grid.put({
                    name = equipment_name,
                    position = ghost.position
                })
            end)
            
            if success and placed then
                -- Remove one item from inventory (using the item name, not equipment name)
                for i = 1, #target_inventory do
                    local inv_stack = target_inventory[i]
                    if inv_stack and inv_stack.valid_for_read and inv_stack.name == match.item_name then
                        local stack_quality = "Normal"
                        if inv_stack.quality then
                            stack_quality = inv_stack.quality.name
                        end
                        local target_quality = "Normal"
                        if match.quality then
                            target_quality = match.quality.name
                        end
                        
                        if stack_quality == target_quality then
                            inv_stack.count = inv_stack.count - 1
                            filled_count = filled_count + 1
                            match.count = match.count - 1
                            break
                        end
                    end
                end
                
                -- Update matches if count reached 0
                if match.count <= 0 then
                    matches[ghost.base_equipment_name] = nil
                end
            elseif success_remove and not placed then
                -- Ghost was removed but equipment couldn't be placed at position
                -- Try to place it anywhere in the grid
                local success_anywhere, placed_anywhere = pcall(function()
                    return grid.put({name = equipment_name})
                end)
                
                if success_anywhere and placed_anywhere then
                    -- Remove one item from inventory
                    for i = 1, #target_inventory do
                        local inv_stack = target_inventory[i]
                        if inv_stack and inv_stack.valid_for_read and inv_stack.name == match.item_name then
                            local stack_quality = "Normal"
                            if inv_stack.quality then
                                stack_quality = inv_stack.quality.name
                            end
                            local target_quality = "Normal"
                            if match.quality then
                                target_quality = match.quality.name
                            end
                            
                            if stack_quality == target_quality then
                                inv_stack.count = inv_stack.count - 1
                                filled_count = filled_count + 1
                                match.count = match.count - 1
                                break
                            end
                        end
                    end
                    
                    if match.count <= 0 then
                        matches[ghost.base_equipment_name] = nil
                    end
                end
            end
        end
    end
    
    -- game.print("[EQUIP FILL CLICK] Finished filling. Total filled: " .. filled_count)
    if filled_count > 0 then
        player.print("Filled " .. filled_count .. " equipment ghost(s)")
    else
        player.print("Could not fill any equipment ghosts")
    end
end

return equipment_grid_fill

