-- scripts-sa/container-deployment.lua
-- Remote deployment of robots and spider vehicles from containers

local vehicles_list = require("scripts-sa.vehicles-list")

local container_deployment = {}

-- GUI element names
container_deployment.FRAME_NAME = "container_remote_deployment_frame"
container_deployment.BUTTON_PREFIX = "container_deploy_btn_"

-- Check if container has deployable items (spider vehicles or bots)
function container_deployment.has_deployable_items(container)
    if not container or not container.valid then
        return false
    end
    
    local inventory = container.get_inventory(defines.inventory.chest)
    if not inventory then
        return false
    end
    
    for i = 1, #inventory do
        local stack = inventory[i]
        if stack and stack.valid_for_read then
            -- Check if it's a spider vehicle
            if vehicles_list.is_spider_vehicle(stack.name) then
                return true
            end
            
            -- Check if it's a deployable bot
            if stack.name == "construction-robot" or stack.name == "logistic-robot" then
                return true
            end
        end
    end
    
    return false
end

-- Scan container inventory for deployable items
-- Returns: {vehicles = {...}, construction_bots = {...}, logistic_bots = {...}}
function container_deployment.scan_deployable_items(container)
    local result = {
        vehicles = {},
        construction_bots = {},
        logistic_bots = {}
    }
    
    if not container or not container.valid then
        return result
    end
    
    local inventory = container.get_inventory(defines.inventory.chest)
    if not inventory then
        return result
    end
    
    -- Scan inventory
    for i = 1, #inventory do
        local stack = inventory[i]
        if stack and stack.valid_for_read then
            local item_name = stack.name
            local item_prototype = prototypes.item[item_name]
            
            if item_prototype then
                local stack_size = item_prototype.stack_size
                local is_entity_data = item_prototype.type == "item-with-entity-data"
                
                -- Spider vehicles
                if vehicles_list.is_spider_vehicle(item_name) then
                    table.insert(result.vehicles, {
                        name = item_name,
                        stack = stack,
                        index = i,
                        count = stack.count,
                        quality = stack.quality,
                        stack_size = stack_size,
                        is_entity_data = is_entity_data,
                        entity_label = stack.entity_label or nil,
                        entity_color = stack.entity_color or nil
                    })
                -- Construction robots
                elseif item_name == "construction-robot" then
                    -- Group by quality
                    local quality_name = stack.quality and stack.quality.name or "Normal"
                    local existing = nil
                    for _, bot in ipairs(result.construction_bots) do
                        if bot.quality_name == quality_name then
                            existing = bot
                            break
                        end
                    end
                    
                    if existing then
                        existing.count = existing.count + stack.count
                    else
                        table.insert(result.construction_bots, {
                            name = item_name,
                            quality = stack.quality,
                            quality_name = quality_name,
                            count = stack.count,
                            stack_size = stack_size
                        })
                    end
                -- Logistic robots
                elseif item_name == "logistic-robot" then
                    -- Group by quality
                    local quality_name = stack.quality and stack.quality.name or "Normal"
                    local existing = nil
                    for _, bot in ipairs(result.logistic_bots) do
                        if bot.quality_name == quality_name then
                            existing = bot
                            break
                        end
                    end
                    
                    if existing then
                        existing.count = existing.count + stack.count
                    else
                        table.insert(result.logistic_bots, {
                            name = item_name,
                            quality = stack.quality,
                            quality_name = quality_name,
                            count = stack.count,
                            stack_size = stack_size
                        })
                    end
                end
            end
        end
    end
    
    -- Sort by quality level
    local function sort_by_quality(a, b)
        local level_a = a.quality and a.quality.level or 0
        local level_b = b.quality and b.quality.level or 0
        return level_a < level_b
    end
    
    table.sort(result.construction_bots, sort_by_quality)
    table.sort(result.logistic_bots, sort_by_quality)
    
    return result
end

