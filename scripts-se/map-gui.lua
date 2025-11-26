-- scripts-se/map-gui.lua
-- Space Exploration version - uses zone checking instead of platform checking
local vehicles_list = require("scripts-se.vehicles-list")
local deployment = require("scripts-se.deployment")

local map_gui = {}

-- Helper functions

local function get_sprite_name(item_name)
    -- Check if we have a custom sprite for this item
    local custom_sprite = "sl-" .. item_name
    return custom_sprite
end

local function sprite_exists(sprite_name)
    local success = pcall(function()
        game.is_valid_sprite_path(sprite_name)
    end)
    return success
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

-- Helper function to check if a zone type is a space type (where containers can be placed)
local function is_space_zone_type(zone_type)
    return zone_type == "orbit" or zone_type == "asteroid-belt" or zone_type == "asteroid-field"
end

-- Helper function to check if player is on a space surface (where deployment is not allowed)
local function is_on_space_surface(surface)
    local success, zone = pcall(function()
        return remote.call("space-exploration", "get_zone_from_surface_index", {surface_index = surface.index})
    end)
    if success and zone then
        return is_space_zone_type(zone.type)
    end
    return false
end

-- SE-SPECIFIC: find_orbital_vehicles function for Space Exploration
-- Uses zone checking instead of platform checking
function map_gui.find_orbital_vehicles(player_surface, player)
    local available_vehicles = {}
    local orbit_count = 0
    local hub_count = 0
    local inventory_count = 0
    
    log("[SE] Searching for orbital vehicles above " .. player_surface.name .. "...")
    if player then player.print("Searching for orbital vehicles above " .. player_surface.name .. "...") end
    
    -- SE-SPECIFIC: Get the player's current zone
    local player_zone = nil
    local success, result = pcall(function()
        return remote.call("space-exploration", "get_zone_from_surface_index", {surface_index = player_surface.index})
    end)
    if success and result then
        player_zone = result
        local zone_info = "Player is on zone: " .. (player_zone.name or "unknown") .. " (type: " .. (player_zone.type or "unknown") .. ")"
        log("[SE] " .. zone_info)
        if player then player.print(zone_info) end
    else
        log("[SE] Could not get player zone, remote call failed")
        if player then player.print("ERROR: Could not get player zone") end
        return available_vehicles
    end
    
    -- Determine which space surface to search (orbit, asteroid-belt, or asteroid-field)
    local target_orbit_surface = nil
    
    if is_space_zone_type(player_zone.type) then
        -- Player is already on a space surface (orbit, asteroid-belt, or asteroid-field) - use that surface
        target_orbit_surface = player_surface
        log("[SE] Player is on space surface: " .. player_surface.name .. " (type: " .. player_zone.type .. ")")
        if player then player.print("Player is on space surface: " .. player_surface.name .. " (type: " .. player_zone.type .. ")") end
    elseif player_zone.type == "planet" or player_zone.type == "moon" then
        -- Player is on a planet/moon - find the orbit, asteroid-belt, or asteroid-field for this planet
        local planet_name = player_zone.name or player_surface.name
        local expected_orbit_name = planet_name .. " Orbit"
        
        log("[SE] Player is on planet/moon: " .. planet_name)
        log("[SE] Looking for space surfaces (orbit, asteroid-belt, asteroid-field) for: " .. planet_name)
        if player then 
            player.print("Player is on planet/moon: " .. planet_name)
            player.print("Looking for space surfaces...")
        end
        
        -- Search all surfaces for matching space zones (orbit, asteroid-belt, asteroid-field)
        -- First try orbit (most common)
        for _, surface in pairs(game.surfaces) do
            log("[SE] Checking surface: " .. surface.name)
            local zone_success, zone_result = pcall(function()
                return remote.call("space-exploration", "get_zone_from_surface_index", {surface_index = surface.index})
            end)
            
            if zone_success and zone_result and is_space_zone_type(zone_result.type) then
                -- Check if this space zone's parent matches the player's zone
                local parent_matches = true
                if zone_result.parent then
                    parent_matches = (zone_result.parent.name == planet_name)
                    log("[SE] Space zone parent: " .. (zone_result.parent.name or "unknown") .. ", Planet: " .. planet_name)
                else
                    log("[SE] Space zone has no parent")
                end
                
                -- Use the space surface if parent matches, or if it's an orbit with matching name
                -- Note: asteroid-belt and asteroid-field zones are handled via parent matching (same as orbit when parent is set)
                if parent_matches or (zone_result.type == "orbit" and surface.name == expected_orbit_name) then
                    target_orbit_surface = surface
                    log("[SE] Found matching space surface: " .. surface.name .. " (type: " .. zone_result.type .. ")")
                    if player then player.print("Found space surface: " .. surface.name .. " (type: " .. zone_result.type .. ")") end
                    break
                end
            end
        end
        
        if not target_orbit_surface then
            log("[SE] Could not find space surface (orbit/asteroid-belt/asteroid-field) for planet: " .. planet_name)
            if player then player.print("ERROR: Could not find space surface for " .. planet_name) end
            return available_vehicles
        end
    else
        log("[SE] Player is on unknown zone type: " .. (player_zone.type or "unknown"))
        if player then player.print("ERROR: Unknown zone type") end
        return available_vehicles
    end
    
    -- Now search the target space surface for containers
    if target_orbit_surface then
        log("[SE] Searching space surface: " .. target_orbit_surface.name)
        if player then player.print("Searching space surface: " .. target_orbit_surface.name) end
        
        -- SE-SPECIFIC: Find deployment containers (ovd-deployment-container) on this space surface
        -- In SE, the container IS the hub - no need to check for separate hubs
        local containers = target_orbit_surface.find_entities_filtered({
            name = "ovd-deployment-container"
            -- No force filter - search all forces
        })
        
        log("[SE] Found " .. #containers .. " deployment containers on space surface " .. target_orbit_surface.name)
        if player then 
            player.print("Found " .. #containers .. " deployment containers on space surface " .. target_orbit_surface.name)
        end
        
        -- Process each container (container = hub in SE)
        for _, container in ipairs(containers) do
            if container and container.valid then
                hub_count = hub_count + 1
                local container_info = "Container #" .. hub_count .. " at (" .. math.floor(container.position.x) .. ", " .. math.floor(container.position.y) .. ")"
                log("[SE] " .. container_info)
                if player then player.print(container_info) end
                
                -- Try different inventory types but track which slots we've already processed
                local processed_slots = {}
                
                for _, inv_type in pairs({defines.inventory.chest}) do
                    local inventory = container.get_inventory(inv_type)
                    if inventory then
                        inventory_count = inventory_count + 1
                        local inv_info = "  Inventory type " .. inv_type .. " has " .. #inventory .. " slots"
                        log("[SE] " .. inv_info)
                        if player then player.print(inv_info) end
                        
                        -- Scan the inventory for all vehicles
                        local slot_count = 0
                        local vehicle_slot_count = 0
                        for i = 1, #inventory do
                            local stack = inventory[i]
                            if stack.valid_for_read then
                                slot_count = slot_count + 1
                                local slot_info = "    Slot " .. i .. ": " .. stack.name .. " x" .. stack.count
                                log("[SE] " .. slot_info)
                                if player then player.print(slot_info) end
                                
                                -- Check if this is a vehicle
                                local is_vehicle = vehicles_list.is_vehicle(stack.name)

                                if is_vehicle then
                                    vehicle_slot_count = vehicle_slot_count + 1
                                    log("[SE]      -> VEHICLE DETECTED: " .. stack.name)
                                    if player then player.print("      -> VEHICLE: " .. stack.name) end
                                end
                                
                                -- Is it a spider vehicle? (for categorization/filtering)
                                local is_spider_vehicle = vehicles_list.is_spider_vehicle(stack.name)
                                
                                if is_vehicle and not processed_slots[i] then
                                    processed_slots[i] = true
                                    log("[SE]      -> ADDING TO VEHICLE LIST: " .. stack.name)
                                    if player then player.print("      -> ADDING TO LIST: " .. stack.name) end
                                    
                                    -- Try to get the vehicle's custom name if available
                                    local name = stack.name:gsub("^%l", string.upper)
                                    
                                    -- Try to get entity_label directly from stack
                                    pcall(function()
                                        if stack.entity_label and stack.entity_label ~= "" then
                                            name = stack.entity_label
                                            log("[SE] Found entity_label directly: " .. name)
                                        end
                                    end)
                                    
                                    -- Fallbacks if direct entity_label didn't work
                                    if name == stack.name:gsub("^%l", string.upper) then
                                        pcall(function()
                                            -- Try label from the stack
                                            if stack.label and stack.label ~= "" then
                                                name = stack.label
                                                log("[SE] Found label: " .. name)
                                            -- Try to extract entity_label from item tags
                                            elseif stack.tags and stack.tags.entity_label then
                                                name = stack.tags.entity_label
                                                log("[SE] Found entity_label in tags: " .. name)
                                            end
                                        end)
                                    end
                                    
                                    -- Add debug log for final extracted name
                                    log("[SE] Final extracted vehicle name: " .. name)
                                    
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
                                            log("[SE] Found vehicle with quality: " .. quality.name)
                                        end
                                    end)
                                    
                                    -- Build tooltip with space surface details
                                    local tooltip = "Space Surface: " .. target_orbit_surface.name .. "\nSlot: " .. i
                                    
                                    -- Get entity name for placing
                                    local entity_name = stack.name
                                    
                                    -- Add the vehicle to the available vehicles list
                                    -- In SE, container = hub
                                    table.insert(available_vehicles, {
                                        name = name,
                                        tooltip = tooltip,
                                        color = color,
                                        index = i,
                                        hub = container,  -- Container IS the hub in SE
                                        inventory_slot = i,
                                        inv_type = inv_type,
                                        platform_name = target_orbit_surface.name,  -- Keep same field name for compatibility
                                        quality = quality,
                                        vehicle_name = stack.name,
                                        entity_name = entity_name,
                                        is_spider = is_spider_vehicle
                                    })
                                    
                                    log("[SE] Added " .. name .. " to available vehicles list")
                                end
                            end
                        end
                        
                        -- Summary for this inventory
                        local inv_summary = "  Inventory summary: " .. slot_count .. " filled slots, " .. vehicle_slot_count .. " vehicles"
                        log("[SE] " .. inv_summary)
                        if player then player.print(inv_summary) end
                    else
                        log("[SE] No inventory found for type " .. inv_type)
                        if player then player.print("  No inventory found for type " .. inv_type) end
                    end
                end
            end
        end
        
        if #containers == 0 then
            log("[SE] No deployment containers found on space surface " .. target_orbit_surface.name)
            if player then player.print("No deployment containers found on space surface " .. target_orbit_surface.name) end
        end
    end
    
    -- Summary log
    local summary = "===== SEARCH SUMMARY ====="
    log("[SE] " .. summary)
    if player then player.print(summary) end
    
    local surface_info = "Player surface: " .. player_surface.name
    log("[SE] " .. surface_info)
    if player then player.print(surface_info) end
    
    local orbits_info = "Orbits checked: " .. orbit_count
    log("[SE] " .. orbits_info)
    if player then player.print(orbits_info) end
    
    local hubs_info = "Hubs found: " .. hub_count
    log("[SE] " .. hubs_info)
    if player then player.print(hubs_info) end
    
    local inventories_info = "Inventories checked: " .. inventory_count
    log("[SE] " .. inventories_info)
    if player then player.print(inventories_info) end
    
    local vehicles_info = "Vehicles found: " .. #available_vehicles
    log("[SE] " .. vehicles_info)
    if player then player.print(vehicles_info) end
    
    local end_summary = "==========================="
    log("[SE] " .. end_summary)
    if player then player.print(end_summary) end
    
    -- Debug log of all found vehicles
    local complete_info = "Search complete. Found " .. orbit_count .. " orbits, " .. hub_count .. " hubs, " .. inventory_count .. " inventories, and " .. #available_vehicles .. " vehicles above " .. player_surface.name
    log("[SE] " .. complete_info)
    if player then player.print(complete_info) end
    
    for i, vehicle in ipairs(available_vehicles) do
        local vehicle_info = "Vehicle " .. i .. ": " .. vehicle.name .. " (" .. vehicle.vehicle_name .. ")"
        log("[SE] " .. vehicle_info)
        if player then player.print(vehicle_info) end
    end
    
    return available_vehicles
end

-- GUI Functions (same as SA version)

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
        caption = "Deploy from space above " .. player.surface.name:gsub("^%l", string.upper),
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

-- Rest of the file is identical to SA version - copying the remaining functions
-- (Due to length, I'll include the key functions that need to be present)

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
    
    if not any_items_available then
        if player.gui.screen["spidertron_deployment_frame"] then
            player.gui.screen["spidertron_deployment_frame"].destroy()
        end
        deployment.deploy_spider_vehicle(player, vehicle_data, deploy_target)
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
    
    -- Track if any items are shown for enabling the deploy button
    local items_shown = false
    
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
        style = "confirm_button"
    }

    storage.temp_deployment_data = {
        vehicle = vehicle_data,
        deploy_target = deploy_target,
        available_items = available_items
    }
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
        log("[SE] Hub is not valid when scanning inventory")
        return available_items
    end
    
    log("[SE] Scanning inventory of hub on space surface: " .. vehicle_data.platform_name)
    
    -- Only use chest inventory to avoid duplicates
    local inventory = hub.get_inventory(defines.inventory.chest)
    if not inventory then
        log("[SE] No chest inventory found on hub")
        return available_items
    end
    
    log("[SE] Hub inventory has " .. #inventory .. " slots")
    
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
                            log("[SE] Item has quality: " .. quality_name .. " (level " .. quality_level .. ")")
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
                    
                    log("[SE] Found " .. stack.count .. " " .. quality_name .. " quality " .. item_name .. " in slot " .. i)
                end
            end
        end
    end
    
    -- Log summary
    for item_name, info in pairs(available_items) do
        log("[SE] Total " .. item_name .. ": " .. info.total)
        for quality_key, quality_data in pairs(info.by_quality) do
            log("[SE]   - " .. quality_data.name .. " (level " .. quality_data.level .. "): " .. quality_data.count)
        end
    end
    
    return available_items
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
    end
end

-- Handle player exiting render mode (when they return to controlling the character)
function map_gui.on_player_changed_render_mode(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    -- Check both conditions
    local spidertron_researched = player.force.technologies["spidertron"].researched
    
    -- SE-SPECIFIC: Check if player is on a space surface (orbit, asteroid-belt, asteroid-field)
    local is_on_space = is_on_space_surface(player.surface)
    
    if spidertron_researched and not is_on_space then
        player.set_shortcut_available("orbital-spidertron-deploy", true)
    else
        player.set_shortcut_available("orbital-spidertron-deploy", false)
    end
end

-- Initialize player's shortcut buttons
function map_gui.initialize_player_shortcuts(player)
    -- First check if the technology is researched
    local spidertron_researched = player.force.technologies["spidertron"].researched
    
    -- SE-SPECIFIC: Check if player is on a space surface (orbit, asteroid-belt, asteroid-field)
    local is_on_space = is_on_space_surface(player.surface)
    
    -- Only enable if researched AND not on a space surface
    if spidertron_researched and not is_on_space then
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

-- Handle extras menu button clicks
local function handle_extras_menu_clicks(event)
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
    
    -- Back to deployment menu button
    if element.name == "back_to_deployment_btn" then
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
    
    -- Skip extras button (deploy without extras)
    if element.name == "skip_extras_btn" then
        player.print("========== SKIP EXTRAS BUTTON CLICKED ==========")
        player.print("Player: " .. player.name)
        
        -- Get the deployment data
        local deployment_data = storage.temp_deployment_data
        if not deployment_data then
            player.print("ERROR: No deployment data found in storage")
            return
        end
        
        player.print("Deployment data found:")
        player.print("  Vehicle name: " .. (deployment_data.vehicle.name or "unknown"))
        player.print("  Deploy target: " .. (deployment_data.deploy_target or "unknown"))
        player.print("  Hub entity: " .. (deployment_data.vehicle.hub and deployment_data.vehicle.hub.name or "nil"))
        if deployment_data.vehicle.hub then
            player.print("  Hub unit_number: " .. (deployment_data.vehicle.hub.unit_number or "nil"))
            player.print("  Hub valid: " .. tostring(deployment_data.vehicle.hub.valid))
        end
        
        -- Close the extras menu
        if player.gui.screen["spidertron_extras_frame"] then
            player.gui.screen["spidertron_extras_frame"].destroy()
        end
        
        player.print("Calling deploy_spider_vehicle()...")
        -- Deploy the vehicle without extras
        deployment.deploy_spider_vehicle(player, deployment_data.vehicle, deployment_data.deploy_target)
        
        -- Clear the temp data
        storage.temp_deployment_data = nil
        player.print("========== SKIP EXTRAS COMPLETE ==========")
        
        return
    end
    
    -- Confirm deployment with extras
    if element.name == "confirm_deploy_with_extras_btn" then
        player.print("========== CONFIRM DEPLOY WITH EXTRAS BUTTON CLICKED ==========")
        player.print("Player: " .. player.name)
        
        -- Get the deployment data
        local deployment_data = storage.temp_deployment_data
        if not deployment_data then
            player.print("ERROR: No deployment data found in storage")
            return
        end
        
        player.print("Deployment data found:")
        player.print("  Vehicle name: " .. (deployment_data.vehicle.name or "unknown"))
        player.print("  Deploy target: " .. (deployment_data.deploy_target or "unknown"))
        player.print("  Hub entity: " .. (deployment_data.vehicle.hub and deployment_data.vehicle.hub.name or "nil"))
        if deployment_data.vehicle.hub then
            player.print("  Hub unit_number: " .. (deployment_data.vehicle.hub.unit_number or "nil"))
            player.print("  Hub valid: " .. tostring(deployment_data.vehicle.hub.valid))
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
            player.print("Found " .. #text_fields .. " text fields in extras menu")
            
            -- Process each text field
            for _, field in pairs(text_fields) do
                local name = field.name
                local _, _, item_name, quality = string.find(name, "text_(.+)_(.+)")
                
                if item_name and quality then
                    local count = tonumber(field.text) or 0
                    if count > 0 then
                        table.insert(selected_extras, {
                            name = item_name,
                            count = count,
                            quality = quality
                        })
                        player.print("Selected extra: " .. count .. "x " .. quality .. " " .. item_name)
                    end
                end
            end
        else
            player.print("WARNING: Extras frame not found or invalid")
        end
        
        player.print("Total extras selected: " .. #selected_extras)
    
        -- Close the extras menu
        if player.gui.screen["spidertron_extras_frame"] then
            player.gui.screen["spidertron_extras_frame"].destroy()
        end
    
        player.print("Calling deploy_spider_vehicle() with " .. #selected_extras .. " extras...")
        -- Deploy the vehicle with extras
        deployment.deploy_spider_vehicle(
            player, 
            deployment_data.vehicle, 
            deployment_data.deploy_target,
            selected_extras
        )
    
        -- Clear the temp data
        storage.temp_deployment_data = nil
        player.print("========== CONFIRM DEPLOY WITH EXTRAS COMPLETE ==========")
    
        return
    end
end

-- Handle GUI clicks
function map_gui.on_gui_click(event)
    local element = event.element
    if not element or not element.valid then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    log("[SE] GUI click on element: " .. element.name)

    -- Handle extras menu clicks
    if element.name == "close_extras_menu_btn" or 
       element.name == "skip_extras_btn" or
       element.name == "confirm_deploy_with_extras_btn" or
       element.name == "back_to_deployment_btn" then
        handle_extras_menu_clicks(event)
        return
    end

    -- Close deployment menu button
    if element.name == "close_deployment_menu_btn" then
        log("[SE] Close deployment menu button clicked")
        if player.gui.screen["spidertron_deployment_frame"] then
            player.gui.screen["spidertron_deployment_frame"].destroy()
        end
        return
    end

    -- Deploy to target location button
    local target_index_str = string.match(element.name, "^deploy_target_(%d+)$")
    if target_index_str then
        local index = tonumber(target_index_str)
        log("[SE] Deploy to target triggered for index: " .. index)

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
        log("[SE] Deploy to player triggered for index: " .. index)

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

return map_gui

