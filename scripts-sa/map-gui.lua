-- scripts-sa/map-gui.lua
local vehicles_list = require("scripts-sa.vehicles-list")
local deployment = require("scripts-sa.deployment")
local api = require("scripts-sa.api")

local map_gui = {}

-- Helper functions

local function sprite_exists(sprite_name)
    local success = pcall(function()
        helpers.is_valid_sprite_path(sprite_name)
    end)
    return success
end

local function get_sprite_name(item_name)
    -- Check if we have a custom sprite for this item
    local custom_sprite = "sl-" .. item_name
    if not sprite_exists(custom_sprite) then --if we dont have a custom sprite, fallback on the item sprite or something, idk. -ooba
        custom_sprite = "item/"..item_name
    end
    return custom_sprite
end

-- Cache for the ammo category mapping
local ammo_category_map = nil

-- Build the ammo category map dynamically from the game's prototypes
local function build_ammo_category_map()
    -- Skip if already built
    if ammo_category_map then return end
    
    -- Initialize the map
    ammo_category_map = {}
    
    -- Loop through all item prototypes
    for name, prototype in pairs(prototypes.item) do
        -- Check if it has an ammo category
        if prototype.ammo_category then
            -- Map the item name to its ammo category
            ammo_category_map[name] = prototype.ammo_category.name
        end
    end
end

-- Get the ammo category for a given item name
function get_ammo_category(item_name)
    -- Make sure the map is built
    if not ammo_category_map then
        build_ammo_category_map()
    end
    
    -- Return the category, or nil if not found
    return ammo_category_map[item_name]
end

