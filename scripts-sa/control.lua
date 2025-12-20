-- scripts-sa/control.lua
local map_gui = require("scripts-sa.map-gui")
local deployment = require("scripts-sa.deployment")
local vehicles_list = require("scripts-sa.vehicles-list")
local platform_gui = require("scripts-sa.platform-gui")
local equipment_grid_fill = require("scripts-sa.equipment-grid-fill")
local api = require("scripts-sa.api")

-- Debug logging function
local function debug_log(message)
    -- log("[Orbital Spider Delivery SA] " .. message)
end

-- Initialize storage
local function init_storage()
    storage = storage or {}
    storage.pending_deployments = storage.pending_deployments or {}
    storage.pending_pod_deployments = storage.pending_pod_deployments or {}
    storage.temp_deployment_data = storage.temp_deployment_data or {}
    storage.pending_grid_open = storage.pending_grid_open or {}
    storage.current_equipment_grid_vehicle = storage.current_equipment_grid_vehicle or nil
    debug_log("Space Age storage initialized")
end

-- Initialize player shortcuts
local function init_players()
    for _, player in pairs(game.players) do
        map_gui.initialize_player_shortcuts(player)
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
    
    debug_log("Space Age module initialized with extras deployment")
end)

-- Register events on load
script.on_load(function()
end)

-- Register events on configuration changed
script.on_configuration_changed(function(data)
    init_storage()
    init_players()
    vehicles_list.initialize()
    
    debug_log("Configuration changed, storage reinitialized")
end)

