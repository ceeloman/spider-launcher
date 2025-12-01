-- scripts-sa/deployment.lua

local deployment = {}

-- Deploy a spider vehicle from orbit with optional extra items
-- Parameters:
--   player: Player entity
--   vehicle_data: Vehicle data table
--   deploy_target: Deployment target ("target" or "player")
--   extras: Optional extras items to deploy
--   defaults: Optional defaults table with equipment_grid and trunk_items
function deployment.deploy_spider_vehicle(player, vehicle_data, deploy_target, extras, defaults)
    -- Get necessary data from the vehicle
    local hub = vehicle_data.hub
    local inv_type = vehicle_data.inv_type
    local inventory_slot = vehicle_data.inventory_slot
    -- Use deploy_item if available (from requirements), otherwise use vehicle_name
    local deploy_item_name = vehicle_data.deploy_item or vehicle_data.vehicle_name
    local vehicle_item_name = vehicle_data.vehicle_name  -- The actual vehicle item to put in pod
    local entity_name = vehicle_data.entity_name
    
    -- Check vehicle requirements if registered (via remote interface to avoid circular dependency)
    if remote.interfaces["spider-launcher"] and remote.interfaces["spider-launcher"]["check_vehicle_requirements"] then
        local req_check, req_result = remote.call("spider-launcher", "check_vehicle_requirements", vehicle_data.vehicle_name, hub)
        if req_check == false then
            player.print("Cannot deploy: " .. tostring(req_result))
            return
        end
    end
    
    -- Verify the hub and inventory are still valid
    if not hub or not hub.valid then
        return
    end
    
    local inventory = hub.get_inventory(inv_type)
    if not inventory then
        return
    end
    
    local stack = inventory[inventory_slot]
    if not stack or not stack.valid_for_read then
        return
    end
    
    if stack.name ~= vehicle_item_name then
        return
    end
    
    -- Check if deployment target is a platform (skip this check for API calls)
    if not vehicle_data.api_target_surface and player.surface.name:find("platform") then
        return
    end
    
    -- If extras are requested, verify they're available (skip check for API calls - items are in pod recipe)
    -- Skip extras availability check if using API (items are built into the pod, not separate)
    if extras and #extras > 0 and not vehicle_data.api_config then
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
                        pcall(function()
                            if stack.quality then
                                stack_quality = stack.quality.name
                            end
                        end)
                        
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
            local message = "Cannot deploy with requested items. Unavailable:"
            player.print(message)
            for _, item in ipairs(unavailable_items) do
                player.print("  - " .. item.name .. " (" .. item.quality .. "): need " .. item.requested .. ", have " .. item.available)
            end
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
            
            pcall(function()
                if equipment.quality then
                    equipment_quality = equipment.quality
                    equipment_quality_name = equipment.quality.name
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
    end
    
    -- Merge defaults equipment_grid into grid_data if provided
    if defaults and defaults.equipment_grid and #defaults.equipment_grid > 0 then
        for _, equip_config in ipairs(defaults.equipment_grid) do
            local count = equip_config.count or 1
            for i = 1, count do
                table.insert(grid_data, {
                    name = equip_config.name,
                    position = nil,  -- Let grid.put find a position
                    energy = equip_config.energy or nil
                })
            end
        end
        has_grid = true  -- Mark as having grid if we added equipment
        -- Ensure grid_data is not empty
        if #grid_data > 0 then
            has_grid = true
        end
    end
    
    -- Store quality name
    local quality_name = nil
    pcall(function()
        if stack.quality then
            quality_name = stack.quality.name
        end
    end)
    
    -- Determine target surface (use API target if available, otherwise player surface)
    local target_surface = vehicle_data.api_target_surface or player.surface
    
    -- Define landing position
    local landing_pos = {x = 0, y = 0}
    
    -- Use API target position if available
    if vehicle_data.api_target_position then
        landing_pos = {x = vehicle_data.api_target_position.x, y = vehicle_data.api_target_position.y}
    else
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
    end

    local chunk_x = math.floor(landing_pos.x / 32)
    local chunk_y = math.floor(landing_pos.y / 32)

    if not target_surface.is_chunk_generated({x = chunk_x, y = chunk_y}) then
        --Generate the chunk
        target_surface.request_to_generate_chunks(landing_pos, 1)
        target_surface.force_generate_chunk_requests()
    end

    -- Helper function to check if a tile is walkable (non-fluid)
    local function is_walkable_tile(position)
        local tile = target_surface.get_tile(position.x, position.y)
        return tile and tile.valid and not tile.prototype.fluid
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
        --player.print("Drop pod can't deploy here! Try over solid ground.")
        return
    end

--[[
 -- Define the delay before the target appears
local delay_ticks = 60 * 9  -- 9 seconds delay
local starting_tick = game.tick

-- Wait for 9 seconds before starting the light sequence
local sequence_start = starting_tick + delay_ticks  -- This is when the sequence begins
local total_animation_ticks = 60 * 8.5  -- 8.5 seconds total animation duration
local grow_duration_ticks = 60 * 7  -- 7 seconds grow duration
local shrink_duration_ticks = total_animation_ticks - grow_duration_ticks  -- 1.5 seconds for shrinking

-- Grow phase - gradually increase size over 7 seconds
-- High frequency animation with smooth steps
for i = 0, 84 do  -- 85 steps over 7 seconds (5 ticks between steps)
    script.on_nth_tick(sequence_start + (i * 5), function(event)
        if not player.valid then return end
        
        -- Size grows during first phase - from 0.3 to 1.5
        local progress = i / 84  -- Normalized progress (0 to 1)
        local scale_factor = 0.3 + (progress * 1.2)  -- Grow from 0.3 to 1.5
        local intensity_factor = 0.3 + (progress * 0.4)  -- Grow intensity from 0.3 to 0.7
        
        -- Draw dark background circle only during daytime
        if target_surface.darkness < 0.3 then
            rendering.draw_sprite{
                sprite = "utility/entity_info_dark_background",
                x_scale = scale_factor * 1.2,
                y_scale = scale_factor * 1.2,
                tint = {r = 1, g = 1, b = 1, a = 0.7},
                render_layer = "ground-patch",
                target = {x = landing_pos.x, y = landing_pos.y},
                surface = target_surface,
                time_to_live = 15
            }
        end
        
        -- Always add light effects since Vulcanus is dark
        rendering.draw_light{
            sprite = "utility/light_small",
            scale = scale_factor,
            intensity = intensity_factor,
            minimum_darkness = 0,
            color = {r = 1, g = 0.1, b = 0.1},
            target = {x = landing_pos.x, y = landing_pos.y},
            surface = target_surface,
            time_to_live = 15
        }
        
        -- Outer glow light
        rendering.draw_light{
            sprite = "utility/light_small",
            scale = scale_factor * 1.3,
            intensity = intensity_factor * 0.7,
            minimum_darkness = 0,
            color = {r = 1, g = 0.3, b = 0.1},
            target = {x = landing_pos.x, y = landing_pos.y},
            surface = target_surface,
            time_to_live = 15
        }
    end)
end

-- Shrinking phase - starts 7 seconds after the sequence begins
local shrink_start = sequence_start + grow_duration_ticks

-- Shrink phase - sharper decrease in size over 1.5 seconds
for i = 0, 18 do  -- 19 steps over 1.5 seconds (5 ticks between steps)
    script.on_nth_tick(shrink_start + (i * 5), function(event)
        if not player.valid then return end
        
        -- Sharper size reduction - from 1.5 down to 0.3
        local progress = i / 18  -- Normalized progress (0 to 1)
        local scale_factor = 1.5 - (progress * 1.2)  -- Shrink from 1.5 to 0.3
        -- Intensity decreases as we near the end
        local intensity_factor = 0.7 - (progress * 0.4)  -- Decrease from 0.7 to 0.3
        
        -- Draw dark background only during daytime
        if target_surface.darkness < 0.3 then
            rendering.draw_sprite{
                sprite = "utility/entity_info_dark_background",
                x_scale = scale_factor * 1.2,
                y_scale = scale_factor * 1.2,
                tint = {r = 1, g = 1, b = 1, a = 0.7},
                render_layer = "ground-patch",
                target = {x = landing_pos.x, y = landing_pos.y},
                surface = target_surface,
                time_to_live = 15
            }
        end
        
        -- Always add light effects
        rendering.draw_light{
            sprite = "utility/light_small",
            scale = scale_factor,
            intensity = intensity_factor,
            minimum_darkness = 0,
            color = {r = 1, g = 0.1, b = 0.1},
            target = {x = landing_pos.x, y = landing_pos.y},
            surface = target_surface,
            time_to_live = 15
        }
        
        -- Outer glow
        rendering.draw_light{
            sprite = "utility/light_small",
            scale = scale_factor * 1.3,
            intensity = intensity_factor * 0.8,
            minimum_darkness = 0,
            color = {r = 1, g = 0.3, b = 0.1},
            target = {x = landing_pos.x, y = landing_pos.y},
            surface = target_surface,
            time_to_live = 15
        }
    end)
end
--]]
    
    -- Store quality itself directly instead of just the name
    local quality = nil
    pcall(function() 
        quality = stack.quality 
        if quality then
        end
    end)
    
    -- Remove the vehicle from the hub inventory
    stack.count = stack.count - 1
    
    -- TFMG compatibility: If deploying scout-o-tron-pod, also remove scout-o-tron
    -- If deploying scout-o-tron, also remove scout-o-tron-pod
    if vehicle_item_name == "scout-o-tron-pod" then
        -- Remove scout-o-tron if it exists
        for i = 1, #inventory do
            local other_stack = inventory[i]
            if other_stack.valid_for_read and other_stack.name == "scout-o-tron" then
                other_stack.count = other_stack.count - 1
                break
            end
        end
    elseif vehicle_item_name == "scout-o-tron" then
        -- Remove scout-o-tron-pod if it exists
        for i = 1, #inventory do
            local other_stack = inventory[i]
            if other_stack.valid_for_read and other_stack.name == "scout-o-tron-pod" then
                other_stack.count = other_stack.count - 1
                break
            end
        end
    end
    
    -- If extras were requested, collect them with their qualities preserved
    -- Skip collection for API calls - items are in pod recipe, not separate inventory items
    local collected_extras = {}
    if extras and #extras > 0 and not vehicle_data.api_config then
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
                        quality = extra.quality,  -- Don't set default, let it be nil if not specified
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
                    pcall(function()
                        if stack.quality then
                            stack_quality = stack.quality.name
                        end
                    end)
                    
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
                        
                        --log("Collected " .. to_take .. " " .. stack_quality .. " " .. stack.name)
                    end
                end
            end
        end
    elseif extras and #extras > 0 and vehicle_data.api_config then
        -- For API calls, use extras directly (they're in pod recipe, not separate items)
        collected_extras = extras
    end
    
    -- Merge defaults trunk_items into collected_extras if provided
    if defaults and defaults.trunk_items and #defaults.trunk_items > 0 then
        for _, item_config in ipairs(defaults.trunk_items) do
            table.insert(collected_extras, {
                name = item_config.name,
                count = item_config.count or 1,
                quality = item_config.quality  -- Don't set default, let it be nil if not specified
            })
        end
    end
    
    -- Try to use a cargo pod
    local cargo_pod = nil
    local success, result = pcall(function()
        return hub.create_cargo_pod()
    end)
    
    if not success or not result or not result.valid then
        return
    end
    
    cargo_pod = result
    
    -- Set cargo pod destination to the target surface at the landing location
    local dest_success, dest_error = pcall(function()
        cargo_pod.cargo_pod_destination = {
            type = defines.cargo_destination.surface,
            surface = target_surface,
            position = landing_pos,
            land_at_exact_position = true
        }
    end)
    
    if not dest_success then
        return
    end
    
    -- Set cargo pod origin to the hub
    local origin_success, origin_error = pcall(function()
        cargo_pod.cargo_pod_origin = hub
    end)
    
    if not origin_success then
        return
    end
    
    -- Save all the deployment information for when the pod lands
    if not storage.pending_pod_deployments then
        storage.pending_pod_deployments = {}
    end
    
    -- Generate a unique ID for this pod
    local pod_id = player.index .. "_" .. game.tick
    
    -- Save the pod deployment information
    storage.pending_pod_deployments[pod_id] = {
        pod = cargo_pod,
        vehicle_name = vehicle_data.name,
        vehicle_color = vehicle_data.color,
        has_grid = has_grid,
        grid_data = grid_data,  -- Includes defaults equipment_grid merged in
        quality = quality,  -- Store the actual quality object
        quality_name = quality_name,  -- Also store the name as backup
        player = player,
        entity_name = entity_name,  -- The actual entity name to create
        item_name = vehicle_item_name,  -- The item name
        extras = collected_extras,  -- Includes defaults trunk_items merged in
        api_config = vehicle_data.api_config  -- Store API config if present
    }
    
    -- Put the vehicle item into the pod's inventory (only if it's not a pod item itself)
    -- If deploy_item is a pod (e.g., scout-o-tron-pod), the pod item becomes the pod, so we don't insert it
    -- Only insert the actual vehicle item (e.g., scout-o-tron) if it's different from the deploy_item
    local item_to_insert = nil
    if deploy_item_name:find("-pod$") then
        -- deploy_item is a pod, so we only insert the vehicle, not the pod
        if vehicle_item_name ~= deploy_item_name then
            item_to_insert = vehicle_item_name
        end
        -- If deploy_item is a pod, don't insert anything (the pod item becomes the pod)
    else
        -- deploy_item is not a pod, insert it normally
        item_to_insert = vehicle_item_name
    end
    
    if item_to_insert then
        local pod_inventory = nil
        
        -- Try to get the cargo pod inventory
        if defines.inventory.cargo_pod then
            pcall(function()
                pod_inventory = cargo_pod.get_inventory(defines.inventory.cargo_pod)
            end)
        end
        
        if not pod_inventory then
            pcall(function()
                pod_inventory = cargo_pod.get_inventory(defines.inventory.chest)
            end)
        end
        
        if pod_inventory then
            pcall(function()
                local insert_data = {
                    name = item_to_insert,
                    count = 1
                }
                if quality and type(quality) == "table" and quality.name then
                    insert_data.quality = quality
                end
                pod_inventory.insert(insert_data)
            end)
        end
    end

end

local function get_ammo_damage(ammo_name)
    player.print(vehicle_display_name .. " launched.")
    local damage_value = 0
    
    pcall(function()
        local ammo_prototype = prototypes.item[ammo_name]
        if ammo_prototype and ammo_prototype.type == "ammo" then
            -- Try to extract damage value from the prototype
            local ammo_data = ammo_prototype.get_ammo_type()
            if ammo_data and ammo_data.action and ammo_data.action.action_delivery and 
               ammo_data.action.action_delivery.target_effects then
                
                -- Sum up all damage effects
                for _, effect in pairs(ammo_data.action.action_delivery.target_effects) do
                    if effect.type == "damage" then
                        damage_value = damage_value + (effect.damage.amount or 0)
                    end
                end
            end
        end
    end)
    
    return damage_value
end

local function find_compatible_slots_by_category(vehicle, ammo_inventory)
    local slots_by_category = {}
    local ammo_slot_count = #ammo_inventory
    
    -- Test each slot with different ammo types to identify compatibility
    local test_ammo = {
        ["bullet"] = "firearm-magazine",
        ["cannon-shell"] = "cannon-shell",
        ["flamethrower"] = "flamethrower-ammo",
        ["rocket"] = "rocket"  -- Added rocket category for spidertrons
    }
    
    -- Test each category against each slot
    for category, test_item in pairs(test_ammo) do
        slots_by_category[category] = {}
        
        for slot_index = 1, ammo_slot_count do
            -- Clear existing slot content first
            pcall(function() ammo_inventory[slot_index].clear() end)
            
            -- Try to insert a test amount
            local success = false
            pcall(function()
                success = ammo_inventory[slot_index].set_stack({
                    name = test_item,
                    count = 1
                })
            end)
            
            if success then
                table.insert(slots_by_category[category], slot_index)
            end
            
            -- Clear the test item
            pcall(function() ammo_inventory[slot_index].clear() end)
        end
    end
    
    return slots_by_category
end

-- Handle cargo pod landing
function deployment.on_cargo_pod_finished_descending(event)
    local pod = event.cargo_pod
    if not pod or not pod.valid then
        return
    end
    
    -- Loop through all pending pod deployments to find a match
    if storage.pending_pod_deployments then
        for pod_id, deployment_data in pairs(storage.pending_pod_deployments) do
            if deployment_data.pod == pod then
                -- Get the deployment information
                local player = deployment_data.player
                local vehicle_name = deployment_data.vehicle_name
                local vehicle_color = deployment_data.vehicle_color
                local has_grid = deployment_data.has_grid
                local grid_data = deployment_data.grid_data
                local entity_name = deployment_data.entity_name
                local extras = deployment_data.extras or {}
                
                -- First, try to extract the vehicle from the pod inventory (original behavior)
                local deployed_vehicle = nil
                local pod_inventory = nil
                
                -- Try to get the pod inventory
                if defines.inventory.cargo_pod then
                    pcall(function()
                        pod_inventory = pod.get_inventory(defines.inventory.cargo_pod)
                    end)
                end
                
                if not pod_inventory then
                    pcall(function()
                        pod_inventory = pod.get_inventory(defines.inventory.chest)
                    end)
                end
                
                -- If pod has inventory, try to extract the vehicle item
                if pod_inventory then
                    for i = 1, #pod_inventory do
                        local stack = pod_inventory[i]
                        if stack.valid_for_read and stack.name == deployment_data.item_name then
                            -- Found the vehicle item in the pod, extract and place it
                            local vehicle_quality = nil
                            pcall(function()
                                if stack.quality then
                                    vehicle_quality = stack.quality
                                end
                            end)
                            
                            -- Create the entity from the item
                            pcall(function()
                                deployed_vehicle = pod.surface.create_entity({
                                    name = entity_name,
                                    position = pod.position,
                                    force = player.force,
                                    create_build_effect_smoke = true,
                                    quality = vehicle_quality or deployment_data.quality
                                })
                            end)
                            
                            -- Remove the item from pod inventory after placing
                            if deployed_vehicle and deployed_vehicle.valid then
                                stack.count = stack.count - 1
                            end
                            break
                        end
                    end
                end
                
                -- If we didn't find the vehicle in the pod, create it from scratch (fallback)
                if not (deployed_vehicle and deployed_vehicle.valid) then
                    pcall(function()
                        deployed_vehicle = pod.surface.create_entity({
                            name = entity_name,
                            position = pod.position,
                            force = player.force,
                            create_build_effect_smoke = true,
                            quality = deployment_data.quality
                        })
                    end)
                    
                    if not (deployed_vehicle and deployed_vehicle.valid) then
                        pcall(function()
                            deployed_vehicle = pod.surface.create_entity({
                                name = entity_name,
                                position = pod.position,
                                force = player.force,
                                create_build_effect_smoke = true,
                                quality_name = deployment_data.quality_name
                            })
                        end)
                    end
                    
                    if not (deployed_vehicle and deployed_vehicle.valid) then
                        pcall(function()
                            deployed_vehicle = pod.surface.create_entity({
                                name = entity_name,
                                position = pod.position,
                                force = player.force,
                                create_build_effect_smoke = true
                            })
                        end)
                    end
                end
                
                -- Apply color if available and entity supports color
                if vehicle_color and deployed_vehicle and deployed_vehicle.valid then
                    -- Check if the entity prototype supports color before applying
                    local entity_prototype = deployed_vehicle.prototype
                    if entity_prototype and entity_prototype.color then
                        local color_success, color_error = pcall(function()
                            deployed_vehicle.color = vehicle_color
                        end)
                        if not color_success then
                        end
                    else
                    end
                end
                
                -- Apply custom name if available
                if deployed_vehicle and deployed_vehicle.valid and vehicle_name ~= entity_name:gsub("^%l", string.upper) then
                    -- Try to set entity_label directly with delayed attempt
                    script.on_nth_tick(5, function()
                        if deployed_vehicle and deployed_vehicle.valid then
                            pcall(function()
                                deployed_vehicle.entity_label = vehicle_name
                            end)
                        end
                        script.on_nth_tick(5, nil)  -- Clear the handler
                    end)
                end
                
                -- Transfer equipment grid using stored data
                -- Check if we have grid_data to apply (either from vehicle or defaults)
                if deployed_vehicle and deployed_vehicle.valid and deployed_vehicle.grid and grid_data and #grid_data > 0 then
                    local target_grid = deployed_vehicle.grid
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
                        
                    end
                end
                
                -- Handle API-provided equipment and items
                if deployment_data.api_config and deployed_vehicle and deployed_vehicle.valid then
                    local api_config = deployment_data.api_config
                    
                    -- Add equipment from config if specified
                    if api_config.equipment_grid and deployed_vehicle.grid then
                        local grid = deployed_vehicle.grid
                        for _, equip_config in ipairs(api_config.equipment_grid) do
                            local count = equip_config.count or 1
                            for i = 1, count do
                                local equip = grid.put({name = equip_config.name})
                                if equip then
                                end
                            end
                        end
                    end
                    
                    -- Add trunk items from config if specified
                    if api_config.trunk_items and vehicle_inventory then
                        for _, item_config in ipairs(api_config.trunk_items) do
                            local inserted = vehicle_inventory.insert({
                                name = item_config.name,
                                count = item_config.count or 1
                            })
                            if inserted > 0 then
                            end
                        end
                    end
                end
                
                -- Show deployment message if entity is scout-o-tron (TFMG compatibility)
                if deployed_vehicle and deployed_vehicle.valid and entity_name == "scout-o-tron" then
                    if player and player.valid then
                        pcall(function()
                            if deployed_vehicle.gps_tag then
                                player.print({"spider-ui.scout-o-tron-deploy-message", deployed_vehicle.gps_tag})
                            end
                        end)
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
                            if inserted > 0 then
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
                            if inserted > 0 then
                            end
                        end
                    end
                    
                    -- Place items in the vehicle's inventory if possible
                    local vehicle_inventory = nil
                    pcall(function() vehicle_inventory = deployed_vehicle.get_inventory(defines.inventory.car_trunk) end)
                    if not vehicle_inventory then
                        pcall(function() vehicle_inventory = deployed_vehicle.get_inventory(defines.inventory.spider_trunk) end)
                    end
                    if not vehicle_inventory then
                        pcall(function() vehicle_inventory = deployed_vehicle.get_inventory(defines.inventory.chest) end)
                    end

                    -- Check for ammo inventory (guns)
                    local ammo_inventory = nil
                    pcall(function() ammo_inventory = deployed_vehicle.get_inventory(defines.inventory.car_ammo) end)
                    if not ammo_inventory then
                        pcall(function() ammo_inventory = deployed_vehicle.get_inventory(defines.inventory.spider_ammo) end)
                    end

                    -- If we have extras to distribute
                    if #extras > 0 and deployed_vehicle and deployed_vehicle.valid then
                        -- Separate ammo from other extras
                        local ammo_extras = {}
                        local other_extras = {}
                        
                        for _, extra in ipairs(extras) do
                            local is_ammo = false
                            pcall(function()
                                local item_prototype = prototypes.item[extra.name]
                                if item_prototype and item_prototype.type == "ammo" then
                                    is_ammo = true
                                end
                            end)
                            
                            if is_ammo and ammo_inventory then
                                table.insert(ammo_extras, extra)
                            else
                                table.insert(other_extras, extra)  -- Includes utilities
                            end
                        end
                        
                        -- Process ammo (unchanged, now includes rockets)
                        if ammo_inventory and #ammo_extras > 0 then
                            local ammo_slot_count = #ammo_inventory
                            --player.print("Vehicle has " .. ammo_slot_count .. " ammo slots")
                            local ammo_by_category = {}
                            for _, extra in ipairs(ammo_extras) do
                                local category = get_ammo_category(extra.name) or "unknown"
                                if not ammo_by_category[category] then
                                    ammo_by_category[category] = {}
                                end
                                local key = extra.name .. "_" .. (extra.quality or "Normal")
                                if not ammo_by_category[category][key] then
                                    ammo_by_category[category][key] = {
                                        name = extra.name,
                                        count = 0,
                                        quality = extra.quality or "Normal"
                                    }
                                end
                                ammo_by_category[category][key].count = ammo_by_category[category][key].count + extra.count
                            end
                            
                            local slots_by_category = find_compatible_slots_by_category(deployed_vehicle, ammo_inventory)
                            for category, slots in pairs(slots_by_category) do
                                --player.print("Category '" .. category .. "' can use slots: " .. table.concat(slots, ", "))
                            end
                            
                            for category, ammo_items in pairs(ammo_by_category) do
                                local ammo_priority = {}
                                for _, data in pairs(ammo_items) do
                                    table.insert(ammo_priority, data)
                                end
                                table.sort(ammo_priority, function(a, b)
                                    local a_damage = get_ammo_damage(a.name)
                                    local b_damage = get_ammo_damage(b.name)
                                    if a.name:find("atomic") then return false end
                                    if b.name:find("atomic") then return true end
                                    if math.abs(a_damage - b_damage) > 1 then
                                        return a_damage > b_damage
                                    end
                                    local a_level = 1
                                    local b_level = 1
                                    pcall(function()
                                        local a_quality_prototype = prototypes.quality[a.quality]
                                        if a_quality_prototype then a_level = a_quality_prototype.level end
                                    end)
                                    pcall(function()
                                        local b_quality_prototype = prototypes.quality[b.quality]
                                        if b_quality_prototype then b_level = b_quality_prototype.level end
                                    end)
                                    return a_level > b_level
                                end)
                                
                                local compatible_slots = slots_by_category[category] or {}
                                if #compatible_slots > 0 and #ammo_priority > 0 then
                                    local priority_ammo = ammo_priority[1]
                                    local ammo_per_slot = math.ceil(priority_ammo.count / #compatible_slots)
                                    local remaining_to_insert = priority_ammo.count
                                    for _, slot_index in ipairs(compatible_slots) do
                                        if remaining_to_insert <= 0 then break end
                                        local to_insert = math.min(ammo_per_slot, remaining_to_insert)
                                        pcall(function() ammo_inventory[slot_index].clear() end)
                                        local success = false
                                        pcall(function()
                                            success = ammo_inventory[slot_index].set_stack({
                                                name = priority_ammo.name,
                                                count = to_insert,
                                                quality = priority_ammo.quality
                                            })
                                        end)
                                        if success then
                                            --player.print("Inserted " .. to_insert .. "x " .. priority_ammo.quality .. " " .. priority_ammo.name .. " into slot " .. slot_index)
                                            remaining_to_insert = remaining_to_insert - to_insert
                                        end
                                    end
                                    if remaining_to_insert > 0 and vehicle_inventory then
                                        local inserted = vehicle_inventory.insert({
                                            name = priority_ammo.name,
                                            count = remaining_to_insert,
                                            quality = priority_ammo.quality
                                        })
                                        if inserted > 0 then
                                            --player.print("Added " .. inserted .. "x " .. priority_ammo.quality .. " " .. priority_ammo.name .. " to vehicle inventory")
                                        end
                                    end
                                    if #ammo_priority > 1 and vehicle_inventory then
                                        for i = 2, #ammo_priority do
                                            local ammo = ammo_priority[i]
                                            local inserted = vehicle_inventory.insert({
                                                name = ammo.name,
                                                count = ammo.count,
                                                quality = ammo.quality
                                            })
                                            if inserted > 0 then
                                                --player.print("Added " .. inserted .. "x " .. ammo.quality .. " " .. ammo.name .. " to vehicle inventory")
                                            end
                                        end
                                    end
                                else
                                    --player.print("No compatible slots found for " .. category .. " ammo, adding to trunk")
                                    for _, ammo in ipairs(ammo_priority) do
                                        if vehicle_inventory then
                                            local inserted = vehicle_inventory.insert({
                                                name = ammo.name,
                                                count = ammo.count,
                                                quality = ammo.quality
                                            })
                                            if inserted > 0 then
                                                --player.print("Added " .. inserted .. "x " .. ammo.quality .. " " .. ammo.name .. " to vehicle inventory")
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        
                        -- Process other extras (including utilities)
                        if #other_extras > 0 and vehicle_inventory then
                            for _, extra in ipairs(other_extras) do
                                local insert_data = {
                                    name = extra.name,
                                    count = extra.count
                                }
                                -- Only add quality if it's a valid quality object, not a string
                                if extra.quality and type(extra.quality) == "table" then
                                    insert_data.quality = extra.quality
                                end
                                local inserted = vehicle_inventory.insert(insert_data)
                                if inserted > 0 then
                                    --player.print("Added " .. inserted .. "x " .. extra.quality .. " " .. extra.name .. " to vehicle inventory")
                                end
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