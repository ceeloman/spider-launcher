-- scripts/deployment.lua
-- Consolidated version with Space Age and Space Exploration compatibility

-- Bug 1: ammo isnt auto added to the vehicle slots 

local deployment = {}

----------------------------------
---------HELPER FUNCTIONS---------
----------------------------------

-- Helper function to safely get quality name with debug logging
local function get_quality_name(quality_obj, context)
    if not quality_obj then
        return "normal"
    end
    
    -- Quality is userdata with .name property
    if type(quality_obj) == "userdata" and quality_obj.name then
        return quality_obj.name
    end
    
    -- Fallback for string quality names
    if type(quality_obj) == "string" then
        return quality_obj
    end
    
    return "normal"
end

-- Helper function to get equipment name from item prototype
local function get_equipment_name_from_item(item_name)
    local item_prototype = prototypes.item[item_name]
    if not item_prototype then
        return nil
    end
    
    if not item_prototype.place_as_equipment_result then
        return nil
    end
    
    local place_result = item_prototype.place_as_equipment_result
    
    -- place_result is userdata with .name property
    if type(place_result) == "userdata" and place_result.name then
        return place_result.name
    end
    
    -- Fallback for string results
    if type(place_result) == "string" then
        return place_result
    end
    
    return nil
end

-- Helper function to check if an item is equipment
local function is_equipment_item(item_name)
    local item_prototype = prototypes.item[item_name]
    return item_prototype and item_prototype.place_as_equipment_result ~= nil
end

-- Helper function to detect if Space Exploration is active
local function is_space_exploration_active()
    return remote.interfaces["space-exploration"] ~= nil
end

-- Find first available planet from the pool (SE-specific)
local function get_available_planet()
    for i = 1, 40 do
        local planet = game.planets["ovd-se-planet-" .. i]
        if planet and not planet.surface then
            return planet
        end
    end
    return nil
end

-- Helper function to check if a zone type is a space type (SE-specific)
local function is_space_zone_type(zone_type)
    return zone_type == "orbit" or zone_type == "asteroid-belt" or zone_type == "asteroid-field"
end

-- Helper function to check if player is on a space surface (SE-specific)
local function is_on_space_surface(surface)
    if not surface or not is_space_exploration_active() then
        return false
    end
    local zone = remote.call("space-exploration", "get_zone_from_surface_index", {surface_index = surface.index})
    if zone then
        return is_space_zone_type(zone.type)
    end
    return false
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
    
    -- Add quality if it's a valid quality object
    if quality then
        local quality_name = get_quality_name(quality, "return_to_hub")
        if prototypes.quality and prototypes.quality[quality_name] then
            insert_data.quality = prototypes.quality[quality_name]
        end
    end
    
    local inserted = hub_inv.insert(insert_data)
    return inserted
end

-- Helper function to get ammo damage
local function get_ammo_damage(ammo_name)
    local damage_value = 0
    
    if prototypes.item and prototypes.item[ammo_name] then
        local ammo_prototype = prototypes.item[ammo_name]
        if ammo_prototype.type == "ammo" and type(ammo_prototype.get_ammo_type) == "function" then
            local ammo_data = ammo_prototype.get_ammo_type()
            if ammo_data and ammo_data.action and ammo_data.action.action_delivery and 
               ammo_data.action.action_delivery.target_effects then
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

-- Helper function to get ammo category
local function get_ammo_category(ammo_name)
    if prototypes.item and prototypes.item[ammo_name] then
        local ammo_prototype = prototypes.item[ammo_name]
        if ammo_prototype.type == "ammo" and type(ammo_prototype.get_ammo_type) == "function" then
            local ammo_data = ammo_prototype.get_ammo_type()
            if ammo_data and ammo_data.category then
                return ammo_data.category
            end
        end
    end
    return nil
end

