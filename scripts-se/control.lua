-- scripts-se/control.lua
-- Space Exploration version
local map_gui = require("scripts-se.map-gui")
local deployment = require("scripts-se.deployment")
local vehicles_list = require("scripts-se.vehicles-list")

-- Debug logging function
local function debug_log(message)
    log("[Orbital Spider Delivery SE] " .. message)
end

-- Initialize storage
local function init_storage()
    storage = storage or {}
    storage.pending_deployments = storage.pending_deployments or {}
    storage.pending_pod_deployments = storage.pending_pod_deployments or {}
    storage.temp_deployment_data = storage.temp_deployment_data or {}
    debug_log("Space Exploration storage initialized")
end

-- Initialize player shortcuts
local function init_players()
    for _, player in pairs(game.players) do
        -- SE-SPECIFIC: Enable the shortcut based on spidertron research
        local spidertron_researched = player.force.technologies["spidertron"] and player.force.technologies["spidertron"].researched or false
        
        player.set_shortcut_available("orbital-spidertron-deploy", spidertron_researched)
    end
end

-- Register events on init
script.on_init(function()
    init_storage()
    init_players()
    for _, player in pairs(game.players) do
        map_gui.initialize_player_shortcuts(player)
    end
    vehicles_list.initialize()
    
    debug_log("Space Exploration module initialized")
end)

-- Register events on load
script.on_load(function()
    debug_log("Space Exploration module loaded")
end)

-- Register events on configuration changed
script.on_configuration_changed(function(data)
    init_storage()
    init_players()
    vehicles_list.initialize()
    
    debug_log("Configuration changed, storage reinitialized")
end)

-- Consolidated GUI click handler (for stack buttons and other GUI elements)
script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if not element or not element.valid then return end
    
    -- Check if this is a stack button by its tags
    if element.tags and element.tags.action == "add_stack" then
        local player = game.players[event.player_index]
        if not player or not player.valid then return end
        
        -- Get data from tags
        local item_name = element.tags.item_name
        local quality_name = element.tags.quality_name
        local stack_size = element.tags.stack_size or 50
        local max_value = element.tags.max_value or 50
        
        -- Find the specific section table (utilities_table, ammo_table, or fuel_table)
        local section_table
        local current = element
        while current and current.valid do
            if current.name == "utilities_table" or current.name == "ammo_table" or current.name == "fuel_table" then
                section_table = current
                break
            end
            current = current.parent
        end
        
        if not section_table then
            debug_log("Could not find section table for stack button")
            return
        end
        
        -- Find slider and text field within the section table
        local slider_name = "slider_" .. item_name .. "_" .. quality_name
        local text_field_name = "text_" .. item_name .. "_" .. quality_name
        local slider, text_field
        
        -- Recursive search function to find elements by name
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
            -- Get current value from text field
            local current_value = tonumber(text_field.text) or 0
            
            -- Calculate new value
            local new_value = math.min(current_value + stack_size, max_value)
            
            -- Update both slider and text field
            slider.slider_value = new_value
            text_field.text = tostring(new_value)
            
            player.print("Added " .. stack_size .. " " .. item_name .. ". New amount: " .. new_value)
            return
        end
    end
    
    -- Pass to map_gui for other button handling
    map_gui.on_gui_click(event)
end)

-- Handle slider value changes
script.on_event(defines.events.on_gui_value_changed, function(event)
    local element = event.element
    if not element or not element.valid then return end
    
    -- Check if this is one of our sliders
    local pattern = "^slider_(.+)_(.+)$"
    local item_name, quality_name = string.match(element.name or "", pattern)
    
    if item_name and quality_name then
        local player = game.players[event.player_index]
        if not player or not player.valid then return end
        
        local value = math.floor(element.slider_value)
        element.slider_value = value
        
        -- Find the specific section table
        local section_table
        local current = element
        while current and current.valid do
            if current.name == "utilities_table" or current.name == "ammo_table" or current.name == "fuel_table" then
                section_table = current
                break
            end
            current = current.parent
        end
        
        if section_table then
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
            end
        end
    end
end)