-- Consolidated GUI click handler (for stack buttons)
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
        
        -- Find the specific section table (utilities_table, ammo_table, fuel_table, or equipment_table)
        local section_table
        local current = element
        while current and current.valid do
            if current.name == "utilities_table" or current.name == "ammo_table" or current.name == "fuel_table" or current.name == "equipment_table" then
                section_table = current
                break
            end
            current = current.parent
        end
        
        if not section_table then
            debug_log("Could not find section table (utilities_table, ammo_table, fuel_table, or equipment_table) for stack button")
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
            
            --player.print("Added " .. stack_size .. " " .. item_name .. ". New amount: " .. new_value)
            return
        else
            debug_log("Could not find slider or text field: " .. slider_name .. ", " .. text_field_name)
        end
    end
    
    -- Check for platform deploy button click
    if element.name == platform_gui.DEPLOY_BUTTON_NAME .. "_btn" then
        local player = game.get_player(event.player_index)
        if player and player.valid then
            platform_gui.on_deploy_button_click(player)
        end
        return
    end
    
    -- Check for equipment grid fill button click
    if element.name == equipment_grid_fill.BUTTON_NAME .. "_btn" then
        local player = game.get_player(event.player_index)
        if player and player.valid then
            equipment_grid_fill.on_fill_button_click(player)
        end
        return
    end
    
    -- Check for equipment grid cargo pod button click
    if element.name == equipment_grid_fill.CARGO_POD_BUTTON_NAME .. "_btn" then
        local player = game.get_player(event.player_index)
        if player and player.valid then
            equipment_grid_fill.on_cargo_pod_button_click(player)
        end
        return
    end
    
    -- Check for equipment item button clicks
    if element.name and element.name:match("^" .. equipment_grid_fill.EQUIPMENT_TOOLBAR_NAME .. "_") then
        local player = game.get_player(event.player_index)
        if player and player.valid and element.tags then
            equipment_grid_fill.on_equipment_item_click(player, element.name, element.tags)
        end
        return
    end
    
    -- Check for orbital deployment button in equipment grid GUI
    if element.name == "equipment_grid_orbital_deploy_btn" then
        local player = game.get_player(event.player_index)
        if not player or not player.valid then return end
        
        -- Close the equipment grid GUI
        if player.opened then
            player.opened = nil
        end
        
        -- Get the vehicle data
        local vehicle = storage.current_equipment_grid_vehicle
        if not vehicle then
            player.print("Error: Vehicle data not found")
            return
        end
        
        -- Find vehicles for the current surface and reopen deployment menu
        local map_gui = require("scripts-sa.map-gui")
        local vehicles = map_gui.find_orbital_vehicles(player.surface)
        if #vehicles == 0 then
            player.print("No vehicles are deployable to this surface.")
        else
            map_gui.show_deployment_menu(player, vehicles)
        end
        
        -- Clear the stored vehicle data
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
    
    -- Check if this is one of our sliders
    local pattern = "^slider_(.+)_(.+)$"
    local item_name, quality_name = string.match(element.name or "", pattern)
    
    if item_name and quality_name then
        -- Get the player
        local player = game.players[event.player_index]
        if not player or not player.valid then return end
        
        -- Format value to integer
        local value = math.floor(element.slider_value)
        
        -- Update the slider to ensure it shows integer values
        element.slider_value = value
        
        -- Find the specific section table (utilities_table, ammo_table, fuel_table, or equipment_table)
        local section_table
        local current = element
        while current and current.valid do
            if current.name == "utilities_table" or current.name == "ammo_table" or current.name == "fuel_table" or current.name == "equipment_table" then
                section_table = current
                break
            end
            current = current.parent
        end
        
        if not section_table then
            debug_log("Could not find section table (utilities_table, ammo_table, fuel_table, or equipment_table) for slider")
            return
        end
        
        -- Find the text field within the section table
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
        
        -- Update text field if found
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
    
    -- Check if this is one of our text fields
    local pattern = "^text_(.+)_(.+)$"
    local item_name, quality_name = string.match(element.name or "", pattern)
    
    if item_name and quality_name then
        -- Get the player
        local player = game.players[event.player_index]
        if not player or not player.valid then return end
        
        -- Parse the value
        local value = tonumber(element.text) or 0
        
        -- Find the items_table by traversing up (check for any section table)
        local items_table
        local current = element
        while current and current.valid do
            if current.name == "utilities_table" or current.name == "ammo_table" or current.name == "fuel_table" or current.name == "equipment_table" or current.name == "extras_table" then
                items_table = current
                break
            end
            current = current.parent
        end
        
        if not items_table then
            debug_log("Could not find items_table for text field")
            return
        end
        
        -- Find the slider within items_table
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
        
        local slider = find_element(items_table, slider_name)
        
        -- Update slider if valid
        if slider and slider.valid then
            -- Get max value from multiple sources (tags, slider_maximum)
            local max_value = nil
            if element.tags and element.tags.max_value then
                max_value = tonumber(element.tags.max_value)
            elseif slider.tags and slider.tags.max_value then
                max_value = tonumber(slider.tags.max_value)
            elseif slider.slider_maximum and type(slider.slider_maximum) == "number" then
                max_value = slider.slider_maximum
            end
            
            -- Clamp value to valid range (0 to available amount)
            if max_value and type(max_value) == "number" then
                value = math.max(0, math.min(value, max_value))
            else
                value = math.max(0, value)
            end
            value = math.floor(value)
            
            -- Update the slider
            slider.slider_value = value
            
            -- Update the text field to show the clamped value
            element.text = tostring(value)
        else
            debug_log("Could not find slider: " .. slider_name)
        end
    end
end)