-- Get or create deployment GUI for container
function container_deployment.get_or_create_gui(player, container)
    if not player or not player.valid then
        return nil
    end
    
    if not container or not container.valid then
        return nil
    end
    
    -- Check if container has deployable items
    if not container_deployment.has_deployable_items(container) then
        container_deployment.remove_gui(player)
        return nil
    end
    
    local relative_gui = player.gui.relative
    if not relative_gui then
        return nil
    end
    
    -- Check if GUI already exists
    local existing_frame = relative_gui[container_deployment.FRAME_NAME]
    if existing_frame and existing_frame.valid then
        return existing_frame
    end
    
    -- Scan for deployable items
    local items = container_deployment.scan_deployable_items(container)
    
    -- Create GUI frame anchored to container
    local anchor = {
        gui = defines.relative_gui_type.container_gui,
        position = defines.relative_gui_position.right
    }
    
    local frame = relative_gui.add{
        type = "frame",
        name = container_deployment.FRAME_NAME,
        direction = "vertical",
        anchor = anchor
    }
    
    frame.style.horizontally_stretchable = false
    frame.style.vertically_stretchable = false
    
    -- Title
    local title_flow = frame.add{
        type = "flow",
        direction = "horizontal"
    }
    title_flow.style.horizontal_align = "center"
    title_flow.style.horizontally_stretchable = true
    
    title_flow.add{
        type = "label",
        caption = {"string-mod-setting.remote-deployment"},
        style = "frame_title"
    }
    
    -- Content frame
    local content_frame = frame.add{
        type = "frame",
        direction = "vertical",
        style = "inside_shallow_frame"
    }
    content_frame.style.padding = 8
    
    -- Scroll pane
    local scroll_pane = content_frame.add{
        type = "scroll-pane",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "auto"
    }
    scroll_pane.style.maximal_height = 400
    scroll_pane.style.minimal_width = 300
    
    -- Table for sprite buttons (5 per row, like equipment toolbar)
    local button_table = scroll_pane.add{
        type = "table",
        name = "deployment_buttons_table",
        column_count = 7,
        style = "filter_slot_table"
    }
    
    local button_count = 0
    
    -- Add vehicle buttons (sprite buttons with icons)
    for _, vehicle in ipairs(items.vehicles) do
        local button_name = container_deployment.BUTTON_PREFIX .. "vehicle_" .. vehicle.index
        local icon_sprite = "item/" .. vehicle.name
        
        local tooltip_text = vehicle.entity_label or vehicle.name
        if vehicle.count > 1 then
            tooltip_text = {"", tooltip_text, " - ", vehicle.count, "x"}
        end
        
        local quality_name_lower = "normal"
        if vehicle.quality then
            quality_name_lower = string.lower(vehicle.quality.name)
        end
        
        -- Icon container with quality overlay
        local icon_container = button_table.add{
            type = "flow"
        }
        icon_container.style.width = 40
        icon_container.style.height = 40
        icon_container.style.padding = 0
        icon_container.style.margin = 0
        
        local sprite_button = icon_container.add{
            type = "sprite-button",
            name = button_name,
            sprite = icon_sprite,
            tooltip = tooltip_text,
            tags = {
                deploy_type = "vehicle",
                item_name = vehicle.name,
                inventory_index = vehicle.index,
                stack_size = vehicle.stack_size,
                is_entity_data = vehicle.is_entity_data,
                count = vehicle.count,
                quality_name = vehicle.quality and vehicle.quality.name or "Normal"
            }
        }
        sprite_button.style.size = 40
        sprite_button.style.padding = 0
        
        -- Quality overlay
        if quality_name_lower ~= "normal" then
            local overlay_name = "sl-" .. quality_name_lower
            local quality_overlay = icon_container.add{
                type = "sprite",
                sprite = overlay_name,
                tooltip = vehicle.quality.name .. " quality"
            }
            quality_overlay.style.size = 14
            quality_overlay.style.top_padding = 23
            quality_overlay.style.left_padding = -40
        end
        
        button_count = button_count + 1
    end
    
    -- Add construction bot buttons
    for _, bot in ipairs(items.construction_bots) do
        local button_name = container_deployment.BUTTON_PREFIX .. "construction_" .. bot.quality_name
        local icon_sprite = "item/construction-robot"
        
        local tooltip_text = "Construction Robot"
        if bot.quality_name ~= "Normal" then
            tooltip_text = {"", tooltip_text, " [", bot.quality_name, "]"}
        end
        if bot.count > 1 then
            tooltip_text = {"", tooltip_text, " - ", bot.count, "x"}
        end
        
        local quality_name_lower = string.lower(bot.quality_name)
        
        -- Icon container with quality overlay
        local icon_container = button_table.add{
            type = "flow"
        }
        icon_container.style.width = 40
        icon_container.style.height = 40
        icon_container.style.padding = 0
        icon_container.style.margin = 0
        
        local sprite_button = icon_container.add{
            type = "sprite-button",
            name = button_name,
            sprite = icon_sprite,
            tooltip = tooltip_text,
            tags = {
                deploy_type = "bot",
                item_name = "construction-robot",
                quality_name = bot.quality_name,
                count = bot.count,
                stack_size = bot.stack_size
            }
        }
        sprite_button.style.size = 40
        sprite_button.style.padding = 0
        
        -- Quality overlay
        if quality_name_lower ~= "normal" then
            local overlay_name = "sl-" .. quality_name_lower
            local quality_overlay = icon_container.add{
                type = "sprite",
                sprite = overlay_name,
                tooltip = bot.quality_name .. " quality"
            }
            quality_overlay.style.size = 14
            quality_overlay.style.top_padding = 23
            quality_overlay.style.left_padding = -40
        end
        
        button_count = button_count + 1
    end
    
    -- Add logistic bot buttons
    for _, bot in ipairs(items.logistic_bots) do
        local button_name = container_deployment.BUTTON_PREFIX .. "logistic_" .. bot.quality_name
        local icon_sprite = "item/logistic-robot"
        
        local tooltip_text = "Logistic Robot"
        if bot.quality_name ~= "Normal" then
            tooltip_text = {"", tooltip_text, " [", bot.quality_name, "]"}
        end
        if bot.count > 1 then
            tooltip_text = {"", tooltip_text, " - ", bot.count, "x"}
        end
        
        local quality_name_lower = string.lower(bot.quality_name)
        
        -- Icon container with quality overlay
        local icon_container = button_table.add{
            type = "flow"
        }
        icon_container.style.width = 40
        icon_container.style.height = 40
        icon_container.style.padding = 0
        icon_container.style.margin = 0
        
        local sprite_button = icon_container.add{
            type = "sprite-button",
            name = button_name,
            sprite = icon_sprite,
            tooltip = tooltip_text,
            tags = {
                deploy_type = "bot",
                item_name = "logistic-robot",
                quality_name = bot.quality_name,
                count = bot.count,
                stack_size = bot.stack_size
            }
        }
        sprite_button.style.size = 40
        sprite_button.style.padding = 0
        
        -- Quality overlay
        if quality_name_lower ~= "normal" then
            local overlay_name = "sl-" .. quality_name_lower
            local quality_overlay = icon_container.add{
                type = "sprite",
                sprite = overlay_name,
                tooltip = bot.quality_name .. " quality"
            }
            quality_overlay.style.size = 14
            quality_overlay.style.top_padding = 23
            quality_overlay.style.left_padding = -40
        end
        
        button_count = button_count + 1
    end
    
    -- Fill remaining row with empty widgets
    local remainder = button_count % 7
    if remainder > 0 then
        for i = remainder + 1, 7 do
            button_table.add{type = "empty-widget"}
        end
    end
    
    -- Separator
    -- local separator = content_frame.add{
    --     type = "line",
    --     direction = "horizontal"
    -- }
    -- separator.style.top_margin = 8
    -- separator.style.bottom_margin = 8

    local spacer = content_frame.add{
        type = "empty-widget"
    }
    spacer.style.height = 8
    
    -- Settings section (slider for quantity selection) - initially hidden
    local settings_frame = content_frame.add{
        type = "frame",
        name = "deployment_settings_section",
        direction = "vertical",
        style = "inside_shallow_frame"
    }
    settings_frame.style.padding = 8
    settings_frame.visible = false
    
    -- Selected item display
    local selected_item_flow = settings_frame.add{
        type = "flow",
        direction = "horizontal"
    }
    selected_item_flow.style.vertical_align = "center"
    selected_item_flow.style.bottom_margin = 8
    
    local selected_label = selected_item_flow.add{
        type = "label",
        caption = {"string-mod-setting.selected"},
    }
    selected_label.style.font = "default-semibold"
    
    local selected_item_sprite = selected_item_flow.add{
        type = "sprite",
        name = "deployment_selected_item_sprite",
        sprite = ""
    }
    selected_item_sprite.style.size = 24
    selected_item_sprite.style.left_margin = 4
    selected_item_sprite.style.stretch_image_to_widget_size = true
    
    local selected_item_label = selected_item_flow.add{
        type = "label",
        name = "deployment_selected_item_name",
        caption = {"string-mod-setting.none"},
    }
    selected_item_label.style.left_margin = 4
    
    -- Deploy amount slider
    local deploy_amount_label = settings_frame.add{
        type = "label",
        caption = {"string-mod-setting.deploy-amount"},
    }
    deploy_amount_label.style.font = "default-semibold"
    deploy_amount_label.style.bottom_margin = 4
    
    local deploy_amount_flow = settings_frame.add{
        type = "flow",
        direction = "horizontal"
    }
    deploy_amount_flow.style.vertical_align = "center"
    deploy_amount_flow.style.bottom_margin = 8
    
    local deploy_amount_slider = deploy_amount_flow.add{
        type = "slider",
        name = "deployment_amount_slider",
        minimum_value = 1,
        maximum_value = 1000,  -- High max value, we'll clamp in textfield
        value = 1
    }
    deploy_amount_slider.set_slider_value_step(1)
    deploy_amount_slider.style.horizontally_stretchable = true
    deploy_amount_slider.style.width = 200
    
    local deploy_amount_textfield = deploy_amount_flow.add{
        type = "textfield",
        name = "deployment_amount_textfield",
        text = "1",
        numeric = true,
        allow_negative = false,
        allow_decimal = false
    }
    deploy_amount_textfield.style.width = 60
    deploy_amount_textfield.style.left_margin = 8
    
    -- Confirm button
    local confirm_button_flow = settings_frame.add{
        type = "flow",
        direction = "horizontal"
    }
    confirm_button_flow.style.horizontal_align = "right"
    confirm_button_flow.style.horizontally_stretchable = true
    confirm_button_flow.style.top_margin = 8
    
    local confirm_deploy_button = confirm_button_flow.add{
        type = "button",
        name = "confirm_deployment_button",
        caption = {"string-mod-setting.deploy"},
        style = "confirm_button"
    }
    
    -- Store container reference
    storage.container_deployment_containers = storage.container_deployment_containers or {}
    storage.container_deployment_containers[player.index] = container
    
    return frame
