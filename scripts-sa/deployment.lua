-- scripts-sa/deployment.lua

local deployment = {}

-- Deploy a spider vehicle from orbit with optional extra items
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
    
    -- Check if deployment target is a platform
    if player.surface.name:find("platform") then
        return
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
    
    -- Store quality name
    local quality_name = nil
    pcall(function()
        if stack.quality then
            quality_name = stack.quality.name
        end
    end)
    
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
    local radius = 5
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
    local delay_ticks = 60 * 9
    local starting_tick = game.tick

    -- Wait for 9 seconds before starting the light sequence
    local sequence_start = starting_tick + delay_ticks
    local total_animation_ticks = 60 * 8.5
    local grow_duration_ticks = 60 * 7
    local shrink_duration_ticks = total_animation_ticks - grow_duration_ticks

    -- Grow phase - gradually increase size over 7 seconds
    for i = 0, 84 do
        script.on_nth_tick(sequence_start + (i * 5), function(event)
            if not player.valid then return end
            
            local progress = i / 84
            local scale_factor = 0.3 + (progress * 1.2)
            local intensity_factor = 0.3 + (progress * 0.4)
            
            if player.surface.darkness < 0.3 then
                rendering.draw_sprite{
                    sprite = "utility/entity_info_dark_background",
                    x_scale = scale_factor * 1.2,
                    y_scale = scale_factor * 1.2,
                    tint = {r = 1, g = 1, b = 1, a = 0.7},
                    render_layer = "ground-patch",
                    target = {x = landing_pos.x, y = landing_pos.y},
                    surface = player.surface,
                    time_to_live = 15
                }
            end
            
            rendering.draw_light{
                sprite = "utility/light_small",
                scale = scale_factor,
                intensity = intensity_factor,
                minimum_darkness = 0,
                color = {r = 1, g = 0.1, b = 0.1},
                target = {x = landing_pos.x, y = landing_pos.y},
                surface = player.surface,
                time_to_live = 15
            }
            
            rendering.draw_light{
                sprite = "utility/light_small",
                scale = scale_factor * 1.3,
                intensity = intensity_factor * 0.7,
                minimum_darkness = 0,
                color = {r = 1, g = 0.3, b = 0.1},
                target = {x = landing_pos.x, y = landing_pos.y},
                surface = player.surface,
                time_to_live = 15
            }
        end)
    end

    -- Shrinking phase
    local shrink_start = sequence_start + grow_duration_ticks

    for i = 0, 18 do
        script.on_nth_tick(shrink_start + (i * 5), function(event)
            if not player.valid then return end
            
            local progress = i / 18
            local scale_factor = 1.5 - (progress * 1.2)
            local intensity_factor = 0.7 - (progress * 0.4)
            
            if player.surface.darkness < 0.3 then
                rendering.draw_sprite{
                    sprite = "utility/entity_info_dark_background",
                    x_scale = scale_factor * 1.2,
                    y_scale = scale_factor * 1.2,
                    tint = {r = 1, g = 1, b = 1, a = 0.7},
                    render_layer = "ground-patch",
                    target = {x = landing_pos.x, y = landing_pos.y},
                    surface = player.surface,
                    time_to_live = 15
                }
            end
            
            rendering.draw_light{
                sprite = "utility/light_small",
                scale = scale_factor,
                intensity = intensity_factor,
                minimum_darkness = 0,
                color = {r = 1, g = 0.1, b = 0.1},
                target = {x = landing_pos.x, y = landing_pos.y},
                surface = player.surface,
                time_to_live = 15
            }
            
            rendering.draw_light{
                sprite = "utility/light_small",
                scale = scale_factor * 1.3,
                intensity = intensity_factor * 0.8,
                minimum_darkness = 0,
                color = {r = 1, g = 0.3, b = 0.1},
                target = {x = landing_pos.x, y = landing_pos.y},
                surface = player.surface,
                time_to_live = 15
            }
        end)
    end
    
    -- Store quality itself directly instead of just the name
    local quality = nil
    pcall(function() 
        quality = stack.quality 
    end)
    
    -- Remove the vehicle from the hub inventory
    stack.count = stack.count - 1
    
    -- If extras were requested, collect them with their qualities preserved
    local collected_extras = {}
    if extras and #extras > 0 then
        local hub_inv = hub.get_inventory(defines.inventory.chest)
        if hub_inv then
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
            
            for i = 1, #hub_inv do
                local stack = hub_inv[i]
                if stack and stack.valid_for_read then
                    local stack_quality = "Normal"
                    pcall(function()
                        if stack.quality then
                            stack_quality = stack.quality.name
                        end
                    end)
                    
                    local key = stack.name .. ":" .. stack_quality
                    if extras_by_key[key] and extras_by_key[key].count > 0 then
                        local to_take = math.min(stack.count, extras_by_key[key].count)
                        
                        local collected_stack = {
                            name = stack.name,
                            count = to_take,
                            quality = stack_quality
                        }
                        
                        table.insert(collected_extras, collected_stack)
                        stack.count = stack.count - to_take
                        extras_by_key[key].count = extras_by_key[key].count - to_take
                    end
                end
            end
        end
    end
    
    -- Try to use a cargo pod
    local cargo_pod = nil
    local success, result = pcall(function()
        return hub.create_cargo_pod()
    end)
    
    if success and result and result.valid then
        cargo_pod = result
        
        -- NEW: Detect same-surface deployment and use surface-switching trick
        local actual_surface = player.surface
        local actual_position = landing_pos
        local is_same_surface = (player.surface == hub.surface)
        local temp_destination_surface = actual_surface
        
        if is_same_surface then
            -- Same surface deployment - temporarily target a different surface
            local nauvis = game.surfaces["nauvis"]
            if nauvis and nauvis ~= actual_surface then
                temp_destination_surface = nauvis
            else
                -- Find any other surface
                for _, surface in pairs(game.surfaces) do
                    if surface ~= actual_surface then
                        temp_destination_surface = surface
                        break
                    end
                end
            end
        end
        
        -- Set cargo pod destination
        cargo_pod.cargo_pod_destination = {
            type = defines.cargo_destination.surface,
            surface = temp_destination_surface,
            position = actual_position,
            land_at_exact_position = true
        }
        
        -- Set cargo pod origin to the hub
        cargo_pod.cargo_pod_origin = hub
        
        -- Save all the deployment information
        if not storage.pending_pod_deployments then
            storage.pending_pod_deployments = {}
        end
        
        local pod_id = player.index .. "_" .. game.tick
        
        storage.pending_pod_deployments[pod_id] = {
            pod = cargo_pod,
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
            -- NEW: Store actual destination for same-surface deployments
            actual_surface = is_same_surface and actual_surface or nil,
            actual_position = is_same_surface and actual_position or nil
        }
        
        return
    end
