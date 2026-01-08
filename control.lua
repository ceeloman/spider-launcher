-- control.lua
-- Consolidated control file with Space Age and Space Exploration compatibility

-- Determine which mods are active
local is_space_age = script.active_mods["space-age"] ~= nil
local is_space_exploration = script.active_mods["space-exploration"] ~= nil

-- Load modules
local map_gui = require("scripts.map-gui")
local deployment = require("scripts.deployment")
local vehicles_list = require("scripts.vehicles-list")
local platform_gui = require("scripts.platform-gui")
local equipment_grid_fill = require("scripts.equipment-grid-fill")
local container_deployment = require("scripts.container-deployment")
--local api = require("scripts.api")

-- Debug logging function
local function debug_log(message)
    if is_space_exploration then
        log("[Orbital Spider Delivery SE] " .. message)
    else
        log("[Orbital Spider Delivery SA] " .. message)
    end
end

-- Initialize storage
local function init_storage()
    storage = storage or {}
    storage.pending_deployments = storage.pending_deployments or {}
    storage.pending_pod_deployments = storage.pending_pod_deployments or {}
    storage.temp_deployment_data = storage.temp_deployment_data or {}
    
    if is_space_age then
        storage.pending_grid_open = storage.pending_grid_open or {}
        storage.current_equipment_grid_vehicle = storage.current_equipment_grid_vehicle or nil
    end
    
    if is_space_exploration then
        storage.cargo_bays = storage.cargo_bays or {}
        storage.cargo_bay_links = storage.cargo_bay_links or {}
    end
    
    debug_log("Storage initialized")
end

-- SE-SPECIFIC: Register a cargo bay in storage

-- ISSUE: Spaceships can change the surface of the bay, we need to track that or use the zone location at the time of deployment
local function register_cargo_bay(entity)
    if not is_space_exploration then return end
    if not entity or not entity.valid or entity.name ~= "ovd-deployment-container" then
        return
    end
    
    local unit_number = entity.unit_number
    if not unit_number then
        return
    end
    
    -- Get zone information
    local zone_name = nil
    local zone_type = nil
    local parent_zone_name = nil
    
    if remote.interfaces["space-exploration"] then
        local zone = remote.call("space-exploration", "get_zone_from_surface_index", {surface_index = entity.surface.index})
        if zone then
            zone_name = zone.name
            zone_type = zone.type
            if zone.parent then
                parent_zone_name = zone.parent.name
            end
        end
    end
    
    storage.cargo_bays[unit_number] = {
        entity = entity,
        surface_index = entity.surface.index,
        surface_name = entity.surface.name,
        zone_name = zone_name,
        zone_type = zone_type,
        parent_zone_name = parent_zone_name,
        last_checked_tick = game.tick
    }
end

-- SE-SPECIFIC: Unregister a cargo bay from storage
local function unregister_cargo_bay(unit_number)
    if not is_space_exploration then return end
    if storage.cargo_bays and storage.cargo_bays[unit_number] then
        storage.cargo_bays[unit_number] = nil
    end
end

-- SE-SPECIFIC: Register all existing cargo bays
local function register_all_cargo_bays()
    if not is_space_exploration then return end
    if not game then return end
    
    storage.cargo_bays = {}
    local count = 0
    
    for _, surface in pairs(game.surfaces) do
        local containers = surface.find_entities_filtered({
            name = "ovd-deployment-container"
        })
        
        for _, container in ipairs(containers) do
            if container and container.valid then
                register_cargo_bay(container)
                count = count + 1
            end
        end
    end
    
    debug_log("Registered " .. count .. " existing cargo bays")
end

-- Initialize player shortcuts
local function init_players()
    for _, player in pairs(game.players) do
        if is_space_exploration then
            -- SE: Enable based on se-space-capsule-navigation research
            local tech_researched = player.force.technologies["se-space-capsule-navigation"] and 
                                   player.force.technologies["se-space-capsule-navigation"].researched or false
            player.set_shortcut_available("orbital-spidertron-deploy", tech_researched)
        elseif is_space_age then
            -- SA: Enable based on space-platform research
            map_gui.initialize_player_shortcuts(player)
        end
    end
end

