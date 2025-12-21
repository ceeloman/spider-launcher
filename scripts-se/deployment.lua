-- scripts-se/deployment.lua
-- Space Exploration version - uses zone checking instead of platform checking

local deployment = {}

-- Find first available planet from the pool
local function get_available_planet()
    for i = 1, 40 do
        local planet = game.planets["ovd-se-planet-" .. i]
        if planet and not planet.surface then
            return planet
        end
    end
    return nil
end

-- Helper function to check if a zone type is a space type (where deployment is not allowed)
local function is_space_zone_type(zone_type)
    return zone_type == "orbit" or zone_type == "asteroid-belt" or zone_type == "asteroid-field"
end

-- Helper function to check if player is on a space surface (where deployment is not allowed)
local function is_on_space_surface(surface)
    if not surface or not remote.interfaces["space-exploration"] then
        return false
    end
    local zone = remote.call("space-exploration", "get_zone_from_surface_index", {surface_index = surface.index})
    if zone then
        return is_space_zone_type(zone.type)
    end
    return false
end

-- Deploy a spider vehicle from orbit with optional extra items
function deployment.deploy_spider_vehicle(player, vehicle_data, deploy_target, extras)
    -- Get necessary data from the vehicle
    local hub = vehicle_data.hub
    local inv_type = vehicle_data.inv_type
    local inventory_slot = vehicle_data.inventory_slot
    local vehicle_item_name = vehicle_data.vehicle_name
    local entity_name = vehicle_data.entity_name
    
    -- Verify the hub and inventory are still valid
    if not hub or not hub.valid then
        return
    end
    
    local inventory = hub.get_inventory(inv_type)
    if not inventory then
        return
    end
    
    local stack = inventory[inventory_slot]
    if not stack or not stack.valid_for_read or stack.name ~= vehicle_item_name then
        return
    end
    
    -- In deploy_spider_vehicle, check if departure surface (hub surface) needs planet
    -- The departure surface is where the cargo pod launches from, not the target surface
    if not hub.surface.planet then
        local available_planet = get_available_planet()
        if available_planet then
            available_planet.associate_surface(hub.surface)
        else
            -- No available planets - log error and abort
            -- log("[OVD Deployment] ERROR: No available planets found! Cannot deploy from surface " .. hub.surface.name .. " (index: " .. hub.surface.index .. ") - departure surface must be linked to a planet. This should have been done when the bay was placed.")
            return
        end
    end
    
    -- SE-SPECIFIC: Validate that deployment target is valid based on hub's location
    -- If hub is on an orbit/asteroid-belt/asteroid-field, can only deploy to:
    -- 1. The same surface (same orbit)
    -- 2. The parent planet/moon of that orbit
    local hub_zone = nil
    local player_zone = nil
    
    if remote.interfaces["space-exploration"] then
        hub_zone = remote.call("space-exploration", "get_zone_from_surface_index", {surface_index = hub.surface.index})
        player_zone = remote.call("space-exploration", "get_zone_from_surface_index", {surface_index = player.surface.index})
    end
    
    -- Debug logging
    -- player.print("[OVD Deployment] Hub surface: " .. hub.surface.name .. " (index: " .. hub.surface.index .. ")")
    -- player.print("[OVD Deployment] Player surface: " .. player.surface.name .. " (index: " .. player.surface.index .. ")")
    
    if hub_zone then
        -- player.print("[OVD Deployment] Hub zone: " .. (hub_zone.name or "nil") .. " (type: " .. (hub_zone.type or "nil") .. ")")
        if hub_zone.parent then
            -- player.print("[OVD Deployment] Hub zone parent: " .. (hub_zone.parent.name or "nil"))
        else
            -- player.print("[OVD Deployment] Hub zone parent: nil")
        end
    else
        -- player.print("[OVD Deployment] Hub zone: nil")
    end
    
    if player_zone then
        -- player.print("[OVD Deployment] Player zone: " .. (player_zone.name or "nil") .. " (type: " .. (player_zone.type or "nil") .. ")")
    else
        -- player.print("[OVD Deployment] Player zone: nil")
    end
    
    -- If hub is on a space zone (orbit, asteroid-belt, asteroid-field), validate deployment target
    if hub_zone and is_space_zone_type(hub_zone.type) then
        local deployment_allowed = false
        
        -- Allow if deploying to the same surface (same orbit)
        if player.surface == hub.surface then
            deployment_allowed = true
            -- player.print("[OVD Deployment] Allowed: Same surface deployment")
        -- Allow if deploying to the parent planet/moon of the hub's orbit
        elseif hub_zone.parent and player_zone then
            -- player.print("[OVD Deployment] Checking parent match: hub parent = " .. (hub_zone.parent.name or "nil") .. ", player zone = " .. (player_zone.name or "nil"))
            -- Check if player is on the parent planet/moon
            if player_zone.name == hub_zone.parent.name then
                deployment_allowed = true
                -- player.print("[OVD Deployment] Allowed: Player is on parent planet/moon")
            else
                -- player.print("[OVD Deployment] Blocked: Player zone name doesn't match hub parent")
            end
        -- Fallback: If parent is nil, try name-based matching (e.g., "Nauvis Orbit" -> "Nauvis")
        elseif not hub_zone.parent and player_zone and (player_zone.type == "planet" or player_zone.type == "moon") then
            -- Extract planet name from orbit name (e.g., "Nauvis Orbit" -> "Nauvis")
            local orbit_name = hub_zone.name or hub.surface.name
            local expected_planet_name = orbit_name:gsub("%s+Orbit$", ""):gsub("%s+Asteroid%-Belt$", ""):gsub("%s+Asteroid%-Field$", "")
            
            -- player.print("[OVD Deployment] Fallback: Checking name match - orbit: " .. orbit_name .. ", expected planet: " .. expected_planet_name .. ", player zone: " .. (player_zone.name or "nil"))
            
            if player_zone.name == expected_planet_name then
                deployment_allowed = true
                -- player.print("[OVD Deployment] Allowed: Name-based match (fallback)")
            else
                -- player.print("[OVD Deployment] Blocked: Name-based match failed")
            end
        else
            if not hub_zone.parent then
                -- player.print("[OVD Deployment] Blocked: Hub zone has no parent and name fallback failed")
            end
            if not player_zone then
                -- player.print("[OVD Deployment] Blocked: Player zone is nil")
            end
        end
        
        -- Block deployment if not allowed
        if not deployment_allowed then
            -- player.print("[OVD Deployment] Deployment BLOCKED - returning early")
            return
        end
    else
        if not hub_zone then
            -- player.print("[OVD Deployment] Hub not on space zone - allowing deployment")
        elseif not is_space_zone_type(hub_zone.type) then
            -- player.print("[OVD Deployment] Hub zone type is not space type - allowing deployment")
        end
    end
    
    -- Additional check: If player is on a space surface, hub must be on the same space surface
    local player_is_on_space = is_on_space_surface(player.surface)
    local hub_is_on_space = is_on_space_surface(hub.surface)
    
    if player_is_on_space then
        if not hub_is_on_space then
            -- Player on space but hub on different surface - shouldn't happen, but block it
            return
        end
        -- Both are on space surfaces - check if they're the same surface
        if player.surface ~= hub.surface then
            -- Different space surfaces - block deployment
            return
        end
    end
    
    -- If extras are requested, verify they're available
    if extras and #extras > 0 then
        -- Check if the hub has the requested extra items with correct qualities
        local extras_available = true
        local unavailable_items = {}
        
        -- Only use the chest inventory to avoid duplicates
        local hub_inv = hub.get_inventory(defines.inventory.chest)
        if not hub_inv then
            return
        end
        
        -- First count how many of each item+quality we need
        local needed_items = {}
        for _, extra in ipairs(extras) do
            local key = extra.name .. ":" .. (extra.quality or "Normal")
            needed_items[key] = (needed_items[key] or 0) + extra.count
        end
        
        -- Then scan inventory to find requested items with matching qualities
        local found_items = {}
        for i = 1, #hub_inv do
            local stack = hub_inv[i]
            if stack.valid_for_read then
                for key, needed in pairs(needed_items) do
                    local item_name, quality = key:match("(.+):(.+)")
                    
                    if stack.name == item_name then
                        local stack_quality = "Normal"
                        if stack.quality then
                            stack_quality = stack.quality.name
                        end
                        
                        if stack_quality == quality then
                            found_items[key] = (found_items[key] or 0) + stack.count
                        end
                    end
                end
            end
        end
        
        -- Check if we found enough of each item+quality
        for key, needed in pairs(needed_items) do
            local found = found_items[key] or 0
            local item_name, quality = key:match("(.+):(.+)")
            
            if found < needed then
                extras_available = false
                table.insert(unavailable_items, {
                    name = item_name,
                    quality = quality,
                    requested = needed,
                    available = found
                })
            end
        end
        
        -- If items are unavailable, notify the player
        if not extras_available then
            return
        end
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
            
            if equipment.quality then
                equipment_quality = equipment.quality
                equipment_quality_name = equipment.quality.name
            end
            
            -- Only store basic equipment data and energy
            table.insert(grid_data, {
                name = equipment.name,
                position = {x = equipment.position.x, y = equipment.position.y},
                energy = equipment.energy,
                quality = equipment_quality,
                quality_name = equipment_quality_name
            })
        end
    end
    
    -- Store quality name
    local quality_name = nil
    if stack.quality then
        quality_name = stack.quality.name
    end
    
    -- Define landing position
    local landing_pos = {x = 0, y = 0}

    local chunk_x = math.floor(landing_pos.x / 32)
    local chunk_y = math.floor(landing_pos.y / 32)

    if not player.surface.is_chunk_generated({x = chunk_x, y = chunk_y}) then
        -- Generate the chunk
        player.surface.request_to_generate_chunks(landing_pos, 1)
        player.surface.force_generate_chunk_requests()
    end
    
    -- Helper function to check if a tile is walkable (non-fluid)
    local function is_walkable_tile(position)
        local tile = player.surface.get_tile(position.x, position.y)
        return tile and tile.valid and not tile.prototype.fluid
    end

    -- Get landing position based on deploy_target
    if deploy_target == "target" and 
       (player.render_mode == defines.render_mode.chart or
        player.render_mode == defines.render_mode.chart_zoomed_in) then
        -- Deploy to map target
        landing_pos.x = player.position.x + math.random(-5, 5)
        landing_pos.y = player.position.y + math.random(-5, 5)
    elseif deploy_target == "player" and player.character then
        -- Deploy to player character
        landing_pos.x = player.character.position.x + math.random(-5, 5)
        landing_pos.y = player.character.position.y + math.random(-5, 5)
    else
        -- Fallback to current position
        if player.character then
            landing_pos.x = player.character.position.x + math.random(-5, 5)
            landing_pos.y = player.character.position.y + math.random(-5, 5)
        else
            landing_pos.x = player.position.x + math.random(-5, 5)
            landing_pos.y = player.position.y + math.random(-5, 5)
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
    else
        -- No valid tiles found, exit
        return
    end

 -- Define the delay before the target appears