-- Handle text field changes
script.on_event(defines.events.on_gui_text_changed, function(event)
    local element = event.element
    if not element or not element.valid then return end
    
    local pattern = "^text_(.+)_(.+)$"
    local item_name, quality_name = string.match(element.name or "", pattern)
    
    if item_name and quality_name then
        local player = game.players[event.player_index]
        if not player or not player.valid then return end
        
        local value = tonumber(element.text) or 0
        
        -- Find the section table by traversing up (utilities_table, ammo_table, or fuel_table)
        local section_table
        local current = element
        while current and current.valid do
            if current.name == "utilities_table" or current.name == "ammo_table" or current.name == "fuel_table" then
                section_table = current
                break
            end
            current = current.parent
        end
        
        if section_table then
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
                -- Get max value from tags if available, otherwise use slider_maximum
                local max_value = slider.tags and slider.tags.max_value or slider.slider_maximum
                value = math.max(0, math.min(value, max_value))
                value = math.floor(value)
                slider.slider_value = value
                element.text = tostring(value)
            end
        end
    end
end)

-- Handle GUI closing (ESC key)
script.on_event(defines.events.on_gui_closed, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    if player.gui.screen["spidertron_extras_frame"] then
        player.gui.screen["spidertron_extras_frame"].destroy()
    end
    
    if player.gui.screen["spidertron_deployment_frame"] then
        player.gui.screen["spidertron_deployment_frame"].destroy()
    end
end)

-- Handle cargo bay visual creation (same as before)
script.on_event(defines.events.on_built_entity, function(event)
    local entity = event.created_entity or event.entity
    if not entity or not entity.valid then return end
    
    if entity.name == "ovd-deployment-container" then
      -- Snap position to grid (2x2 grid for cargo-bay alignment)
      local grid_size = 2
      local snapped_x = math.floor(entity.position.x / grid_size + 0.5) * grid_size
      local snapped_y = math.floor(entity.position.y / grid_size + 0.5) * grid_size
      local snapped_position = {snapped_x, snapped_y}
      
      -- Create the cargo bay visual on top
      local cargo_bay = entity.surface.create_entity{
        name = "ovd-cargo-bay",
        position = snapped_position,
        force = entity.force,
        create_build_effect_smoke = false
      }
      
      if cargo_bay and cargo_bay.valid then
        cargo_bay.destructible = false  -- Can't be damaged separately
        cargo_bay.minable = false  -- Can't be mined separately
        
        -- Store the link between them
        storage.cargo_bay_links = storage.cargo_bay_links or {}
        storage.cargo_bay_links[entity.unit_number] = cargo_bay
      end
    end
end)

script.on_event(defines.events.on_player_mined_entity, function(event)
    local entity = event.entity
    if not entity or not entity.valid then return end
    
    if entity.name == "ovd-deployment-container" then
      -- Destroy the linked cargo bay
      if storage.cargo_bay_links and storage.cargo_bay_links[entity.unit_number] then
        local cargo_bay = storage.cargo_bay_links[entity.unit_number]
        if cargo_bay and cargo_bay.valid then
          cargo_bay.destroy()
        end
        storage.cargo_bay_links[entity.unit_number] = nil
      end
    end
end)

script.on_event(defines.events.on_entity_died, function(event)
    local entity = event.entity
    if not entity or not entity.valid then return end
    
    if entity.name == "ovd-deployment-container" then
      -- Destroy the linked cargo bay
      if storage.cargo_bay_links and storage.cargo_bay_links[entity.unit_number] then
        local cargo_bay = storage.cargo_bay_links[entity.unit_number]
        if cargo_bay and cargo_bay.valid then
          cargo_bay.destroy()
        end
        storage.cargo_bay_links[entity.unit_number] = nil
      end
    end
end)