-- Register events on init
script.on_init(function()
    init_storage()
    init_players()
    
    if is_space_exploration then
        register_all_cargo_bays()
    end
    
    for _, player in pairs(game.players) do
        map_gui.initialize_player_shortcuts(player)
    end
    vehicles_list.initialize()
    
    debug_log("Module initialized")
end)

-- Register events on load
script.on_load(function()
    debug_log("Module loaded")
end)

-- Register events on configuration changed
script.on_configuration_changed(function(data)
    init_storage()
    init_players()
    
    if is_space_exploration then
        register_all_cargo_bays()
    end
    
    vehicles_list.initialize()
    
    debug_log("Configuration changed, storage reinitialized")
end)

-- Consolidated GUI click handler
script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if not element or not element.valid then return end

    if equipment_grid_fill then
        equipment_grid_fill.on_gui_click(event)
    end
    
    -- Handle stack buttons (both SA and SE)
    if element.tags and element.tags.action == "add_stack" then
        local player = game.players[event.player_index]
        if not player or not player.valid then return end
        
        local item_name = element.tags.item_name
        local quality_name = element.tags.quality_name
        local stack_size = element.tags.stack_size or 50
        local max_value = element.tags.max_value or 50
        
        -- Find section table
        local section_table
        local current = element
        while current and current.valid do
            if current.name == "utilities_table" or current.name == "ammo_table" or 
               current.name == "fuel_table" or current.name == "equipment_table" or 
               current.name == "supplies_table" then
                section_table = current
                break
            end
            current = current.parent
        end

        if not section_table then
            debug_log("Could not find section table for stack button")
            return
        end
        
        -- Find slider and text field
        local slider_name = "slider_" .. item_name .. "_" .. quality_name
        local text_field_name = "text_" .. item_name .. "_" .. quality_name
        local slider, text_field
        
        local function find_element(elem, name)
            if elem.name == name then
                return elem
            end
            for _, child in pairs(elem.children or {}) do
                local result = find_element(child, name)
                if result then return result end
            end
            return nil
        end
        
        slider = find_element(section_table, slider_name)
        text_field = find_element(section_table, text_field_name)
        
        if slider and slider.valid and text_field and text_field.valid then
            local current_value = tonumber(text_field.text) or 0
            local new_value = math.min(current_value + stack_size, max_value)
            slider.slider_value = new_value
            text_field.text = tostring(new_value)
            return
        else
            debug_log("Could not find slider or text field: " .. slider_name .. ", " .. text_field_name)
        end
    end

    -- Container deployment buttons
    if element.name and element.name:match("^" .. container_deployment.BUTTON_PREFIX) then
        local player = game.get_player(event.player_index)
        if player and player.valid and element.tags then
            container_deployment.on_button_click(player, element.name, element.tags)
        end
        return
    end
    
    if element.name == "confirm_deployment_button" then
        local player = game.get_player(event.player_index)
        if player and player.valid then
            container_deployment.on_confirm_deployment(player)
        end
        return
    end
    
    if element.name == platform_gui.DEPLOY_BUTTON_NAME .. "_btn" then
        local player = game.get_player(event.player_index)
        if player and player.valid then
            platform_gui.on_deploy_button_click(player)
        end
        return
    end
    
    if element.name == equipment_grid_fill.BUTTON_NAME .. "_btn" then
        local player = game.get_player(event.player_index)
        if player and player.valid then
            equipment_grid_fill.on_fill_button_click(player)
        end
        return
    end
    
    if element.name == equipment_grid_fill.CARGO_POD_BUTTON_NAME .. "_btn" then
        local player = game.get_player(event.player_index)
        if player and player.valid then
            equipment_grid_fill.on_cargo_pod_button_click(player)
        end
        return
    end
    
    if element.name and element.name:match("^" .. equipment_grid_fill.EQUIPMENT_TOOLBAR_NAME .. "_") then
        local player = game.get_player(event.player_index)
        if player and player.valid and element.tags then
            equipment_grid_fill.on_equipment_item_click(player, element.name, element.tags)
        end
        return
    end
    
    -- Orbital deployment button in equipment grid GUI
    if element.name == "equipment_grid_orbital_deploy_btn" then
        local player = game.get_player(event.player_index)
        if not player or not player.valid then return end
        
        if player.opened then
            player.opened = nil
        end
        
        local vehicle = storage.current_equipment_grid_vehicle
        if not vehicle then
            player.print("Error: Vehicle data not found")
            return
        end
        
        local vehicles = map_gui.find_orbital_vehicles(player.surface)
        if #vehicles == 0 then
            player.print("string-mod-setting.no-vehicles-deployable-here")
        else
            map_gui.show_deployment_menu(player, vehicles)
        end
        
        storage.current_equipment_grid_vehicle = nil
        return
    end
    
    -- Pass to map_gui for other button handling
    map_gui.on_gui_click(event)