-- Helper function to find compatible ammo slots by category
local function find_compatible_slots_by_category(vehicle, ammo_inventory)
    local slots_by_category = {}
    local ammo_slot_count = #ammo_inventory
    
    -- Define test ammo for different categories
    local test_ammo = {
        ["bullet"] = "firearm-magazine",
        ["cannon-shell"] = "cannon-shell",
        ["flamethrower"] = "flamethrower-ammo",
        ["rocket"] = "rocket"
    }
    
    for category, test_item in pairs(test_ammo) do
        slots_by_category[category] = {}
        
        for slot_index = 1, ammo_slot_count do
            local slot = ammo_inventory[slot_index]
            if slot then
                -- Debug print to check each slot
                game.print("Checking slot " .. slot_index .. " for category: " .. category)
                slot.clear()
                local success = slot.set_stack({
                    name = test_item,
                    count = 1
                })
                if success then
                    table.insert(slots_by_category[category], slot_index)
                    -- Debug print to indicate successful insertion
                    game.print("Slot " .. slot_index .. " is compatible for category: " .. category)
                else
                    -- Debug print to indicate failed insertion
                    game.print("Slot " .. slot_index .. " is not compatible for category: " .. category)
                end
                slot.clear()
            end
        end
    end
    
    return slots_by_category
end