-- Handle shortcut button clicks
script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name == "orbital-spidertron-deploy" then
        local player = game.get_player(event.player_index)
        if not player then return end
        
        debug_log("=== ORBITAL DEPLOYMENT SHORTCUT CLICKED ===")
        player.print("=== ORBITAL DEPLOYMENT SHORTCUT CLICKED ===")
        player.print("Player: " .. player.name)
        player.print("Player surface: " .. player.surface.name .. " (index: " .. player.surface.index .. ")")
        debug_log("Player: " .. player.name)
        debug_log("Player surface: " .. player.surface.name .. " (index: " .. player.surface.index .. ")")
        
        -- Log all loaded surfaces
        player.print("--- ALL LOADED SURFACES ---")
        debug_log("--- ALL LOADED SURFACES ---")
        local surface_count = 0
        for _, surface in pairs(game.surfaces) do
            surface_count = surface_count + 1
            local surface_info = "Surface #" .. surface_count .. ": " .. surface.name .. " (index: " .. surface.index .. ")"
            player.print(surface_info)
            debug_log(surface_info)
            
            -- Try to get zone info for each surface
            local success, zone = pcall(function()
                return remote.call("space-exploration", "get_zone_from_surface_index", {surface_index = surface.index})
            end)
            if success and zone then
                local zone_info = "  -> Zone: " .. (zone.name or "unknown") .. " (type: " .. (zone.type or "unknown") .. ")"
                player.print(zone_info)
                debug_log(zone_info)
                if zone.parent then
                    local parent_info = "  -> Zone parent: " .. (zone.parent.name or "unknown")
                    player.print(parent_info)
                    debug_log(parent_info)
                end
            else
                local no_zone_info = "  -> No zone information available"
                player.print(no_zone_info)
                debug_log(no_zone_info)
            end
        end
        local total_info = "Total surfaces: " .. surface_count
        player.print(total_info)
        debug_log(total_info)
        player.print("--- END SURFACE LIST ---")
        debug_log("--- END SURFACE LIST ---")
        
        -- Find orbital spider vehicles
        player.print("Searching for orbital vehicles...")
        debug_log("Searching for orbital vehicles...")
        local vehicles = map_gui.find_orbital_vehicles(player.surface, player)
        local found_info = "Found " .. #vehicles .. " deployable vehicles"
        player.print(found_info)
        debug_log(found_info)
        
        if #vehicles == 0 then
            player.print("No vehicles are deployable to this surface.")
            debug_log("No vehicles found - deployment aborted")
            return
        end
        
        -- Show selection dialog with appropriate deployment options
        local menu_info = "Showing deployment menu with " .. #vehicles .. " vehicles"
        player.print(menu_info)
        debug_log(menu_info)
        map_gui.show_deployment_menu(player, vehicles)
    end
end)

-- Register event for when player changes surface
script.on_event(defines.events.on_player_changed_surface, function(event)
    map_gui.on_player_changed_surface(event)
end)

-- Handle render mode changes
if defines.events.on_player_render_mode_changed then
    script.on_event(defines.events.on_player_render_mode_changed, function(event)
        map_gui.on_player_changed_render_mode(event)
    end)
end

-- Handle new player creation
script.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if player then
        map_gui.initialize_player_shortcuts(player)
    end
end)

-- Register a single event handler for cargo pod landings
script.on_event(defines.events.on_cargo_pod_finished_descending, function(event)
    deployment.on_cargo_pod_finished_descending(event)
end)

-- Update when relevant technologies are researched
script.on_event(defines.events.on_research_finished, function(event)
    local tech_name = event.research.name
    -- SE-SPECIFIC: Check if this is the spidertron technology
    if tech_name == "spidertron" then
        -- Update shortcuts for all players in this force
        for _, player in pairs(event.research.force.players) do
            map_gui.initialize_player_shortcuts(player)
            player.set_shortcut_available("orbital-spidertron-deploy", true)
        end
    end
end)

-- Handle player leaving the game (cleanup)
script.on_event(defines.events.on_player_left_game, function(event)
    local player_index = event.player_index
    
    -- Clean up any temp deployment data for this player
    if storage.temp_deployment_data and storage.temp_deployment_data.player_index == player_index then
        storage.temp_deployment_data = nil
    end
end)

-- Clean up any stale deployment data periodically
script.on_nth_tick(300, function()  -- Check every 5 seconds
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
        
        if #stale_ids > 0 then
            log("Cleaned up " .. #stale_ids .. " stale deployment records")
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
        
        if #stale_pod_ids > 0 then
            log("Cleaned up " .. #stale_pod_ids .. " stale pod deployment records")
        end
    end
end)

debug_log("Space Exploration control script loaded")

-- In control.lua on_init, after init_storage()

-- Create planet for SE surfaces if it doesn't exist
script.on_init(function()
    init_storage()
    init_players()
    
    -- Try to create planet from our space-location
    if prototypes.space_location["ovd-se-generic"] then
        local planet = game.planets["ovd-se-generic"]
        if not planet then
            log("[OVD] Attempting to create planet from ovd-se-generic space-location")
            -- Planets are created automatically when a space location is discovered
            -- Try creating a dummy surface first, then we can associate SE surfaces later
            local success, result = pcall(function()
                local temp_surface = game.create_surface("ovd-temp-planet-surface", {})
                local proto = prototypes.space_location["ovd-se-generic"]
                if proto then
                    -- This might create the planet
                    return game.planets["ovd-se-generic"]
                end
            end)
            
            if success and result then
                log("[OVD] Planet created successfully")
            else
                log("[OVD] Could not create planet: " .. tostring(result))
            end
        end
    end
    
    -- Rest of your init code
    for _, player in pairs(game.players) do
        map_gui.initialize_player_shortcuts(player)
    end
    vehicles_list.initialize()
end)