function map_gui.find_orbital_vehicles(player_surface, player)
    local available_vehicles = {}
    local platform_count = 0
    local hub_count = 0
    local inventory_count = 0
    
    if player then
    end
    
    -- Iterate through all surfaces to find platforms
    for _, surface in pairs(game.surfaces) do
        -- Debug info for each surface
       --log("Checking surface: " .. surface.name)
        
        -- Check if this is a platform surface
        if surface.platform then
            platform_count = platform_count + 1
            if player then
            end
            
            -- Check if the platform is orbiting the player's current surface
            local is_orbiting_current_planet = false
            
            -- Check the platform's space_location
            if surface.platform.space_location then
                local platform_location = surface.platform.space_location
                
                -- Log the space_location for debugging
                local location_str = tostring(platform_location)
                if player then
                end
                
                -- Extract the planet name from the location string
                -- Pattern looks for text between ": " and " (planet)"
                local orbiting_planet = location_str:match(": ([^%(]+) %(planet%)")
                
                if orbiting_planet then
                    if player then
                    end
                    
                    -- Check if this platform is orbiting the current planet
                    if orbiting_planet == player_surface.name then
                        is_orbiting_current_planet = true
                        if player then
                        end
                    else
                        if player then
                        end
                    end
                else
                    if player then
                    end
                    -- If we can't determine, let's include it to be safe
                    is_orbiting_current_planet = true
                end
            else
                if player then
                end
                -- If no space_location is specified, assume it's valid
                is_orbiting_current_planet = true
            end
            
            -- Only proceed if the platform is orbiting the current planet
            if is_orbiting_current_planet then
                -- Check if the platform has a hub
                if surface.platform.hub and surface.platform.hub.valid then
                    hub_count = hub_count + 1
                    if player then
                    end
                    
                    -- Check for vehicles in the hub's inventory
                    local hub = surface.platform.hub
                    
                    -- Try different inventory types but track which slots we've already processed
                    local processed_slots = {}
                    
                    for _, inv_type in pairs({defines.inventory.chest}) do
                        local inventory = hub.get_inventory(inv_type)
                        if inventory then
                            inventory_count = inventory_count + 1
                            if player then
                            end
                            
                            -- Scan the inventory for all vehicles
                            for i = 1, #inventory do
                                local stack = inventory[i]
                                if stack.valid_for_read then
                                    if player then
                                    end
                                    
                                    -- Check if this is a vehicle
                                    local is_vehicle = vehicles_list.is_vehicle(stack.name)
                                    
                                    if is_vehicle then
                                        if player then
                                        end
                                    else
                                        if player then
                                        end
                                    end
                                    
                                    -- Is it a spider vehicle? (for categorization/filtering)
                                    local is_spider_vehicle = vehicles_list.is_spider_vehicle(stack.name)
                                    
                                    -- Check if this vehicle has deployment requirements (via API)
                                    local has_requirements = false
                                    local requirements_met = true
                                    local deploy_item = stack.name
                                    local entity_name = stack.name
                                    
                                    if is_vehicle and api.vehicle_requirements and api.vehicle_requirements[stack.name] then
                                        -- Check if vehicle has requirements registered
                                        has_requirements = true
                                        local req_data = api.vehicle_requirements[stack.name]
                                        
                                        -- Get deploy_item and entity_name from requirements
                                        deploy_item = req_data.deploy_item or stack.name
                                        entity_name = req_data.entity_name or stack.name
                                        
                                        -- Check if all required items exist
                                        local req_check, req_result = api.check_vehicle_requirements(stack.name, hub)
                                        if req_check then
                                            requirements_met = true
                                            if player then
                                            end
                                        else
                                            requirements_met = false
                                            if player then
                                            end
                                        end
                                    end
                                    
                                    -- Only add vehicle if it has no requirements OR all requirements are met
                                    local should_skip = false
                                    if is_vehicle and has_requirements and not requirements_met then
                                        should_skip = true
                                    end
                                    
                                    if is_vehicle and not processed_slots[i] and not should_skip then
                                        processed_slots[i] = true
                                        if player then
                                        end
                                        
                                        -- Try to get the vehicle's custom name if available
                                        local name = stack.name:gsub("^%l", string.upper)
                                        
                                        -- Try to get entity_label directly from stack
                                        pcall(function()
                                            if stack.entity_label and stack.entity_label ~= "" then
                                                name = stack.entity_label
                                               --log("Found entity_label directly: " .. name)
                                            end
                                        end)
                                        
                                        -- Fallbacks if direct entity_label didn't work
                                        if name == stack.name:gsub("^%l", string.upper) then
                                            pcall(function()
                                                -- Try label from the stack
                                                if stack.label and stack.label ~= "" then
                                                    name = stack.label
                                                   --log("Found label: " .. name)
                                                -- Try to extract entity_label from item tags
                                                elseif stack.tags and stack.tags.entity_label then
                                                    name = stack.tags.entity_label
                                                   --log("Found entity_label in tags: " .. name)
                                                end
                                            end)
                                        end
                                        
                                        -- Add debug log for final extracted name
                                       --log("Final extracted vehicle name: " .. name)
                                        
                                        -- Try to get color info safely
                                        local color = {r=1, g=0.5, b=0.0}  -- Default color
                                        pcall(function()
                                            if stack.entity_color then
                                                color = stack.entity_color
                                            end
                                        end)
                                        
                                        -- Try to get quality info safely
                                        local quality = nil
                                        pcall(function()
                                            if stack.quality then
                                                quality = stack.quality
                                               --log("Found vehicle with quality: " .. quality.name)
                                            end
                                        end)
                                        
                                        -- Build tooltip with platform details
                                        local tooltip = "Platform: " .. surface.name .. "\nSlot: " .. i
                                        
                                        -- Get entity name and deploy item (may have been set by requirements check)
                                        -- If not set by requirements, use defaults
                                        if not entity_name or entity_name == stack.name then
                                            -- Check if there's a registered requirement that specifies entity_name
                                            if api.vehicle_requirements and api.vehicle_requirements[stack.name] then
                                                local req_data = api.vehicle_requirements[stack.name]
                                                entity_name = req_data.entity_name or stack.name
                                                deploy_item = req_data.deploy_item or stack.name
                                            end
                                        end
                                        
                                        -- Default entity_name if still not set
                                        if not entity_name then
                                            entity_name = stack.name
                                        end
                                        
                                        -- Use deploy_item (from requirements) or vehicle_name (the actual item in inventory)
                                        local vehicle_item_name = deploy_item or stack.name
                                        
                                        -- Add the vehicle to the available vehicles list
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
                                            vehicle_name = stack.name,  -- The item in inventory
                                            deploy_item = vehicle_item_name,  -- The item to deploy (may differ)
                                            entity_name = entity_name,  -- The entity to create
                                            is_spider = is_spider_vehicle
                                        })
                                        
                                        if player then
                                        end
                                    end
                                end
                            end
                        else
                           --log("No inventory found for type " .. inv_type)
                        end
                    end
                else
                   --log("Platform has no valid hub")
                end
            else
               --log("Skipping platform as it's not orbiting the current planet")
            end
        else
           --log("Not a platform surface")
        end
    end
    
    -- Debug log of all found vehicles
   --log("Search complete. Found " .. platform_count .. " platforms, " .. hub_count .. " hubs, " .. inventory_count .. " inventories, and " .. #available_vehicles .. " vehicles above " .. player_surface.name)
    
    if player then
    end
    
    for i, vehicle in ipairs(available_vehicles) do
       --log("Vehicle " .. i .. ": " .. vehicle.name .. " (" .. vehicle.vehicle_name .. ")")
        if player then
        end
    end
    
    return available_vehicles
end

-- GUI Functions

-- Show spider vehicle deployment menu with target/player location options
function map_gui.show_deployment_menu(player, vehicles)
    -- Close existing dialog if any
    if player.gui.screen["spidertron_deployment_frame"] then
        player.gui.screen["spidertron_deployment_frame"].destroy()
    end
    
    -- Create the deployment menu frame
    local frame = player.gui.screen.add{
        type = "frame",
        name = "spidertron_deployment_frame",
        direction = "vertical"
    }
    
    player.opened = frame
    
    -- Position at top of screen
    frame.auto_center = false
    local resolution = player.display_resolution
    frame.location = {x = resolution.width / 2 - 200, y = 50}
    
    -- Add title bar with drag handle and close button
    local title_flow = frame.add{
        type = "flow",
        direction = "horizontal",
        name = "title_flow"
    }
    
    -- Add caption as label
    local title_label = title_flow.add{
        type = "label",
        caption = {"", " Orbital Deployment"},
        style = "frame_title"
    }
    title_label.drag_target = frame
    
    -- Add draggable space
    local drag_handle = title_flow.add{
        type = "empty-widget",
        style = "draggable_space_header"
    }
    drag_handle.style.horizontally_stretchable = true
    drag_handle.style.height = 24
    drag_handle.style.right_margin = 4
    drag_handle.ignored_by_interaction = false
    drag_handle.drag_target = frame
    
    -- Add close button
    local close_button = title_flow.add{
        type = "sprite-button",
        name = "close_deployment_menu_btn",
        sprite = "utility/close",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        tooltip = {"gui.close"},
        style = "frame_action_button"
    }
    
    -- Add title
    frame.add{
        type = "label",
        caption = "Deploy from orbit above " .. player.surface.name:gsub("^%l", string.upper),
        style = "caption_label"
    }
    
    if frame.vehicle_table then
        frame.vehicle_table.destroy()
    end
    
    -- Create a vertical scroll pane to contain the vehicles
    local scroll_pane = frame.add{
        type = "scroll-pane",
        name = "vehicle_scroll_pane",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "auto"
    }
    scroll_pane.style.maximal_height = 400
    scroll_pane.style.minimal_width = 400
    
    -- Create a table for the vehicles
    local vehicle_table = scroll_pane.add{
        type = "table",
        name = "vehicle_table",
        column_count = 1,  -- Single column layout
        --style = "spidertron_table"
    }
    vehicle_table.style.horizontal_spacing = 8
    vehicle_table.style.vertical_spacing = 4
    
    -- Add each vehicle
    for i, vehicle in ipairs(vehicles) do
        -- Create a container for each vehicle row
        local row_container = vehicle_table.add{
            type = "flow",
            direction = "horizontal",
            name = "vehicle_container_" .. i
        }
        row_container.style.vertical_align = "center"
        row_container.style.top_padding = 2
        row_container.style.bottom_padding = 2
        row_container.style.width = 380  -- Set fixed width to container
        
        -- Determine sprite name
        local sprite_name = "item/spidertron"  -- Default fallback
        if vehicle.vehicle_name then
            sprite_name = "item/" .. vehicle.vehicle_name
        end
                
        -- Icon container with vehicle sprite and quality overlay
        local icon_container = row_container.add{
            type = "flow"
        }
        icon_container.style.width = 28
        icon_container.style.height = 28
        icon_container.style.padding = 0
        icon_container.style.margin = 0

        -- Vehicle icon
        local entity_icon = icon_container.add{
            type = "sprite-button",
            sprite = sprite_name,
            tooltip = "Vehicle from " .. vehicle.platform_name
        }
        entity_icon.style.size = 28
        entity_icon.style.padding = 0
        entity_icon.style.margin = 0

        -- Add quality overlay if vehicle has quality
        if vehicle.quality and vehicle.quality.name ~= "Normal" then
            local quality_name = string.lower(vehicle.quality.name)
            local overlay_name = "sl-" .. quality_name
            local quality_overlay = icon_container.add{
                type = "sprite",
                sprite = overlay_name,
                tooltip = vehicle.quality.name .. " quality"
            }
            quality_overlay.style.size = 14
            quality_overlay.style.top_padding = 13
            quality_overlay.style.left_padding = -30
        end
        
        -- Name (possibly with color)
        local name_label = row_container.add{
            type = "label",
            caption = vehicle.name,
            tooltip = "Located on " .. vehicle.platform_name
        }
        name_label.style.minimal_width = 176
        
        if vehicle.color then
            name_label.style.font_color = vehicle.color
        end
        
        -- Add spacer to push buttons to the right
        local spacer = row_container.add{
            type = "empty-widget"
        }
        spacer.style.horizontally_stretchable = true
        spacer.style.minimal_width = 10
        
        -- Right side: buttons
        local button_flow = row_container.add{
            type = "flow",
            direction = "horizontal"
        }
        button_flow.style.horizontal_align = "right"
        
        -- Check if in map view (chart or zoomed-in chart)
        local in_map_view = player.render_mode == defines.render_mode.chart or 
                           player.render_mode == defines.render_mode.chart_zoomed_in
    
        -- Check if the player is on the same surface as their character
        local is_same_surface = player.surface == player.physical_surface
    
        if in_map_view then
            -- Always allow deploying to map target
            local target_button = button_flow.add{
                type = "sprite-button",
                name = "deploy_target_" .. i,
                sprite = "utility/shoot_cursor_green",
                tooltip = "Deploy to target location on map"
            }
            target_button.style.size = 28
            
            -- Only allow deploy to player if map view is of same surface as their body
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
            -- Not in map view, always show deploy-to-player
            local player_button = button_flow.add{
                type = "sprite-button",
                name = "deploy_player_" .. i,
                sprite = "entity/character",
                tooltip = "Deploy to your character's location"
            }
            player_button.style.size = 28
        end
    end
    
    -- Store the list for reference when clicking
    storage.spidertrons = vehicles  -- Keeping the same storage variable name for compatibility
end

--putting it here cause fuck it

local function match_in_list(list,string) --finds if theres a matching string in list, returns true if so, since we do alot of that, it makes sense to compact it to a function
    for _,name in pairs(list) do
        if name == string then return true end
    end
return false end

local function list_match_list(list,list_2) --this checks if theres any match between two lists
    for _,string in pairs(list_2) do
        if match_in_list(list,string) then return true end
    end
return false end


function map_gui.list_compatible_items_in_inventory(inventory,compatible_items_list,available_items)
    if not inventory then return game.print("inventory was nil") end
    local match_list = {}

    for i = 1, #inventory do
        local stack = inventory[i]
        if stack and stack.valid_for_read then
            if match_in_list(compatible_items_list,stack.name) then
                if not available_items[stack.name] then
                    available_items[stack.name] = {
                        total = 0,
                        by_quality = {}
                    }
                end
                local quality_name = "Normal"
                local quality_level = 1
                local quality_color = {r=1, g=1, b=1}
                pcall(function()
                    if stack.quality then
                        quality_name = stack.quality.name
                        quality_level = stack.quality.level
                        quality_color = stack.quality.color
                    end
                end)
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
return match_list end
    


function map_gui.show_extras_menu(player, vehicle_data, deploy_target)
    if player.gui.screen["spidertron_extras_frame"] then
        player.gui.screen["spidertron_extras_frame"].destroy()
    end
    
    -- Initialize lists for each section
    local utilities_list = {
        {name = "construction-robot", display_name = "Construction Robot"},
        {name = "repair-pack", display_name = "Repair Pack"}
    }
    local ammo_list = {}
    local fuel_list = {}
    local equipment_list = {}
    
    -- Scan platform inventory for available items
    local available_items = map_gui.scan_platform_inventory(vehicle_data)
    
    -- Check if the vehicle can use ammo
    local entity_prototype = prototypes.entity[vehicle_data.entity_name]
    local has_guns = false
    local compatible_ammo_categories = {}
    if entity_prototype and entity_prototype.guns then
        has_guns = true
        pcall(function()
            for gun_name, gun_data in pairs(entity_prototype.guns) do
                pcall(function()
                    if gun_data.attack_parameters then
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
                end)
            end
        end)
        
        -- Scan inventory for compatible ammo
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
                                local quality_name = "Normal"
                                local quality_level = 1
                                local quality_color = {r=1, g=1, b=1}
                                pcall(function()
                                    if stack.quality then
                                        quality_name = stack.quality.name
                                        quality_level = stack.quality.level
                                        quality_color = stack.quality.color
                                    end
                                end)
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
    -- Check if the vehicle needs fuel (has a burner accepting chemical fuel)
    local needs_fuel = false
    if entity_prototype and entity_prototype.burner_prototype then
        local burner = entity_prototype.burner_prototype
        if burner.fuel_categories and burner.fuel_categories["chemical"] then
            needs_fuel = true
        end
    end
    -- Scan for chemical fuel items if the vehicle needs fuel
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
                            local quality_name = "Normal"
                            local quality_level = 1
                            local quality_color = {r=1, g=1, b=1}
                            pcall(function()
                                if stack.quality then
                                    quality_name = stack.quality.name
                                    quality_level = stack.quality.level
                                    quality_color = stack.quality.color
                                end
                            end)
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

    --check if the vehichle prototype has an equipment grid
    local has_equipment
    if entity_prototype and entity_prototype.grid_prototype then
        has_equipment = true
        local grid_categories = entity_prototype.grid_prototype.equipment_categories
        local compatible_equipment = {}
        pcall(function() --not sure why we're pcalling functions but whatever
            for name, equipment_prototype in pairs(prototypes.equipment) do
                local equipment_categories = equipment_prototype.equipment_categories
                if list_match_list(equipment_categories,grid_categories) then
                    table.insert(compatible_equipment,equipment_prototype.take_result.name) --does falsely assume that the equipment is placed by the same item it makes when recivied. in exchange for (probably) being more performant
                end
            end
        end)

        local hub = vehicle_data.hub
        if hub and hub.valid then
            local hub_inventory = hub.get_inventory(defines.inventory.chest)
            equipment_list = map_gui.list_compatible_items_in_inventory(hub_inventory,compatible_equipment,available_items)
        end
    end
    
    -- Check if any items are available across all sections
    local any_items_available = false
    for _, item in ipairs(utilities_list) do
        if available_items[item.name] and available_items[item.name].total > 0 then
            any_items_available = true
            break
        end
    end
    for _, item in ipairs(ammo_list) do
        if available_items[item.name] and available_items[item.name].total > 0 then
            any_items_available = true
            break
        end
    end
    for _, item in ipairs(fuel_list) do
        if available_items[item.name] and available_items[item.name].total > 0 then
            any_items_available = true
            break
        end
    end
    for _, item in ipairs(equipment_list) do
        if available_items[item.name] and available_items[item.name].total > 0 then
            any_items_available = true
            break
        end
    end
    
    if not any_items_available then
        if player.gui.screen["spidertron_deployment_frame"] then
            player.gui.screen["spidertron_deployment_frame"].destroy()
        end
        -- Get default equipment and trunk items for this vehicle (if registered)
        local defaults = {equipment_grid = {}, trunk_items = {}}
        if api.vehicle_defaults and api.vehicle_defaults[vehicle_data.vehicle_name] then
            defaults = api.vehicle_defaults[vehicle_data.vehicle_name]
        end
        
        deployment.deploy_spider_vehicle(player, vehicle_data, deploy_target, nil, defaults)
        return
    end
    
    -- Create the extras menu frame
    local frame = player.gui.screen.add{
        type = "frame",
        name = "spidertron_extras_frame",
        direction = "vertical"
    }
    player.opened = frame
    frame.auto_center = false
    local resolution = player.display_resolution
    frame.location = {x = resolution.width / 2 - 250, y = resolution.height / 2 - 200}
    
    -- Add title bar
    local title_flow = frame.add{
        type = "flow",
        direction = "horizontal",
        name = "title_flow"
    }
    local title_label = title_flow.add{
        type = "label",
        caption = {"", " Deployment Add-ons"},
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
    local back_button = title_flow.add{
        type = "sprite-button",
        name = "back_to_deployment_btn",
        sprite = "utility/backward_arrow",
        hovered_sprite = "utility/backward_arrow",
        clicked_sprite = "utility/backward_arrow",
        tooltip = {"", "Back to Deployment Menu"},
        style = "frame_action_button"
    }
    local close_button = title_flow.add{
        type = "sprite-button",
        name = "close_extras_menu_btn",
        sprite = "utility/close",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        tooltip = {"gui.close"},
        style = "frame_action_button"
    }
    
    frame.add{
        type = "label",
        caption = "Add items to deploy with " .. vehicle_data.name,
        style = "caption_label"
    }
    
    -- Create tabbed pane
    local tabbed_pane = frame.add{
        type = "tabbed-pane",
        name = "extras_tabbed_pane"
    }
    
    -- Helper function to sort qualities by level
    local function sort_qualities(a, b)
        return a.level > b.level
    end
    
    -- Helper function to add item entry
    local function add_item_entry(items_table, item, item_info)
        if item_info and item_info.total > 0 then
            local qualities = {}
            for _, quality_data in pairs(item_info.by_quality) do
                table.insert(qualities, quality_data)
            end
            table.sort(qualities, sort_qualities)
            
            for _, quality_data in ipairs(qualities) do
                if quality_data.count > 0 then
                    items_shown = true
                    -- Left-aligned sprite and name
                    local left_flow = items_table.add{
                        type = "flow",
                        direction = "horizontal"
                    }
                    left_flow.style.vertical_align = "center"
                    local icon_container = left_flow.add{
                        type = "flow"
                    }
                    icon_container.style.width = 28
                    icon_container.style.height = 28
                    icon_container.style.padding = 0
                    icon_container.style.margin = 0
                    local sprite = icon_container.add{
                        type = "sprite-button",
                        sprite = get_sprite_name(item.name),
                    tooltip = string.gsub(quality_data.name, "^%l", string.upper) -- Capitalize first letter
                    }
                    sprite.style.size = 28
                    sprite.style.padding = 0
                    sprite.style.margin = 0
                    local quality_name = string.lower(quality_data.name)
                    local overlay_name = "sl-" .. quality_name
                    local quality_overlay = icon_container.add{
                        type = "sprite",
                        sprite = overlay_name,
                        tooltip = quality_data.name .. " quality"
                    }
                    quality_overlay.style.size = 14
                    quality_overlay.style.top_padding = 13
                    quality_overlay.style.left_padding = -30
                    left_flow.add{
                        type = "label",
                        caption = prototypes.item[item.name].localised_name or item.name .. " (" .. quality_data.count .. " available)"
                        --tooltip = {"Add " .. quality_data.name .. " " .. prototypes.item[item.name].localised_name or item.name .. " to deployment"}
                    }
                    
                    -- Right-aligned slider, text box, and stack button
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
                        sprite = "virtual-signal/signal-stack-size",--i couldnt tell you why but fp_stack broke, this works though.
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
                    slider.tooltip = "Select quantity to add"
                    count_textfield.tooltip = "Enter quantity to add"
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
    
    -- Track if any items are shown for enabling the deploy button
    local items_shown = false
    
    -- Tab 1: Utilities (always shown)
    local utilities_tab = tabbed_pane.add{
        type = "tab",
        name = "utilities_tab",
        caption = "[img=item/repair-pack] Utilities", -- Rich text with item icon
        tooltip = "Utilities"
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
        column_count = 2, -- Left (sprite+name), Right (slider+text+stack)
        style = "table"
    }
    for _, item in ipairs(utilities_list) do
        add_item_entry(utilities_table, item, available_items[item.name])
    end
    tabbed_pane.add_tab(utilities_tab, utilities_content)
    
    -- Tab 2: Ammo (shown if vehicle has guns)
    if has_guns then
        local ammo_tab = tabbed_pane.add{
            type = "tab",
            name = "ammo_tab",
            caption = "[img=item/firearm-magazine] Ammo", -- Rich text with item icon
            tooltip = "Ammo"
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
    
    -- Tab 3: Fuel (shown if vehicle needs fuel)
    if needs_fuel then
        local fuel_tab = tabbed_pane.add{
            type = "tab",
            name = "fuel_tab",
            caption = "[img=item/rocket-fuel] Fuel", -- Rich text with item icon
            tooltip = "Fuel"
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

    -- Tab 4: Equipment (shown if vehichle has equipment)
    if has_equipment then
        local equipment_tab = tabbed_pane.add{
            type = "tab",
            name = "equipment_tab",
            caption = "[img=item/roboport] Equipment", -- Rich text with item icon
            tooltip = "Equipment"
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
        if #equipment_list > 0 then
            local equipment_table = equipment_scroll_pane.add{
                type = "table",
                name = "equipment_table",
                column_count = 2,
                style = "table"
            }
            for _, item in ipairs(equipment_list) do
                add_item_entry(equipment_table, item, available_items[item.name])
            end
        else
            equipment_scroll_pane.add{
                type = "label",
                caption = "No equipment items available"
            }.style.font_color = {r=0.5, g=0.5, b=0.5}
        end
        tabbed_pane.add_tab(equipment_tab, equipment_content)
    end
    
    -- Add spacer
    local vert_spacer = frame.add{
        type = "empty-widget"
    }
    vert_spacer.style.minimal_height = 10

    -- Add deploy button row
    local button_flow = frame.add{
        type = "flow",
        name = "button_flow",
        direction = "horizontal"
    }
    button_flow.style.horizontal_align = "right"
    local button_spacer = button_flow.add{
        type = "empty-widget"
    }
    button_spacer.style.minimal_width = 10
    button_flow.add{
        type = "button",
        name = "skip_extras_btn",
        caption = "Deploy Without Extras",
        style = "back_button"
    }
    button_flow.add{
        type = "button",
        name = "confirm_deploy_with_extras_btn",
        caption = "Deploy with Selected Items",
        style = "confirm_button" -- Removed enabled = items_shown
    }

    storage.temp_deployment_data = {
        vehicle = vehicle_data,
        deploy_target = deploy_target,
        available_items = available_items
    }
end

-- Event Handlers

-- Listen for player changing surface
function map_gui.on_player_changed_surface(event)
    local player = game.get_player(event.player_index)
    if player then
        -- Close any open spidertron deployment menus
        if player.gui.screen["spidertron_deployment_frame"] then
            player.gui.screen["spidertron_deployment_frame"].destroy()
        end
        -- Update shortcut availability (platform check may have changed)
        map_gui.initialize_player_shortcuts(player)
    end
end

-- Handle player exiting render mode (when they return to controlling the character)
function map_gui.on_player_changed_render_mode(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    -- Use the same logic as initialize_player_shortcuts
    map_gui.initialize_player_shortcuts(player)
end

-- Improved platform inventory scanner with better debugging
function map_gui.scan_platform_inventory(vehicle_data)
    local available_items = {}
    local hub = vehicle_data.hub
    
    -- Define items to look for
    local items_to_scan = {
        "construction-robot",
        "repair-pack"
    }
    
    -- Initialize available items table
    for _, item_name in ipairs(items_to_scan) do
        available_items[item_name] = {
            total = 0,
            by_quality = {}
        }
    end
    
    -- If hub is not valid, return empty results
    if not hub or not hub.valid then
       --log("Hub is not valid when scanning inventory")
        return available_items
    end
    
   --log("Scanning inventory of hub on platform: " .. vehicle_data.platform_name)
    
    -- Only use chest inventory to avoid duplicates
    local inventory = hub.get_inventory(defines.inventory.chest)
    if not inventory then
       --log("No chest inventory found on hub")
        return available_items
    end
    
   --log("Hub inventory has " .. #inventory .. " slots")
    
    -- Scan each slot for items and their qualities
    for i = 1, #inventory do
        local stack = inventory[i]
        if stack and stack.valid_for_read then
            -- Check if this is one of our target items
            for _, item_name in ipairs(items_to_scan) do
                if stack.name == item_name then
                    -- Extract quality information
                    local quality_name = "Normal"
                    local quality_level = 1
                    local quality_color = {r=1, g=1, b=1}
                    
                    -- Try to get quality
                    pcall(function()
                        if stack.quality then
                            quality_name = stack.quality.name
                            quality_level = stack.quality.level
                            quality_color = stack.quality.color
                           --log("Item has quality: " .. quality_name .. " (level " .. quality_level .. ")")
                        end
                    end)
                    
                    -- Create a quality key for grouping
                    local quality_key = quality_name
                    
                    -- Initialize quality entry if needed
                    if not available_items[item_name].by_quality[quality_key] then
                        available_items[item_name].by_quality[quality_key] = {
                            name = quality_name,
                            level = quality_level,
                            color = quality_color,
                            count = 0
                        }
                    end
                    
                    -- Add to counts
                    available_items[item_name].by_quality[quality_key].count = 
                        available_items[item_name].by_quality[quality_key].count + stack.count
                    available_items[item_name].total = 
                        available_items[item_name].total + stack.count
                    
                   --log("Found " .. stack.count .. " " .. quality_name .. " quality " .. item_name .. " in slot " .. i)
                end
            end
        end
    end
    
    -- Log summary
    for item_name, info in pairs(available_items) do
       --log("Total " .. item_name .. ": " .. info.total)
        for quality_key, quality_data in pairs(info.by_quality) do
           --log("  - " .. quality_data.name .. " (level " .. quality_data.level .. "): " .. quality_data.count)
        end
    end
    
    return available_items
end

-- Update handle_extras_menu_clicks to handle qualities
function handle_extras_menu_clicks(event)
    local element = event.element
    if not element or not element.valid then return end
    
    local player = game.get_player(event.player_index)
    if not player then return end
    
    -- Close extras menu button
    if element.name == "close_extras_menu_btn" then
        if player.gui.screen["spidertron_extras_frame"] then
            player.gui.screen["spidertron_extras_frame"].destroy()
        end
        return
    end
    
    -- Skip extras button (deploy without extras)
    if element.name == "skip_extras_btn" then
        -- Get the deployment data
        local deployment_data = storage.temp_deployment_data
        if not deployment_data then
            return
        end
        
        -- Close the extras menu
        if player.gui.screen["spidertron_extras_frame"] then
            player.gui.screen["spidertron_extras_frame"].destroy()
        end
        
        -- Get default equipment and trunk items for this vehicle (if registered)
        local defaults = {equipment_grid = {}, trunk_items = {}}
        if api.vehicle_defaults and api.vehicle_defaults[deployment_data.vehicle.vehicle_name] then
            defaults = api.vehicle_defaults[deployment_data.vehicle.vehicle_name]
        end
        
        -- Deploy the vehicle without extras (but with defaults)
        deployment.deploy_spider_vehicle(player, deployment_data.vehicle, deployment_data.deploy_target, nil, defaults)
        
        -- Clear the temp data
        storage.temp_deployment_data = nil
        
        return
    end
    
    -- Confirm deployment with extras
    if element.name == "confirm_deploy_with_extras_btn" then
        -- Get the deployment data
        local deployment_data = storage.temp_deployment_data
        if not deployment_data then
            return
        end
    
        -- Build a list of selected extras
        local selected_extras = {}
    
        -- Helper function to recursively search for text fields
        local function find_text_fields(element, results)
            if not element or not element.valid then return end
            
            -- Check if this is a text field with our naming pattern
            if element.type == "textfield" and 
               element.name and 
               string.find(element.name, "^text_") then
                table.insert(results, element)
            end
            
            -- Recursively search children
            if element.children then
                for _, child in pairs(element.children) do
                    find_text_fields(child, results)
                end
            end
        end
    
        -- Find all text fields
        local text_fields = {}
        local frame = player.gui.screen["spidertron_extras_frame"]
        if frame and frame.valid then
            find_text_fields(frame, text_fields)
            
            -- Process each text field
            for _, field in pairs(text_fields) do
                local name = field.name
                local _, _, item_name, quality = string.find(name, "text_(.+)_(.+)")
                local in_grid = false
                if prototypes.item[item_name].place_as_equipment_result then
                    in_grid = prototypes.item[item_name].place_as_equipment_result
                end
                
                if item_name and quality then
                    local count = tonumber(field.text) or 0
                    if count > 0 then
                        table.insert(selected_extras, {
                            name = item_name,
                            count = count,
                            quality = quality,
                            in_grid = in_grid,
                        })
                    end
                end
            end
        end
        
        -- Close the extras menu
        if player.gui.screen["spidertron_extras_frame"] then
            player.gui.screen["spidertron_extras_frame"].destroy()
        end
        
        -- Get default equipment and trunk items for this vehicle (if registered)
        local defaults = {equipment_grid = {}, trunk_items = {}}
        if api.vehicle_defaults and api.vehicle_defaults[deployment_data.vehicle.vehicle_name] then
            defaults = api.vehicle_defaults[deployment_data.vehicle.vehicle_name]
        end
        
        -- Deploy the vehicle with extras (defaults will be merged with extras)
        deployment.deploy_spider_vehicle(
            player, 
            deployment_data.vehicle, 
            deployment_data.deploy_target,
            selected_extras,
            defaults
        )
        
        -- Clear the temp data
        storage.temp_deployment_data = nil
        
        return
    end
end

function map_gui.on_gui_click(event)
    local element = event.element
    if not element or not element.valid then return end

    local player = game.get_player(event.player_index)
    if not player then return end

   --log("GUI click on element: " .. element.name)

    -- Close deployment menu button
    if element.name == "close_deployment_menu_btn" then
       --log("Close deployment menu button clicked")
        if player.gui.screen["spidertron_deployment_frame"] then
            player.gui.screen["spidertron_deployment_frame"].destroy()
        end
        return
    end

    -- Handle extras menu clicks
    if element.name == "close_extras_menu_btn" or 
       element.name == "skip_extras_btn" or
       element.name == "confirm_deploy_with_extras_btn" then
        handle_extras_menu_clicks(event)
        return
    end

    -- Deploy to target location button
    local target_index_str = string.match(element.name, "^deploy_target_(%d+)$")
    if target_index_str then
        local index = tonumber(target_index_str)
       --log("Deploy to target triggered for index: " .. index)

        if index and storage.spidertrons and storage.spidertrons[index] then
            local vehicle = storage.spidertrons[index]

            -- Close the dialog
            if player.gui.screen["spidertron_deployment_frame"] then
                player.gui.screen["spidertron_deployment_frame"].destroy()
            end

            -- Show the extras menu instead of immediately deploying
            map_gui.show_extras_menu(player, vehicle, "target")
        end
        return
    end

    -- Deploy to player location button
    local player_index_str = string.match(element.name, "^deploy_player_(%d+)$")
    if player_index_str then
        local index = tonumber(player_index_str)
       --log("Deploy to player triggered for index: " .. index)

        if index and storage.spidertrons and storage.spidertrons[index] then
            local vehicle = storage.spidertrons[index]

            -- Close the dialog
            if player.gui.screen["spidertron_deployment_frame"] then
                player.gui.screen["spidertron_deployment_frame"].destroy()
            end

            -- Show the extras menu instead of immediately deploying
            map_gui.show_extras_menu(player, vehicle, "player")
        end
        return
    end
end

-- Update the on_gui_click function to include the extras menu buttons
local original_on_gui_click = map_gui.on_gui_click
function map_gui.on_gui_click(event)
    local element = event.element
    if not element or not element.valid then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    -- Handle extras menu clicks
    if element.name == "close_extras_menu_btn" or 
       element.name == "skip_extras_btn" or
       element.name == "confirm_deploy_with_extras_btn" then
        handle_extras_menu_clicks(event)
        return
    end

    if event.element.name == "back_to_deployment_btn" then
        -- Close the extras menu
        if player.gui.screen["spidertron_extras_frame"] then
            player.gui.screen["spidertron_extras_frame"].destroy()
        end
        
        -- Retrieve stored vehicle data
        local vehicles = map_gui.find_orbital_vehicles(player.surface, player)
        
        -- Reopen the deployment menu with the same vehicles list
        map_gui.show_deployment_menu(player, vehicles)
        return
    end

    -- Deploy to target location button (map cursor)
    local target_index_str = string.match(element.name, "^deploy_target_(%d+)$")
    if target_index_str then
        local index = tonumber(target_index_str)
       --log("Deploy to target triggered for index: " .. index)

        if index and storage.spidertrons and storage.spidertrons[index] then
            local vehicle = storage.spidertrons[index]

            -- Close the dialog
            if player.gui.screen["spidertron_deployment_frame"] then
                player.gui.screen["spidertron_deployment_frame"].destroy()
            end

            -- Show the extras menu instead of immediately deploying
            map_gui.show_extras_menu(player, vehicle, "target")
        end
        return
    end

    -- Deploy to player location button
    local player_index_str = string.match(element.name, "^deploy_player_(%d+)$")
    if player_index_str then
        local index = tonumber(player_index_str)
       --log("Deploy to player triggered for index: " .. index)

        if index and storage.spidertrons and storage.spidertrons[index] then
            local vehicle = storage.spidertrons[index]

            -- Close the dialog
            if player.gui.screen["spidertron_deployment_frame"] then
                player.gui.screen["spidertron_deployment_frame"].destroy()
            end

            -- Show the extras menu instead of immediately deploying
            map_gui.show_extras_menu(player, vehicle, "player")
        end
        return
    end

    -- For any other GUI clicks, call the original handler
    if original_on_gui_click then
        original_on_gui_click(event)
    end
end

-- Handle shortcut button clicks
function map_gui.on_lua_shortcut(event)
    if event.prototype_name == "orbital-spidertron-deploy" then
        local player = game.get_player(event.player_index)
        if not player then return end
        
        -- Find orbital spider vehicles
        local vehicles = map_gui.find_orbital_vehicles(player.surface, player)
        if #vehicles == 0 then
            --player.print("No vehicles are deployable to this surface.")
            return
        end
        
        -- Show selection dialog with appropriate deployment options
        map_gui.show_deployment_menu(player, vehicles)
    end
end

-- Handle the GUI being closed, such as pressing Esc or clicking the "X" button
function map_gui.on_gui_closed(event)
    local player = game.get_player(event.player_index)
    if player and player.gui.screen["spidertron_deployment_frame"] then
        -- Close the deployment menu when the GUI is closed
        player.gui.screen["spidertron_deployment_frame"].destroy()
    end
end

-- Remove any open deployment dialog (used in surface change or other events)
function map_gui.destroy_deploy_button(player)
    if player.gui.screen["spidertron_deployment_frame"] then
        player.gui.screen["spidertron_deployment_frame"].destroy()
    end
end

-- Initialize player's shortcut buttons
function map_gui.initialize_player_shortcuts(player)
    -- Check if TFMG mod is active
    local is_tfmg_active = api.is_tfmg_active()
    
    -- Check if any spider-vehicle types exist in the game
    if not vehicles_list.spider_vehicles then
        vehicles_list.initialize()
    end
    local has_spider_vehicles = #vehicles_list.spider_vehicles > 0
    
    -- Determine if on a platform surface
    -- Check if the surface has a platform property (more reliable than name matching)
    local is_on_platform = false
    if player.surface.platform then
        is_on_platform = true
    elseif player.surface.name:find("platform") then
        is_on_platform = true
    end
    
    -- Determine if shortcut should be enabled
    local should_enable = false
    
    if is_tfmg_active then
        -- TFMG is active, enable from start (scout-o-trons are in starting inventory)
        should_enable = true
    elseif not has_spider_vehicles then
        -- If no spider-vehicle types exist, unlock from start
        should_enable = true
    else
        -- Check for spider-related technologies
        local spidertron_tech = player.force.technologies["spidertron"]
        local any_spider_researched = (spidertron_tech and spidertron_tech.researched) or false
        
        -- Also check for modded spidertrons
        for tech_name, tech in pairs(player.force.technologies) do
            if tech.researched and (
                tech_name:find("spider") or 
                tech_name:find("spidertron") or 
                tech_name:find("spiderdrone") or
                tech_name:find("spiderbot")
            ) then
                any_spider_researched = true
                break
            end
        end
        
        should_enable = any_spider_researched
    end
    
    -- Enable shortcut if conditions are met
    -- With TFMG, ignore platform check (player is always on platform)
    if should_enable and (not is_on_platform or is_tfmg_active) then
        player.set_shortcut_available("orbital-spidertron-deploy", true)
    else
        player.set_shortcut_available("orbital-spidertron-deploy", false)
    end
end

-- Initialize players
function map_gui.initialize_all_players()
    for _, player in pairs(game.players) do
        map_gui.initialize_player_shortcuts(player)
    end
end

-- Set up periodic cleanup for deployment data
function map_gui.setup_cleanup_task()
    script.on_nth_tick(300, function()  -- Check every 5 seconds
        -- Clean up pod deployments
        if storage.pending_pod_deployments then
            local current_tick = game.tick
            local stale_ids = {}
            
            -- Find pod deployments older than 1 minute (3600 ticks)
            for id, data in pairs(storage.pending_pod_deployments) do
                local deployment_tick = tonumber(id:match("_%d+$"):sub(2))
                if current_tick - deployment_tick > 3600 then
                    table.insert(stale_ids, id)
                end
            end
            
            -- Remove stale deployments
            for _, id in ipairs(stale_ids) do
                storage.pending_pod_deployments[id] = nil
            end
            
            if #stale_ids > 0 then
               --log("Cleaned up " .. #stale_ids .. " stale pod deployment records")
            end
        end
    end)
end

return map_gui