----------------------------------
------------DEPLOYMENT------------
----------------------------------

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
    
    -- SE-SPECIFIC: Check if departure surface needs planet association
    if is_space_exploration_active() then
        if not hub.surface.planet then
            local available_planet = get_available_planet()
            if available_planet then
                available_planet.associate_surface(hub.surface)
            else
                return
            end
        end
        
        -- SE-SPECIFIC: Validate deployment target
        local hub_zone = remote.call("space-exploration", "get_zone_from_surface_index", {surface_index = hub.surface.index})
        local player_zone = remote.call("space-exploration", "get_zone_from_surface_index", {surface_index = player.surface.index})
        
        if hub_zone and is_space_zone_type(hub_zone.type) then
            local deployment_allowed = false
            
            if player.surface == hub.surface then
                deployment_allowed = true
            elseif hub_zone.parent and player_zone then
                if player_zone.name == hub_zone.parent.name then
                    deployment_allowed = true
                end
            elseif not hub_zone.parent and player_zone and (player_zone.type == "planet" or player_zone.type == "moon") then
                local orbit_name = hub_zone.name or hub.surface.name
                local expected_planet_name = orbit_name:gsub("%s+Orbit$", ""):gsub("%s+Asteroid%-Belt$", ""):gsub("%s+Asteroid%-Field$", "")
                if player_zone.name == expected_planet_name then
                    deployment_allowed = true
                end
            end
            
            if not deployment_allowed then
                return
            end
        end
        
        -- SE-SPECIFIC: Check if player is on a space surface
        local player_is_on_space = is_on_space_surface(player.surface)
        local hub_is_on_space = is_on_space_surface(hub.surface)
        
        if player_is_on_space then
            if not hub_is_on_space or player.surface ~= hub.surface then
                return
            end
        end
    end
    
    -- If extras are requested, verify they're available
    if extras and #extras > 0 then
        local hub_inv = hub.get_inventory(defines.inventory.chest)
        if not hub_inv then
            return
        end
        
        local needed_items = {}
        for _, extra in ipairs(extras) do
            local quality_name = get_quality_name(extra.quality)
            local key = extra.name .. ":" .. quality_name
            needed_items[key] = (needed_items[key] or 0) + extra.count
        end
        
        local found_items = {}
        for i = 1, #hub_inv do
            local stack = hub_inv[i]
            if stack.valid_for_read then
                for key, needed in pairs(needed_items) do
                    local item_name, quality = key:match("(.+):(.+)")
                    if stack.name == item_name then
                        local stack_quality = get_quality_name(stack.quality)
                        if stack_quality == quality then
                            found_items[key] = (found_items[key] or 0) + stack.count
                        end
                    end
                end
            end
        end
        
        for key, needed in pairs(needed_items) do
            local found = found_items[key] or 0
            if found < needed then
                return
            end
        end
    end
    
    -- Store grid data before removing from inventory
    local grid_data = {}
    local has_grid = false
    
    if stack.grid then
        has_grid = true
        
        -- First pass: collect ghost equipment and try to replace with real equipment
        local ghost_equipment_list = {}
        for _, equipment in pairs(stack.grid.equipment) do
            local equipment_name = equipment.name
            local is_ghost = false
            local base_equipment_name = nil
            
            if equipment.prototype and equipment.prototype.type == "equipment-ghost" then
                is_ghost = true
                if equipment.ghost_name then
                    base_equipment_name = equipment.ghost_name
                elseif equipment_name and equipment_name ~= "equipment-ghost" and equipment_name:match("%-ghost$") then
                    base_equipment_name = equipment_name:gsub("%-ghost$", "")
                end
            elseif equipment_name and equipment_name:match("%-ghost$") and equipment_name ~= "equipment-ghost" then
                is_ghost = true
                base_equipment_name = equipment_name:gsub("%-ghost$", "")
            elseif equipment_name == "equipment-ghost" then
                is_ghost = true
                if equipment.ghost_name then
                    base_equipment_name = equipment.ghost_name
                end
            elseif equipment_name == "equipment" then
                is_ghost = true
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
                    
                    for i = 1, #hub_inv do
                        local inv_stack = hub_inv[i]
                        if inv_stack and inv_stack.valid_for_read then
                            local equipment_name = get_equipment_name_from_item(inv_stack.name)
                            
                            if equipment_name == ghost_data.base_name then
                                local quality_match = true
                                if ghost_data.quality then
                                    local stack_quality = get_quality_name(inv_stack.quality)
                                    local ghost_quality_name = get_quality_name(ghost_data.quality)
                                    quality_match = (string.lower(stack_quality) == string.lower(ghost_quality_name))
                                end
                                
                                if quality_match then
                                    found_item = inv_stack.name
                                    found_quality = inv_stack.quality
                                    break
                                end
                            end
                        end
                    end
                    
                    if found_item then
                        local equipment_name = get_equipment_name_from_item(found_item)
                        
                        if equipment_name then
                            -- Remove one item from inventory
                            for i = 1, #hub_inv do
                                local inv_stack = hub_inv[i]
                                if inv_stack and inv_stack.valid_for_read and inv_stack.name == found_item then
                                    local stack_quality = get_quality_name(inv_stack.quality)
                                    local target_quality = get_quality_name(found_quality)
                                    
                                    if stack_quality == target_quality then
                                        inv_stack.count = inv_stack.count - 1
                                        break
                                    end
                                end
                            end
                            
                            table.insert(grid_data, {
                                name = equipment_name,
                                position = {x = ghost_data.position.x, y = ghost_data.position.y},
                                energy = nil,
                                quality = found_quality,
                                quality_name = get_quality_name(found_quality),
                                item_fallback_name = found_item
                            })
                        end
                    end
                end
            end
            
            -- Remove all ghost equipment from the grid
            for _, ghost_data in ipairs(ghost_equipment_list) do
                stack.grid.take({position = ghost_data.position})
            end
        end
        
        -- Second pass: collect real equipment data
        for _, equipment in pairs(stack.grid.equipment) do
            local equipment_name = equipment.name
            local equipment_quality = equipment.quality
            local equipment_quality_name = get_quality_name(equipment_quality)
            
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
        for _, item in ipairs(extras) do
            if item.in_grid then
                local count = item.count or 1
                for i = 1, count do
                    local equipment_name = nil
                    
                    if item.in_grid then
                        if item.in_grid.name then
                            equipment_name = item.in_grid.name
                        elseif type(item.in_grid) == "string" then
                            equipment_name = item.in_grid
                        else
                            equipment_name = get_equipment_name_from_item(item.name)
                        end
                    end
                    
                    if equipment_name then
                        if equipment_name:match("%-ghost$") or equipment_name == "equipment" then
                            goto continue_extra
                        end
                        
                        table.insert(grid_data, {
                            name = equipment_name,
                            position = nil,
                            energy = nil,
                            quality = item.quality,
                            item_fallback_name = item.name
                        })
                    end
                    
                    ::continue_extra::
                end
                has_grid = true
            end
        end
    end
    
    -- Store quality
    local quality = stack.quality
    local quality_name = get_quality_name(quality)
    
    -- Define landing position
    local landing_pos = {x = 0, y = 0}

    local chunk_x = math.floor(landing_pos.x / 32)
    local chunk_y = math.floor(landing_pos.y / 32)

    if not player.surface.is_chunk_generated({x = chunk_x, y = chunk_y}) then
        player.surface.request_to_generate_chunks(landing_pos, 1)
        player.surface.force_generate_chunk_requests()
    end
    
    local function is_walkable_tile(position)
        local tile = player.surface.get_tile(position.x, position.y)
        return tile and tile.valid and not tile.prototype.fluid
    end

    -- Get landing position based on deploy_target
    if deploy_target == "target" and 
       (player.render_mode == defines.render_mode.chart or
        player.render_mode == defines.render_mode.chart_zoomed_in) then
        landing_pos.x = player.position.x + math.random(-5, 5)
        landing_pos.y = player.position.y + math.random(-5, 5)
    elseif deploy_target == "player" and player.character then
        landing_pos.x = player.character.position.x + math.random(-5, 5)
        landing_pos.y = player.character.position.y + math.random(-5, 5)
    else
        if player.character then
            landing_pos.x = player.character.position.x + math.random(-5, 5)
            landing_pos.y = player.character.position.y + math.random(-5, 5)
        else
            landing_pos.x = player.position.x + math.random(-5, 5)
            landing_pos.y = player.position.y + math.random(-5, 5)
        end
    end

    -- Find valid non-fluid tile
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

    if #valid_positions > 0 then
        local random_index = math.random(1, #valid_positions)
        landing_pos = valid_positions[random_index]
    else
        return
    end
    
    -- Remove the vehicle from the hub inventory
    stack.count = stack.count - 1
    
    -- Collect extras with their qualities preserved
    local collected_extras = {}
    if extras and #extras > 0 then
        local hub_inv = hub.get_inventory(defines.inventory.chest)
        if hub_inv then
            local extras_by_key = {}
            for _, extra in ipairs(extras) do
                local quality_name = get_quality_name(extra.quality)
                local key = extra.name .. ":" .. quality_name
                if not extras_by_key[key] then
                    extras_by_key[key] = {
                        name = extra.name,
                        quality = quality_name,
                        count = 0
                    }
                end
                extras_by_key[key].count = extras_by_key[key].count + extra.count
            end
            
            for i = 1, #hub_inv do
                local stack = hub_inv[i]
                if stack and stack.valid_for_read then
                    local stack_quality = get_quality_name(stack.quality)
                    local key = stack.name .. ":" .. stack_quality
                    
                    if extras_by_key[key] and extras_by_key[key].count > 0 then
                        local to_take = math.min(stack.count, extras_by_key[key].count)
                        
                        table.insert(collected_extras, {
                            name = stack.name,
                            count = to_take,
                            quality = stack_quality
                        })
                        
                        stack.count = stack.count - to_take
                        extras_by_key[key].count = extras_by_key[key].count - to_take
                    end
                end
            end
        end
    end
    
    -- Try to create cargo pod
    local cargo_pod = nil
    
    if is_space_exploration_active() then
        -- SE: Get linked cargo-bay entity
        local cargo_bay = nil
        if storage.cargo_bay_links and hub.unit_number then
            cargo_bay = storage.cargo_bay_links[hub.unit_number]
            if cargo_bay and not cargo_bay.valid then
                cargo_bay = nil
            end
        end
        
        if not cargo_bay then
            local nearby_entities = hub.surface.find_entities_filtered{
                position = hub.position,
                radius = 5,
                name = "ovd-cargo-bay"
            }
            if #nearby_entities > 0 then
                cargo_bay = nearby_entities[1]
                if not storage.cargo_bay_links then
                    storage.cargo_bay_links = {}
                end
                storage.cargo_bay_links[hub.unit_number] = cargo_bay
            end
        end
        
        if cargo_bay and cargo_bay.valid then
            local cargo_hatch = nil
            
            if cargo_bay.cargo_hatches then
                if type(cargo_bay.cargo_hatches) == "table" then
                    if #cargo_bay.cargo_hatches > 0 then
                        cargo_hatch = cargo_bay.cargo_hatches[1]
                    elseif cargo_bay.cargo_hatches[1] then
                        cargo_hatch = cargo_bay.cargo_hatches[1]
                    end
                end
            end
            
            if not cargo_hatch and cargo_bay.get_cargo_hatches then
                local hatches = cargo_bay.get_cargo_hatches()
                if hatches and type(hatches) == "table" then
                    if #hatches > 0 then
                        cargo_hatch = hatches[1]
                    elseif hatches[1] then
                        cargo_hatch = hatches[1]
                    end
                end
            end
            
            if not cargo_hatch and cargo_bay.cargo_hatch then
                cargo_hatch = cargo_bay.cargo_hatch
            end
            
            if cargo_hatch and cargo_hatch.valid then
                local result = cargo_hatch.create_cargo_pod()
                if result and result.valid then
                    cargo_pod = result
                end
            end
        end
    else
        -- SA: Direct creation from hub
        if hub and hub.valid then
            local result = hub.create_cargo_pod()
            if result and result.valid then
                cargo_pod = result
            end
        end
    end
    
    if not cargo_pod then
        return
    end
    
    -- Detect same-surface deployment
    local actual_surface = player.surface
    local actual_position = landing_pos
    local is_same_surface = (player.surface == hub.surface)
    local temp_destination_surface = actual_surface
    
    if is_same_surface then
        local nauvis = game.surfaces["nauvis"]
        if nauvis and nauvis ~= actual_surface then
            temp_destination_surface = nauvis
        else
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
    
    cargo_pod.cargo_pod_origin = hub
    
    -- Save deployment information
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
        hub = hub,
        actual_surface = is_same_surface and actual_surface or nil,
        actual_position = is_same_surface and actual_position or nil
    }
