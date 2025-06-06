-- scripts-sa/platform-gui.lua
--[[is this redundant?
local platform_gui = {}

-- Create the deploy button when viewing a planet
function platform_gui.create_deploy_button(player)
    -- Check if button already exists
    if player.gui.screen["orbital_spidertron_frame"] then
        return
    end
    
    -- Create frame at top of screen
    local frame = player.gui.screen.add{
        type = "frame",
        name = "orbital_spidertron_frame",
        caption = "Orbital Spidertron",
        direction = "vertical"
    }
    
    -- Position at top middle of screen
    local resolution = player.display_resolution
    frame.location = {x = resolution.width / 2 - 100, y = 10}
    
    -- Add button
    local button_flow = frame.add{
        type = "flow",
        name = "button_flow",
        direction = "horizontal"
    }
    
    -- Add spidertron icon
    button_flow.add{
        type = "sprite-button",
        name = "spidertron_icon",
        sprite = "item/spidertron",
        tooltip = "Orbital Spidertron Deployment"
    }
    
    -- Add deploy button
    button_flow.add{
        type = "button",
        name = "deploy_spidertron_btn",
        caption = "Deploy Spidertron",
        tooltip = "Deploy a spidertron from orbit to this planet",
        style = "confirm_button"
    }
    
    log("Deploy button created")
end

-- Check for spidertrons in orbit above the current planet
function platform_gui.find_orbital_spidertrons(planet_surface)
    local available_spidertrons = {}
    
    -- Get all platforms
    if remote.interfaces["space-age"] and remote.interfaces["space-age"]["get_platforms"] then
        for _, force in pairs(game.forces) do
            local platforms = remote.call("space-age", "get_platforms", {force = force.name})
            if platforms then
                for _, platform in pairs(platforms) do
                    -- Check if platform is over this planet
                    if platform.space_location and platform_gui.is_over_planet(platform, planet_surface) then
                        -- Check for spidertrons in hub
                        if platform.hub and platform.hub.valid then
                            local spidertrons = platform_gui.get_spidertrons_from_hub(platform.hub)
                            if #spidertrons > 0 then
                                for _, spidertron in ipairs(spidertrons) do
                                    table.insert(available_spidertrons, {
                                        platform = platform,
                                        hub = platform.hub,
                                        slot = spidertron.slot,
                                        inv_type = spidertron.inv_type,
                                        name = spidertron.name,
                                        tooltip = spidertron.tooltip
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return available_spidertrons
end

-- Check if a platform is over a specific planet
function platform_gui.is_over_planet(platform, planet_surface)
    -- This is a placeholder implementation
    -- In real code, you would check if the platform's space_location
    -- corresponds to the given planet surface
    
    -- For testing, always return true
    return true
end

-- Get spidertrons from a hub entity
function map_gui.get_spidertrons_from_hub(hub_entity)
    local result = {}
    
    if not hub_entity or not hub_entity.valid then 
        return result 
    end
    
    -- Get the inventory
    local inventory = hub_entity.get_inventory(defines.inventory.chest)
    if inventory then
        -- Count how many spidertrons are in the inventory
        local spidertron_count = inventory.get_item_count("spidertron")
        if spidertron_count > 0 then
            log("Found " .. spidertron_count .. " spidertrons in inventory")
            
            -- For each slot in the inventory
            for i = 1, #inventory do
                -- Check if it's a spidertron
                if inventory[i].valid_for_read and inventory[i].name == "spidertron" then
                    -- Add it to our result
                    table.insert(result, {
                        name = "Spidertron #" .. i,
                        tooltip = "Slot: " .. i,
                        slot = i,
                        inv_type = defines.inventory.chest
                    })
                end
            end
        end
    end
    
    return result
end

-- Show spidertron selection dialog
function platform_gui.show_selection_dialog(player, spidertrons)
    if #spidertrons == 0 then
        player.print("No spidertrons are available in orbit.")
        return
    end
    
    -- Close existing dialog if any
    if player.gui.screen["spidertron_selection_frame"] then
        player.gui.screen["spidertron_selection_frame"].destroy()
    end
    
    -- Create the selection dialog
    local frame = player.gui.screen.add{
        type = "frame",
        name = "spidertron_selection_frame",
        caption = "Select Spidertron to Deploy",
        direction = "vertical"
    }
    
    -- Center the frame
    frame.force_auto_center()
    
    -- Add list of spidertrons
    local list_flow = frame.add{
        type = "flow",
        name = "list_flow",
        direction = "vertical"
    }
    
    for i, spidertron in ipairs(spidertrons) do
        list_flow.add{
            type = "button",
            name = "select_spidertron_" .. i,
            caption = spidertron.name,
            tooltip = spidertron.tooltip
        }
    end
    
    -- Add cancel button
    local button_flow = frame.add{
        type = "flow",
        name = "button_flow",
        direction = "horizontal"
    }
    
    button_flow.add{
        type = "button",
        name = "cancel_selection",
        caption = "Cancel"
    }
    
    -- Store selection data
    storage.spidertron_selection = {
        spidertrons = spidertrons,
        planet_surface = player.surface
    }
end

-- Handle GUI click events
function platform_gui.on_gui_click(event)
    local element = event.element
    if not element or not element.valid then return end
    
    local player = game.get_player(event.player_index)
    if not player then return end
    
    if element.name == "deploy_spidertron_btn" then
        -- Find spidertrons in orbit above current planet
        local spidertrons = platform_gui.find_orbital_spidertrons(player.surface)
        platform_gui.show_selection_dialog(player, spidertrons)
    elseif element.name:find("select_spidertron_") then
        local index = tonumber(element.name:sub(17))
        if not index or not storage.spidertron_selection then return end
        
        local spidertron = storage.spidertron_selection.spidertrons[index]
        if not spidertron then return end
        
        -- Close the selection dialog
        if player.gui.screen["spidertron_selection_frame"] then
            player.gui.screen["spidertron_selection_frame"].destroy()
        end
        
        -- Deploy the selected spidertron (placeholder for now)
        player.print("Spidertron deployment commencing for: " .. spidertron.name)
    elseif element.name == "cancel_selection" then
        -- Close the selection dialog
        if player.gui.screen["spidertron_selection_frame"] then
            player.gui.screen["spidertron_selection_frame"].destroy()
        end
    end
end

-- Remove the deploy button
function platform_gui.destroy_deploy_button(player)
    if player.gui.screen["orbital_spidertron_frame"] then
        player.gui.screen["orbital_spidertron_frame"].destroy()
    end
end

return platform_gui
]]