end

local function get_ammo_damage(ammo_name)
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

                if deployment_data.actual_surface and deployment_data.actual_position then
                    pod.teleport(deployment_data.actual_position, deployment_data.actual_surface)
                end
                
                -- Get the deployment information
                local player = deployment_data.player
                local vehicle_name = deployment_data.vehicle_name
                local vehicle_color = deployment_data.vehicle_color
                local has_grid = deployment_data.has_grid
                local grid_data = deployment_data.grid_data
                local entity_name = deployment_data.entity_name
                local extras = deployment_data.extras or {}
                
                -- Log quality information
                if deployment_data.quality then
                    log("Pod landing: Using quality name: " .. deployment_data.quality.name)
                end
                
                -- Try approach 1: passing quality directly
                local deployed_vehicle = nil
                pcall(function()
                    deployed_vehicle = pod.surface.create_entity({
                        name = entity_name,
                        position = pod.position,
                        force = player.force,
                        create_build_effect_smoke = true,
                        quality = deployment_data.quality
                    })
                end)

                -- If approach 1 failed, try approach 2: passing quality_name
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

                -- If both approaches failed, create without quality
                if not (deployed_vehicle and deployed_vehicle.valid) then
                    deployed_vehicle = pod.surface.create_entity({
                        name = entity_name,
                        position = pod.position,
                        force = player.force,
                        create_build_effect_smoke = true
                    })
                end
                
                -- Check if quality was preserved
                if deployed_vehicle and deployed_vehicle.valid and deployed_vehicle.quality then
                    log("Deployed vehicle has quality: " .. deployed_vehicle.quality.name)
                else
                    log("Deployed vehicle has no quality or invalid quality")
                end
                
                -- Apply color if available
                if vehicle_color and deployed_vehicle and deployed_vehicle.valid then
                    deployed_vehicle.color = vehicle_color
                end
                
                -- Apply custom name if available
                if deployed_vehicle and deployed_vehicle.valid and vehicle_name ~= entity_name:gsub("^%l", string.upper) then
                    -- Try to set entity_label directly with delayed attempt
                    script.on_nth_tick(5, function()
                        if deployed_vehicle and deployed_vehicle.valid then
                            pcall(function()
                                deployed_vehicle.entity_label = vehicle_name
                                log("Set entity_label to: " .. vehicle_name .. " after delay")
                            end)
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
                    log("Transferred equipment grid to deployed vehicle with " .. #grid_data .. " items")
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
                                log("Inserted " .. inserted .. "x " .. best_fuel_item.quality .. " " .. best_fuel_item.name .. " into fuel inventory")
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
                                log("Inserted " .. inserted .. " units of carbon into fuel inventory as fallback")
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
                                local inserted = vehicle_inventory.insert({
                                    name = extra.name,
                                    count = extra.count,
                                    quality = extra.quality
                                })
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