end

-- Remove deployment GUI
function container_deployment.remove_gui(player)
    if not player or not player.valid then
        return
    end
    
    local relative_gui = player.gui.relative
    if not relative_gui then
        return
    end
    
    local frame = relative_gui[container_deployment.FRAME_NAME]
    if frame and frame.valid then
        frame.destroy()
    end
    
    -- Clean up stored container reference
    if storage.container_deployment_containers then
        storage.container_deployment_containers[player.index] = nil
    end
end

-- Handle button click
function container_deployment.on_button_click(player, button_name, tags)
    if not tags then
        return
    end
    
    local container = storage.container_deployment_containers and storage.container_deployment_containers[player.index]
    if not container or not container.valid then
        player.print("Container is no longer available")
        return
    end
    
    local deploy_type = tags.deploy_type
    local item_name = tags.item_name
    local stack_size = tags.stack_size
    local count = tags.count or 1
    
    -- If stack size > 1, show slider
    if stack_size and stack_size > 1 then
        container_deployment.show_slider(player, tags)
        return
    end
    
    -- Deploy immediately
    if deploy_type == "vehicle" then
        container_deployment.deploy_vehicle(player, container, tags, 1)
    elseif deploy_type == "bot" then
        container_deployment.deploy_bot(player, container, tags, count)
    end
