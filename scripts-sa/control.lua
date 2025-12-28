-- scripts-sa/control.lua
local map_gui = require("scripts-sa.map-gui")
local deployment = require("scripts-sa.deployment")
local vehicles_list = require("scripts-sa.vehicles-list")
local platform_gui = require("scripts-sa.platform-gui")
local equipment_grid_fill = require("scripts-sa.equipment-grid-fill")
local container_deployment = require("scripts-sa.container-deployment")
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
            if current.name == "utilities_table" or current.name == "ammo_table" or current.name == "fuel_table" or current.name == "equipment_table" or current.name == "supplies_table" then
                section_table = current
                break
            end
            current = current.parent
        end

        if not section_table then
            debug_log("Could not find section table (utilities_table, ammo_table, fuel_table, equipment_table, or supplies_table) for stack button")
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

    if element.name == "deployment_amount_slider" then
        local player = game.players[event.player_index]
        if player and player.valid then
            container_deployment.on_slider_changed(player, element)
        end
        return  -- Important: return here so we don't continue to pattern matching
    end
    
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
            if current.name == "utilities_table" or current.name == "ammo_table" or current.name == "fuel_table" or current.name == "equipment_table" or current.name == "supplies_table" then
                section_table = current
                break
            end
            current = current.parent
        end

        if not section_table then
            debug_log("Could not find section table (utilities_table, ammo_table, fuel_table, equipment_table, or supplies_table) for slider")
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

    if element.name == "deployment_amount_textfield" then
        local player = game.players[event.player_index]
        if player and player.valid then
            container_deployment.on_textfield_changed(player, element)
        end
        return
    end
    
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
            if current.name == "utilities_table" or current.name == "ammo_table" or current.name == "fuel_table" or current.name == "equipment_table" or current.name == "extras_table" or current.name == "supplies_table" then
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

    container_deployment.remove_gui(player)
    
    -- Clear stored vehicle data
    storage.current_equipment_grid_vehicle = nil
end)

-- Handle GUI opening (to show platform deploy button and equipment fill button)
script.on_event(defines.events.on_gui_opened, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
    -- Only try to create platform button if we're opening a platform hub
    if event.entity and event.entity.valid and 
       (event.entity.type == "space-platform-hub" or event.entity.name == "space-platform-hub") then
        -- Store the opened entity for next tick processing
        storage.pending_grid_open = storage.pending_grid_open or {}
        storage.pending_grid_open[player.index] = {
            opened = event.entity,
            tick = game.tick
        }
    end
    
    -- Create equipment grid fill button immediately
    equipment_grid_fill.get_or_create_fill_button(player)

    local opened = player.opened
    if opened and opened.valid then
        -- Check if it's a container (chest, cargo wagon, etc.)
        local success, is_container = pcall(function()
            return opened.get_inventory(defines.inventory.chest) ~= nil
        end)
        
        if success and is_container then
            -- Try to create container deployment GUI
            container_deployment.get_or_create_gui(player, opened)
        end
    end
    
    -- Check what was opened
    local opened = player.opened
    if opened and opened.valid then
        -- Check if it's an entity (like a chest/container)
        local success_entity, is_entity = pcall(function()
            return opened.name ~= nil and opened.get_inventory ~= nil
        end)
        
        if success_entity and is_entity then
            -- Try to get the entity's inventory
            local inventory = opened.get_inventory(defines.inventory.chest)
            if inventory then
                -- Check all items in the inventory for items that need grid initialization
                for i = 1, #inventory do
                    local stack = inventory[i]
                    if stack and stack.valid_for_read then
                        local item_prototype = prototypes.item[stack.name]
                        if item_prototype and item_prototype.type == "item-with-entity-data" then
                            if item_prototype.stack_size == 1 then
                                if not stack.grid then
                                    local success_grid, grid = pcall(function()
                                        return stack.create_grid()
                                    end)
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Check if opened is an equipment grid for a vehicle
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
    -- Handle pending GUI opens (for platform button)
    if storage.pending_grid_open then
        for player_index, data in pairs(storage.pending_grid_open) do
            if game.tick > data.tick then  -- Wait one tick
                local player = game.get_player(player_index)
                if player and player.valid then
                    -- Pass the entity that was opened
                    platform_gui.get_or_create_deploy_button(player, data.opened)
                    equipment_grid_fill.get_or_create_fill_button(player)
                end
                storage.pending_grid_open[player_index] = nil
            end
        end
    end
    
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