end)

-- Handle slider value changes
script.on_event(defines.events.on_gui_value_changed, function(event)
    local element = event.element
    if not element or not element.valid then return end

    -- Container deployment slider
    if container_deployment and element.name == "deployment_amount_slider" then
        local player = game.players[event.player_index]
        if player and player.valid then
            container_deployment.on_slider_changed(player, element)
        end
        return
    end
    
    -- Handle item sliders (both SA and SE)
    local pattern = "^slider_(.+)_(.+)$"
    local item_name, quality_name = string.match(element.name or "", pattern)
    
    if item_name and quality_name then
        local player = game.players[event.player_index]
        if not player or not player.valid then return end
        
        local value = math.floor(element.slider_value)
        element.slider_value = value
        
        -- Find section table
        local section_table
        local current = element
        while current and current.valid do
            if current.name == "utilities_table" or current.name == "ammo_table" or 
               current.name == "fuel_table" or current.name == "equipment_table" or 
               current.name == "supplies_table" then
                section_table = current
                break
            end
            current = current.parent
        end

        if not section_table then
            debug_log("Could not find section table for slider")
            return
        end
        
        -- Find text field
        local text_field_name = "text_" .. item_name .. "_" .. quality_name
        local function find_element(elem, name)
            if elem.name == name then
                return elem
            end
            for _, child in pairs(elem.children or {}) do
                local result = find_element(child, name)
                if result then return result end
            end
            return nil
        end
        
        local text_field = find_element(section_table, text_field_name)
        
        if text_field and text_field.valid then
            text_field.text = tostring(value)
        else
            debug_log("Could not find text field: " .. text_field_name)
        end
    end
end)

-- Handle text field changes
script.on_event(defines.events.on_gui_text_changed, function(event)
    local element = event.element
    if not element or not element.valid then return end

    -- Container deployment textfield
    if container_deployment and element.name == "deployment_amount_textfield" then
        local player = game.players[event.player_index]
        if player and player.valid then
            container_deployment.on_textfield_changed(player, element)
        end
        return
    end
    
    -- Handle item text fields (both SA and SE)
    local pattern = "^text_(.+)_(.+)$"
    local item_name, quality_name = string.match(element.name or "", pattern)
    
    if item_name and quality_name then
        local player = game.players[event.player_index]
        if not player or not player.valid then return end
        
        local value = tonumber(element.text) or 0
        
        -- Find section table
        local section_table
        local current = element
        while current and current.valid do
            if current.name == "utilities_table" or current.name == "ammo_table" or 
               current.name == "fuel_table" or current.name == "equipment_table" or 
               current.name == "extras_table" or current.name == "supplies_table" then
                section_table = current
                break
            end
            current = current.parent
        end

        if not section_table then
            debug_log("Could not find section table for text field")
            return
        end
        
        -- Find slider
        local slider_name = "slider_" .. item_name .. "_" .. quality_name
        local function find_element(elem, name)
            if elem.name == name then
                return elem
            end
            for _, child in pairs(elem.children or {}) do
                local result = find_element(child, name)
                if result then return result end
            end
            return nil
        end
        
        local slider = find_element(section_table, slider_name)
        
        if slider and slider.valid then
            -- Get max value
            local max_value = nil
            if element.tags and element.tags.max_value then
                max_value = tonumber(element.tags.max_value)
            elseif slider.tags and slider.tags.max_value then
                max_value = tonumber(slider.tags.max_value)
            elseif slider.slider_maximum and type(slider.slider_maximum) == "number" then
                max_value = slider.slider_maximum
            end
            
            -- Clamp value
            if max_value and type(max_value) == "number" then
                value = math.max(0, math.min(value, max_value))
            else
                value = math.max(0, value)
            end
            value = math.floor(value)
            
            slider.slider_value = value
            element.text = tostring(value)
        else
            debug_log("Could not find slider: " .. slider_name)
        end
    end
end)