end

-- Handle cargo pod landing
function deployment.on_cargo_pod_finished_descending(event)
    local pod = event.cargo_pod
    if not pod or not pod.valid then
        return
    end
    
    local hub = nil
    
    if storage.pending_pod_deployments then
        for pod_id, deployment_data in pairs(storage.pending_pod_deployments) do
            if deployment_data.pod == pod then
                
                -- Teleport to actual surface if needed
                if deployment_data.actual_surface and deployment_data.actual_position then
                    pod.teleport(deployment_data.actual_position, deployment_data.actual_surface)
                end
                
                if deployment_data.is_supplies_deployment then
                    -- Create smoke effect
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
                    
                    storage.pending_pod_deployments[pod_id] = nil
                    return
                end
                
                local player = deployment_data.player
                local vehicle_name = deployment_data.vehicle_name
                local vehicle_color = deployment_data.vehicle_color
                local has_grid = deployment_data.has_grid
                local grid_data = deployment_data.grid_data
                local entity_name = deployment_data.entity_name
                local extras = deployment_data.extras or {}
                
                if deployment_data.hub and deployment_data.hub.valid then
                    hub = deployment_data.hub
                end
                
                -- Create deployed vehicle
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

                if not (deployed_vehicle and deployed_vehicle.valid) then
                    deployed_vehicle = pod.surface.create_entity({
                        name = entity_name,
                        position = pod.position,
                        force = player.force,
                        create_build_effect_smoke = true
                    })
                end
                
                if deployed_vehicle and deployed_vehicle.valid then
                    script.raise_script_built({entity = deployed_vehicle})
                end
                
                if vehicle_color and deployed_vehicle and deployed_vehicle.valid then
                    deployed_vehicle.color = vehicle_color
                end
                
                if deployed_vehicle and deployed_vehicle.valid and vehicle_name ~= entity_name:gsub("^%l", string.upper) then
                    script.on_nth_tick(5, function()
                        if deployed_vehicle and deployed_vehicle.valid and vehicle_name then
                            deployed_vehicle.entity_label = vehicle_name
                        end
                        script.on_nth_tick(5, nil)
                    end)
                end
                
                -- Get vehicle inventory for later use
                local vehicle_inventory = nil
                if deployed_vehicle and deployed_vehicle.valid then
                    vehicle_inventory = deployed_vehicle.get_inventory(defines.inventory.car_trunk)
                    if not vehicle_inventory then
                        vehicle_inventory = deployed_vehicle.get_inventory(defines.inventory.spider_trunk)
                    end
                    if not vehicle_inventory then
                        vehicle_inventory = deployed_vehicle.get_inventory(defines.inventory.chest)
                    end
                end
                
                -- Transfer equipment grid
                if has_grid and deployed_vehicle and deployed_vehicle.valid and deployed_vehicle.grid then
                    local target_grid = deployed_vehicle.grid
                    for idx, equip_data in ipairs(grid_data) do
                        local new_equipment = nil
                        
                        if equip_data.quality_name and equip_data.quality then
                            new_equipment = target_grid.put({
                                name = equip_data.name,
                                position = equip_data.position,
                                quality = equip_data.quality
                            })
                        end
                        
                        if not new_equipment then
                            new_equipment = target_grid.put({
                                name = equip_data.name,
                                position = equip_data.position
                            })
                        end
                        
                        if not new_equipment then
                            new_equipment = target_grid.put({name = equip_data.name})
                        end
                        
                        if new_equipment and new_equipment.valid and equip_data.energy then
                            new_equipment.energy = equip_data.energy
                        end

                        if not new_equipment then
                            if vehicle_inventory then
                                local insert_data = {
                                    name = equip_data.item_fallback_name or equip_data.name,
                                    count = 1
                                }
                                if equip_data.quality then
                                    insert_data.quality = equip_data.quality
                                end
                                local inserted = vehicle_inventory.insert(insert_data)
                                if inserted < 1 and hub then
                                    return_items_to_hub(hub, equip_data.item_fallback_name or equip_data.name, 1, equip_data.quality)
                                end
                            else
                                if hub then
                                    return_items_to_hub(hub, equip_data.item_fallback_name or equip_data.name, 1, equip_data.quality)
                                end
                            end
                        end
                    end
                end
                
                -- Provide fuel
                if deployed_vehicle and deployed_vehicle.valid then
                    local fuel_inventory = deployed_vehicle.get_fuel_inventory()
                    if fuel_inventory then
                        local highest_fuel_value = 0
                        local best_fuel_item = nil
                        
                        for _, extra in ipairs(extras) do
                            local item = prototypes.item[extra.name]
                            if item and item.fuel_value and item.fuel_category == "chemical" then
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
                            if inserted < best_fuel_item.count and hub then
                                local overflow = best_fuel_item.count - inserted
                                return_items_to_hub(hub, best_fuel_item.name, overflow, best_fuel_item.quality)
                            end
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
                            local inserted = fuel_inventory.insert({name = "carbon", count = 5})
                            if inserted < 5 and hub then
                                return_items_to_hub(hub, "carbon", 5 - inserted, nil)
                            end
                        end
                    end
                    
                    -- Get ammo inventory
                    local ammo_inventory = nil
                    ammo_inventory = deployed_vehicle.get_inventory(defines.inventory.car_ammo)
                    if not ammo_inventory then
                        ammo_inventory = deployed_vehicle.get_inventory(defines.inventory.spider_ammo)
                    end

                    -- Distribute extras
                    if #extras > 0 then
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
                                table.insert(other_extras, extra)
                            end
                        end
                        
                        -- Process ammo
                        if ammo_inventory and #ammo_extras > 0 then
                            local ammo_by_category = {}
                            for _, extra in ipairs(ammo_extras) do
                                local category = get_ammo_category(extra.name) or "unknown"
                                if not ammo_by_category[category] then
                                    ammo_by_category[category] = {}
                                end
                                local key = extra.name .. "_" .. (extra.quality or "normal")
                                if not ammo_by_category[category][key] then
                                    ammo_by_category[category][key] = {
                                        name = extra.name,
                                        count = 0,
                                        quality = extra.quality or "normal"
                                    }
                                end
                                ammo_by_category[category][key].count = ammo_by_category[category][key].count + extra.count
                            end
                            
                            local slots_by_category = find_compatible_slots_by_category(deployed_vehicle, ammo_inventory)
                            
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
                                        if inserted < remaining_to_insert and hub then
                                            local overflow = remaining_to_insert - inserted
                                            return_items_to_hub(hub, priority_ammo.name, overflow, priority_ammo.quality)
                                        end
                                    elseif remaining_to_insert > 0 and hub then
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
                                            if inserted < ammo.count and hub then
                                                local overflow = ammo.count - inserted
                                                return_items_to_hub(hub, ammo.name, overflow, ammo.quality)
                                            end
                                        end
                                    end
                                else
                                    for _, ammo in ipairs(ammo_priority) do
                                        if vehicle_inventory then
                                            local inserted = vehicle_inventory.insert({
                                                name = ammo.name,
                                                count = ammo.count,
                                                quality = ammo.quality
                                            })
                                            if inserted < ammo.count and hub then
                                                local overflow = ammo.count - inserted
                                                return_items_to_hub(hub, ammo.name, overflow, ammo.quality)
                                            end
                                        elseif hub then
                                            return_items_to_hub(hub, ammo.name, ammo.count, ammo.quality)
                                        end
                                    end
                                end
                            end
                        end
                        
                        -- Process other extras
                        if #other_extras > 0 and vehicle_inventory then
                            for _, extra in ipairs(other_extras) do
                                local is_equipment = is_equipment_item(extra.name)
                                
                                if not is_equipment then
                                    local inserted = vehicle_inventory.insert({
                                        name = extra.name,
                                        count = extra.count,
                                        quality = extra.quality
                                    })
                                    if inserted < extra.count and hub then
                                        local overflow = extra.count - inserted
                                        return_items_to_hub(hub, extra.name, overflow, extra.quality)
                                    end
                                end
                            end
                        elseif #other_extras > 0 and hub then
                            for _, extra in ipairs(other_extras) do
                                local is_equipment = is_equipment_item(extra.name)
                                if not is_equipment then
                                    return_items_to_hub(hub, extra.name, extra.count, extra.quality)
                                end
                            end
                        end
                    end
                end
                
                -- Create smoke effect
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
                
                -- TFMG compatibility
                if deployed_vehicle and deployed_vehicle.valid and entity_name == "scout-o-tron" then
                    if player and player.valid and deployed_vehicle.gps_tag then
                        player.print({"spider-ui.scout-o-tron-deploy-message", deployed_vehicle.gps_tag})
                    end
                end
                
                storage.pending_pod_deployments[pod_id] = nil
                return
            end
        end
    end