end

-- Show slider section for quantity selection
function container_deployment.show_slider(player, tags)
    local relative_gui = player.gui.relative
    if not relative_gui then
        return
    end
    
    local frame = relative_gui[container_deployment.FRAME_NAME]
    if not frame or not frame.valid then
        return
    end
    
    -- Find content frame first
    local content_frame = nil
    for _, child in pairs(frame.children) do
        if child.type == "frame" and child.direction == "vertical" then
            content_frame = child
            break
        end
    end
    
    if not content_frame then
        return
    end
    
    -- Find settings section within content_frame
    local settings_frame = content_frame["deployment_settings_section"]
    if not settings_frame or not settings_frame.valid then
        return
    end
    
    -- Update selected item display by finding the elements
    local selected_sprite = nil
    local selected_label = nil
    local deploy_amount_flow = nil
    
    -- Search through settings_frame children
    for _, child in pairs(settings_frame.children) do
        if child.type == "flow" and child.direction == "horizontal" then
            -- Check if this is the selected item flow
            for _, subchild in pairs(child.children) do
                if subchild.name == "deployment_selected_item_sprite" then
                    selected_sprite = subchild
                elseif subchild.name == "deployment_selected_item_name" then
                    selected_label = subchild
                elseif subchild.name == "deployment_amount_slider" or subchild.name == "deployment_amount_textfield" then
                    deploy_amount_flow = child
                end
            end
        end
    end
    
    -- Update selected item display
    if selected_sprite and selected_label then
        selected_sprite.sprite = "item/" .. tags.item_name
        
        local item_prototype = prototypes.item[tags.item_name]
        local display_name = item_prototype and item_prototype.localised_name or tags.item_name
        if tags.quality_name and tags.quality_name ~= "Normal" then
            display_name = {"", display_name, " [", tags.quality_name, "]"}
        end
        selected_label.caption = display_name
    end
    
    -- Recreate slider and textfield with correct max
    if deploy_amount_flow and deploy_amount_flow.valid then
        -- Clear existing slider and textfield
        deploy_amount_flow.clear()
        
        local max_count = tags.count or 1
        local stack_size = tags.stack_size or 50
        
        -- Smart default: 1 stack, or max if less than 1 stack
        local default_value = math.min(stack_size, max_count)
        
        -- Ensure max_count is at least 2 for slider (minimum_value must be < maximum_value)
        local slider_max = math.max(2, max_count)
        
        -- Create new slider with correct max
        local deploy_amount_slider = deploy_amount_flow.add{
            type = "slider",
            name = "deployment_amount_slider",
            minimum_value = 1,
            maximum_value = slider_max,
            value = default_value
        }
        deploy_amount_slider.set_slider_value_step(1)
        deploy_amount_slider.style.horizontally_stretchable = true
        deploy_amount_slider.style.width = 200
        
        -- Disable slider if only 1 item available
        if max_count <= 1 then
            deploy_amount_slider.enabled = false
        end
        
        local deploy_amount_textfield = deploy_amount_flow.add{
            type = "textfield",
            name = "deployment_amount_textfield",
            text = tostring(default_value),
            numeric = true,
            allow_negative = false,
            allow_decimal = false
        }
        deploy_amount_textfield.style.width = 60
        deploy_amount_textfield.style.left_margin = 8
        
        -- Disable textfield if only 1 item available
        if max_count <= 1 then
            deploy_amount_textfield.enabled = false
        end
    end
    
    -- Store selected tags for confirm button (includes max count for clamping)
    storage.container_deployment_selected = storage.container_deployment_selected or {}
    storage.container_deployment_selected[player.index] = tags
    
    -- Show settings section
    settings_frame.visible = true