-- Handle GUI closing
script.on_event(defines.events.on_gui_closed, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    if player.gui.screen["spidertron_extras_frame"] then
        player.gui.screen["spidertron_extras_frame"].destroy()
    end
    
    if player.gui.screen["spidertron_deployment_frame"] then
        player.gui.screen["spidertron_deployment_frame"].destroy()
    end
    
    -- Clean up equipment grid button
    local relative_gui = player.gui.relative
    if relative_gui then
        local button_frame = relative_gui["equipment_grid_orbital_deploy"]
        if button_frame and button_frame.valid then
            button_frame.destroy()
        end
    end
    storage.current_equipment_grid_vehicle = nil

    -- Container deployment GUI cleanup
    if container_deployment then
        container_deployment.remove_gui(player)
    end
end)

-- Handle GUI opening
script.on_event(defines.events.on_gui_opened, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
    -- SA-SPECIFIC: Platform hub opened - show deploy button
    if is_space_age and platform_gui and equipment_grid_fill then
        if event.entity and event.entity.valid and 
           (event.entity.type == "space-platform-hub" or event.entity.name == "space-platform-hub") then
            storage.pending_grid_open = storage.pending_grid_open or {}
            storage.pending_grid_open[player.index] = {
                opened = event.entity,
                tick = game.tick
            }
        end
        
        equipment_grid_fill.on_gui_opened(event)
    end

    local opened = player.opened
    if opened and opened.valid then
        -- Container deployment GUI
        if container_deployment then
            local success, is_container = pcall(function()
                return opened.get_inventory(defines.inventory.chest) ~= nil
            end)
            
            if success and is_container then
                container_deployment.get_or_create_gui(player, opened)
            end
        end
        
        -- Initialize grids for items with entity data
        local success_entity, is_entity = pcall(function()
            return opened.name ~= nil and opened.get_inventory ~= nil
        end)
        
        if success_entity and is_entity then
            local inventory = opened.get_inventory(defines.inventory.chest)
            if inventory then
                for i = 1, #inventory do
                    local stack = inventory[i]
                    if stack and stack.valid_for_read then
                        local item_prototype = prototypes.item[stack.name]
                        if item_prototype and item_prototype.type == "item-with-entity-data" then
                            if item_prototype.stack_size == 1 then
                                if not stack.grid then
                                    pcall(function()
                                        return stack.create_grid()
                                    end)
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Equipment grid opened for vehicle
        local success, has_equipment = pcall(function()
            return opened.equipment ~= nil
        end)
        
        if success and has_equipment then
            local grid = opened
            local success_owner, itemstack_owner = pcall(function()
                return grid.itemstack_owner
            end)
            
            if success_owner and itemstack_owner then
                if vehicles_list.is_vehicle(itemstack_owner.name) then
                    if storage.spidertrons then
                        for _, vehicle in ipairs(storage.spidertrons) do
                            if vehicle.vehicle_name == itemstack_owner.name then
                                storage.current_equipment_grid_vehicle = vehicle
                                
                                local relative_gui = player.gui.relative
                                if relative_gui then
                                    local button_frame = relative_gui["equipment_grid_orbital_deploy"]
                                    if not button_frame or not button_frame.valid then
                                        local gui_type = nil
                                        if defines.relative_gui_type.equipment_grid_gui then
                                            gui_type = defines.relative_gui_type.equipment_grid_gui
                                        end
                                        
                                        if gui_type then
                                            local anchor = {
                                                gui = gui_type,
                                                position = defines.relative_gui_position.bottom
                                            }
                                            
                                            local frame_config = {
                                                type = "frame",
                                                name = "equipment_grid_orbital_deploy",
                                                style = "frame"
                                            }
                                            
                                            local success_frame, toolbar_frame = pcall(function()
                                                return relative_gui.add(frame_config)
                                            end)
                                            
                                            if not success_frame then
                                                frame_config.anchor = anchor
                                                success_frame, toolbar_frame = pcall(function()
                                                    return relative_gui.add(frame_config)
                                                end)
                                            end
                                            
                                            if success_frame and toolbar_frame then
                                                toolbar_frame.style.horizontally_stretchable = false
                                                toolbar_frame.style.vertically_stretchable = false
                                                toolbar_frame.style.top_padding = 3
                                                toolbar_frame.style.bottom_padding = 6
                                                toolbar_frame.style.left_padding = 6
                                                toolbar_frame.style.right_padding = 6
                                                
                                                local button_flow = toolbar_frame.add{
                                                    type = "flow",
                                                    name = "button_flow",
                                                    direction = "horizontal"
                                                }
                                                button_flow.style.horizontal_align = "right"
                                                
                                                local orbital_deploy_button = button_flow.add{
                                                    type = "button",
                                                    name = "equipment_grid_orbital_deploy_btn",
                                                    caption = "string-mod-setting.orbital-deployment",
                                                    style = "confirm_button"
                                                }
                                                orbital_deploy_button.tooltip = "Continue orbital deployment and reopen deployment menu"
                                            end
                                        end
                                    end
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Handle tick events
script.on_event(defines.events.on_tick, function(event)
    -- SA-SPECIFIC: Handle pending GUI opens
    if is_space_age and platform_gui and equipment_grid_fill then
        if storage.pending_grid_open then
            for player_index, data in pairs(storage.pending_grid_open) do
                if game.tick > data.tick then
                    local player = game.get_player(player_index)
                    if player and player.valid then
                        platform_gui.get_or_create_deploy_button(player, data.opened)
                        equipment_grid_fill.get_or_create_fill_button(player)
                    end
                    storage.pending_grid_open[player_index] = nil
                end
            end
        end
    end

    -- Handle pending equipment grid reopens (after render mode switch)
    if equipment_grid_fill and storage.pending_equipment_reopen then
        for player_index, data in pairs(storage.pending_equipment_reopen) do
            if game.tick > data.tick then  -- Just 1 tick wait
                local player = game.get_player(player_index)
                
                if player and player.valid and data.entity and data.entity.valid then
                    if data.is_vehicle then
                        player.opened = data.entity
                    else
                        player.opened = data.entity
                        
                        local inv = data.entity.get_inventory(defines.inventory.chest)
                        if inv then
                            for i = 1, #inv do
                                local stack = inv[i]
                                if stack and stack.valid_for_read and stack.name == data.item_name and stack.grid then
                                    player.opened = stack.grid
                                    if not player.opened or player.opened ~= stack.grid then
                                        player.opened = stack
                                    end
                                    break
                                end
                            end
                        end
                    end
                    
                    equipment_grid_fill.get_or_create_fill_button(player)
                end
                storage.pending_equipment_reopen[player_index] = nil
            end
        end
    end
    
    -- Handle pending deployments
    if storage.pending_deployment then
        for player_index, data in pairs(storage.pending_deployment) do
            if not data.processed then
                data.processed = true
            else
                local player = game.get_player(player_index)
                if player then
                    local vehicles = map_gui.find_orbital_vehicles(data.planet_surface)
                    if #vehicles == 0 then
                        player.print({"", "No vehicles are deployable to ", data.planet_name, "."})
                    else
                        map_gui.show_deployment_menu(player, vehicles)
                    end
                end
                storage.pending_deployment[player_index] = nil
            end
        end
    end
end)

-- Handle shortcut button clicks
script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name == "orbital-spidertron-deploy" then
        local player = game.get_player(event.player_index)
        if not player then return end
        
        if is_space_exploration then
            debug_log("=== ORBITAL DEPLOYMENT SHORTCUT CLICKED ===")
            debug_log("Player: " .. player.name)
            debug_log("Player surface: " .. player.surface.name .. " (index: " .. player.surface.index .. ")")
        end
        
        -- SA-SPECIFIC: Handle platform surface - switch to planet
        if is_space_age and player.surface.platform then
            local planet_name = nil
            if player.surface.platform.space_location then
                local location_str = tostring(player.surface.platform.space_location)
                planet_name = location_str:match(": ([^%(]+) %(planet%)")
            end
            
            if planet_name then
                local planet_surface = game.get_surface(planet_name)
                if planet_surface then
                    if player.opened then
                        player.opened = nil
                    end

                    local target_position = {x = 0, y = 0}
                    player.set_controller{
                        type = defines.controllers.remote,
                        surface = planet_surface,
                        position = target_position
                    }

                    storage.pending_deployment = storage.pending_deployment or {}
                    storage.pending_deployment[player.index] = {
                        planet_surface = planet_surface,
                        planet_name = planet_name
                    }
                    return
                end
            else
                player.print("string-mod-setting.platform-in-transit")
                return
            end
        end
        
        -- Find orbital vehicles
        local vehicles = map_gui.find_orbital_vehicles(player.surface, player)
        
        if #vehicles == 0 then
            player.print("string-mod-setting.no-vehicles-deployable-here")
            if is_space_exploration then
                debug_log("No vehicles found - deployment aborted")
            end
            return
        end
        
        -- Show deployment menu
        if is_space_exploration then
            debug_log("Showing deployment menu with " .. #vehicles .. " vehicles")
        end
        map_gui.show_deployment_menu(player, vehicles)
    end
end)

-- SE-SPECIFIC: Handle cargo bay creation
if is_space_exploration then
    script.on_event(defines.events.on_built_entity, function(event)
        local entity = event.created_entity or event.entity
        if not entity or not entity.valid then return end
        
        if entity.name == "ovd-deployment-container" then
            -- Snap position to grid
            local grid_size = 2
            local snapped_x = math.floor(entity.position.x / grid_size + 0.5) * grid_size
            local snapped_y = math.floor(entity.position.y / grid_size + 0.5) * grid_size
            local snapped_position = {snapped_x, snapped_y}
            
            -- Create cargo bay visual
            local cargo_bay = entity.surface.create_entity{
                name = "ovd-cargo-bay",
                position = snapped_position,
                force = entity.force,
                create_build_effect_smoke = false
            }
            
            if cargo_bay and cargo_bay.valid then
                cargo_bay.destructible = false
                cargo_bay.minable = false
                
                storage.cargo_bay_links = storage.cargo_bay_links or {}
                storage.cargo_bay_links[entity.unit_number] = cargo_bay
            end
            
            register_cargo_bay(entity)
            
            -- Link surface to planet at bay placement
            local surface = entity.surface
            
            if surface and not surface.planet then
                local available_planet = nil
                for i = 1, 40 do
                    local planet = game.planets["ovd-se-planet-" .. i]
                    if planet and not planet.surface then
                        available_planet = planet
                        break
                    end
                end
                
                if available_planet then
                    available_planet.associate_surface(surface)
                else
                    log("[OVD Bay Placement] ERROR: No available planets found! Surface " .. surface.name .. " (index: " .. surface.index .. ") is NOT linked to a planet. Deployment may fail!")
                end
            end
        end
    end)

    script.on_event(defines.events.on_player_mined_entity, function(event)
        local entity = event.entity
        if not entity or not entity.valid then return end
        
        if entity.name == "ovd-deployment-container" then
            if storage.cargo_bay_links and storage.cargo_bay_links[entity.unit_number] then
                local cargo_bay = storage.cargo_bay_links[entity.unit_number]
                if cargo_bay and cargo_bay.valid then
                    cargo_bay.destroy()
                end
                storage.cargo_bay_links[entity.unit_number] = nil
            end
            
            unregister_cargo_bay(entity.unit_number)
        end
    end)

    script.on_event(defines.events.on_entity_died, function(event)
        local entity = event.entity
        if not entity or not entity.valid then return end
        
        if entity.name == "ovd-deployment-container" then
            if storage.cargo_bay_links and storage.cargo_bay_links[entity.unit_number] then
                local cargo_bay = storage.cargo_bay_links[entity.unit_number]
                if cargo_bay and cargo_bay.valid then
                    cargo_bay.destroy()
                end
                storage.cargo_bay_links[entity.unit_number] = nil
            end
            
            unregister_cargo_bay(entity.unit_number)
        end
    end)
end

-- Handle player events
script.on_event(defines.events.on_player_changed_surface, function(event)
    map_gui.on_player_changed_surface(event)
end)

if defines.events.on_player_render_mode_changed then
    script.on_event(defines.events.on_player_render_mode_changed, function(event)
        map_gui.on_player_changed_render_mode(event)
    end)
end

script.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if player then
        map_gui.initialize_player_shortcuts(player)
    end
end)