end

-- Deploy supplies (robots) from orbit without a vehicle
function deployment.deploy_supplies(player, target_surface, selected_bots)
    -- Find ANY platform hub that has the requested bots
    local hub = nil
    local hub_inventory = nil
    
    for _, surface in pairs(game.surfaces) do
        if surface.platform and surface.platform.hub and surface.platform.hub.valid then
            local test_hub = surface.platform.hub
            local test_inv = test_hub.get_inventory(defines.inventory.chest)
            
            if test_inv then
                local has_all_bots = true
                
                for _, bot_data in ipairs(selected_bots) do
                    local found_count = 0
                    
                    for i = 1, #test_inv do
                        local stack = test_inv[i]
                        if stack and stack.valid_for_read and stack.name == bot_data.name then
                            local stack_quality = get_quality_name(stack.quality)
                            if stack_quality == bot_data.quality then
                                found_count = found_count + stack.count
                            end
                        end
                    end
                    
                    if found_count < bot_data.count then
                        has_all_bots = false
                        break
                    end
                end
                
                if has_all_bots then
                    hub = test_hub
                    hub_inventory = test_inv
                    break
                end
            end
        end
    end
    
    if not hub or not hub_inventory then
        player.print("Could not find platform with required robots")
        return
    end
    
    -- Determine landing position
    local landing_pos = {x = 0, y = 0}

    if player.render_mode == defines.render_mode.chart or 
       player.render_mode == defines.render_mode.chart_zoomed_in then
        landing_pos.x = player.position.x + math.random(-5, 5)
        landing_pos.y = player.position.y + math.random(-5, 5)
    elseif player.character then
        landing_pos.x = player.character.position.x + math.random(-5, 5)
        landing_pos.y = player.character.position.y + math.random(-5, 5)
    else
        landing_pos.x = player.position.x + math.random(-5, 5)
        landing_pos.y = player.position.y + math.random(-5, 5)
    end
    
    -- Ensure valid tile
    local function is_walkable_tile(position)
        local tile = target_surface.get_tile(position.x, position.y)
        return tile and tile.valid and not tile.prototype.fluid
    end
    
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
    
    if #valid_positions > 0 then
        local random_index = math.random(1, #valid_positions)
        landing_pos = valid_positions[random_index]
    else
        return
    end
    
    -- Remove bots from hub inventory
    local collected_bots = {}
    for _, bot_data in ipairs(selected_bots) do
        local needed = bot_data.count
        
        for i = 1, #hub_inventory do
            if needed <= 0 then break end
            
            local stack = hub_inventory[i]
            if stack and stack.valid_for_read and stack.name == bot_data.name then
                local stack_quality = get_quality_name(stack.quality)
                
                if stack_quality == bot_data.quality then
                    local to_take = math.min(stack.count, needed)
                    
                    table.insert(collected_bots, {
                        name = bot_data.name,
                        quality = stack.quality,
                        count = to_take
                    })
                    
                    stack.count = stack.count - to_take
                    needed = needed - to_take
                end
            end
        end
    end
    
    -- Create cargo pod
    local cargo_pod = hub.create_cargo_pod()
    if not cargo_pod then
        player.print("Failed to create cargo pod")
        return
    end

    local pod_inventory = cargo_pod.get_inventory(defines.inventory.chest)
    if not pod_inventory then
        player.print("Failed to access cargo pod inventory")
        cargo_pod.destroy()
        return
    end

    -- Add bots to pod inventory
    for _, bot_data in ipairs(collected_bots) do
        pod_inventory.insert({
            name = bot_data.name,
            quality = bot_data.quality,
            count = bot_data.count
        })
    end
    
    -- Detect same-surface deployment
    local actual_surface = target_surface
    local actual_position = landing_pos
    local is_same_surface = (target_surface == hub.surface)
    local temp_destination_surface = actual_surface
    
    if is_same_surface then
        -- ISSUE - when testing SE, we shouold identify if the zone / surface is a planet and restrict deployment. 
        -- at the same time, you shoulndt be able to place cargo bays on planet tiles, but you can place them on spaceship tiles which can be placed on planet surfaces. 
        -- so deployment bays can be placed on planet surfaces so we do need to ensure this is restricted. 
        -- maybe the check ignores cargo bays on planet surfaces. 
        local nauvis = game.surfaces["nauvis"]
        if nauvis and nauvis ~= actual_surface then
            temp_destination_surface = nauvis
        else
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
    
    cargo_pod.cargo_pod_origin = hub
    
    -- Store deployment data
    if not storage.pending_pod_deployments then
        storage.pending_pod_deployments = {}
    end
    
    local pod_id = player.index .. "_supplies_" .. game.tick
    
    storage.pending_pod_deployments[pod_id] = {
        pod = cargo_pod,
        player = player,
        is_supplies_deployment = true,
        bots = collected_bots,
        actual_surface = is_same_surface and actual_surface or nil,
        actual_position = is_same_surface and actual_position or nil
    }
end

return deployment