-- local delay_ticks = 60 * 9  -- 9 seconds delay
-- local starting_tick = game.tick

-- Wait for 9 seconds before starting the light sequence
-- local sequence_start = starting_tick + delay_ticks  -- This is when the sequence begins
-- local total_animation_ticks = 60 * 8.5  -- 8.5 seconds total animation duration
-- local grow_duration_ticks = 60 * 7  -- 7 seconds grow duration
-- local shrink_duration_ticks = total_animation_ticks - grow_duration_ticks  -- 1.5 seconds for shrinking

-- Grow phase - gradually increase size over 7 seconds
-- High frequency animation with smooth steps
-- for i = 0, 84 do  -- 85 steps over 7 seconds (5 ticks between steps)
--     script.on_nth_tick(sequence_start + (i * 5), function(event)
--         if not player.valid then return end
--         
--         -- Size grows during first phase - from 0.3 to 1.5
--         local progress = i / 84  -- Normalized progress (0 to 1)
--         local scale_factor = 0.3 + (progress * 1.2)  -- Grow from 0.3 to 1.5
--         local intensity_factor = 0.3 + (progress * 0.4)  -- Grow intensity from 0.3 to 0.7
--         
--         -- Draw dark background circle only during daytime
--         if player.surface.darkness < 0.3 then
--             rendering.draw_sprite{
--                 sprite = "utility/entity_info_dark_background",
--                 x_scale = scale_factor * 1.2,
--                 y_scale = scale_factor * 1.2,
--                 tint = {r = 1, g = 1, b = 1, a = 0.7},
--                 render_layer = "ground-patch",
--                 target = {x = landing_pos.x, y = landing_pos.y},
--                 surface = player.surface,
--                 time_to_live = 15
--             }
--         end
--         
--         -- Always add light effects since Vulcanus is dark
--         rendering.draw_light{
--             sprite = "utility/light_small",
--             scale = scale_factor,
--             intensity = intensity_factor,
--             minimum_darkness = 0,
--             color = {r = 1, g = 0.1, b = 0.1},
--             target = {x = landing_pos.x, y = landing_pos.y},
--             surface = player.surface,
--             time_to_live = 15
--         }
--         
--         -- Outer glow light
--         rendering.draw_light{
--             sprite = "utility/light_small",
--             scale = scale_factor * 1.3,
--             intensity = intensity_factor * 0.7,
--             minimum_darkness = 0,
--             color = {r = 1, g = 0.3, b = 0.1},
--             target = {x = landing_pos.x, y = landing_pos.y},
--             surface = player.surface,
--             time_to_live = 15
--         }
--     end)
-- end