-- SE-SPECIFIC: Handle cargo pod finished ascending (for same-surface deployment workaround)
if is_space_exploration then
    script.on_event(defines.events.on_cargo_pod_finished_ascending, function(event)
        local pod = event.cargo_pod
        if not pod or not pod.valid then return end
        
        if storage.pending_pod_deployments then
            for pod_id, deployment_data in pairs(storage.pending_pod_deployments) do
                local matches = false
                if deployment_data.pod_unit_number and pod.unit_number then
                    matches = (deployment_data.pod_unit_number == pod.unit_number)
                else
                    matches = (deployment_data.pod == pod)
                end
                
                if matches and deployment_data.actual_surface and deployment_data.actual_position then
                    pod.cargo_pod_destination = {
                        type = defines.cargo_destination.surface,
                        surface = deployment_data.actual_surface,
                        position = deployment_data.actual_position,
                        land_at_exact_position = true
                    }
                    return
                end
            end
        end
    end)
end

-- Handle cargo pod landing
script.on_event(defines.events.on_cargo_pod_finished_descending, function(event)
    deployment.on_cargo_pod_finished_descending(event)
end)

-- Handle technology research
script.on_event(defines.events.on_research_finished, function(event)
    local tech_name = event.research.name
    
    if is_space_exploration then
        if tech_name == "se-space-capsule-navigation" then
            for _, player in pairs(event.research.force.players) do
                map_gui.initialize_player_shortcuts(player)
                player.set_shortcut_available("orbital-spidertron-deploy", true)
            end
        end
    elseif is_space_age then
        if tech_name == "space-platform" then
            for _, player in pairs(event.research.force.players) do
                map_gui.initialize_player_shortcuts(player)
                player.set_shortcut_available("orbital-spidertron-deploy", true)
            end
        end
    end
end)