end

-- Find nearest roboport network (checks vehicle networks first, then stationary roboports)
-- Find network for bot deployment
-- Uses construction area coverage to determine which network the bot should join
local function find_network_for_bot(surface, position, bot_type, force)
    -- Find all networks whose construction area covers this position
    local networks = surface.find_logistic_networks_by_construction_area(position, force)
    
    if not networks or #networks == 0 then
        return nil
    end
    
    local target_entity = nil
    local selected_network = nil
    local network_type = nil
    
    -- For construction bots, prioritize vehicle networks
    if bot_type == "construction-robot" then
        -- First pass: look for vehicle networks
        for i, network in pairs(networks) do
            if network and network.valid and network.cells and #network.cells > 0 then
                local owner = network.cells[1].owner
                if owner and owner.valid and (owner.type == "spider-vehicle" or owner.type == "car") then
                    target_entity = owner
                    selected_network = network
                    network_type = "vehicle"
                    break
                end
            end
        end
    end
    
    -- If no vehicle network found (or logistic bot), use first available network
    if not selected_network then
        -- Select the first roboport network available
        for _, network in ipairs(networks) do
            if network.valid and network.cells and #network.cells > 0 then
                local cell = network.cells[1]
                local target_entity = cell.owner
                
                if target_entity and target_entity.valid and (target_entity.type == "roboport") then
                    selected_network = network
                    break
                end
            end
        end
    end
    
    if target_entity and target_entity.valid then
        return {
            entity = target_entity,
            network = selected_network,
            type = network_type
        }
    end
    
    return nil
