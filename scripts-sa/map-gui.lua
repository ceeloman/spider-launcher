-- scripts-sa/map-gui.lua
local vehicles_list = require("scripts-sa.vehicles-list")
local deployment = require("scripts-sa.deployment")
local api = require("scripts-sa.api")

local map_gui = {}

-- ================F============================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Check if a sprite exists
local function sprite_exists(sprite_name)
    if not sprite_name then return false end
    if helpers and helpers.is_valid_sprite_path then
        return helpers.is_valid_sprite_path(sprite_name)
    end
    return true
end

-- Get the appropriate sprite name for an item
local function get_sprite_name(item_name)
    local custom_sprite = "sl-" .. item_name
    if not sprite_exists(custom_sprite) then
        custom_sprite = "item/" .. item_name
    end
    return custom_sprite
end

--  Capitalize the first letter of a string something like "spidertron" becomes "Spidertron"
local function capitalize_first(str)
    return str:gsub("^%l", string.upper)
end

-- Get the quality name from a stack or quality object
local function get_quality_name(stack_or_quality)
    if not stack_or_quality then return "Normal" end
    if type(stack_or_quality) == "string" then return stack_or_quality end
    if stack_or_quality.name then return stack_or_quality.name end
    return "Normal"
end

-- Create a quality overlay sprite on top of an item icon
local function create_quality_overlay(parent, quality)
    if quality and quality.name ~= "Normal" then
        local quality_name = string.lower(quality.name)
        local overlay_name = "sl-" .. quality_name
        local quality_overlay = parent.add{
            type = "sprite",
            sprite = overlay_name,
            tooltip = quality.name .. " quality"
        }
        quality_overlay.style.size = 14
        quality_overlay.style.top_padding = 13
        quality_overlay.style.left_padding = -30
        return quality_overlay
    end
    return nil
end

-- Create an item icon with quality overlay
local function create_item_icon_with_quality(parent, item_name, quality, tooltip)
    local icon_container = parent.add{
        type = "flow"
    }
    icon_container.style.width = 28
    icon_container.style.height = 28
    icon_container.style.padding = 0
    icon_container.style.margin = 0

    local sprite = icon_container.add{
        type = "sprite-button",
        sprite = get_sprite_name(item_name),
        tooltip = tooltip or get_quality_name(quality)
    }
    sprite.style.size = 28
    sprite.style.padding = 0
    sprite.style.margin = 0
    
    create_quality_overlay(icon_container, quality)
    
    return icon_container
end

-- Cache for the ammo category mapping
local ammo_category_map = nil

-- Build the ammo category map
local function build_ammo_category_map()
    if ammo_category_map then return end
    ammo_category_map = {}
    for name, prototype in pairs(prototypes.item) do
        if prototype.ammo_category then
            ammo_category_map[name] = prototype.ammo_category.name
        end
    end
end

-- Get the ammo category for a given item
function get_ammo_category(item_name)
    if not ammo_category_map then
        build_ammo_category_map()
    end
    return ammo_category_map[item_name]
end

-- Check if a string matches any entry in a list
local function match_in_list(list, string)
    for _, name in pairs(list) do
        if name == string then return true end
    end
    return false
end

-- Check if any string in list_2 matches any entry in list
local function list_match_list(list, list_2)
    for _, string in pairs(list_2) do
        if match_in_list(list, string) then return true end
    end
    return false
end

-- ============================================================================
-- VEHICLE DISCOVERY
-- ============================================================================