-- Handle GUI closing (ESC key)
script.on_event(defines.events.on_gui_closed, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    -- Check if the closed element is a frame (since Factorio doesn't give us the exact element)
    -- This handles ESC key presses
    if player.gui.screen["spidertron_extras_frame"] then
        player.gui.screen["spidertron_extras_frame"].destroy()
    end
    
    if player.gui.screen["spidertron_deployment_frame"] then
        player.gui.screen["spidertron_deployment_frame"].destroy()
    end
    
    -- Clean up equipment grid orbital deploy button
    local relative_gui = player.gui.relative
    if relative_gui then
        local button_frame = relative_gui["equipment_grid_orbital_deploy"]
        if button_frame and button_frame.valid then
            button_frame.destroy()
        end
    end
    
    -- Clear stored vehicle data
    storage.current_equipment_grid_vehicle = nil
end)



-- Helper function to initialize scout-o-tron equipment grid
-- local function initialize_scout_grid(stack)
--     if not stack or not stack.valid_for_read or stack.name ~= "scout-o-tron" then
--         return false
--     end
    
--     -- Create grid if it doesn't exist
--     if not stack.grid then
--         local success, grid = pcall(function()
--             return stack.create_grid()
--         end)
--         if success and grid then
--             return true
--         end
--     end
    
--     return false
-- end

-- Handle GUI opening (to show platform deploy button and equipment fill button)
script.on_event(defines.events.on_gui_opened, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
    
    -- Try to create/update platform deploy button immediately
    -- The periodic check (every 1 second) will also try if this fails
    platform_gui.get_or_create_deploy_button(player)
    
    -- Create equipment grid fill button immediately
    equipment_grid_fill.get_or_create_fill_button(player)
    
    -- Check if opened is an equipment grid for a vehicle
    local opened = player.opened
    if opened and opened.valid then
        -- Check if it's an equipment grid
        local success, has_equipment = pcall(function()
            return opened.equipment ~= nil
        end)
        
        if success and has_equipment then
            -- It's an equipment grid - try to find the vehicle data
            local grid = opened
            local success_owner, itemstack_owner = pcall(function()
                return grid.itemstack_owner
            end)
            
            if success_owner and itemstack_owner then
                -- Check if it's a vehicle item
                if vehicles_list.is_vehicle(itemstack_owner.name) then
                    -- Try to find the vehicle in storage.spidertrons
                    if storage.spidertrons then
                        for _, vehicle in ipairs(storage.spidertrons) do
                            if vehicle.vehicle_name == itemstack_owner.name then
                                -- Store vehicle data for the orbital deployment button
                                storage.current_equipment_grid_vehicle = vehicle
                                
                                -- Add orbital deployment button to the equipment grid GUI
                                -- Equipment grids use relative GUI
                                local relative_gui = player.gui.relative
                                if relative_gui then
                                    -- Check if button already exists
                                    local button_frame = relative_gui["equipment_grid_orbital_deploy"]
                                    if not button_frame or not button_frame.valid then
                                        -- Try to find the equipment grid GUI type
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
                                                -- Try without anchor
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
                                                    caption = "Orbital Deployment",
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

script.on_event(defines.events.on_tick, function(event)
    -- Handle pending deployments
    if storage.pending_deployment then
        for player_index, data in pairs(storage.pending_deployment) do
            if not data.processed then
                data.processed = true
                -- Skip this tick, process next tick
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
        
        --game.print("[Deploy] Player surface: " .. player.surface.name)
        --game.print("[Deploy] Is platform surface: " .. tostring(player.surface.platform ~= nil))
        
        -- Check if player is on a platform surface - switch to planet and open map GUI
        if player.surface.platform then
            --game.print("[Deploy] Player is on platform surface, extracting planet...")
            
            -- Extract the planet name from the platform's space_location
            local planet_name = nil
            if player.surface.platform.space_location then
                local location_str = tostring(player.surface.platform.space_location)
                --game.print("[Deploy] Platform space_location string: " .. location_str)
                planet_name = location_str:match(": ([^%(]+) %(planet%)")
                --game.print("[Deploy] Extracted planet name: " .. tostring(planet_name))
            else
                --game.print("[Deploy] Platform has no space_location property")
            end
            
            if planet_name then
                -- Get the planet surface
                local planet_surface = game.get_surface(planet_name)
                --game.print("[Deploy] Planet surface lookup result: " .. tostring(planet_surface ~= nil))
                if planet_surface then
                    --game.print("[Deploy] Found planet surface: " .. planet_surface.name)
                    
                    -- Close any open GUIs
                    if player.opened then
                        player.opened = nil
                    end

                    -- Open map view at 0,0 on the planet surface
                    local target_position = {x = 0, y = 0}
                    player.set_controller{
                        type = defines.controllers.remote,
                        surface = planet_surface,
                        position = target_position
                    }

                    -- Store data needed for next tick
                    storage.pending_deployment = storage.pending_deployment or {}
                    storage.pending_deployment[player.index] = {
                        planet_surface = planet_surface,
                        planet_name = planet_name
                    }
                    return
                end
            else
                --game.print("[Deploy] ERROR: Could not determine which planet this platform is orbiting")
                player.print("Vehicle Deployment is not possible while the platform is in transit")
                return
            end
        end
        
        -- Find orbital spider vehicles
        --game.print("[Deploy] Player not on platform, searching for vehicles on surface: " .. player.surface.name)
        local vehicles = map_gui.find_orbital_vehicles(player.surface)
        --game.print("[Deploy] Found " .. #vehicles .. " vehicles for surface: " .. player.surface.name)
        if #vehicles == 0 then
            player.print("No vehicles are deployable to this surface.")
            return
        end
        
        -- Show selection dialog with appropriate deployment options
        --game.print("[Deploy] Showing deployment menu with " .. #vehicles .. " vehicles")
        map_gui.show_deployment_menu(player, vehicles)
    end
end)

-- Add a command to test deployment message
commands.add_command("test_deploy_message", "Test spider vehicle deployment message", function(command)
    local player = game.get_player(command.player_index)
    if not player then return end
    
    --player.print("Spider vehicle deployment commencing for: Test Spider")
    
    if player and player.valid and player.surface then
        local text = player.surface.create_entity({
            name = "flying-text",
            position = player.position,
            text = "Deploying Test Spider",
            color = {r=1, g=0, b=0}
        })
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
    -- Check if this is the space-platform technology
    if tech_name == "space-platform" then
        -- Update shortcuts for all players in this force
        for _, player in pairs(event.research.force.players) do
            map_gui.initialize_player_shortcuts(player)
            local surface_name = player.surface.name
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
            -- log("Cleaned up " .. #stale_ids .. " stale deployment records")
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
            -- log("Cleaned up " .. #stale_pod_ids .. " stale pod deployment records")
        end
    end
end)

-- Debug command to inspect hub inventory
commands.add_command("debug_hub_inventory", "Debug hub inventory items", function(command)
    local player = game.get_player(command.player_index)
    if not player then 
        return 
    end
    
    --player.print("Scanning hub inventories for debugging...")
    
    -- Try to find the vehicle data from storage
    if not storage.spidertrons or #storage.spidertrons == 0 then
        --player.print("No vehicles found in storage.spidertrons")
        return
    end
    
    -- Get the first vehicle's hub for testing
    local hub = storage.spidertrons[1].hub
    if not hub or not hub.valid then
        --player.print("Hub is not valid")
        return
    end
    
    --player.print("Found hub on platform: " .. storage.spidertrons[1].platform_name)
    
    -- Try chest inventory
    local inventory = hub.get_inventory(defines.inventory.chest)
    if not inventory then
        --player.print("No chest inventory found")
    else
        --player.print("Chest inventory has " .. #inventory .. " slots")
        
        -- Scan each slot
        for i = 1, #inventory do
            local stack = inventory[i]
            if stack.valid_for_read then
                local quality_str = "Normal"
                if stack.quality then
                    quality_str = stack.quality.name
                end
                
                --player.print("Slot " .. i .. ": " .. stack.name .. " x" .. stack.count .. " (" .. quality_str .. ")")
            end
        end
    end
end)

-- Temporary debug command to check planet information
commands.add_command("debug_planet_info", "Debug planet information from current platform", function(command)
    local player = game.get_player(command.player_index)
    if not player then 
        return 
    end
    
    player.print("=== Planet Debug Info ===")
    
    -- Check player's current surface
    local player_surface = player.surface
    if player_surface then
        player.print("Player surface: " .. tostring(player_surface.name))
        
        -- Check if it's a platform surface
        if player_surface.platform then
            player.print("Surface is a platform")
            
            -- Check space_location
            local space_location = player_surface.platform.space_location
            if space_location then
                player.print("space_location: " .. tostring(space_location))
                
                -- Try to get planet from platform
                local planet_success, planet = pcall(function()
                    return player_surface.platform.planet
                end)
                if planet_success and planet then
                    player.print("platform.planet found: " .. tostring(planet))
                    
                    -- Try to get planet name
                    local name_success, planet_name = pcall(function()
                        return planet.name
                    end)
                    if name_success and planet_name then
                        player.print("planet.name: " .. tostring(planet_name))
                    end
                    
                    -- Try to get associated_surfaces
                    local surfaces_success, associated_surfaces = pcall(function()
                        return planet.associated_surfaces
                    end)
                    if surfaces_success and associated_surfaces then
                        player.print("planet.associated_surfaces count: " .. tostring(#associated_surfaces))
                        for i, surface in ipairs(associated_surfaces) do
                            local surface_name = "unknown"
                            local name_success, name = pcall(function()
                                return surface.name
                            end)
                            if name_success and name then
                                surface_name = name
                            end
                            player.print("  [" .. i .. "] " .. surface_name)
                            
                            -- Check if this is arrival
                            if surface_name:lower():find("arrival") then
                                player.print("    ^^^ This is ARRIVAL!")
                            end
                        end
                    else
                        player.print("Could not access planet.associated_surfaces")
                    end
                else
                    player.print("platform.planet not found")
                end
                
                -- Try to get planet from space_location
                local space_planet_success, space_planet = pcall(function()
                    return space_location.planet
                end)
                if space_planet_success and space_planet then
                    player.print("space_location.planet found: " .. tostring(space_planet))
                end
                
                -- Try space_location.name
                local loc_name_success, loc_name = pcall(function()
                    return space_location.name
                end)
                if loc_name_success and loc_name then
                    player.print("space_location.name: " .. tostring(loc_name))
                    
                    -- Try to find planet in game.planets
                    local planet_lookup = game.planets[loc_name]
                    if planet_lookup then
                        player.print("Found planet in game.planets[" .. loc_name .. "]")
                        
                        -- Try associated_surfaces
                        local surfaces_success2, associated_surfaces2 = pcall(function()
                            return planet_lookup.associated_surfaces
                        end)
                        if surfaces_success2 and associated_surfaces2 then
                            player.print("game.planets[" .. loc_name .. "].associated_surfaces count: " .. tostring(#associated_surfaces2))
                            for i, surface in ipairs(associated_surfaces2) do
                                local surface_name = "unknown"
                                local name_success, name = pcall(function()
                                    return surface.name
                                end)
                                if name_success and name then
                                    surface_name = name
                                end
                                player.print("  [" .. i .. "] " .. surface_name)
                                
                                -- Check if this is arrival
                                if surface_name:lower():find("arrival") then
                                    player.print("    ^^^ This is ARRIVAL!")
                                end
                            end
                        end
                    end
                end
            else
                player.print("No space_location found")
            end
        else
            player.print("Surface is not a platform")
        end
    else
        player.print("No player surface found")
    end
    
    player.print("=== End Planet Debug ===")
end)

-- Command to specifically check for arrival
commands.add_command("debug_find_arrival", "Find arrival planet and surfaces", function(command)
    local player = game.get_player(command.player_index)
    if not player then 
        return 
    end
    
    player.print("=== Searching for Arrival ===")
    
    -- First, check current platform if on one
    local player_surface = player.surface
    if player_surface and player_surface.platform then
        player.print("Current platform: " .. tostring(player_surface.name))
        
        local space_location = player_surface.platform.space_location
        if space_location then
            player.print("space_location: " .. tostring(space_location))
            
            -- Try to get planet from space_location.name
            local loc_name_success, loc_name = pcall(function()
                return space_location.name
            end)
            if loc_name_success and loc_name then
                player.print("space_location.name: " .. tostring(loc_name))
                
                -- Get planet from game.planets
                local planet = game.planets[loc_name]
                if planet then
                    player.print("Found planet: " .. tostring(planet))
                    
                    -- Check associated_surfaces for arrival
                    local surfaces_success, associated_surfaces = pcall(function()
                        return planet.associated_surfaces
                    end)
                    if surfaces_success and associated_surfaces then
                        player.print("associated_surfaces count: " .. tostring(#associated_surfaces))
                        for i, surface in ipairs(associated_surfaces) do
                            local surface_name = "unknown"
                            local localised_name_str = nil
                            
                            -- Get name
                            local name_success, name = pcall(function()
                                return surface.name
                            end)
                            if name_success and name then
                                surface_name = name
                            end
                            
                            -- Get localised_name
                            local localised_success, localised_name = pcall(function()
                                return surface.localised_name
                            end)
                            if localised_success and localised_name then
                                localised_name_str = game.get_localised_string(localised_name)
                            end
                            
                            local is_arrival = false
                            if surface_name:lower():find("arrival") or (localised_name_str and localised_name_str:lower():find("arrival")) then
                                is_arrival = true
                            end
                            
                            if is_arrival then
                                player.print("  [" .. i .. "] " .. surface_name .. " (localised: " .. tostring(localised_name_str) .. ") <--- ARRIVAL FOUND!")
                            else
                                player.print("  [" .. i .. "] " .. surface_name .. " (localised: " .. tostring(localised_name_str) .. ")")
                            end
                        end
                    end
                end
            end
        end
    end
    
    player.print("--- Searching all planets for arrival ---")
    
    -- Search through all planets in game.planets
    local found_arrival = false
    for planet_name, planet in pairs(game.planets) do
        local planet_name_str = tostring(planet_name)
        
        -- Check if planet name contains arrival
        if planet_name_str:lower():find("arrival") then
            player.print("Found planet with 'arrival' in name: " .. planet_name_str)
            found_arrival = true
            
            -- Get associated_surfaces
            local surfaces_success, associated_surfaces = pcall(function()
                return planet.associated_surfaces
            end)
            if surfaces_success and associated_surfaces then
                player.print("  associated_surfaces count: " .. tostring(#associated_surfaces))
                for i, surface in ipairs(associated_surfaces) do
                    local surface_name = "unknown"
                    local name_success, name = pcall(function()
                        return surface.name
                    end)
                    if name_success and name then
                        surface_name = name
                        player.print("    [" .. i .. "] " .. surface_name)
                    end
                end
            end
        else
            -- Check associated_surfaces for arrival even if planet name doesn't have it
            local surfaces_success, associated_surfaces = pcall(function()
                return planet.associated_surfaces
            end)
            if surfaces_success and associated_surfaces then
                for i, surface in ipairs(associated_surfaces) do
                    local surface_name = "unknown"
                    local name_success, name = pcall(function()
                        return surface.name
                    end)
                    if name_success and name then
                        surface_name = name
                        if surface_name:lower():find("arrival") then
                            player.print("Found 'arrival' in planet '" .. planet_name_str .. "' associated_surfaces:")
                            player.print("  Planet: " .. planet_name_str)
                            player.print("  Surface [" .. i .. "]: " .. surface_name .. " <--- ARRIVAL!")
                            found_arrival = true
                            
                            -- Show all surfaces for this planet
                            player.print("  All surfaces for this planet:")
                            for j, surf in ipairs(associated_surfaces) do
                                local surf_name = "unknown"
                                local surf_name_success, surf_name_result = pcall(function()
                                    return surf.name
                                end)
                                if surf_name_success and surf_name_result then
                                    surf_name = surf_name_result
                                end
                                player.print("    [" .. j .. "] " .. surf_name)
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Also search all surfaces directly
    player.print("--- Searching all surfaces for arrival ---")
    for _, surface in pairs(game.surfaces) do
        local surface_name = surface.name
        if surface_name:lower():find("arrival") then
            player.print("Found surface with 'arrival': " .. surface_name)
            found_arrival = true
            
            -- Check if this surface has a planet property
            local planet_success, planet = pcall(function()
                return surface.planet
            end)
            if planet_success and planet then
                player.print("  Surface belongs to planet: " .. tostring(planet))
            end
        end
    end
    
    if not found_arrival then
        player.print("No 'arrival' found in any planets or surfaces")
    end
    
    player.print("=== End Arrival Search ===")
end)

-- Command to check nauvis localised name
commands.add_command("debug_nauvis_localised", "Check nauvis planet localised name", function(command)
    local player = game.get_player(command.player_index)
    if not player then 
        return 
    end
    
    player.print("=== Checking Nauvis Localised Name ===")
    
    -- First, check if player is on a platform and get space_location
    local player_surface = player.surface
    if player_surface and player_surface.platform then
        local space_location = player_surface.platform.space_location
        if space_location then
            player.print("space_location found: " .. tostring(space_location))
            
            -- Check space_location.localised_name (LuaSpaceLocationPrototype has this)
            local space_localised_success, space_localised = pcall(function()
                return space_location.localised_name
            end)
            if space_localised_success and space_localised then
                player.print("space_location.localised_name (raw): " .. tostring(space_localised))
                
                local string_success, localised_string = pcall(function()
                    return game.get_localised_string(space_localised)
                end)
                if string_success and localised_string then
                    player.print("space_location.localised_name (string): " .. tostring(localised_string))
                else
                    player.print("Could not convert space_location.localised_name to string")
                end
            else
                player.print("Could not access space_location.localised_name")
            end
            
            -- Also check space_location.name
            local space_name_success, space_name = pcall(function()
                return space_location.name
            end)
            if space_name_success and space_name then
                player.print("space_location.name: " .. tostring(space_name))
            end
        end
    end
    
    -- Get nauvis planet
    local nauvis_planet = game.planets["nauvis"]
    if nauvis_planet then
        player.print("Found nauvis planet: " .. tostring(nauvis_planet))
        
        -- Get planet.name
        local name_success, planet_name = pcall(function()
            return nauvis_planet.name
        end)
        if name_success and planet_name then
            player.print("planet.name: " .. tostring(planet_name))
        end
        
        player.print("Note: LuaPlanet does not have localised_name property")
        
        -- Also check associated_surfaces
        local surfaces_success, associated_surfaces = pcall(function()
            return nauvis_planet.associated_surfaces
        end)
        if surfaces_success and associated_surfaces then
            player.print("associated_surfaces count: " .. tostring(#associated_surfaces))
            for i, surface in ipairs(associated_surfaces) do
                local surface_name = "unknown"
                local surface_localised = nil
                
                local name_success2, name2 = pcall(function()
                    return surface.name
                end)
                if name_success2 and name2 then
                    surface_name = name2
                end
                
                local localised_success2, localised2 = pcall(function()
                    return surface.localised_name
                end)
                if localised_success2 and localised2 then
                    local string_success2, localised_string2 = pcall(function()
                        return game.get_localised_string(localised2)
                    end)
                    if string_success2 and localised_string2 then
                        surface_localised = localised_string2
                    end
                end
                
                player.print("  [" .. i .. "] name: " .. surface_name .. ", localised: " .. tostring(surface_localised))
            end
        else
            player.print("Could not access associated_surfaces")
        end
    else
        player.print("Could not find nauvis planet in game.planets")
    end
    
    player.print("=== End Nauvis Check ===")
end)