-- Shrinking phase - starts 7 seconds after the sequence begins
-- local shrink_start = sequence_start + grow_duration_ticks

-- Shrink phase - sharper decrease in size over 1.5 seconds
-- for i = 0, 18 do  -- 19 steps over 1.5 seconds (5 ticks between steps)
--     script.on_nth_tick(shrink_start + (i * 5), function(event)
--         if not player.valid then return end
--         
--         -- Sharper size reduction - from 1.5 down to 0.3
--         local progress = i / 18  -- Normalized progress (0 to 1)
--         local scale_factor = 1.5 - (progress * 1.2)  -- Shrink from 1.5 to 0.3
--         -- Intensity decreases as we near the end
--         local intensity_factor = 0.7 - (progress * 0.4)  -- Decrease from 0.7 to 0.3
--         
--         -- Draw dark background only during daytime
--         if player.surface.darkness < 0.3 then
--             rendering.draw_sprite{
--                 sprite = "utility/entity_info_dark_background",
--                 x_scale = scale_factor * 1.2,
--                 y_scale = scale_factor * 1.2,
--                 tint = {r = 1, g = 1, b = 1, a = 0.7},
--                 render_layer = "ground-patch",
--                 target = {x = landing_pos.x, y = landing_pos.y},
--                 surface = player.surface,
--                 time_to_live = 15
--             }
--         end
--         
--         -- Always add light effects
--         rendering.draw_light{
--             sprite = "utility/light_small",
--             scale = scale_factor,
--             intensity = intensity_factor,
--             minimum_darkness = 0,
--             color = {r = 1, g = 0.1, b = 0.1},
--             target = {x = landing_pos.x, y = landing_pos.y},
--             surface = player.surface,
--             time_to_live = 15
--         }
--         
--         -- Outer glow
--         rendering.draw_light{
--             sprite = "utility/light_small",
--             scale = scale_factor * 1.3,
--             intensity = intensity_factor * 0.8,
--             minimum_darkness = 0,
--             color = {r = 1, g = 0.3, b = 0.1},
--             target = {x = landing_pos.x, y = landing_pos.y},
--             surface = player.surface,
--             time_to_live = 15
--         }
--     end)
-- end
    
    -- Store quality itself directly instead of just the name
    local quality = nil
    if stack.quality then
        quality = stack.quality
    end
    
    -- Remove the vehicle from the hub inventory
    stack.count = stack.count - 1
    
    -- If extras were requested, collect them with their qualities preserved
    local collected_extras = {}
    if extras and #extras > 0 then
        -- Use chest inventory since that's where we found the items
        local hub_inv = hub.get_inventory(defines.inventory.chest)
        if hub_inv then
            -- Organize extras by name and quality for easier searching
            local extras_by_key = {}
            for _, extra in ipairs(extras) do
                local key = extra.name .. ":" .. (extra.quality or "Normal")
                if not extras_by_key[key] then
                    extras_by_key[key] = {
                        name = extra.name,
                        quality = extra.quality or "Normal",
                        count = 0
                    }
                end
                extras_by_key[key].count = extras_by_key[key].count + extra.count
            end
            
            -- Process each stack in the inventory
            for i = 1, #hub_inv do
                local stack = hub_inv[i]
                if stack and stack.valid_for_read then
                    -- Get the quality of this stack
                    local stack_quality = "Normal"
                    if stack.quality then
                        stack_quality = stack.quality.name
                    end
                    
                    -- Check if this matches any requested extras
                    local key = stack.name .. ":" .. stack_quality
                    if extras_by_key[key] and extras_by_key[key].count > 0 then
                        -- Calculate how many to take from this stack
                        local to_take = math.min(stack.count, extras_by_key[key].count)
                        
                        -- Create a copy of this stack to preserve its quality
                        local collected_stack = {
                            name = stack.name,
                            count = to_take,
                            quality = stack_quality
                        }
                        
                        -- Remember we collected this stack
                        table.insert(collected_extras, collected_stack)
                        
                        -- Remove the items from the hub
                        stack.count = stack.count - to_take
                        
                        -- Update how many we still need
                        extras_by_key[key].count = extras_by_key[key].count - to_take
                    end
                end
            end
        end
    end
    
    -- Get the linked cargo-bay entity
    local cargo_bay = nil
    if storage.cargo_bay_links and hub.unit_number then
        cargo_bay = storage.cargo_bay_links[hub.unit_number]
        if cargo_bay and not cargo_bay.valid then
            cargo_bay = nil
        end
    end
    
    -- If not found in storage, try to find it on the surface
    if not cargo_bay then
        local nearby_entities = hub.surface.find_entities_filtered{
            position = hub.position,
            radius = 5,
            name = "ovd-cargo-bay"
        }
        if #nearby_entities > 0 then
            cargo_bay = nearby_entities[1]
            -- Update storage with the found cargo-bay
            if not storage.cargo_bay_links then
                storage.cargo_bay_links = {}
            end
            storage.cargo_bay_links[hub.unit_number] = cargo_bay
        end
    end
    
    if not cargo_bay or not cargo_bay.valid then
        return
    end
    
    -- Get the cargo hatch from the cargo-bay entity
    local cargo_hatch = nil
    
    -- Try different methods to access the hatch
    if cargo_bay.cargo_hatches then
        if type(cargo_bay.cargo_hatches) == "table" then
            if #cargo_bay.cargo_hatches > 0 then
                cargo_hatch = cargo_bay.cargo_hatches[1]
            elseif cargo_bay.cargo_hatches[1] then
                cargo_hatch = cargo_bay.cargo_hatches[1]
            end
        end
    end
    
    if not cargo_hatch then
        if cargo_bay.get_cargo_hatches then
            local hatches = cargo_bay.get_cargo_hatches()
            if hatches and type(hatches) == "table" then
                if #hatches > 0 then
                    cargo_hatch = hatches[1]
                elseif hatches[1] then
                    cargo_hatch = hatches[1]
                end
            end
        end
    end
    
    if not cargo_hatch then
        if cargo_bay.cargo_hatch then
            cargo_hatch = cargo_bay.cargo_hatch
        end
    end
    
    if not cargo_hatch or not cargo_hatch.valid then
        return
    end
    
    -- Try to use a cargo pod (create from the cargo hatch, not the cargo-bay)
    local cargo_pod = nil
    if cargo_hatch and cargo_hatch.valid then
        local result = cargo_hatch.create_cargo_pod()
        if result and result.valid then
            cargo_pod = result
        end
    end
    
    if cargo_pod then
        
        -- NEW: Detect same-surface deployment and use surface-switching trick
        local actual_surface = player.surface
        local actual_position = landing_pos
        local is_same_surface = (player.surface == hub.surface)
        local temp_destination_surface = actual_surface
        
        if is_same_surface then
            -- Same surface deployment - temporarily target nauvis to avoid intermezzo
            local nauvis = game.surfaces["nauvis"]
            if nauvis and nauvis ~= actual_surface then
                temp_destination_surface = nauvis
            else
                -- Find any other surface if nauvis is not available
                for _, surface in pairs(game.surfaces) do
                    if surface ~= actual_surface then
                        temp_destination_surface = surface
                        break
                    end
                end
            end
        end
        
        -- Set cargo pod destination (use temp surface if same-surface deployment)
        cargo_pod.cargo_pod_destination = {
            type = defines.cargo_destination.surface,
            surface = temp_destination_surface,
            position = actual_position,
            land_at_exact_position = true
        }
        
        
        --game.print("[OVD] Cargo pod destination set successfully")
        
        -- -- Set cargo pod origin to the cargo hatch (or cargo-bay as fallback)
        -- if cargo_hatch and cargo_hatch.owner then
        --     cargo_pod.cargo_pod_origin = cargo_hatch.owner
        -- elseif cargo_hatch then
        --     cargo_pod.cargo_pod_origin = cargo_hatch
        -- elseif cargo_bay then
        --     cargo_pod.cargo_pod_origin = cargo_bay
        -- end
        
        -- Save all the deployment information for when the pod lands
        if not storage.pending_pod_deployments then
            storage.pending_pod_deployments = {}
        end
        
        -- Generate a unique ID for this pod
        local pod_id = player.index .. "_" .. game.tick
        
        -- Save the pod deployment information
        storage.pending_pod_deployments[pod_id] = {
            pod = cargo_pod,
            pod_unit_number = cargo_pod.unit_number,
            vehicle_name = vehicle_data.name,
            vehicle_color = vehicle_data.color,
            has_grid = has_grid,
            grid_data = grid_data,
            quality = quality,
            quality_name = quality_name,
            player = player,
            entity_name = entity_name,
            item_name = vehicle_item_name,
            extras = collected_extras,
            hub = hub,  -- Store hub for returning overflow items
            -- Same-surface deployment data
            actual_surface = is_same_surface and actual_surface or nil,
            actual_position = is_same_surface and actual_position or nil
        }
        
        -- If this is same-surface deployment, we'll fix the destination after finished ascending
        -- The destination will be changed in the on_cargo_pod_finished_ascending event handler (see control.lua)
        if needs_destination_fix then
            --game.print("[OVD] Pod marked for destination fix after ascending (pod_id: " .. pod_id .. ")")
            --game.print("[OVD] Original destination will be: " .. original_destination_surface.name .. " at (" .. landing_pos.x .. ", " .. landing_pos.y .. ")")
        end
        
        return
    end
    
    -- If cargo pod creation fails, notify the player and abort