end

-- Deploy a vehicle
function container_deployment.deploy_vehicle(player, container, tags, quantity)
    quantity = quantity or 1
    local inventory_index = tags.inventory_index
    
    if not inventory_index then
        return
    end
    
    local inventory = container.get_inventory(defines.inventory.chest)
    if not inventory then
        return
    end
    
    local stack = inventory[inventory_index]
    if not stack or not stack.valid_for_read then
        return
    end
    
    -- Cap quantity to available count
    quantity = math.min(quantity, stack.count)
    
    local deployed = 0
    for i = 1, quantity do
        -- Extract all vehicle data BEFORE creating entity
        local vehicle_name = stack.entity_label or stack.name
        local vehicle_color = stack.entity_color
        local quality = stack.quality
        local has_grid = stack.grid ~= nil
        local grid_data = {}
        
        -- Extract equipment grid data
        if has_grid and stack.grid then
            for _, equipment in pairs(stack.grid.equipment) do
                if equipment and equipment.valid then
                    -- Skip equipment ghosts - they can't be placed
                    local is_ghost = false
                    if equipment.prototype and equipment.prototype.type == "equipment-ghost" then
                        is_ghost = true
                    elseif equipment.name and equipment.name:match("%-ghost$") and equipment.name ~= "equipment-ghost" then
                        is_ghost = true
                    elseif equipment.name == "equipment-ghost" then
                        is_ghost = true
                    end
                    
                    -- Only process real equipment, not ghosts
                    if not is_ghost then
                        local item_name = equipment.name
                        -- Find the item that places this equipment
                        for prototype_name, item_prototype in pairs(prototypes.item) do
                            if item_prototype.place_as_equipment_result then
                                local result = item_prototype.place_as_equipment_result
                                if (type(result) == "string" and result == equipment.name) or
                                   (type(result) == "table" and result.name == equipment.name) then
                                    item_name = prototype_name
                                    break
                                end
                            end
                        end
                        
                        table.insert(grid_data, {
                            name = equipment.name,
                            position = equipment.position,
                            quality = equipment.quality,
                            energy = equipment.energy,
                            item_fallback_name = item_name
                        })
                    end
                end
            end
        end
        
        -- Spawn exactly at container position
        local deploy_pos = container.position
        
        -- Create the entity
        local created_entity = container.surface.create_entity({
            name = stack.name,
            position = deploy_pos,
            force = player.force,
            quality = quality,
            create_build_effect_smoke = true
        })
        
        if created_entity and created_entity.valid then
            -- Apply color
            if vehicle_color then
                created_entity.color = vehicle_color
            end
            
            -- Apply custom name
            if vehicle_name and vehicle_name ~= stack.name then
                created_entity.entity_label = vehicle_name
            end
            
            -- Restore equipment grid
            if has_grid and created_entity.grid and #grid_data > 0 then
                local target_grid = created_entity.grid
                for _, equip_data in ipairs(grid_data) do
                    local new_equipment = nil
                    
                    -- Try with quality and position
                    if equip_data.quality then
                        new_equipment = target_grid.put({
                            name = equip_data.name,
                            position = equip_data.position,
                            quality = equip_data.quality
                        })
                    end
                    
                    -- Try without quality
                    if not new_equipment then
                        new_equipment = target_grid.put({
                            name = equip_data.name,
                            position = equip_data.position
                        })
                    end
                    
                    -- Try anywhere in grid
                    if not new_equipment then
                        new_equipment = target_grid.put({name = equip_data.name})
                    end
                    
                    -- Set energy
                    if new_equipment and new_equipment.valid and equip_data.energy then
                        new_equipment.energy = equip_data.energy
                    end
                    
                    -- If still failed, drop in inventory
                    if not new_equipment then
                        local vehicle_inv = created_entity.get_inventory(defines.inventory.spider_trunk)
                        if not vehicle_inv then
                            vehicle_inv = created_entity.get_inventory(defines.inventory.car_trunk)
                        end
                        if vehicle_inv then
                            vehicle_inv.insert({
                                name = equip_data.item_fallback_name or equip_data.name,
                                count = 1,
                                quality = equip_data.quality
                            })
                        end
                    end
                end
            end
            
            deployed = deployed + 1
            
            -- Remove from inventory
            stack.count = stack.count - 1
            
            if stack.count == 0 then
                break
            end
        end
    end
    
    if deployed > 0 then
        --player.print("Deployed " .. deployed .. " " .. (tags.item_name or "vehicle"))
    else
        player.print({"string-mod-setting.deploy-failed"})
    end
    
    -- Refresh GUI
    container_deployment.remove_gui(player)
    container_deployment.get_or_create_gui(player, container)