-- Find all orbital vehicles on platforms orbiting the player's current planet
function map_gui.find_orbital_vehicles(player_surface)
    local available_vehicles = {}
    local platform_count = 0
    local hub_count = 0
    local inventory_count = 0
    
    for _, surface in pairs(game.surfaces) do
        if surface.platform then
            platform_count = platform_count + 1
            
            local is_orbiting_current_planet = false
            
            if surface.platform.space_location then
                local platform_location = surface.platform.space_location
                local location_str = tostring(platform_location)
                local orbiting_planet = location_str:match(": ([^%(]+) %(planet%)")
                
                if orbiting_planet then
                    if orbiting_planet == player_surface.name then
                        is_orbiting_current_planet = true
                    end
                else
                    is_orbiting_current_planet = true
                end
            else
                is_orbiting_current_planet = true
            end
            
            if is_orbiting_current_planet then
                if surface.platform.hub and surface.platform.hub.valid then
                    hub_count = hub_count + 1
                    local hub = surface.platform.hub
                    local processed_slots = {}
                    
                    for _, inv_type in pairs({defines.inventory.chest}) do
                        local inventory = hub.get_inventory(inv_type)
                        if inventory then
                            inventory_count = inventory_count + 1
                            
                            for i = 1, #inventory do
                                local stack = inventory[i]
                                if stack.valid_for_read then
                                    local is_vehicle = vehicles_list.is_vehicle(stack.name)
                                    local is_spider_vehicle = vehicles_list.is_spider_vehicle(stack.name)
                                    
                                    if is_vehicle and not processed_slots[i] then
                                        processed_slots[i] = true
                                        
                                        local name = capitalize_first(stack.name)
                                        
                                        if stack.entity_label and stack.entity_label ~= "" then
                                            name = stack.entity_label
                                        end
                                        
                                        local color = nil
                                        if stack.entity_color then
                                            color = stack.entity_color
                                        end
                                        
                                        local quality = nil
                                        if stack.quality then
                                            quality = stack.quality
                                        end
                                        
                                        local tooltip = "Platform: " .. surface.name .. "\nSlot: " .. i
                                        local entity_name = stack.name
                                        
                                        table.insert(available_vehicles, {
                                            name = name,
                                            tooltip = tooltip,
                                            color = color,
                                            index = i,
                                            hub = hub,
                                            inventory_slot = i,
                                            inv_type = inv_type,
                                            platform_name = surface.platform.name,
                                            quality = quality,
                                            vehicle_name = stack.name,
                                            entity_name = entity_name,
                                            is_spider = is_spider_vehicle
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return available_vehicles
end

-- ============================================================================
-- INVENTORY SCANNING
-- ============================================================================

-- List compatible items in an inventory
function map_gui.list_compatible_items_in_inventory(inventory, compatible_items_list, available_items)
    if not inventory then 
        return {}
    end
    local match_list = {}

    for i = 1, #inventory do
        local stack = inventory[i]
        if stack and stack.valid_for_read then
            if not stack.name:match("%-ghost$") and match_in_list(compatible_items_list, stack.name) then
                if not available_items[stack.name] then
                    available_items[stack.name] = {
                        total = 0,
                        by_quality = {}
                    }
                end
                local quality_name = get_quality_name(stack.quality)
                local quality_level = 1
                local quality_color = {r=1, g=1, b=1}
                if stack.quality then
                    quality_level = stack.quality.level
                    quality_color = stack.quality.color
                end
                local quality_key = quality_name
                if not available_items[stack.name].by_quality[quality_key] then
                    available_items[stack.name].by_quality[quality_key] = {
                        name = quality_name,
                        level = quality_level,
                        color = quality_color,
                        count = 0
                    }
                end
                available_items[stack.name].by_quality[quality_key].count = 
                    available_items[stack.name].by_quality[quality_key].count + stack.count
                available_items[stack.name].total =
                    available_items[stack.name].total + stack.count

                local found = false
                for _, item in ipairs(match_list) do
                    if item.name == stack.name then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(match_list, {
                        name = stack.name,
                        display_name = stack.name
                    })
                end
            end
        end
    end
    return match_list
end

-- Scan the platform inventory for available items
function map_gui.scan_platform_inventory(vehicle_data)
    local available_items = {}
    local hub = vehicle_data.hub
    
    local items_to_scan = {
        "construction-robot",
        "repair-pack"
    }
    
    for _, item_name in ipairs(items_to_scan) do
        available_items[item_name] = {
            total = 0,
            by_quality = {}
        }
    end
    
    if not hub or not hub.valid then
        return available_items
    end
    
    local inventory = hub.get_inventory(defines.inventory.chest)
    if not inventory then
        return available_items
    end
    
    for i = 1, #inventory do
        local stack = inventory[i]
        if stack and stack.valid_for_read then
            for _, item_name in ipairs(items_to_scan) do
                if stack.name == item_name then
                    local quality_name = get_quality_name(stack.quality)
                    local quality_level = 1
                    local quality_color = {r=1, g=1, b=1}
                    
                    if stack.quality then
                        quality_level = stack.quality.level
                        quality_color = stack.quality.color
                    end
                    
                    local quality_key = quality_name
                    
                    if not available_items[item_name].by_quality[quality_key] then
                        available_items[item_name].by_quality[quality_key] = {
                            name = quality_name,
                            level = quality_level,
                            color = quality_color,
                            count = 0
                        }
                    end
                    
                    available_items[item_name].by_quality[quality_key].count = 
                        available_items[item_name].by_quality[quality_key].count + stack.count
                    available_items[item_name].total = 
                        available_items[item_name].total + stack.count
                end
            end
        end
    end
    
    return available_items
end

-- ============================================================================
-- GUI BUILDERS
-- ============================================================================

-- Show the deployment menu
function map_gui.show_deployment_menu(player, vehicles)
    if player.gui.screen["spidertron_deployment_frame"] then
        player.gui.screen["spidertron_deployment_frame"].destroy()
    end
    
    if player.opened then
        player.opened = nil
        -- Don't create GUI yet - wait for next tick
        storage.pending_deployment = storage.pending_deployment or {}
        storage.pending_deployment[player.index] = {
            vehicles = vehicles,
            planet_surface = player.surface
        }
        return
    end

    local frame = player.gui.screen.add{
        type = "frame",
        name = "spidertron_deployment_frame",
        direction = "vertical"
    }
    
    player.opened = frame
    
    frame.auto_center = false
    local resolution = player.display_resolution
    frame.location = {x = resolution.width / 2 - 200, y = 50}
    
    local title_flow = frame.add{
        type = "flow",
        direction = "horizontal",
        name = "title_flow"
    }
    
    local title_label = title_flow.add{
        type = "label",
        caption = {"", " Orbital Deployment"},
        style = "frame_title"
    }
    title_label.drag_target = frame
    
    local drag_handle = title_flow.add{
        type = "empty-widget",
        style = "draggable_space_header"
    }
    drag_handle.style.horizontally_stretchable = true
    drag_handle.style.height = 24
    drag_handle.style.right_margin = 4
    drag_handle.ignored_by_interaction = false
    drag_handle.drag_target = frame
    
    local close_button = title_flow.add{
        type = "sprite-button",
        name = "close_deployment_menu_btn",
        sprite = "utility/close",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        tooltip = "Close deployment menu",
        style = "frame_action_button"
    }
    
    local planet_display_name = nil
    
    if storage.pending_deployment and storage.pending_deployment[player.index] then
        storage.pending_deployment[player.index] = {
            planet_surface = planet_surface,
            planet_name = planet_surface and prototypes.space_location[planet_surface.name] and prototypes.space_location[planet_surface.name].localised_name or planet_name
        }
    end
    
    if not planet_display_name then
        local space_location = nil
        
        if player.surface and player.surface.platform then
            -- On platform - get the space_location it's orbiting
            space_location = player.surface.platform.space_location
        else
            -- On planet - get the planet's space_location prototype
            space_location = prototypes.space_location[player.surface.name]
        end
        
        if space_location then
            planet_display_name = space_location.localised_name
        end
        
        -- Final fallback
        if not planet_display_name then
            planet_display_name = capitalize_first(player.surface.name)
        end
    end
    
    local caption_text = nil
    if type(planet_display_name) == "table" then
        caption_text = {"", "Deploy from orbit above ", planet_display_name}
    else
        caption_text = "Deploy from orbit above " .. planet_display_name
    end
    
    frame.add{
        type = "label",
        caption = caption_text,
        style = "caption_label"
    }
    
    if frame.vehicle_table then
        frame.vehicle_table.destroy()
    end
    
    local scroll_pane = frame.add{
        type = "scroll-pane",
        name = "vehicle_scroll_pane",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "auto"
    }
    scroll_pane.style.maximal_height = 400
    scroll_pane.style.minimal_width = 400
    
    local vehicle_table = scroll_pane.add{
        type = "table",
        name = "vehicle_table",
        column_count = 1,
    }
    vehicle_table.style.horizontal_spacing = 8
    vehicle_table.style.vertical_spacing = 4
    
    for i, vehicle in ipairs(vehicles) do
        local row_container = vehicle_table.add{
            type = "flow",
            direction = "horizontal",
            name = "vehicle_container_" .. i
        }
        row_container.style.vertical_align = "center"
        row_container.style.top_padding = 2
        row_container.style.bottom_padding = 2
        row_container.style.width = 380
        
        local sprite_name = "item/spidertron"
        if vehicle.vehicle_name then
            sprite_name = "item/" .. vehicle.vehicle_name
        end
        
        create_item_icon_with_quality(row_container, vehicle.vehicle_name, vehicle.quality, "Vehicle from " .. vehicle.platform_name)
        
        local name_label = row_container.add{
            type = "label",
            caption = vehicle.name,
            tooltip = "Located on " .. vehicle.platform_name
        }
        name_label.style.minimal_width = 176
        
        if vehicle.color then
            name_label.style.font_color = vehicle.color
        end
        
        local spacer = row_container.add{
            type = "empty-widget"
        }
        spacer.style.horizontally_stretchable = true
        spacer.style.minimal_width = 10
        
        local button_flow = row_container.add{
            type = "flow",
            direction = "horizontal"
        }
        button_flow.style.horizontal_align = "right"
        
        local has_equipment_grid = false
        local entity_prototype = prototypes.entity[vehicle.entity_name]
        if entity_prototype and entity_prototype.grid_prototype then
            has_equipment_grid = true
        end
        
        if has_equipment_grid then
            local edit_grid_button = button_flow.add{
                type = "sprite-button",
                name = "edit_equipment_grid_" .. i,
                sprite = "utility/empty_armor_slot",
                tooltip = "Remotely configure vehicle equipment grid"
            }
            edit_grid_button.style.size = 28
        end
        
        local in_map_view = player.render_mode == defines.render_mode.chart or 
                           player.render_mode == defines.render_mode.chart_zoomed_in
    
        local is_same_surface = player.surface == player.physical_surface
    
        if in_map_view then
            local target_button = button_flow.add{
                type = "sprite-button",
                name = "deploy_target_" .. i,
                sprite = "utility/shoot_cursor_green",
                tooltip = "Deploy to map cursor location"
            }
            target_button.style.size = 28
            
            if is_same_surface then
                local player_button = button_flow.add{
                    type = "sprite-button",
                    name = "deploy_player_" .. i,
                    sprite = "entity/character",
                    tooltip = "Deploy to your character's location"
                }
                player_button.style.size = 28
            end
        else
            local player_button = button_flow.add{
                type = "sprite-button",
                name = "deploy_player_" .. i,
                sprite = "entity/character",
                tooltip = "Deploy to your character's location"
            }
            player_button.style.size = 28
        end
    end
    
    storage.spidertrons = vehicles
end

-- Helper function to add item entry (extracted from show_extras_menu)
local function add_item_entry(items_table, item, item_info)
    if item_info and item_info.total > 0 then
        local qualities = {}
        for _, quality_data in pairs(item_info.by_quality) do
            table.insert(qualities, quality_data)
        end
        table.sort(qualities, function(a, b) return a.level > b.level end)
        
        for _, quality_data in ipairs(qualities) do
            if quality_data.count > 0 then
                local left_flow = items_table.add{
                    type = "flow",
                    direction = "horizontal"
                }
                left_flow.style.vertical_align = "center"
                
                create_item_icon_with_quality(left_flow, item.name, quality_data, capitalize_first(quality_data.name))
                
                left_flow.add{
                    type = "label",
                    caption = prototypes.item[item.name].localised_name or item.name .. " (" .. quality_data.count .. " available)"
                }
                
                local right_flow = items_table.add{
                    type = "flow",
                    direction = "horizontal"
                }
                right_flow.style.horizontal_align = "right"
                right_flow.style.horizontally_stretchable = true
                right_flow.style.vertical_align = "center"
                local stack_size = 50
                local prototype = prototypes.item[item.name]
                if prototype then
                    stack_size = prototype.stack_size
                end
                local quality_name = string.lower(quality_data.name)
                local slider = right_flow.add{
                    type = "slider",
                    name = "slider_" .. item.name .. "_" .. quality_name,
                    minimum_value = 0,
                    maximum_value = quality_data.count,
                    value = 0,
                    value_step = 1
                }
                slider.style.width = 140
                local count_textfield = right_flow.add{
                    type = "textfield",
                    name = "text_" .. item.name .. "_" .. quality_name,
                    text = "0",
                    numeric = true,
                    allow_decimal = false,
                    allow_negative = false
                }
                count_textfield.style.width = 40
                count_textfield.style.horizontal_align = "right"
                local stack_button = right_flow.add{
                    type = "sprite-button",
                    name = "stack_" .. item.name .. "_" .. quality_data.name,
                    sprite = "ovd_stack",
                    tooltip = "Add 1 stack (" .. stack_size .. " items)",
                    tags = {
                        action = "add_stack",
                        item_name = item.name,
                        quality_name = quality_data.name,
                        stack_size = stack_size,
                        max_value = quality_data.count
                    }
                }
                stack_button.style.size = 24
                slider.tooltip = "Slide to select quantity"
                count_textfield.tooltip = "Type quantity or use slider"
                count_textfield.tags = {max_value = quality_data.count}
                slider.tags = {
                    item_name = item.name,
                    quality_name = quality_data.name,
                    max_value = quality_data.count
                }
            end
        end
    else
        local left_flow = items_table.add{
            type = "flow",
            direction = "horizontal"
        }
        left_flow.style.vertical_align = "center"
        local sprite = left_flow.add{
            type = "sprite-button",
            sprite = get_sprite_name(item.name),
            tooltip = "No " .. item.display_name .. " available",
            enabled = false
        }
        sprite.style.size = 28
        left_flow.add{
            type = "label",
            caption = item.display_name .. " (0 available)",
            tooltip = "No " .. item.display_name .. " available"
        }.style.font_color = {r=0.5, g=0.5, b=0.5}
        local right_flow = items_table.add{
            type = "flow",
            direction = "horizontal"
        }
        right_flow.style.horizontal_align = "right"
        right_flow.style.horizontally_stretchable = true
        right_flow.add{
            type = "label",
            caption = "Not available",
            tooltip = "No " .. item.display_name .. " available"
        }.style.font_color = {r=0.5, g=0.5, b=0.5}
    end
end

function map_gui.show_extras_menu(player, vehicle_data, deploy_target)
    
    if player.gui.screen["spidertron_extras_frame"] then
        player.gui.screen["spidertron_extras_frame"].destroy()
    end
    
    local utilities_list = {
        {name = "construction-robot", display_name = "Construction Robot"},
        {name = "repair-pack", display_name = "Repair Pack"}
    }
    local ammo_list = {}
    local fuel_list = {}
    local equipment_list = {}
    
    local available_items = map_gui.scan_platform_inventory(vehicle_data)
    
    -- MULTIPLAYER FIX: Use player-specific storage
    if not storage.temp_deployment_data then
        storage.temp_deployment_data = {}
    end
    storage.temp_deployment_data[player.index] = {
        vehicle = vehicle_data,
        deploy_target = deploy_target,
        available_items = available_items
    }
    
    local entity_prototype = prototypes.entity[vehicle_data.entity_name]
    local has_guns = false
    local compatible_ammo_categories = {}
    if entity_prototype and entity_prototype.guns then
        has_guns = true
        for gun_name, gun_data in pairs(entity_prototype.guns) do
            if gun_data and gun_data.attack_parameters then
                if gun_data.attack_parameters.ammo_category then
                    compatible_ammo_categories[gun_data.attack_parameters.ammo_category] = true
                end
                if gun_data.attack_parameters.ammo_categories then
                    if type(gun_data.attack_parameters.ammo_categories) == "string" then
                        compatible_ammo_categories[gun_data.attack_parameters.ammo_categories] = true
                    elseif type(gun_data.attack_parameters.ammo_categories) == "table" then
                        if gun_data.attack_parameters.ammo_categories[1] then
                            compatible_ammo_categories[gun_data.attack_parameters.ammo_categories[1]] = true
                        end
                        for k, v in pairs(gun_data.attack_parameters.ammo_categories) do
                            if type(k) == "string" and k ~= "toString" then
                                compatible_ammo_categories[k] = true
                            end
                        end
                    end
                end
            end
        end
        
        local hub = vehicle_data.hub
        if hub and hub.valid then
            local inventory = hub.get_inventory(defines.inventory.chest)
            if inventory then
                for i = 1, #inventory do
                    local stack = inventory[i]
                    if stack and stack.valid_for_read then
                        local item_prototype = prototypes.item[stack.name]
                        if item_prototype and item_prototype.type == "ammo" then
                            local item_ammo_category = get_ammo_category(stack.name)
                            if item_ammo_category and compatible_ammo_categories[item_ammo_category] then
                                if not available_items[stack.name] then
                                    available_items[stack.name] = {
                                        total = 0,
                                        by_quality = {}
                                    }
                                end
                                local quality_name = get_quality_name(stack.quality)
                                local quality_level = 1
                                local quality_color = {r=1, g=1, b=1}
                                if stack.quality then
                                    quality_level = stack.quality.level
                                    quality_color = stack.quality.color
                                end
                                local quality_key = quality_name
                                if not available_items[stack.name].by_quality[quality_key] then
                                    available_items[stack.name].by_quality[quality_key] = {
                                        name = quality_name,
                                        level = quality_level,
                                        color = quality_color,
                                        count = 0
                                    }
                                end
                                available_items[stack.name].by_quality[quality_key].count = 
                                    available_items[stack.name].by_quality[quality_key].count + stack.count
                                available_items[stack.name].total = 
                                    available_items[stack.name].total + stack.count
                                
                                local found = false
                                for _, item in ipairs(ammo_list) do
                                    if item.name == stack.name then
                                        found = true
                                        break
                                    end
                                end
                                if not found then
                                    table.insert(ammo_list, {
                                        name = stack.name,
                                        display_name = stack.name
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    local needs_fuel = false
    if entity_prototype and entity_prototype.burner_prototype then
        local burner = entity_prototype.burner_prototype
        if burner.fuel_categories and burner.fuel_categories["chemical"] then
            needs_fuel = true
        end
    end
    
    if needs_fuel then
        local hub = vehicle_data.hub
        if hub and hub.valid then
            local inventory = hub.get_inventory(defines.inventory.chest)
            if inventory then
                for i = 1, #inventory do
                    local stack = inventory[i]
                    if stack and stack.valid_for_read then
                        local item = prototypes.item[stack.name]
                        if item and item.fuel_value and item.fuel_category == "chemical" and
                           not string.find(stack.name:lower(), "seed") and
                           not string.find(stack.name:lower(), "egg") and
                           not string.find(stack.name:lower(), "spoil") and
                           (item.spoil_result == nil) then
                            if not available_items[stack.name] then
                                available_items[stack.name] = {
                                    total = 0,
                                    by_quality = {}
                                }
                            end
                            local quality_name = get_quality_name(stack.quality)
                            local quality_level = 1
                            local quality_color = {r=1, g=1, b=1}
                            if stack.quality then
                                quality_level = stack.quality.level
                                quality_color = stack.quality.color
                            end
                            local quality_key = quality_name
                            if not available_items[stack.name].by_quality[quality_key] then
                                available_items[stack.name].by_quality[quality_key] = {
                                    name = quality_name,
                                    level = quality_level,
                                    color = quality_color,
                                    count = 0
                                }
                            end
                            available_items[stack.name].by_quality[quality_key].count = 
                                available_items[stack.name].by_quality[quality_key].count + stack.count
                            available_items[stack.name].total = 
                                available_items[stack.name].total + stack.count
                            
                            local found = false
                            for _, fuel in ipairs(fuel_list) do
                                if fuel.name == stack.name then
                                    found = true
                                    break
                                end
                            end
                            if not found then
                                table.insert(fuel_list, {
                                    name = stack.name,
                                    display_name = stack.name
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    local has_equipment = false
    if entity_prototype and entity_prototype.grid_prototype then
        has_equipment = true
        local grid_categories = entity_prototype.grid_prototype.equipment_categories
        local compatible_equipment = {}
        if prototypes.equipment then
            for name, equipment_prototype in pairs(prototypes.equipment) do
                if name:match("%-ghost$") then
                    goto continue
                end
                
                if equipment_prototype and equipment_prototype.equipment_categories then
                    local equipment_categories = equipment_prototype.equipment_categories
                    if list_match_list(equipment_categories, grid_categories) then
                        if equipment_prototype.take_result and equipment_prototype.take_result.name then
                            local item_name = equipment_prototype.take_result.name
                            if not item_name:match("%-ghost$") then
                                table.insert(compatible_equipment, item_name)
                            end
                        end
                    end
                end
                ::continue::
            end
        end

        local hub = vehicle_data.hub
        if hub and hub.valid then
            local hub_inventory = hub.get_inventory(defines.inventory.chest)
            if hub_inventory then
                equipment_list = map_gui.list_compatible_items_in_inventory(hub_inventory, compatible_equipment, available_items)
            end
        end
    end
    
    local frame = player.gui.screen.add{
        type = "frame",
        name = "spidertron_extras_frame",
        direction = "vertical"
    }
    player.opened = frame
    frame.auto_center = false
    local resolution = player.display_resolution
    frame.location = {x = resolution.width / 2 - 250, y = resolution.height / 2 - 200}
    
    local title_flow = frame.add{
        type = "flow",
        direction = "horizontal",
        name = "title_flow"
    }
    local title_label = title_flow.add{
        type = "label",
        caption = {"", " Deployment Menu"},
        style = "frame_title"
    }
    title_label.drag_target = frame
    local drag_handle = title_flow.add{
        type = "empty-widget",
        style = "draggable_space_header"
    }
    drag_handle.style.horizontally_stretchable = true
    drag_handle.style.height = 24
    drag_handle.style.right_margin = 4
    drag_handle.ignored_by_interaction = false
    drag_handle.drag_target = frame
    
    -- CHANGED: Only close button, no back button (X goes back to vehicle list)
    local close_button = title_flow.add{
        type = "sprite-button",
        name = "close_extras_menu_btn",
        sprite = "utility/close",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        tooltip = "Back to vehicle selection",
        style = "frame_action_button"
    }
    
    local info_flow = frame.add{
        type = "flow",
        direction = "vertical"
    }
    info_flow.add{
        type = "label",
        caption = "Configure loadout for " .. vehicle_data.name,
        style = "caption_label"
    }
    info_flow.add{
        type = "label",
        caption = "Select items to include with deployment",
        style = "label"
    }.style.font_color = {r=0.7, g=0.7, b=0.7}
    
    local tabbed_pane = frame.add{
        type = "tabbed-pane",
        name = "extras_tabbed_pane"
    }
    
    local utilities_tab = tabbed_pane.add{
        type = "tab",
        name = "utilities_tab",
        caption = "[img=item/repair-pack] Utilities",
        tooltip = "Construction bots and repair packs"
    }
    local utilities_content = tabbed_pane.add{
        type = "flow",
        name = "utilities_content",
        direction = "vertical"
    }
    local utilities_scroll_pane = utilities_content.add{
        type = "scroll-pane",
        name = "utilities_scroll_pane",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "auto"
    }
    utilities_scroll_pane.style.maximal_height = 300
    utilities_scroll_pane.style.minimal_width = 500
    local utilities_table = utilities_scroll_pane.add{
        type = "table",
        name = "utilities_table",
        column_count = 2,
        style = "table"
    }
    for _, item in ipairs(utilities_list) do
        add_item_entry(utilities_table, item, available_items[item.name])
    end
    tabbed_pane.add_tab(utilities_tab, utilities_content)
    
    if has_guns and #ammo_list > 0 then
        local ammo_tab = tabbed_pane.add{
            type = "tab",
            name = "ammo_tab",
            caption = "[img=item/firearm-magazine] Ammo",
            tooltip = "Ammunition for vehicle weapons"
        }
        local ammo_content = tabbed_pane.add{
            type = "flow",
            name = "ammo_content",
            direction = "vertical"
        }
        local ammo_scroll_pane = ammo_content.add{
            type = "scroll-pane",
            name = "ammo_scroll_pane",
            horizontal_scroll_policy = "never",
            vertical_scroll_policy = "auto"
        }
        ammo_scroll_pane.style.maximal_height = 300
        ammo_scroll_pane.style.minimal_width = 500
        if #ammo_list > 0 then
            local ammo_table = ammo_scroll_pane.add{
                type = "table",
                name = "ammo_table",
                column_count = 2,
                style = "table"
            }
            for _, item in ipairs(ammo_list) do
                add_item_entry(ammo_table, item, available_items[item.name])
            end
        else
            ammo_scroll_pane.add{
                type = "label",
                caption = "No Ammo items available"
            }.style.font_color = {r=0.5, g=0.5, b=0.5}
        end
        tabbed_pane.add_tab(ammo_tab, ammo_content)
    end
    
    if needs_fuel then
        local fuel_tab = tabbed_pane.add{
            type = "tab",
            name = "fuel_tab",
            caption = "[img=item/rocket-fuel] Fuel",
            tooltip = "Fuel for vehicle burner"
        }
        local fuel_content = tabbed_pane.add{
            type = "flow",
            name = "fuel_content",
            direction = "vertical"
        }
        local fuel_scroll_pane = fuel_content.add{
            type = "scroll-pane",
            name = "fuel_scroll_pane",
            horizontal_scroll_policy = "never",
            vertical_scroll_policy = "auto"
        }
        fuel_scroll_pane.style.maximal_height = 300
        fuel_scroll_pane.style.minimal_width = 500
        if #fuel_list > 0 then
            local fuel_table = fuel_scroll_pane.add{
                type = "table",
                name = "fuel_table",
                column_count = 2,
                style = "table"
            }
            for _, item in ipairs(fuel_list) do
                add_item_entry(fuel_table, item, available_items[item.name])
            end
        else
            fuel_scroll_pane.add{
                type = "label",
                caption = "No Fuel items available"
            }.style.font_color = {r=0.5, g=0.5, b=0.5}
        end
        tabbed_pane.add_tab(fuel_tab, fuel_content)
    end
    
    if has_equipment and api.is_tfmg_active() then
        local equipment_tab = tabbed_pane.add{
            type = "tab",
            name = "equipment_tab",
            caption = "[img=item/personal-roboport-equipment] Equipment",
            tooltip = "Equipment grid modules"
        }
        local equipment_content = tabbed_pane.add{
            type = "flow",
            name = "equipment_content",
            direction = "vertical"
        }
        local equipment_scroll_pane = equipment_content.add{
            type = "scroll-pane",
            name = "equipment_scroll_pane",
            horizontal_scroll_policy = "never",
            vertical_scroll_policy = "auto"
        }
        equipment_scroll_pane.style.maximal_height = 300
        equipment_scroll_pane.style.minimal_width = 500
        
        local vehicle_stack = nil
        local grid = nil
        if vehicle_data.hub and vehicle_data.hub.valid then
            local inv_type = vehicle_data.inv_type or defines.inventory.chest
            local hub_inventory = vehicle_data.hub.get_inventory(inv_type)
            if hub_inventory then
                vehicle_stack = hub_inventory[vehicle_data.inventory_slot]
                if vehicle_stack and vehicle_stack.valid_for_read then
                    grid = vehicle_stack.grid
                    if not grid then
                        local success, created_grid = pcall(function()
                            return vehicle_stack.create_grid()
                        end)
                        if success and created_grid then
                            grid = created_grid
                        end
                    end
                end
            end
        end
        
        -- MULTIPLAYER FIX: Store in player-specific storage
        if grid and grid.valid then
            storage.temp_deployment_data[player.index].equipment_grid = grid
            storage.temp_deployment_data[player.index].equipment_vehicle_stack = vehicle_stack
        end

        -- local equipment_counts = {}
        local has_ghosts = false
        -- First, normalize the data to group by equipment_name + quality
        local normalized_equipment = {}
        if grid and grid.valid then
            for _, equipment in pairs(grid.equipment) do
                if equipment and equipment.valid then
                    local is_ghost = equipment.prototype and equipment.prototype.type == "equipment-ghost"
                    local equipment_name = equipment.name
                    
                    if is_ghost and equipment.ghost_name and equipment.ghost_name ~= "" then
                        equipment_name = equipment.ghost_name
                    end
                    
                    -- Get quality name
                    local quality_name = "Normal"
                    local quality_level = 0

                    if equipment.quality then
                        quality_name = equipment.quality.name  -- Direct access works fine!
                        quality_level = equipment.quality.level or 0
                    end
                    
                    -- Key is equipment_name:quality
                    local key = equipment_name .. ":" .. quality_name
                    
                    if not normalized_equipment[key] then
                        local equipment_prototype = prototypes.equipment[equipment_name]
                        normalized_equipment[key] = {
                            equipment_name = equipment_name,
                            localised_name = equipment_prototype and equipment_prototype.localised_name or equipment_name,
                            quality_name = quality_name,
                            quality_level = quality_level,
                            real_count = 0,
                            ghost_count = 0
                        }
                    end
                    
                    if is_ghost then
                        normalized_equipment[key].ghost_count = normalized_equipment[key].ghost_count + 1
                        has_ghosts = true
                    else
                        normalized_equipment[key].real_count = normalized_equipment[key].real_count + 1
                    end
                end
            end
        end

        -- Sort by equipment name, then by quality level
        local sorted_equipment = {}
        for _, data in pairs(normalized_equipment) do
            table.insert(sorted_equipment, data)
        end

        table.sort(sorted_equipment, function(a, b)
            -- First sort by equipment name (using localised_name)
            local name_a = type(a.localised_name) == "string" and a.localised_name or tostring(a.localised_name)
            local name_b = type(b.localised_name) == "string" and b.localised_name or tostring(b.localised_name)
            
            if name_a ~= name_b then
                return name_a < name_b
            end
            
            -- Then sort by quality level (Normal=0, Uncommon=1, etc.)
            return a.quality_level < b.quality_level
        end)

        local equipment_list_flow = equipment_scroll_pane.add{
            type = "flow",
            name = "equipment_list_flow",
            direction = "vertical"
        }
        equipment_list_flow.style.top_padding = 10
        equipment_list_flow.style.bottom_padding = 10
        equipment_list_flow.style.left_padding = 10
        equipment_list_flow.style.right_padding = 10

        if next(normalized_equipment) then            
            for _, eq in ipairs(sorted_equipment) do
                -- Build caption: "Name [Quality] x5 (x2 unfulfilled)"
                local quality_display = eq.quality_name ~= "Normal" and " [" .. eq.quality_name .. "]" or ""
                local real_display = eq.real_count > 0 and (" x" .. eq.real_count) or ""
                local ghost_display = eq.ghost_count > 0 and (" (x" .. eq.ghost_count .. " unfulfilled)") or ""
                
                local caption
                if type(eq.localised_name) == "string" then
                    caption = eq.localised_name .. quality_display .. real_display .. ghost_display
                else
                    caption = {"", eq.localised_name, quality_display, real_display, ghost_display}
                end
                
                local equipment_label = equipment_list_flow.add{
                    type = "label",
                    caption = caption
                }
                equipment_label.style.top_padding = 2
                equipment_label.style.bottom_padding = 2
                
                -- Color blue if ANY ghosts exist for this equipment+quality combo
                if eq.ghost_count > 0 then
                    equipment_label.style.font_color = {r=0.5, g=0.7, b=1}
                end
            end
        else
            local no_equipment_label = equipment_list_flow.add{
                type = "label",
                caption = "No equipment installed",
                style = "caption_label"
            }
            no_equipment_label.style.font_color = {r=0.7, g=0.7, b=0.7}
        end

        -- Show warning if ghosts exist
        if has_ghosts then
            local warning_flow = equipment_scroll_pane.add{
                type = "flow",
                direction = "vertical"
            }
            warning_flow.style.top_padding = 10
            warning_flow.style.left_padding = 10
            warning_flow.style.right_padding = 10
            
            local warning_label = warning_flow.add{
                type = "label",
                caption = "[color=yellow]Unfulfilled equipment requests detected. You can deploy anyway, and if the platform has the equipment items, the vehicle will attempt to fill the loadout.[/color]"
            }
            warning_label.style.single_line = false
            warning_label.style.maximal_width = 480
        end

        -- Store ghost status for deployment validation
        storage.temp_deployment_data[player.index].has_equipment_ghosts = has_ghosts

        local button_flow = equipment_scroll_pane.add{
            type = "flow",
            name = "equipment_button_flow",
            direction = "horizontal"
        }
        button_flow.style.horizontally_stretchable = true
        button_flow.style.horizontal_align = "center"
        button_flow.style.top_padding = 10
        button_flow.style.bottom_padding = 10

        local open_grid_button = button_flow.add{
            type = "button",
            name = "open_equipment_grid_btn",
            caption = "Manage Equipment Grid",
            style = "button"
        }
        open_grid_button.style.minimal_width = 200
        open_grid_button.style.minimal_height = 40
        open_grid_button.tooltip = "Configure equipment before deployment"
        
        tabbed_pane.add_tab(equipment_tab, equipment_content)
    end
    
    -- local vert_spacer = frame.add{
    --     type = "empty-widget"
    -- }
    -- vert_spacer.style.minimal_height = 10

    -- CHANGED: Single Deploy button at bottom
    local button_flow = frame.add{
        type = "flow",
        name = "button_flow",
        direction = "horizontal"
    }
    button_flow.style.horizontal_align = "right"
    button_flow.style.horizontally_stretchable = true

    button_flow.add{
        type = "button",
        name = "confirm_deploy_btn",
        caption = "Deploy",
        tooltip = "Deploy vehicle",
        style = "confirm_button"
    }
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

function map_gui.on_player_changed_surface(event)
    local player = game.get_player(event.player_index)
    if player then
        if player.gui.screen["spidertron_deployment_frame"] then
            player.gui.screen["spidertron_deployment_frame"].destroy()
        end
    end
end

function map_gui.on_player_changed_render_mode(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local space_platform_researched = player.force.technologies["space-platform"] and player.force.technologies["space-platform"].researched or false
    
    if space_platform_researched then
        player.set_shortcut_available("orbital-spidertron-deploy", true)
    else
        player.set_shortcut_available("orbital-spidertron-deploy", false)
    end
end

local function collect_selected_extras(player, frame)
    local selected_extras = {}
    
    local function find_text_fields(element, results)
        if not element or not element.valid then return end
        
        if element.type == "textfield" and 
           element.name and 
           string.find(element.name, "^text_") then
            table.insert(results, element)
        end
        
        if element.children then
            for _, child in pairs(element.children) do
                find_text_fields(child, results)
            end
        end
    end

    local text_fields = {}
    if frame and frame.valid then
        find_text_fields(frame, text_fields)
        
        for _, field in pairs(text_fields) do
            local name = field.name
            local _, _, item_name, quality = string.find(name, "text_(.+)_(.+)")
            local in_grid = false
            if item_name and prototypes.item[item_name] and prototypes.item[item_name].place_as_equipment_result then
                local place_result = prototypes.item[item_name].place_as_equipment_result
                if type(place_result) == "string" then
                    if place_result:match("%-ghost$") then
                        in_grid = place_result:gsub("%-ghost$", "")
                    else
                        in_grid = place_result
                    end
                elseif place_result and place_result.name then
                    local eq_name = place_result.name
                    if eq_name:match("%-ghost$") then
                        in_grid = {name = eq_name:gsub("%-ghost$", "")}
                    else
                        in_grid = place_result
                    end
                else
                    in_grid = place_result
                end
            end
            
            if item_name and quality then
                local count = tonumber(field.text) or 0
                if count > 0 then
                    table.insert(selected_extras, {
                        name = item_name,
                        count = count,
                        quality = quality,
                        in_grid = in_grid
                    })
                end
            end
        end
    end
    
    return selected_extras
end

function handle_extras_menu_clicks(event)
    local element = event.element
    if not element or not element.valid then return end
    
    local player = game.get_player(event.player_index)
    if not player then return end
    
    -- CHANGED: X button now goes back to vehicle list
    if element.name == "close_extras_menu_btn" then
        if player.gui.screen["spidertron_extras_frame"] then
            player.gui.screen["spidertron_extras_frame"].destroy()
        end
        
        -- Reopen vehicle list
        local vehicles = map_gui.find_orbital_vehicles(player.surface)
        map_gui.show_deployment_menu(player, vehicles)
        return
    end
    
    -- CHANGED: Single deploy button (replaces both old buttons)
    if element.name == "confirm_deploy_btn" then
        local deployment_data = storage.temp_deployment_data and storage.temp_deployment_data[player.index]
        if not deployment_data then
            return
        end
        
        if deployment_data.has_equipment_ghosts == true then
            player.print("Has ghosts, checking tab...")
            
            local frame = player.gui.screen["spidertron_extras_frame"]
            if frame and frame.valid then
                local tabbed_pane = frame["extras_tabbed_pane"]
                if tabbed_pane and tabbed_pane.valid then
                    -- Count tabs to find equipment tab's index among TABS ONLY
                    local equipment_tab_index = nil
                    local tab_count = 0
                    
                    for i = 1, #tabbed_pane.children do
                        local child = tabbed_pane.children[i]
                        
                        if child.type == "tab" then
                            tab_count = tab_count + 1
                            player.print("Tab #" .. tab_count .. ": " .. tostring(child.name))
                            
                            if child.name == "equipment_tab" then
                                equipment_tab_index = tab_count
                                player.print("Found equipment_tab at tab index " .. tab_count)
                                break
                            end
                        end
                    end
                    
                    if equipment_tab_index then
                        local current_index = tabbed_pane.selected_tab_index or 1
                        player.print("Current tab: " .. current_index .. ", Equipment tab: " .. equipment_tab_index)
                        
                        if current_index == equipment_tab_index then
                            player.print("Already on equipment tab, allowing deployment")
                            -- Fall through
                        else
                            player.print("Switching to equipment tab...")
                            tabbed_pane.selected_tab_index = equipment_tab_index
                            player.print("[color=yellow]Unfulfilled equipment requests detected. Review equipment tab before deploying.[/color]")
                            return
                        end
                    end
                end
            end
        end

        -- Continue with deployment...
        local vehicle_data = deployment_data.vehicle
        
        -- REVALIDATION: Check if vehicle still exists
        local hub = vehicle_data.hub
        if not hub or not hub.valid then
            player.print("[color=red]Deployment failed: Platform hub no longer available[/color]")
            if player.gui.screen["spidertron_extras_frame"] then
                player.gui.screen["spidertron_extras_frame"].destroy()
            end
            storage.temp_deployment_data[player.index] = nil
            local vehicles = map_gui.find_orbital_vehicles(player.surface)
            map_gui.show_deployment_menu(player, vehicles)
            return
        end
        
        local inv_type = vehicle_data.inv_type or defines.inventory.chest
        local hub_inventory = hub.get_inventory(inv_type)
        if not hub_inventory then
            player.print("[color=red]Deployment failed: Cannot access platform inventory[/color]")
            if player.gui.screen["spidertron_extras_frame"] then
                player.gui.screen["spidertron_extras_frame"].destroy()
            end
            storage.temp_deployment_data[player.index] = nil
            local vehicles = map_gui.find_orbital_vehicles(player.surface)
            map_gui.show_deployment_menu(player, vehicles)
            return
        end
        
        local inventory_slot = vehicle_data.inventory_slot
        local stack = hub_inventory[inventory_slot]
        
        if not stack or not stack.valid_for_read or stack.name ~= vehicle_data.vehicle_name then
            player.print("[color=red]This vehicle was already deployed by another player[/color]")
            if player.gui.screen["spidertron_extras_frame"] then
                player.gui.screen["spidertron_extras_frame"].destroy()
            end
            storage.temp_deployment_data[player.index] = nil
            local vehicles = map_gui.find_orbital_vehicles(player.surface)
            map_gui.show_deployment_menu(player, vehicles)
            return
        end
        
        -- Collect selected extras
        local frame = player.gui.screen["spidertron_extras_frame"]
        local selected_extras = collect_selected_extras(player, frame)
        
        -- REVALIDATION: Check if selected items are still available
        if #selected_extras > 0 then
            local items_valid = true
            local missing_items = {}
            
            -- Count what we need
            local needed_items = {}
            for _, extra in ipairs(selected_extras) do
                local key = extra.name .. ":" .. (extra.quality or "Normal")
                needed_items[key] = (needed_items[key] or 0) + extra.count
            end
            
            -- Count what we have
            local found_items = {}
            for i = 1, #hub_inventory do
                local inv_stack = hub_inventory[i]
                if inv_stack.valid_for_read then
                    for key, needed in pairs(needed_items) do
                        local item_name, quality = key:match("(.+):(.+)")
                        
                        if inv_stack.name == item_name then
                            local stack_quality = get_quality_name(inv_stack.quality)
                            
                            if stack_quality == quality then
                                found_items[key] = (found_items[key] or 0) + inv_stack.count
                            end
                        end
                    end
                end
            end
            
            -- Check availability
            for key, needed in pairs(needed_items) do
                local found = found_items[key] or 0
                if found < needed then
                    items_valid = false
                    local item_name, quality = key:match("(.+):(.+)")
                    table.insert(missing_items, {
                        name = item_name,
                        quality = quality,
                        needed = needed,
                        available = found
                    })
                end
            end
            
            if not items_valid then
                -- Show error and stay in extras menu
                local error_msg = "[color=red]Some selected items are no longer available:[/color]"
                for _, item in ipairs(missing_items) do
                    error_msg = error_msg .. "\n" .. item.name .. " (" .. item.quality .. "): need " .. item.needed .. ", have " .. item.available
                end
                player.print(error_msg)
                return
            end
        end
        
        -- Everything validated, proceed with deployment
        if player.gui.screen["spidertron_extras_frame"] then
            player.gui.screen["spidertron_extras_frame"].destroy()
        end
        
        deployment.deploy_spider_vehicle(
            player, 
            deployment_data.vehicle, 
            deployment_data.deploy_target,
            selected_extras
        )
        
        storage.temp_deployment_data[player.index] = nil
        
        return
    end
end

function map_gui.on_gui_click(event)
    local element = event.element
    if not element or not element.valid then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    if element.name == "close_deployment_menu_btn" then
        if player.gui.screen["spidertron_deployment_frame"] then
            player.gui.screen["spidertron_deployment_frame"].destroy()
        end
        return
    end

    if element.name == "open_equipment_grid_btn" then
        local deployment_data = storage.temp_deployment_data and storage.temp_deployment_data[player.index]
        if not deployment_data then
            player.print("Error: No deployment data found")
            return
        end
        
        local vehicle_data = deployment_data.vehicle
        if not vehicle_data then
            player.print("Error: No vehicle data found")
            return
        end
        
        if not vehicle_data.hub or not vehicle_data.hub.valid then
            player.print("Error: Hub is invalid")
            return
        end
        
        local inv_type = vehicle_data.inv_type or defines.inventory.chest
        local hub_inventory = vehicle_data.hub.get_inventory(inv_type)
        if not hub_inventory then
            player.print("Error: Could not get hub inventory")
            return
        end
        
        local inventory_slot = vehicle_data.inventory_slot
        if not inventory_slot then
            player.print("Error: No inventory slot specified")
            return
        end
        
        local vehicle_stack = hub_inventory[inventory_slot]
        if not vehicle_stack then
            player.print("Error: Vehicle stack is nil")
            return
        end
        if not vehicle_stack.valid_for_read then
            player.print("Error: Vehicle stack is not readable")
            return
        end
        
        if player.gui.screen["spidertron_extras_frame"] then
            player.gui.screen["spidertron_extras_frame"].destroy()
        end
        
        local grid = vehicle_stack.grid
        if not grid then
            local success, created_grid = pcall(function()
                return vehicle_stack.create_grid()
            end)
            if success and created_grid then
                grid = created_grid
            else
                player.print("Error: Failed to create equipment grid")
                return
            end
        end
        
        if not grid or not grid.valid then
            player.print("Error: Grid is invalid")
            return
        end
        
        player.opened = grid
        
        local opened = player.opened
        
        if not opened or opened ~= grid then
            player.opened = vehicle_stack
        end
        
        return
    end

    if element.name == "close_extras_menu_btn" or 
       element.name == "confirm_deploy_btn" then
        handle_extras_menu_clicks(event)
        return
    end

    local edit_grid_index_str = string.match(element.name, "^edit_equipment_grid_(%d+)$")
    if edit_grid_index_str then
        local index = tonumber(edit_grid_index_str)
        if storage.spidertrons and storage.spidertrons[index] then
            local vehicle = storage.spidertrons[index]
            
            storage.current_equipment_grid_vehicle = vehicle
            
            local hub = vehicle.hub
            if not hub or not hub.valid then
                return
            end
            
            local inv_type = vehicle.inv_type or defines.inventory.chest
            local hub_inventory = hub.get_inventory(inv_type)
            if not hub_inventory then
                return
            end
            
            local vehicle_stack = hub_inventory[vehicle.inventory_slot]
            if not vehicle_stack then
                return
            end
            if not vehicle_stack.valid_for_read then
                return
            end
            
            if player.gui.screen["spidertron_deployment_frame"] then
                player.gui.screen["spidertron_deployment_frame"].destroy()
            end
            
            local grid = vehicle_stack.grid
            if not grid then
                local success, created_grid = pcall(function()
                    return vehicle_stack.create_grid()
                end)
                if success and created_grid then
                    grid = created_grid
                else
                    player.print("Error: Failed to create equipment grid")
                    return
                end
            end
            
            if not grid or not grid.valid then
                player.print("Error: Grid is invalid")
                return
            end
            
            player.opened = grid
            
            local opened = player.opened
            
            if not opened or opened ~= grid then
                player.opened = vehicle_stack
            end
        end
        return
    end
    
    local target_index_str = string.match(element.name, "^deploy_target_(%d+)$")
    if target_index_str then
        local index = tonumber(target_index_str)

        if index and storage.spidertrons and storage.spidertrons[index] then
            local vehicle = storage.spidertrons[index]

            if player.gui.screen["spidertron_deployment_frame"] then
                player.gui.screen["spidertron_deployment_frame"].destroy()
            end

            map_gui.show_extras_menu(player, vehicle, "target")
        end
        return
    end

    local player_index_str = string.match(element.name, "^deploy_player_(%d+)$")
    if player_index_str then
        local index = tonumber(player_index_str)

        if index and storage.spidertrons and storage.spidertrons[index] then
            local vehicle = storage.spidertrons[index]

            if player.gui.screen["spidertron_deployment_frame"] then
                player.gui.screen["spidertron_deployment_frame"].destroy()
            end

            map_gui.show_extras_menu(player, vehicle, "player")
        end
        return
    end
end

function map_gui.on_lua_shortcut(event)
    if event.prototype_name == "orbital-spidertron-deploy" then
        local player = game.get_player(event.player_index)
        if not player then return end
        
        local vehicles = map_gui.find_orbital_vehicles(player.surface)
        if #vehicles == 0 then
            return
        end
        
        map_gui.show_deployment_menu(player, vehicles)
    end
end

function map_gui.on_gui_closed(event)
    local player = game.get_player(event.player_index)
    if player and player.gui.screen["spidertron_deployment_frame"] then
        player.gui.screen["spidertron_deployment_frame"].destroy()
    end
end

function map_gui.destroy_deploy_button(player)
    if player.gui.screen["spidertron_deployment_frame"] then
        player.gui.screen["spidertron_deployment_frame"].destroy()
    end
end

function map_gui.initialize_player_shortcuts(player)
    
    local is_tfmg_active = api and api.is_tfmg_active() or false
    
    if not vehicles_list.spider_vehicles then
        vehicles_list.initialize()
    end
    local has_spider_vehicles = #vehicles_list.spider_vehicles > 0
    
    local should_enable = false
    
    if is_tfmg_active then
        should_enable = true
    elseif not has_spider_vehicles then
        should_enable = true
    else
        local space_platform_tech = player.force.technologies["space-platform"]
        local space_platform_researched = (space_platform_tech and space_platform_tech.researched) or false
        
        should_enable = space_platform_researched
    end
    
    if should_enable then
        player.set_shortcut_available("orbital-spidertron-deploy", true)
    else
        player.set_shortcut_available("orbital-spidertron-deploy", false)
    end
end

function map_gui.initialize_all_players()
    for _, player in pairs(game.players) do
        map_gui.initialize_player_shortcuts(player)
    end
end

function map_gui.setup_cleanup_task()
    script.on_nth_tick(300, function()
        if storage.pending_pod_deployments then
            local current_tick = game.tick
            local stale_ids = {}
            
            for id, data in pairs(storage.pending_pod_deployments) do
                local deployment_tick = tonumber(id:match("_%d+$"):sub(2))
                if current_tick - deployment_tick > 3600 then
                    table.insert(stale_ids, id)
                end
            end
            
            for _, id in ipairs(stale_ids) do
                storage.pending_pod_deployments[id] = nil
            end
        end
    end)
end

return map_gui