-- scripts-sa/deployment.lua

local deployment = {}

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
        
        -- First pass: collect ghost equipment and try to replace with real equipment from platform inventory
        local ghost_equipment_list = {}
        for _, equipment in pairs(stack.grid.equipment) do
            local equipment_name = equipment.name
            local is_ghost = false
            local base_equipment_name = nil
            
            -- Check if it's a ghost by prototype type first (most reliable)
            if equipment.prototype and equipment.prototype.type == "equipment-ghost" then
                is_ghost = true
                -- Get the base equipment name from ghost_name property
                if equipment.ghost_name then
                    base_equipment_name = equipment.ghost_name
                else
                    -- Fallback: try stripping suffix (but not for "equipment-ghost")
                    if equipment_name and equipment_name ~= "equipment-ghost" and equipment_name:match("%-ghost$") then
                        base_equipment_name = equipment_name:gsub("%-ghost$", "")
                    end
                end
            -- Check if it's a ghost by name pattern (but not if it's just "equipment-ghost")
            elseif equipment_name and equipment_name:match("%-ghost$") and equipment_name ~= "equipment-ghost" then
                is_ghost = true
                base_equipment_name = equipment_name:gsub("%-ghost$", "")
            -- Check if name is just "equipment-ghost" - need to get base from ghost_name property
            elseif equipment_name == "equipment-ghost" then
                is_ghost = true
                -- Get base name from ghost_name property
                if equipment.ghost_name then
                    base_equipment_name = equipment.ghost_name
                end
            -- Check if name is just "equipment" (likely a ghost from old TFMG)
            elseif equipment_name == "equipment" then
                is_ghost = true
                -- Can't determine base name from generic "equipment", skip it
            end
            
            if is_ghost and equipment.valid and base_equipment_name then
                table.insert(ghost_equipment_list, {
                    position = {x = equipment.position.x, y = equipment.position.y},
                    base_name = base_equipment_name,
                    quality = equipment.quality
                })
            end
        end
        
        -- Try to fill ghost equipment from platform inventory
        if #ghost_equipment_list > 0 then
            local hub_inv = hub.get_inventory(defines.inventory.chest)
            if hub_inv then
                for _, ghost_data in ipairs(ghost_equipment_list) do
                    local found_item = nil
                    local found_quality = nil
                    
                    -- Search inventory for items that place this equipment
                    for i = 1, #hub_inv do
                        local inv_stack = hub_inv[i]
                        if inv_stack and inv_stack.valid_for_read then
                            local item_prototype = prototypes.item[inv_stack.name]
                            if item_prototype and item_prototype.place_as_equipment_result then
                                local place_result = item_prototype.place_as_equipment_result
                                local result_equipment_name = nil
                                
                                -- Extract equipment name from place_result
                                if type(place_result) == "string" then
                                    result_equipment_name = place_result
                                elseif place_result and place_result.name then
                                    result_equipment_name = place_result.name
                                end
                                
                                -- Check if this item places the equipment we need
                                if result_equipment_name == ghost_data.base_name then
                                    -- Check quality match if ghost has quality
                                    local quality_match = true
                                    if ghost_data.quality then
                                        local stack_quality = "Normal"
                                        if inv_stack.quality then
                                            stack_quality = inv_stack.quality.name
                                        end
                                        local ghost_quality_name = "Normal"
                                        if type(ghost_data.quality) == "table" and ghost_data.quality.name then
                                            ghost_quality_name = ghost_data.quality.name
                                        elseif type(ghost_data.quality) == "string" then
                                            ghost_quality_name = ghost_data.quality
                                        end
                                        -- Normalize quality names for comparison (case-insensitive)
                                        stack_quality = string.lower(stack_quality)
                                        ghost_quality_name = string.lower(ghost_quality_name)
                                        quality_match = (stack_quality == ghost_quality_name)
                                    end
                                    
                                    if quality_match then
                                        found_item = inv_stack.name
                                        found_quality = inv_stack.quality
                                        break
                                    end
                                end
                            end
                        end
                    end
                    
                    -- If we found a matching item, add it to grid_data and remove from inventory
                    if found_item then
                        local item_prototype = prototypes.item[found_item]
                        if item_prototype and item_prototype.place_as_equipment_result then
                            local place_result = item_prototype.place_as_equipment_result
                            local equipment_name = nil
                            
                            if type(place_result) == "string" then
                                equipment_name = place_result
                            elseif place_result and place_result.name then
                                equipment_name = place_result.name
                            end
                            
                            if equipment_name then
                                -- Remove one item from inventory
                                for i = 1, #hub_inv do
                                    local inv_stack = hub_inv[i]
                                    if inv_stack and inv_stack.valid_for_read and inv_stack.name == found_item then
                                        local stack_quality = "Normal"
                                        if inv_stack.quality then
                                            stack_quality = inv_stack.quality.name
                                        end
                                        local target_quality = "Normal"
                                        if found_quality then
                                            target_quality = found_quality.name
                                        end
                                        
                                        if stack_quality == target_quality then
                                            inv_stack.count = inv_stack.count - 1
                                            break
                                        end
                                    end
                                end
                                
                                -- Add to grid_data
                                table.insert(grid_data, {
                                    name = equipment_name,
                                    position = {x = ghost_data.position.x, y = ghost_data.position.y},
                                    energy = nil,  -- New equipment starts with full energy
                                    quality = found_quality,
                                    quality_name = found_quality and found_quality.name or nil,
                                    item_fallback_name = found_item
                                })
                            end
                        end
                    end
                end
            end
            
            -- Remove all ghost equipment from the grid (whether replaced or not)
            for _, ghost_data in ipairs(ghost_equipment_list) do
                stack.grid.take({position = ghost_data.position})
            end
        end
        
        -- Second pass: collect real equipment data
        for _, equipment in pairs(stack.grid.equipment) do
            local equipment_name = equipment.name
            
            -- Store equipment quality
            local equipment_quality = nil
            local equipment_quality_name = nil
            
            if equipment.quality then
                equipment_quality = equipment.quality
                equipment_quality_name = equipment.quality.name
            end
            
            -- game.print("[EQUIPMENT DEBUG] Storing grid equipment: name=" .. tostring(equipment_name) .. ", position={" .. equipment.position.x .. ", " .. equipment.position.y .. "}, energy=" .. tostring(equipment.energy))
            
            table.insert(grid_data, {
                name = equipment_name,
                position = {x = equipment.position.x, y = equipment.position.y},
                energy = equipment.energy,
                quality = equipment_quality,
                quality_name = equipment_quality_name
            })
        end
    end

    -- Add equipment items from extras to grid_data
    if extras and #extras > 0 then
        -- game.print("[EQUIPMENT DEBUG] Processing " .. #extras .. " extras items")
        for _, item in ipairs(extras) do
            -- game.print("[EQUIPMENT DEBUG] Checking item: " .. item.name .. ", in_grid: " .. tostring(item.in_grid) .. ", count: " .. tostring(item.count))
            if item.in_grid then
                local count = item.count or 1
                -- game.print("[EQUIPMENT DEBUG] Item " .. item.name .. " has in_grid, processing " .. count .. " copies")
                for i = 1, count do
                    -- item.in_grid is a LuaEquipmentPrototype from place_as_equipment_result
                    -- It has a .name property we can access directly
                    local equipment_name = nil
                    -- game.print("[EQUIPMENT DEBUG] Processing extra item: " .. item.name .. ", in_grid type=" .. type(item.in_grid))
                    if item.in_grid then
                        -- Try to get name property (works for LuaEquipmentPrototype, table, or string)
                        if item.in_grid.name then
                            equipment_name = item.in_grid.name
                            -- game.print("[EQUIPMENT DEBUG] Extracted equipment name from in_grid.name: " .. equipment_name)
                        elseif type(item.in_grid) == "string" then
                            equipment_name = item.in_grid
                            -- game.print("[EQUIPMENT DEBUG] Using in_grid as string: " .. equipment_name)
                        else
                            -- Fallback: get equipment name from item prototype
                            -- game.print("[EQUIPMENT DEBUG] in_grid has no .name property, trying prototype lookup")
                            local item_prototype = prototypes.item[item.name]
                            if item_prototype then
                                -- game.print("[EQUIPMENT DEBUG] Item prototype found: " .. tostring(item_prototype.name) .. ", place_as_equipment_result=" .. tostring(item_prototype.place_as_equipment_result ~= nil))
                                if item_prototype.place_as_equipment_result then
                                    local place_result = item_prototype.place_as_equipment_result
                                    -- game.print("[EQUIPMENT DEBUG] place_as_equipment_result type=" .. type(place_result))
                                    if place_result and place_result.name then
                                        equipment_name = place_result.name
                                        -- game.print("[EQUIPMENT DEBUG] Got equipment name from prototype: " .. equipment_name)
                                    elseif type(place_result) == "string" then
                                        equipment_name = place_result
                                        -- game.print("[EQUIPMENT DEBUG] Got equipment name from prototype string: " .. equipment_name)
                                    end
                                end
                            else
                                -- game.print("[EQUIPMENT DEBUG] No item prototype found for " .. item.name)
                            end
                        end
                    end
                    
                    -- Only add if we have a valid equipment name and it's not a ghost
                    if equipment_name then
                        -- Skip ghost equipment (from old TFMG versions)
                        if equipment_name:match("%-ghost$") or equipment_name == "equipment" then
                            -- game.print("[EQUIPMENT DEBUG] Skipping ghost equipment from extras: " .. equipment_name)
                            goto continue_extra
                        end
                        
                        local quality_str = "nil"
                        if item.quality then
                            if type(item.quality) == "table" and item.quality.name then
                                quality_str = item.quality.name
                            elseif type(item.quality) == "string" then
                                quality_str = item.quality
                            end
                        end
                        -- game.print("[EQUIPMENT DEBUG] Adding to grid_data: equipment=" .. equipment_name .. ", fallback=" .. item.name .. ", quality=" .. quality_str)
                        table.insert(grid_data, {
                            name = equipment_name,
                            position = nil,  -- Let grid.put find a position
                            energy = nil,
                            quality = item.quality,
                            item_fallback_name = item.name
                        })
                    else
                        -- game.print("[EQUIPMENT DEBUG] WARNING: No equipment_name found for item " .. item.name)
                    end
                    
                    ::continue_extra::
                end
                has_grid = true  -- Mark as having grid if we added equipment
            else
                -- game.print("[EQUIPMENT DEBUG] Item " .. item.name .. " does not have in_grid set")
            end
        end
        -- game.print("[EQUIPMENT DEBUG] Total grid_data items: " .. #grid_data .. ", has_grid: " .. tostring(has_grid))
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
    if stack.quality then
        quality = stack.quality
    end
    
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
                    if stack.quality then
                        stack_quality = stack.quality.name
                    end
                    
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
    if hub and hub.valid then
        local result = hub.create_cargo_pod()
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
    
    if prototypes.item and prototypes.item[ammo_name] then
        local ammo_prototype = prototypes.item[ammo_name]
        if ammo_prototype.type == "ammo" and type(ammo_prototype.get_ammo_type) == "function" then
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
    end
    
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
            local slot = ammo_inventory[slot_index]
            if slot then
                -- Clear existing slot content first
                slot.clear()
                
                -- Try to insert a test amount
                local success = slot.set_stack({
                    name = test_item,
                    count = 1
                })
                
                if success then
                    table.insert(slots_by_category[category], slot_index)
                end
                
                -- Clear the test item
                slot.clear()
            end
        end
    end
    
    return slots_by_category
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
    
    -- Get hub from cargo pod origin
    local hub = nil
    if pod.cargo_pod_origin and pod.cargo_pod_origin.valid then
        hub = pod.cargo_pod_origin
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
                    -- log("Pod landing: Using quality name: " .. deployment_data.quality.name)
                end
                
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
                
                -- Check if quality was preserved
                if deployed_vehicle and deployed_vehicle.valid and deployed_vehicle.quality then
                    -- log("Deployed vehicle has quality: " .. deployed_vehicle.quality.name)
                else
                    -- log("Deployed vehicle has no quality or invalid quality")
                end
                
                if deployed_vehicle and deployed_vehicle.valid then
                    script.raise_script_built({entity = deployed_vehicle})
                end
                
                -- Apply color only if the spider has a color set (let game use default if not)
                if vehicle_color and deployed_vehicle and deployed_vehicle.valid then
                    deployed_vehicle.color = vehicle_color
                end
                
                -- Apply custom name if available
                if deployed_vehicle and deployed_vehicle.valid and vehicle_name ~= entity_name:gsub("^%l", string.upper) then
                    -- Try to set entity_label directly with delayed attempt
                    script.on_nth_tick(5, function()
                        if deployed_vehicle and deployed_vehicle.valid and vehicle_name then
                            deployed_vehicle.entity_label = vehicle_name
                            -- log("Set entity_label to: " .. vehicle_name .. " after delay")
                        end
                        script.on_nth_tick(5, nil)  -- Clear the handler
                    end)
                end
                
                --moved this up, so that we have the vehicle inventory available for our equipment grid filling.
                local vehicle_inventory = nil
                vehicle_inventory = deployed_vehicle.get_inventory(defines.inventory.car_trunk)
                if not vehicle_inventory then
                    vehicle_inventory = deployed_vehicle.get_inventory(defines.inventory.spider_trunk)
                end
                if not vehicle_inventory then
                    vehicle_inventory = deployed_vehicle.get_inventory(defines.inventory.chest)
                end
                
                -- Transfer equipment grid using stored data
                -- game.print("[EQUIPMENT DEBUG] Grid placement check: has_grid=" .. tostring(has_grid) .. ", vehicle_valid=" .. tostring(deployed_vehicle and deployed_vehicle.valid) .. ", has_grid_obj=" .. tostring(deployed_vehicle and deployed_vehicle.valid and deployed_vehicle.grid ~= nil))
                if has_grid and deployed_vehicle and deployed_vehicle.valid and deployed_vehicle.grid then
                    local target_grid = deployed_vehicle.grid
                    -- game.print("[EQUIPMENT DEBUG] Attempting to place " .. #grid_data .. " equipment items in grid")
                    for idx, equip_data in ipairs(grid_data) do
                        local pos_str = "nil"
                        if equip_data.position then
                            pos_str = "{" .. equip_data.position.x .. ", " .. equip_data.position.y .. "}"
                        end
                        local quality_str = "nil"
                        if equip_data.quality then
                            if type(equip_data.quality) == "table" and equip_data.quality.name then
                                quality_str = equip_data.quality.name
                            elseif type(equip_data.quality) == "string" then
                                quality_str = equip_data.quality
                            else
                                quality_str = tostring(equip_data.quality)
                            end
                        elseif equip_data.quality_name then
                            quality_str = equip_data.quality_name
                        end
                        local energy_str = equip_data.energy and tostring(equip_data.energy) or "nil"
                        -- game.print("[EQUIPMENT DEBUG] Item " .. idx .. "/" .. #grid_data .. ": name=" .. tostring(equip_data.name) .. ", position=" .. pos_str .. ", quality=" .. quality_str .. ", energy=" .. energy_str .. ", fallback=" .. tostring(equip_data.item_fallback_name))
                        -- Try to create equipment at the exact position first with quality
                        local new_equipment = nil
                        
                        -- First try creating with quality if available
                        if equip_data.quality_name and equip_data.quality then
                            -- game.print("[EQUIPMENT DEBUG] Attempt 1: With quality " .. equip_data.quality_name .. ", position=" .. pos_str)
                            new_equipment = target_grid.put({
                                name = equip_data.name,
                                position = equip_data.position,
                                quality = equip_data.quality
                            })
                            -- if new_equipment then
                            --     local placed_pos = new_equipment.position
                            --     game.print("[EQUIPMENT DEBUG] Successfully placed " .. equip_data.name .. " with quality " .. quality_str .. " at {" .. placed_pos.x .. ", " .. placed_pos.y .. "}")
                            -- else
                            --     game.print("[EQUIPMENT DEBUG] Failed to place " .. equip_data.name .. " with quality " .. quality_str .. " at position " .. pos_str)
                            -- end
                        end
                        
                        -- If that fails, try without quality
                        if not new_equipment then
                            -- game.print("[EQUIPMENT DEBUG] Attempt 2: Without quality, position=" .. pos_str)
                            new_equipment = target_grid.put({
                                name = equip_data.name,
                                position = equip_data.position
                            })
                            -- if new_equipment then
                            --     local placed_pos = new_equipment.position
                            --     game.print("[EQUIPMENT DEBUG] Successfully placed " .. equip_data.name .. " without quality at {" .. placed_pos.x .. ", " .. placed_pos.y .. "}")
                            -- else
                            --     game.print("[EQUIPMENT DEBUG] Failed to place " .. equip_data.name .. " without quality at position " .. pos_str)
                            -- end
                        end
                        
                        -- If that fails, try to put it somewhere else in the grid
                        if not new_equipment then
                            -- game.print("[EQUIPMENT DEBUG] Attempt 3: Anywhere in grid (auto-position)")
                            new_equipment = target_grid.put({name = equip_data.name})
                            -- if new_equipment then
                            --     local placed_pos = new_equipment.position
                            --     game.print("[EQUIPMENT DEBUG] Successfully placed " .. equip_data.name .. " anywhere in grid at {" .. placed_pos.x .. ", " .. placed_pos.y .. "}")
                            -- else
                            --     game.print("[EQUIPMENT DEBUG] Failed to place " .. equip_data.name .. " anywhere in grid")
                            -- end
                        end
                        
                        -- Set energy level if successful
                        if new_equipment and new_equipment.valid and equip_data.energy then
                            new_equipment.energy = equip_data.energy
                            -- game.print("[EQUIPMENT DEBUG] Set energy level for " .. equip_data.name)
                        end

                        if not new_equipment then --if we do fail to put the equipment anywhere, we'll go ahead and drop it in the trunk
                            -- game.print("[EQUIPMENT DEBUG] All grid placement attempts failed for " .. equip_data.name .. ", trying inventory fallback with item: " .. tostring(equip_data.item_fallback_name) .. ", quality: " .. quality_str)
                            if vehicle_inventory then
                                local insert_data = {
                                    name = equip_data.item_fallback_name or equip_data.name,
                                    count = 1
                                }
                                if equip_data.quality then
                                    insert_data.quality = equip_data.quality
                                end
                                local inserted = vehicle_inventory.insert(insert_data)
                                -- if inserted > 0 then
                                --     game.print("[EQUIPMENT DEBUG] Successfully inserted " .. (equip_data.item_fallback_name or equip_data.name) .. " into inventory (count: " .. inserted .. ", quality: " .. quality_str .. ")")
                                -- else
                                --     game.print("[EQUIPMENT DEBUG] FAILED to insert " .. (equip_data.item_fallback_name or equip_data.name) .. " into inventory (quality: " .. quality_str .. ")")
                                -- end
                                -- Return overflow to hub if insertion failed
                                if inserted < 1 and hub then
                                    -- game.print("[EQUIPMENT DEBUG] Returning failed item to hub: " .. (equip_data.item_fallback_name or equip_data.name))
                                    return_items_to_hub(hub, equip_data.item_fallback_name or equip_data.name, 1, equip_data.quality)
                                end
                            else
                                -- game.print("[EQUIPMENT DEBUG] ERROR: vehicle_inventory is nil, cannot insert fallback item " .. (equip_data.item_fallback_name or equip_data.name))
                                -- Return to hub if no vehicle inventory
                                if hub then
                                    -- game.print("[EQUIPMENT DEBUG] Returning item to hub: " .. (equip_data.item_fallback_name or equip_data.name))
                                    return_items_to_hub(hub, equip_data.item_fallback_name or equip_data.name, 1, equip_data.quality)
                                end
                            end
                        end
                        
                        -- Log equipment quality
                        -- if new_equipment and new_equipment.valid then
                        --     if new_equipment.quality then
                        --         local final_pos = new_equipment.position
                        --         game.print("[EQUIPMENT DEBUG] Equipment " .. equip_data.name .. " deployed with quality: " .. new_equipment.quality.name .. " at {" .. final_pos.x .. ", " .. final_pos.y .. "}, energy: " .. tostring(new_equipment.energy))
                        --     else
                        --         local final_pos = new_equipment.position
                        --         game.print("[EQUIPMENT DEBUG] Equipment " .. equip_data.name .. " deployed without quality at {" .. final_pos.x .. ", " .. final_pos.y .. "}, energy: " .. tostring(new_equipment.energy))
                        --     end
                        -- end
                    end
                else
                    -- game.print("[EQUIPMENT DEBUG] Skipping grid placement - conditions not met")
                end
                -- log("Transferred equipment grid to deployed vehicle with " .. #grid_data .. " items")
                
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
                                -- log("Inserted " .. inserted .. "x " .. best_fuel_item.quality .. " " .. best_fuel_item.name .. " into fuel inventory")
                            end
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
                            if inserted > 0 then
                                -- log("Inserted " .. inserted .. " units of carbon into fuel inventory as fallback")
                            end
                            -- Return overflow to hub if not all carbon was inserted
                            if inserted < 5 and hub then
                                return_items_to_hub(hub, "carbon", 5 - inserted, nil)
                            end
                        end
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
                        
                        -- Process ammo (unchanged, now includes rockets)
                        if ammo_inventory and #ammo_extras > 0 then
                            local ammo_slot_count = #ammo_inventory
                            ----player.print("Vehicle has " .. ammo_slot_count .. " ammo slots")
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
                                ----player.print("Category '" .. category .. "' can use slots: " .. table.concat(slots, ", "))
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
                                    if prototypes.quality and a.quality and prototypes.quality[a.quality] then
                                        local a_quality_prototype = prototypes.quality[a.quality]
                                        a_level = a_quality_prototype.level
                                    end
                                    if prototypes.quality and b.quality and prototypes.quality[b.quality] then
                                        local b_quality_prototype = prototypes.quality[b.quality]
                                        b_level = b_quality_prototype.level
                                    end
                                    return a_level > b_level
                                end)
                                
                                local compatible_slots = slots_by_category[category] or {}
                                if #compatible_slots > 0 and #ammo_priority > 0 then
                                    local priority_ammo = ammo_priority[1]
                                    local ammo_per_slot = math.ceil(priority_ammo.count / #compatible_slots)
                                    local remaining_to_insert = priority_ammo.count
                                    for _, slot_index in ipairs(compatible_slots) do
                                        if remaining_to_insert <= 0 then break end
                                        local slot = ammo_inventory[slot_index]
                                        if slot then
                                            local to_insert = math.min(ammo_per_slot, remaining_to_insert)
                                            slot.clear()
                                            local success = slot.set_stack({
                                                name = priority_ammo.name,
                                                count = to_insert,
                                                quality = priority_ammo.quality
                                            })
                                            if success then
                                                ----player.print("Inserted " .. to_insert .. "x " .. priority_ammo.quality .. " " .. priority_ammo.name .. " into slot " .. slot_index)
                                                remaining_to_insert = remaining_to_insert - to_insert
                                            end
                                        end
                                    end
                                    if remaining_to_insert > 0 and vehicle_inventory then
                                        local inserted = vehicle_inventory.insert({
                                            name = priority_ammo.name,
                                            count = remaining_to_insert,
                                            quality = priority_ammo.quality
                                        })
                                        if inserted > 0 then
                                            ----player.print("Added " .. inserted .. "x " .. priority_ammo.quality .. " " .. priority_ammo.name .. " to vehicle inventory")
                                        end
                                        -- Return overflow to hub if not all ammo was inserted
                                        if inserted < remaining_to_insert and hub then
                                            local overflow = remaining_to_insert - inserted
                                            return_items_to_hub(hub, priority_ammo.name, overflow, priority_ammo.quality)
                                        end
                                    elseif remaining_to_insert > 0 and hub then
                                        -- No vehicle inventory available, return all to hub
                                        return_items_to_hub(hub, priority_ammo.name, remaining_to_insert, priority_ammo.quality)
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
                                                ----player.print("Added " .. inserted .. "x " .. ammo.quality .. " " .. ammo.name .. " to vehicle inventory")
                                            end
                                            -- Return overflow to hub if not all ammo was inserted
                                            if inserted < ammo.count and hub then
                                                local overflow = ammo.count - inserted
                                                return_items_to_hub(hub, ammo.name, overflow, ammo.quality)
                                            end
                                        end
                                    end
                                else
                                    ----player.print("No compatible slots found for " .. category .. " ammo, adding to trunk")
                                    for _, ammo in ipairs(ammo_priority) do
                                        if vehicle_inventory then
                                            local inserted = vehicle_inventory.insert({
                                                name = ammo.name,
                                                count = ammo.count,
                                                quality = ammo.quality
                                            })
                                            if inserted > 0 then
                                                ----player.print("Added " .. inserted .. "x " .. ammo.quality .. " " .. ammo.name .. " to vehicle inventory")
                                            end
                                            -- Return overflow to hub if not all ammo was inserted
                                            if inserted < ammo.count and hub then
                                                local overflow = ammo.count - inserted
                                                return_items_to_hub(hub, ammo.name, overflow, ammo.quality)
                                            end
                                        elseif hub then
                                            -- No vehicle inventory available, return all to hub
                                            return_items_to_hub(hub, ammo.name, ammo.count, ammo.quality)
                                        end
                                    end
                                end
                            end
                        end
                        
                        -- Process other extras (including utilities)
                        if #other_extras > 0 and vehicle_inventory then
                            -- game.print("[EQUIPMENT DEBUG] Processing " .. #other_extras .. " other_extras items")
                            for _, extra in ipairs(other_extras) do
                                local insert_data = {
                                    name = extra.name,
                                    count = extra.count
                                }
                                -- Only add quality if it's a valid quality object, not a string
                                if extra.quality and type(extra.quality) == "table" then
                                    insert_data.quality = extra.quality
                                end
                                local item_prototype = prototypes.item[insert_data.name]
                                local is_equipment = item_prototype and item_prototype.place_as_equipment_result ~= nil
                                -- game.print("[EQUIPMENT DEBUG] other_extras item: " .. extra.name .. ", is_equipment=" .. tostring(is_equipment) .. ", count=" .. tostring(extra.count))
                                local inserted = 0
                                if not is_equipment then --if its an equipment grid item, dont insert it into the inventory
                                    inserted = vehicle_inventory.insert(insert_data)
                                    if inserted > 0 then
                                        -- game.print("[EQUIPMENT DEBUG] Inserted " .. inserted .. "x " .. extra.name .. " into inventory")
                                    else
                                        -- game.print("[EQUIPMENT DEBUG] Failed to insert " .. extra.name .. " into inventory")
                                    end
                                    -- Return overflow to hub if not all items were inserted
                                    if inserted < extra.count and hub then
                                        local overflow = extra.count - inserted
                                        return_items_to_hub(hub, extra.name, overflow, extra.quality)
                                    end
                                else
                                    -- game.print("[EQUIPMENT DEBUG] Skipping " .. extra.name .. " - it's equipment (should be in grid)")
                                end
                            end
                        elseif #other_extras > 0 and hub then
                            -- No vehicle inventory available, return all extras to hub
                            for _, extra in ipairs(other_extras) do
                                local item_prototype = prototypes.item[extra.name]
                                local is_equipment = item_prototype and item_prototype.place_as_equipment_result ~= nil
                                if not is_equipment then
                                    return_items_to_hub(hub, extra.name, extra.count, extra.quality)
                                end
                            end
                        else
                            if #other_extras > 0 then
                                -- game.print("[EQUIPMENT DEBUG] WARNING: other_extras has " .. #other_extras .. " items but vehicle_inventory is nil")
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
                
                -- Show deployment message if entity is scout-o-tron (TFMG compatibility)
                if deployed_vehicle and deployed_vehicle.valid and entity_name == "scout-o-tron" then
                    if player and player.valid and deployed_vehicle.gps_tag then
                        player.print({"spider-ui.scout-o-tron-deploy-message", deployed_vehicle.gps_tag})
                    end
                end
                
                -- Remove this deployment from storage
                storage.pending_pod_deployments[pod_id] = nil
                return
            end
        end
    end
end

return deployment