end

-- Deploy bots
function container_deployment.deploy_bot(player, container, tags, quantity)
    quantity = quantity or tags.count or 1
    local item_name = tags.item_name
    local quality_name = tags.quality_name or "Normal"
    
    -- Find and remove bots from inventory
    local inventory = container.get_inventory(defines.inventory.chest)
    if not inventory then
        return
    end
    
    local deployed = 0
    local remaining_to_deploy = quantity
    
    for i = 1, #inventory do
        if remaining_to_deploy <= 0 then
            break
        end
        
        local stack = inventory[i]
        if stack and stack.valid_for_read and stack.name == item_name then
            local stack_quality = stack.quality and stack.quality.name or "Normal"
            
            if stack_quality == quality_name then
                -- Deploy bots from this stack
                local to_deploy = math.min(stack.count, remaining_to_deploy)
                
                for j = 1, to_deploy do
                    -- Spawn exactly at container position
                    local deploy_pos = container.position
                    
                    -- Find target network for this bot
                    local target_network_info = find_network_for_bot(
                        container.surface,
                        deploy_pos,
                        item_name,
                        player.force
                    )
                    
                    -- Create bot entity
                    local bot = container.surface.create_entity({
                        name = item_name,
                        position = deploy_pos,
                        force = player.force,
                        quality = stack.quality,
                        player = player,
                        raise_built = true
                    })
                    
                    if bot and bot.valid then
                        -- Manually assign bot to network (script-created bots don't auto-join)
                        if target_network_info and target_network_info.network and target_network_info.network.valid then
                            bot.logistic_network = target_network_info.network
                        end
                        
                        deployed = deployed + 1
                    end
                end
                
                -- Remove bots from inventory
                stack.count = stack.count - to_deploy
                remaining_to_deploy = remaining_to_deploy - to_deploy
            end
        end
    end
    
    if deployed > 0 then
        -- Check which network type covers the container position (for message)
        local sample_network = find_network_for_bot(container.surface, container.position, item_name, player.force)
        local message = {"string-mod-setting.deployed", deployed, item_name}
        -- if sample_network and sample_network.type then
        --     message = message .. " → " .. sample_network.type .. " network"
        -- end
        --player.print(message)
    else
        player.print("Failed to deploy bots")
    end
    
    -- Refresh GUI
    container_deployment.remove_gui(player)
    container_deployment.get_or_create_gui(player, container)
end

-- Handle confirm deployment button
function container_deployment.on_confirm_deployment(player)
    local container = storage.container_deployment_containers and storage.container_deployment_containers[player.index]
    if not container or not container.valid then
        player.print("Container is no longer available")
        return
    end
    
    local tags = storage.container_deployment_selected and storage.container_deployment_selected[player.index]
    if not tags then
        return
    end
    
    -- Get deployment quantity from textfield
    local relative_gui = player.gui.relative
    if not relative_gui then
        return
    end
    
    local frame = relative_gui[container_deployment.FRAME_NAME]
    if not frame or not frame.valid then
        return
    end
    
    -- Find content frame first
    local content_frame = nil
    for _, child in pairs(frame.children) do
        if child.type == "frame" and child.direction == "vertical" then
            content_frame = child
            break
        end
    end
    
    if not content_frame then
        return
    end
    
    local settings_frame = content_frame["deployment_settings_section"]
    if not settings_frame or not settings_frame.valid then
        return
    end
    
    -- Find textfield within settings_frame
    local textfield = nil
    for _, child in pairs(settings_frame.children) do
        if child.type == "flow" then
            for _, subchild in pairs(child.children) do
                if subchild.name == "deployment_amount_textfield" then
                    textfield = subchild
                    break
                end
            end
        end
    end
    
    if not textfield then
        return
    end
    
    local quantity = tonumber(textfield.text) or 1
    
    -- Clamp to available count from tags
    local max_count = tags.count or 1
    quantity = math.max(1, math.min(quantity, max_count))
    quantity = math.floor(quantity)
    
    -- Deploy based on type
    if tags.deploy_type == "vehicle" then
        container_deployment.deploy_vehicle(player, container, tags, quantity)
    elseif tags.deploy_type == "bot" then
        container_deployment.deploy_bot(player, container, tags, quantity)
    end
    
    -- Hide settings section after deployment (check if still valid first)
    if settings_frame and settings_frame.valid then
        settings_frame.visible = false
    end
    
    -- Clear selected tags
    if storage.container_deployment_selected then
        storage.container_deployment_selected[player.index] = nil
    end
end

-- Handle slider value change
function container_deployment.on_slider_changed(player, slider)
    if not slider or not slider.valid then
        return
    end
    
    local value = math.floor(slider.slider_value)
    slider.slider_value = value
    
    -- Find textfield in same parent
    local parent = slider.parent
    if not parent then
        return
    end
    
    local textfield = parent["deployment_amount_textfield"]
    if textfield and textfield.valid then
        textfield.text = tostring(value)
    end
end

-- Handle textfield change
function container_deployment.on_textfield_changed(player, textfield)
    if not textfield or not textfield.valid then
        return
    end
    
    local value = tonumber(textfield.text) or 1
    
    -- Get max count from stored tags
    local tags = storage.container_deployment_selected and storage.container_deployment_selected[player.index]
    local max_count = 1000  -- Default high value
    if tags and tags.count then
        max_count = tags.count
    end
    
    -- Clamp value
    value = math.max(1, math.min(value, max_count))
    value = math.floor(value)
    
    -- Find slider in same parent
    local parent = textfield.parent
    if not parent then
        return
    end
    
    local slider = parent["deployment_amount_slider"]
    if slider and slider.valid then
        slider.slider_value = value
        textfield.text = tostring(value)
    end
end

return container_deployment