-- Handle player leaving
script.on_event(defines.events.on_player_left_game, function(event)
    local player_index = event.player_index
    
    if storage.temp_deployment_data and storage.temp_deployment_data.player_index == player_index then
        storage.temp_deployment_data = nil
    end
end)

-- Clean up stale data periodically
script.on_nth_tick(300, function()
    -- Clean up pending deployments
    if storage.pending_deployments then
        local current_tick = game.tick
        local stale_ids = {}
        
        for id, data in pairs(storage.pending_deployments) do
            local deployment_tick = tonumber(id:match("_%d+$"):sub(2))
            if current_tick - deployment_tick > 3600 then
                table.insert(stale_ids, id)
            end
        end
        
        for _, id in ipairs(stale_ids) do
            storage.pending_deployments[id] = nil
        end
    end
    
    -- Clean up pending pod deployments
    if storage.pending_pod_deployments then
        local current_tick = game.tick
        local stale_pod_ids = {}
        
        for id, data in pairs(storage.pending_pod_deployments) do
            local deployment_tick = tonumber(id:match("_%d+$"):sub(2))
            if current_tick - deployment_tick > 3600 then
                table.insert(stale_pod_ids, id)
            end
        end
        
        for _, id in ipairs(stale_pod_ids) do
            storage.pending_pod_deployments[id] = nil
        end
    end
    
    -- SE-SPECIFIC: Clean up invalid cargo bays
    if is_space_exploration and storage.cargo_bays then
        local invalid_bays = {}
        for unit_number, bay_data in pairs(storage.cargo_bays) do
            if not bay_data.entity or not bay_data.entity.valid then
                table.insert(invalid_bays, unit_number)
            end
        end
        
        for _, unit_number in ipairs(invalid_bays) do
            storage.cargo_bays[unit_number] = nil
        end
    end
end)

debug_log("Control script loaded")