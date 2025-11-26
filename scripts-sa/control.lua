-- scripts-sa/control.lua
local map_gui = require("scripts-sa.map-gui")
local deployment = require("scripts-sa.deployment")
local vehicles_list = require("scripts-sa.vehicles-list")

-- Debug logging function
local function debug_log(message)
    log("[Orbital Spider Delivery SA] " .. message)
end

-- Initialize storage
local function init_storage()
    storage = storage or {}
    storage.pending_deployments = storage.pending_deployments or {}
    storage.pending_pod_deployments = storage.pending_pod_deployments or {}
    storage.temp_deployment_data = storage.temp_deployment_data or {}
    debug_log("Space Age storage initialized")
end

-- Initialize player shortcuts
local function init_players()
    for _, player in pairs(game.players) do
        -- Enable the shortcut based on space-platform research
        local space_platform_researched = player.force.technologies["space-platform"] and player.force.technologies["space-platform"].researched or false
        local surface_name = player.surface.name
                
        player.set_shortcut_available("orbital-spidertron-deploy", space_platform_researched)
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
    debug_log("Space Age module loaded")
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
            debug_log("Could not find section table (utilities_table, ammo_table, or fuel_table) for stack button")
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
        else
            debug_log("Could not find slider or text field: " .. slider_name .. ", " .. text_field_name)
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
        -- Get the player
        local player = game.players[event.player_index]
        if not player or not player.valid then return end
        
        -- Format value to integer
        local value = math.floor(element.slider_value)
        
        -- Update the slider to ensure it shows integer values
        element.slider_value = value
        
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
            debug_log("Could not find section table (utilities_table, ammo_table, or fuel_table) for slider")
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
        
        -- Find the items_table by traversing up
        local items_table
        local current = element
        while current and current.valid and current.name ~= "extras_table" do
            current = current.parent
        end
        if current and current.name == "extras_table" then
            items_table = current
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
            -- Clamp value to valid range
            value = math.max(0, math.min(value, slider.slider_maximum))
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
end)

-- Handle shortcut button clicks
script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name == "orbital-spidertron-deploy" then
        local player = game.get_player(event.player_index)
        if not player then return end
        
        -- Find orbital spider vehicles
        local vehicles = map_gui.find_orbital_vehicles(player.surface)
        if #vehicles == 0 then
            player.print("No vehicles are deployable to this surface.")
            return
        end
        
        -- Show selection dialog with appropriate deployment options
        map_gui.show_deployment_menu(player, vehicles)
    end
end)

-- Add a command to test deployment message
commands.add_command("test_deploy_message", "Test spider vehicle deployment message", function(command)
    local player = game.get_player(command.player_index)
    if not player then return end
    
    player.print("Spider vehicle deployment commencing for: Test Spider")
    
    local success, err = pcall(function()
        local text = player.surface.create_entity({
            name = "flying-text",
            position = player.position,
            text = "Deploying Test Spider",
            color = {r=1, g=0, b=0}
        })
    end)
    
    if not success then
        player.print("Error creating flying text: " .. tostring(err))
    else
        player.print("Flying text created successfully")
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

-- Debug command to inspect hub inventory
commands.add_command("debug_hub_inventory", "Debug hub inventory items", function(command)
    local player = game.get_player(command.player_index)
    if not player then 
        return 
    end
    
    player.print("Scanning hub inventories for debugging...")
    
    -- Try to find the vehicle data from storage
    if not storage.spidertrons or #storage.spidertrons == 0 then
        player.print("No vehicles found in storage.spidertrons")
        return
    end
    
    -- Get the first vehicle's hub for testing
    local hub = storage.spidertrons[1].hub
    if not hub or not hub.valid then
        player.print("Hub is not valid")
        return
    end
    
    player.print("Found hub on platform: " .. storage.spidertrons[1].platform_name)
    
    -- Try chest inventory
    local inventory = hub.get_inventory(defines.inventory.chest)
    if not inventory then
        player.print("No chest inventory found")
    else
        player.print("Chest inventory has " .. #inventory .. " slots")
        
        -- Scan each slot
        for i = 1, #inventory do
            local stack = inventory[i]
            if stack.valid_for_read then
                local quality_str = "Normal"
                pcall(function()
                    if stack.quality then
                        quality_str = stack.quality.name
                    end
                end)
                
                player.print("Slot " .. i .. ": " .. stack.name .. " x" .. stack.count .. " (" .. quality_str .. ")")
            end
        end
    end
end)

debug_log("Space Age control script loaded")