-- scripts-sa/map-gui.lua
local map_gui = {}

-- Find spidertrons in orbit with extensive debugging
function map_gui.find_orbital_spidertrons(player_surface)
    local available_spidertrons = {}
    local platform_count = 0
    local hub_count = 0
    local inventory_count = 0
    
    log("Searching for orbital spidertrons above " .. player_surface.name .. "...")
    
    -- Iterate through all surfaces to find platforms
    for _, surface in pairs(game.surfaces) do
        -- Debug info for each surface
        log("Checking surface: " .. surface.name)
        
        -- Check if this is a platform surface
        if surface.platform then
            platform_count = platform_count + 1
            log("Found platform #" .. platform_count .. ": " .. surface.name)
            
            -- Check if the platform is orbiting the player's current surface
            local is_orbiting_current_planet = false
            
            -- Check the platform's space_location
            if surface.platform.space_location then
                local platform_location = surface.platform.space_location
                
                -- Log the space_location for debugging
                local location_str = tostring(platform_location)
                log("Platform space_location: " .. location_str)
                
                -- Extract the planet name from the location string
                -- Pattern looks for text between ": " and " (planet)"
                local orbiting_planet = location_str:match(": ([^%(]+) %(planet%)")
                
                if orbiting_planet then
                    log("Platform is orbiting planet: " .. orbiting_planet)
                    
                    -- Check if this platform is orbiting the current planet
                    if orbiting_planet == player_surface.name then
                        is_orbiting_current_planet = true
                        log("Platform is orbiting the current planet")
                    else
                        log("Platform is NOT orbiting the current planet")
                    end
                else
                    log("Could not determine which planet this platform is orbiting")
                    -- If we can't determine, let's include it to be safe
                    is_orbiting_current_planet = true
                end
            else
                log("Platform has no space_location property")
                -- If no space_location is specified, assume it's valid
                is_orbiting_current_planet = true
            end
            
            -- Only proceed if the platform is orbiting the current planet
            if is_orbiting_current_planet then
                -- Check if the platform has a hub
                if surface.platform.hub and surface.platform.hub.valid then
                    hub_count = hub_count + 1
                    log("Platform has valid hub #" .. hub_count)
                    
                    -- Check for spidertrons in the hub's inventory
                    local hub = surface.platform.hub
                    log("Hub entity name: " .. hub.name)
                    
                    -- Try different inventory types but track which slots we've already processed
                    local processed_slots = {}
                    
                    for _, inv_type in pairs({defines.inventory.chest}) do
                        local inventory = hub.get_inventory(inv_type)
                        if inventory then
                            inventory_count = inventory_count + 1
                            log("Found inventory type " .. inv_type .. " with " .. #inventory .. " slots")
                            
                            -- Check for spidertrons in this inventory
                            local spidertron_count = inventory.get_item_count("spidertron")
                            log("Inventory contains " .. spidertron_count .. " spidertrons")
                            
                            -- Scan the inventory for spidertrons
                            for i = 1, #inventory do
                                local stack = inventory[i]
                                if stack.valid_for_read then
                                    log("Slot " .. i .. " contains: " .. stack.name .. " x" .. stack.count)
                                    
                                    if stack.name == "spidertron" and not processed_slots[i] then
                                        processed_slots[i] = true
                                        -- Create entry for this spidertron
                                        log("Found spidertron in slot " .. i)
                                        
                                        -- Try to get the spidertron's custom name if available
                                        local name = "Spidertron"
                                        
                                        -- Try to get entity_label directly from stack (per LuaItemCommonabstract documentation)
                                        pcall(function()
                                            if stack.entity_label and stack.entity_label ~= "" then
                                                name = stack.entity_label
                                                log("Found entity_label directly: " .. name)
                                            end
                                        end)
                                        
                                        -- Fallbacks if direct entity_label didn't work
                                        if name == "Spidertron" then
                                            pcall(function()
                                                -- Try label from the stack
                                                if stack.label and stack.label ~= "" then
                                                    name = stack.label
                                                    log("Found label: " .. name)
                                                -- Try to extract entity_label from item tags if it exists
                                                elseif stack.tags and stack.tags.entity_label then
                                                    name = stack.tags.entity_label
                                                    log("Found entity_label in tags: " .. name)
                                                end
                                            end)
                                            
                                            -- In some mods, custom entity data might be stored in custom_description or similar fields
                                            pcall(function()
                                                if stack.custom_description then
                                                    local label_match = stack.custom_description:match("Label: ([^,]+)")
                                                    if label_match then
                                                        name = label_match
                                                        log("Found label in custom_description: " .. name)
                                                    end
                                                end
                                            end)
                                        end
                                        
                                        -- Log some important properties individually instead of using pairs()
                                        log("Spidertron properties available:")
                                        pcall(function() log("  name = " .. (stack.name or "nil")) end)
                                        pcall(function() log("  count = " .. (stack.count or "nil")) end)
                                        pcall(function() log("  label = " .. (stack.label or "nil")) end)
                                        pcall(function() log("  entity_label = " .. (stack.entity_label or "nil")) end)
                                        pcall(function() log("  durability = " .. (stack.durability or "nil")) end)
                                        pcall(function() log("  health = " .. (stack.health or "nil")) end)
                                        
                                        -- Add debug log for final extracted name
                                        log("Final extracted spidertron name: " .. name)
                                        
                                        -- Try to get color info safely
                                        local color = {r=0.8, g=0.2, b=0.2}  -- Default red
                                        pcall(function()
                                            if stack.entity_color then
                                                color = stack.entity_color
                                            end
                                        end)
                                        
                                        -- Build tooltip with platform details
                                        local tooltip = "Platform: " .. surface.name .. "\nSlot: " .. i
                                        
                                        local quality = nil
                                        pcall(function()
                                            if stack.quality then
                                                quality = stack.quality
                                                log("Found spidertron with quality: " .. quality.name .. " (level " .. quality.level .. ")")
                                            end
                                        end)

                                        table.insert(available_spidertrons, {
                                            name = name,
                                            tooltip = tooltip,
                                            color = color,
                                            index = i,
                                            hub = hub,
                                            inventory_slot = i,
                                            inv_type = inv_type,
                                            platform_name = surface.name,
                                            quality = quality 
                                        })
                                    end
                                end
                            end
                        else
                            log("No inventory found for type " .. inv_type)
                        end
                    end
                else
                    log("Platform has no valid hub")
                end
            else
                log("Skipping platform as it's not orbiting the current planet")
            end
        else
            log("Not a platform surface")
        end
    end
    
    log("Search complete. Found " .. platform_count .. " platforms, " .. hub_count .. " hubs, " .. inventory_count .. " inventories, and " .. #available_spidertrons .. " spidertrons above " .. player_surface.name)
    
    return available_spidertrons
end

-- Show spidertron deployment menu with target/player location options
function map_gui.show_deployment_menu(player, spidertrons)
    -- Close existing dialog if any
    if player.gui.screen["spidertron_deployment_frame"] then
        player.gui.screen["spidertron_deployment_frame"].destroy()
    end
    
    -- Create the deployment menu frame
    local frame = player.gui.screen.add{
        type = "frame",
        name = "spidertron_deployment_frame",
        caption = {"", " Orbital Deployment"},
        direction = "vertical"
    }
    
    -- Position at top of screen
    local resolution = player.display_resolution
    frame.location = {x = resolution.width / 2 - 200, y = 50}
    
    -- Add title bar with close button
    local title_flow = frame.add{
        type = "flow",
        name = "title_flow",
        direction = "horizontal"
    }
    
    -- Add title
    title_flow.add{
        type = "label",
        caption = "Deploy from orbit above " .. player.surface.name:gsub("^%l", string.upper),
        style = "caption_label"
    }
    -- Add spacer to push close button to right
    local spacer = title_flow.add{
        type = "empty-widget",
        name = "spacer"
    }
    spacer.style.horizontally_stretchable = true
    
    -- Add close button
    title_flow.add{
        type = "button",
        name = "close_deployment_menu_btn",
        caption = "×",  -- Unicode multiplication sign as an X
        style = "frame_action_button"
    }
    
    -- Add scrollable container for the list
    local scroll_pane = frame.add{
        type = "scroll-pane",
        name = "spidertron_scroll_pane",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "auto"
    }
    scroll_pane.style.maximal_height = 400
    scroll_pane.style.minimal_width = 400
    
    -- Create table for spidertrons
    local spidertron_table = scroll_pane.add{
        type = "table",
        name = "spidertron_table",
        column_count = 3,  -- Icon, Name, Buttons
        style = "table"
    }
    
    -- Add each spidertron
    for i, spidertron in ipairs(spidertrons) do
        -- Icon with color
        local icon = spidertron_table.add{
            type = "sprite",
            sprite = "item/spidertron",
            --tooltip = "Spidertron from " .. spidertron.platform_name
        }
        
        -- Name (possibly with color)
        local name_label = spidertron_table.add{
            type = "label",
            caption = spidertron.name,
            --tooltip = "Located on " .. spidertron.platform_name
        }
        
        if spidertron.color then
            name_label.style.font_color = spidertron.color
        end
        
        -- Action buttons flow
        local button_flow = spidertron_table.add{
            type = "flow",
            direction = "horizontal"
        }
        
        -- Check if in map view (chart or zoomed-in chart)
        local in_map_view = player.render_mode == defines.render_mode.chart or 
                            player.render_mode == defines.render_mode.chart_zoomed_in

        -- Check if the player is on the same surface as their character
        local is_same_surface = player.surface == player.physical_surface

        if in_map_view then
            -- Always allow deploying to map target
            button_flow.add{
                type = "sprite-button",
                name = "deploy_target_" .. i,
                sprite = "utility/go_to_arrow",
                tooltip = "Deploy to target location on map",
                style = "tool_button"
            }

            -- Only allow deploy to player if map view is of same surface as their body
            if is_same_surface then
                button_flow.add{
                    type = "sprite-button",
                    name = "deploy_player_" .. i,
                    sprite = "entity/character",
                    tooltip = "Deploy to your character's location",
                    style = "tool_button"
                }
            end
        else
            -- Not in map view, always show deploy-to-player
            button_flow.add{
                type = "sprite-button",
                name = "deploy_player_" .. i,
                sprite = "entity/character",
                tooltip = "Deploy to your character's location",
                style = "tool_button"
            }
        end
    end
    
    -- Store the list for reference when clicking
    storage.spidertrons = spidertrons
end


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

-- Function to update the deployment menu based on the player's render mode and surface
function map_gui.update_deployment_menu(player)
    -- Ensure the deployment menu exists and get the button flow
    local frame = player.gui.screen["spidertron_deployment_frame"]
    if not frame then
        return
    end
    
    local button_flow = frame["button_flow"]
    if not button_flow then
        return
    end
    
    -- Destroy previous buttons before refreshing
    button_flow.clear()

    -- Determine if the player is on the same surface
    local is_same_surface = player.surface == player.get_personal_transport().surface

    -- If render mode is chart or zoomed in and on the same surface, show both options
    if player.render_mode == defines.render_mode.chart or player.render_mode == defines.render_mode.chart_zoomed_in then
        if is_same_surface then
            -- Show both options: deploy to player and target location
            button_flow.add{
                type = "sprite-button",
                name = "deploy_target",
                sprite = "utility/go_to_arrow",
                tooltip = "Deploy to target location on map",
                style = "tool_button"
            }

            button_flow.add{
                type = "sprite-button",
                name = "deploy_player",
                sprite = "entity/character",
                tooltip = "Deploy to your character's location",
                style = "tool_button"
            }
        else
            -- Only show deploy to player location if not on the same surface
            button_flow.add{
                type = "sprite-button",
                name = "deploy_player",
                sprite = "entity/character",
                tooltip = "Deploy to your character's location",
                style = "tool_button"
            }
        end
    else
        -- Show deploy to player location if not in render mode
        button_flow.add{
            type = "sprite-button",
            name = "deploy_player",
            sprite = "entity/character",
            tooltip = "Deploy to your character's location",
            style = "tool_button"
        }
    end
end

-- Handle player exiting render mode (when they return to controlling the character)
function map_gui.on_player_changed_render_mode(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    -- Check both conditions
    local spidertron_researched = player.force.technologies["spidertron"].researched
    
    if spidertron_researched and not player.surface.name:find("platform") then
        player.set_shortcut_available("orbital-spidertron-deploy", true)
    else
        player.set_shortcut_available("orbital-spidertron-deploy", false)
    end
end


-- Handle GUI click events
function map_gui.on_gui_click(event)
    local element = event.element
    if not element or not element.valid then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    log("[Neural Spider Control] Combined GUI Click Handler triggered for element: " .. element.name)

    -- Close deployment menu button
    if element.name == "close_deployment_menu_btn" then
        if player.gui.screen["spidertron_deployment_frame"] then
            player.gui.screen["spidertron_deployment_frame"].destroy()
        end
        return
    end

    -- Deploy to target location button (map cursor)
    local target_index_str = string.match(element.name, "^deploy_target_(%d+)$")
    if target_index_str then
        local index = tonumber(target_index_str)
        log("[Neural Spider Control] Deploy to target triggered for index: " .. index)

        if index and storage.spidertrons and storage.spidertrons[index] then
            local spidertron = storage.spidertrons[index]

            -- Close the dialog
            if player.gui.screen["spidertron_deployment_frame"] then
                player.gui.screen["spidertron_deployment_frame"].destroy()
            end

            -- Show deployment message
            player.print("Initiating deployment of Spidertron: " .. spidertron.name .. " from orbit to map target")

            -- Deploy the spidertron to the map target
            map_gui.deploy_spidertron(player, spidertron, "target")
        end
        return
    end

    -- Deploy to player location button
    local player_index_str = string.match(element.name, "^deploy_player_(%d+)$")
    if player_index_str then
        local index = tonumber(player_index_str)
        log("[Neural Spider Control] Deploy to player triggered for index: " .. index)

        if index and storage.spidertrons and storage.spidertrons[index] then
            local spidertron = storage.spidertrons[index]

            -- Close the dialog
            if player.gui.screen["spidertron_deployment_frame"] then
                player.gui.screen["spidertron_deployment_frame"].destroy()
            end

            -- Show deployment message
            player.print("Initiating deployment of Spidertron: " .. spidertron.name .. " from orbit to your location. Be careful the pod does not land on your head!")

            -- Deploy the spidertron to the player's location
            map_gui.deploy_spidertron(player, spidertron, "player")
        end
        return
    end

    -- Fallback if no matching handler
    log("[Neural Spider Control] Unhandled GUI element clicked: " .. element.name)
end

-- Deploy a spidertron from orbit
function map_gui.deploy_spidertron(player, spidertron_data, deploy_target)
    -- Get necessary data from the spidertron
    local hub = spidertron_data.hub
    local inv_type = spidertron_data.inv_type
    local inventory_slot = spidertron_data.inventory_slot
    
    -- Verify the hub and inventory are still valid
    if not hub or not hub.valid then
        player.print("Error: Hub is no longer valid")
        return
    end
    
    local inventory = hub.get_inventory(inv_type)
    if not inventory then
        player.print("Error: Inventory not found")
        return
    end
    
    local stack = inventory[inventory_slot]
    if not stack or not stack.valid_for_read or stack.name ~= "spidertron" then
        player.print("Error: Spidertron is no longer in the specified slot")
        return
    end
    
    -- Check if deployment target is a platform
    if player.surface.name:find("platform") then
        player.print("Error: Cannot deploy Spidertrons on platforms")
        return
    end
    
    -- Store grid data before removing from inventory
    local grid_data = {}
    local has_grid = false
    
    if stack.grid then
        has_grid = true
        for _, equipment in pairs(stack.grid.equipment) do
            -- Store equipment quality
            local equipment_quality = nil
            local equipment_quality_name = nil
            
            pcall(function()
                if equipment.quality then
                    equipment_quality = equipment.quality
                    equipment_quality_name = equipment.quality.name
                    log("Equipment " .. equipment.name .. " has quality: " .. equipment_quality_name)
                end
            end)
            
            -- Only store basic equipment data and energy
            table.insert(grid_data, {
                name = equipment.name,
                position = {x = equipment.position.x, y = equipment.position.y},
                energy = equipment.energy,
                quality = equipment_quality,
                quality_name = equipment_quality_name
            })
        end
        log("Stored grid data with " .. #grid_data .. " equipment items")
    end
    
    -- Store quality name
    local quality_name = nil
    pcall(function()
        if stack.quality then
            quality_name = stack.quality.name
            log("Deploying spidertron with quality name: " .. quality_name)
        end
    end)
    
    -- Define landing position
    local landing_pos = {x = 0, y = 0}

    local chunk_x = math.floor(landing_pos.x / 32)
    local chunk_y = math.floor(landing_pos.y / 32)

    if not player.surface.is_chunk_generated({x = chunk_x, y = chunk_y}) then
        -- Decide what to do: either generate or abort
        player.print("Target area not yet explored. Mapping landing zone...")
        
        --Generate the chunk
        player.surface.request_to_generate_chunks(landing_pos, 1)
        player.surface.force_generate_chunk_requests()
        
    end
    
    -- Helper function to check if a tile is walkable (non-fluid)
    local function is_walkable_tile(position)
        local tile = player.surface.get_tile(position.x, position.y)
        return tile and not tile.prototype.fluid
    end

    -- Get landing position based on deploy_target
    if deploy_target == "target" and 
       (player.render_mode == defines.render_mode.chart or
        player.render_mode == defines.render_mode.chart_zoomed_in) then
        -- Deploy to map target
        landing_pos.x = player.position.x + math.random(-5, 5)
        landing_pos.y = player.position.y + math.random(-5, 5)
        log("Using map target position: " .. landing_pos.x .. ", " .. landing_pos.y)
    elseif deploy_target == "player" and player.character then
        -- Deploy to player character
        landing_pos.x = player.character.position.x + math.random(-5, 5)
        landing_pos.y = player.character.position.y + math.random(-5, 5)
        log("Using player position: " .. landing_pos.x .. ", " .. landing_pos.y)
    else
        -- Fallback to current position
        if player.character then
            landing_pos.x = player.character.position.x + math.random(-5, 5)
            landing_pos.y = player.character.position.y + math.random(-5, 5)
            log("Fallback to character position: " .. landing_pos.x .. ", " .. landing_pos.y)
        else
            landing_pos.x = player.position.x + math.random(-5, 5)
            landing_pos.y = player.position.y + math.random(-5, 5)
            log("Fallback to cursor position: " .. landing_pos.x .. ", " .. landing_pos.y)
        end
    end

    -- Check surrounding area to find a valid non-fluid (walkable) tile
    local valid_positions = {}
    local radius = 5  -- Check a 5x5 area around the landing position
    for dx = -radius, radius do
        for dy = -radius, radius do
            local check_pos = {x = landing_pos.x + dx, y = landing_pos.y + dy}
            if is_walkable_tile(check_pos) then
                table.insert(valid_positions, check_pos)
            end
        end
    end

    -- If there are valid positions, pick one at random
    if #valid_positions > 0 then
        local random_index = math.random(1, #valid_positions)
        landing_pos = valid_positions[random_index]
        log("Selected valid landing position: " .. landing_pos.x .. ", " .. landing_pos.y)
    else
        -- No valid tiles found, exit
        player.print("Drop pod can't deploy over fluids! Try over land.")
        return
    end

    -- Define the delay before the target appears
    local delay_ticks = 60 * 9  -- 9 seconds delay

    script.on_nth_tick(game.tick + delay_ticks, function(event)
        if not player.valid then return end
    
        local x = landing_pos.x
        local y = landing_pos.y
        local size = 1.5  -- Half-length of the X arms
        local ttl = 60 * 9  -- 9 seconds
    
        -- First diagonal \
        rendering.draw_line{
            color = {r = 1, g = 0.1, b = 0.1, a = 0.6},
            width = 2,
            from = {x = x - size, y = y - size},
            to = {x = x + size, y = y + size},
            surface = player.surface,
            time_to_live = ttl
        }
    
        -- Second diagonal /
        rendering.draw_line{
            color = {r = 1, g = 0.1, b = 0.1, a = 0.6},
            width = 2,
            from = {x = x - size, y = y + size},
            to = {x = x + size, y = y - size},
            surface = player.surface,
            time_to_live = ttl
        }
    end)
    
    -- Store quality itself directly instead of just the name
    local quality = nil
    pcall(function() 
        quality = stack.quality 
        if quality then
            log("Captured actual quality object with name: " .. quality.name)
        end
    end)
    
    -- Remove the spidertron from the hub inventory
    stack.count = stack.count - 1
    
    -- Try to use a cargo pod
    local cargo_pod = nil
    local success, result = pcall(function()
        return hub.create_cargo_pod()
    end)
    
    if success and result and result.valid then
        cargo_pod = result
        
        -- Set cargo pod destination to the player's surface at the random location
        cargo_pod.cargo_pod_destination = {
            type = defines.cargo_destination.surface,
            surface = player.surface,
            position = landing_pos,
            land_at_exact_position = true
        }
        
        -- Set cargo pod origin to the hub
        cargo_pod.cargo_pod_origin = hub
        
        -- Save all the deployment information for when the pod lands
        if not storage.pending_pod_deployments then
            storage.pending_pod_deployments = {}
        end
        
        -- Generate a unique ID for this pod
        local pod_id = player.index .. "_" .. game.tick
        
        -- Save the pod deployment information
        storage.pending_pod_deployments[pod_id] = {
            pod = cargo_pod,
            spidertron_name = spidertron_data.name,
            spidertron_color = spidertron_data.color,
            has_grid = has_grid,
            grid_data = grid_data,
            quality = quality,  -- Store the actual quality object
            quality_name = quality_name,  -- Also store the name as backup
            player = player
        }
        
        return
    end
    
    -- If cargo pod creation fails, notify the player and abort
    player.print("Error: Could not create cargo pod from hub. Deployment aborted.")
end

-- This function handles the cargo pod landing event
function map_gui.on_cargo_pod_finished_descending(event)
    local pod = event.cargo_pod
    if not pod or not pod.valid then
        return
    end
    
    -- Loop through all pending pod deployments to find a match
    if storage.pending_pod_deployments then
        for pod_id, deployment in pairs(storage.pending_pod_deployments) do
            -- If this is our pod
            if deployment.pod == pod then
                -- Get the deployment information
                local player = deployment.player
                local spidertron_name = deployment.spidertron_name
                local spidertron_color = deployment.spidertron_color
                local has_grid = deployment.has_grid
                local grid_data = deployment.grid_data
                
                -- Log quality information
                if deployment.quality then
                    log("Pod landing: Using quality name: " .. deployment.quality.name)
                end
                
                -- Try approach 1: passing quality directly
                local deployed_spidertron = nil
                pcall(function()
                    deployed_spidertron = pod.surface.create_entity({
                        name = "spidertron",
                        position = pod.position,
                        force = player.force,
                        create_build_effect_smoke = true,
                        quality = deployment.quality
                    })
                end)
                
                -- If approach 1 failed, try approach 2: passing quality_name
                if not (deployed_spidertron and deployed_spidertron.valid) then
                    pcall(function()
                        deployed_spidertron = pod.surface.create_entity({
                            name = "spidertron",
                            position = pod.position,
                            force = player.force,
                            create_build_effect_smoke = true,
                            quality_name = deployment.quality_name
                        })
                    end)
                end
                
                -- If both approaches failed, create without quality
                if not (deployed_spidertron and deployed_spidertron.valid) then
                    deployed_spidertron = pod.surface.create_entity({
                        name = "spidertron",
                        position = pod.position,
                        force = player.force,
                        create_build_effect_smoke = true
                    })
                end
                
                -- Check if quality was preserved
                if deployed_spidertron and deployed_spidertron.valid and deployed_spidertron.quality then
                    log("Deployed spidertron has quality: " .. deployed_spidertron.quality.name)
                else
                    log("Deployed spidertron has no quality or invalid quality")
                end
                
                -- Apply color if available
                if spidertron_color and deployed_spidertron and deployed_spidertron.valid then
                    deployed_spidertron.color = spidertron_color
                end
                
                -- Apply custom name if available
                if deployed_spidertron and deployed_spidertron.valid and spidertron_name ~= "Spidertron" then
                    -- Try to set entity_label directly with delayed attempt
                    script.on_nth_tick(5, function()
                        if deployed_spidertron and deployed_spidertron.valid then
                            pcall(function()
                                deployed_spidertron.entity_label = spidertron_name
                                log("Set entity_label to: " .. spidertron_name .. " after delay")
                            end)
                        end
                        script.on_nth_tick(5, nil)  -- Clear the handler
                    end)
                end
                
                -- Transfer equipment grid using stored data
                if has_grid and deployed_spidertron and deployed_spidertron.valid and deployed_spidertron.grid then
                    local target_grid = deployed_spidertron.grid
                    for _, equip_data in ipairs(grid_data) do
                        -- Try to create equipment at the exact position first with quality
                        local new_equipment = nil
                        
                        -- First try creating with quality if available
                        if equip_data.quality_name then
                            pcall(function()
                                new_equipment = target_grid.put({
                                    name = equip_data.name,
                                    position = equip_data.position,
                                    quality = equip_data.quality,  -- Try passing quality object
                                    quality_name = equip_data.quality_name  -- Also try with quality_name
                                })
                            end)
                        end
                        
                        -- If that fails, try without quality
                        if not new_equipment then
                            new_equipment = target_grid.put({
                                name = equip_data.name,
                                position = equip_data.position
                            })
                        end
                        
                        -- If that fails, try to put it somewhere else in the grid
                        if not new_equipment then
                            new_equipment = target_grid.put({name = equip_data.name})
                        end
                        
                        -- Set energy level if successful
                        if new_equipment and new_equipment.valid and equip_data.energy then
                            new_equipment.energy = equip_data.energy
                        end
                        
                        -- Log equipment quality
                        if new_equipment and new_equipment.valid and new_equipment.quality then
                            log("Equipment " .. equip_data.name .. " deployed with quality: " .. new_equipment.quality.name)
                        else
                            log("Equipment " .. equip_data.name .. " has no quality or invalid quality")
                        end
                    end
                    log("Transferred equipment grid to deployed spidertron with " .. #grid_data .. " items")
                end
                
                -- Create smoke cloud effect
                for i = 1, 30 do
                    pod.surface.create_trivial_smoke({
                        name = "smoke-train-stop",
                        position = {
                            x = pod.position.x + (math.random() - 0.5) * 4,
                            y = pod.position.y + (math.random() - 0.5) * 4
                        },
                        initial_height = 0.5,
                        max_radius = 2.0,
                        speed = {0, -0.03}
                    })
                end
                
                -- Remove this deployment from storage
                storage.pending_pod_deployments[pod_id] = nil
                return
            end
        end
    end
end

-- Handle shortcut button clicks
function map_gui.on_lua_shortcut(event)
    if event.prototype_name == "orbital-spidertron-deploy" then
        local player = game.get_player(event.player_index)
        if not player then return end
        
        -- Find orbital spidertrons
        local spidertrons = map_gui.find_orbital_spidertrons(player.surface)
        if #spidertrons == 0 then
            player.print("No spidertrons are available in orbit above this planet.")
            return
        end
        
        -- Show selection dialog with appropriate deployment options
        map_gui.show_deployment_menu(player, spidertrons)
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
    -- First check if the technology is researched
    local spidertron_researched = player.force.technologies["spidertron"].researched
    
    -- Only enable if researched AND not on a platform
    if spidertron_researched and not player.surface.name:find("platform") then
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
                log("Cleaned up " .. #stale_ids .. " stale pod deployment records")
            end
        end
    end)
end

return map_gui