end

-- Helper function to return overflow items to hub inventory
local function return_items_to_hub(hub, item_name, count, quality)
    if not hub or not hub.valid or count <= 0 then
        return
    end
    
    local hub_inv = hub.get_inventory(defines.inventory.chest)
    if not hub_inv then
        return
    end
    
    local insert_data = {
        name = item_name,
        count = count
    }
    
    -- Add quality if it's a valid quality object, not a string
    if quality and type(quality) == "table" then
        insert_data.quality = quality
    elseif quality and type(quality) == "string" then
        -- Try to find quality prototype by name
        if prototypes.quality and prototypes.quality[quality] then
            insert_data.quality = prototypes.quality[quality]
        end
    end
    
    local inserted = hub_inv.insert(insert_data)
    -- If hub is also full, items will be lost, but at least we tried
    return inserted
end

-- Handle cargo pod landing
function deployment.on_cargo_pod_finished_descending(event)
    local pod = event.cargo_pod
    if not pod or not pod.valid then
        return
    end
    
    -- Get hub from deployment data (preferred) or cargo pod origin (fallback)
    local hub = nil
    
    -- Loop through all pending pod deployments to find a match
    if storage.pending_pod_deployments then
        for pod_id, deployment_data in pairs(storage.pending_pod_deployments) do
            -- Try matching by unit_number first (more reliable than object reference)
            local matches = false
            if deployment_data.pod_unit_number and pod.unit_number then
                matches = (deployment_data.pod_unit_number == pod.unit_number)
            else
                -- Fallback to object reference matching
                matches = (deployment_data.pod == pod)
            end
            
            if matches then

                -- Get the deployment information
                local player = deployment_data.player
                local vehicle_name = deployment_data.vehicle_name
                local vehicle_color = deployment_data.vehicle_color
                local has_grid = deployment_data.has_grid
                local grid_data = deployment_data.grid_data
                local entity_name = deployment_data.entity_name
                local extras = deployment_data.extras or {}
                
                -- Get hub from deployment data (stored when pod was created)
                if deployment_data.hub and deployment_data.hub.valid then
                    hub = deployment_data.hub
                end
                -- Note: If hub is not available, overflow items cannot be returned
                -- This is acceptable as the primary goal is to prevent item deletion
                
                -- Try approach 1: passing quality directly
                local deployed_vehicle = nil
                if deployment_data.quality then
                    deployed_vehicle = pod.surface.create_entity({
                        name = entity_name,
                        position = pod.position,
                        force = player.force,
                        create_build_effect_smoke = true,
                        quality = deployment_data.quality
                    })
                end

                -- If approach 1 failed, try approach 2: without quality
                if not (deployed_vehicle and deployed_vehicle.valid) then
                    deployed_vehicle = pod.surface.create_entity({
                        name = entity_name,
                        position = pod.position,
                        force = player.force,
                        create_build_effect_smoke = true
                    })
                end

                -- If both approaches failed, create without quality
                if not (deployed_vehicle and deployed_vehicle.valid) then
                    deployed_vehicle = pod.surface.create_entity({
                        name = entity_name,
                        position = pod.position,
                        force = player.force,
                        create_build_effect_smoke = true
                    })
                end
                
                -- Apply color if available
                if vehicle_color and deployed_vehicle and deployed_vehicle.valid then
                    deployed_vehicle.color = vehicle_color
                end
                
                -- Apply custom name if available
                if deployed_vehicle and deployed_vehicle.valid and vehicle_name ~= entity_name:gsub("^%l", string.upper) then
                    -- Try to set entity_label directly with delayed attempt
                    script.on_nth_tick(5, function()
                        if deployed_vehicle and deployed_vehicle.valid and vehicle_name then
                            deployed_vehicle.entity_label = vehicle_name
                        end
                        script.on_nth_tick(5, nil)  -- Clear the handler
                    end)
                end
                
                -- Transfer equipment grid using stored data
                if has_grid and deployed_vehicle and deployed_vehicle.valid and deployed_vehicle.grid then
                    local target_grid = deployed_vehicle.grid
                    for _, equip_data in ipairs(grid_data) do
                        -- Try to create equipment at the exact position first with quality
                        local new_equipment = nil
                        
                        -- First try creating with quality if available
                        if equip_data.quality_name and equip_data.quality then
                            new_equipment = target_grid.put({
                                name = equip_data.name,
                                position = equip_data.position,
                                quality = equip_data.quality
                            })
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
                    end
                end
                
                -- Provide fuel if the vehicle has a fuel inventory
                if deployed_vehicle and deployed_vehicle.valid then
                    local fuel_inventory = deployed_vehicle.get_fuel_inventory()
                    if fuel_inventory then
                        -- Check for fuel in extras and prioritize highest fuel value
                        local highest_fuel_value = 0
                        local best_fuel_item = nil
                        local fuel_extras = {}
                        
                        for _, extra in ipairs(extras) do
                            local item = prototypes.item[extra.name]
                            if item and item.fuel_value and item.fuel_category == "chemical" then
                                table.insert(fuel_extras, extra)
                                if item.fuel_value > highest_fuel_value then
                                    highest_fuel_value = item.fuel_value
                                    best_fuel_item = extra
                                end
                            end
                        end
                        
                        if best_fuel_item then
                            local inserted = fuel_inventory.insert({
                                name = best_fuel_item.name,
                                count = best_fuel_item.count,
                                quality = best_fuel_item.quality
                            })
                            -- Return overflow to hub if not all fuel was inserted
                            if inserted < best_fuel_item.count and hub then
                                local overflow = best_fuel_item.count - inserted
                                return_items_to_hub(hub, best_fuel_item.name, overflow, best_fuel_item.quality)
                            end
                            -- Remove used fuel from extras to avoid double-handling
                            for i, extra in ipairs(extras) do
                                if extra.name == best_fuel_item.name and extra.quality == best_fuel_item.quality then
                                    extras[i].count = extras[i].count - inserted
                                    if extras[i].count <= 0 then
                                        table.remove(extras, i)
                                    end
                                    break
                                end
                            end
                        else
                            -- Fallback to 5 carbon if no fuel provided
                            local inserted = fuel_inventory.insert({name = "carbon", count = 5})
                            -- Return overflow to hub if not all carbon was inserted
                            if inserted < 5 and hub then
                                return_items_to_hub(hub, "carbon", 5 - inserted, nil)
                            end
                        end
                    end
                    
                    -- Place items in the vehicle's inventory if possible
                    local vehicle_inventory = nil
                    vehicle_inventory = deployed_vehicle.get_inventory(defines.inventory.car_trunk)
                    if not vehicle_inventory then
                        vehicle_inventory = deployed_vehicle.get_inventory(defines.inventory.spider_trunk)
                    end
                    if not vehicle_inventory then
                        vehicle_inventory = deployed_vehicle.get_inventory(defines.inventory.chest)
                    end

                    -- Check for ammo inventory (guns)
                    local ammo_inventory = nil
                    ammo_inventory = deployed_vehicle.get_inventory(defines.inventory.car_ammo)
                    if not ammo_inventory then
                        ammo_inventory = deployed_vehicle.get_inventory(defines.inventory.spider_ammo)
                    end

                    -- If we have extras to distribute
                    if #extras > 0 and deployed_vehicle and deployed_vehicle.valid then
                        -- Separate ammo from other extras
                        local ammo_extras = {}
                        local other_extras = {}
                        
                        for _, extra in ipairs(extras) do
                            local is_ammo = false
                            if prototypes.item and prototypes.item[extra.name] then
                                local item_prototype = prototypes.item[extra.name]
                                if item_prototype.type == "ammo" then
                                    is_ammo = true
                                end
                            end
                            
                            if is_ammo and ammo_inventory then
                                table.insert(ammo_extras, extra)
                            else
                                table.insert(other_extras, extra)  -- Includes utilities
                            end
                        end
                        
                        -- Process ammo (simplified version - full version would need get_ammo_damage and find_compatible_slots_by_category)
                        if ammo_inventory and #ammo_extras > 0 then
                            for _, ammo in ipairs(ammo_extras) do
                                local inserted = ammo_inventory.insert({
                                    name = ammo.name,
                                    count = ammo.count,
                                    quality = ammo.quality
                                })
                                local remaining = ammo.count - inserted
                                if remaining > 0 and vehicle_inventory then
                                    local vehicle_inserted = vehicle_inventory.insert({
                                        name = ammo.name,
                                        count = remaining,
                                        quality = ammo.quality
                                    })
                                    -- Return overflow to hub if vehicle inventory is also full
                                    if vehicle_inserted < remaining and hub then
                                        local overflow = remaining - vehicle_inserted
                                        return_items_to_hub(hub, ammo.name, overflow, ammo.quality)
                                    end
                                elseif remaining > 0 and hub then
                                    -- No vehicle inventory available, return all overflow to hub
                                    return_items_to_hub(hub, ammo.name, remaining, ammo.quality)
                                end
                            end
                        end
                        
                        -- Process other extras (including utilities)
                        if #other_extras > 0 and vehicle_inventory then
                            for _, extra in ipairs(other_extras) do
                                local inserted = vehicle_inventory.insert({
                                    name = extra.name,
                                    count = extra.count,
                                    quality = extra.quality
                                })
                                -- Return overflow to hub if not all items were inserted
                                if inserted < extra.count and hub then
                                    local overflow = extra.count - inserted
                                    return_items_to_hub(hub, extra.name, overflow, extra.quality)
                                end
                            end
                        elseif #other_extras > 0 and hub then
                            -- No vehicle inventory available, return all extras to hub
                            for _, extra in ipairs(other_extras) do
                                return_items_to_hub(hub, extra.name, extra.count, extra.quality)
                            end
                        end
                    end
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

return deployment








