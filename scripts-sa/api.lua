-- API for other mods to use spider-launcher deployment system
local deployment = require("scripts-sa.deployment")

local api = {}

-- Deploy a vehicle from a platform hub using the orbital delivery system
-- Parameters:
--   hub: The space platform hub entity
--   surface_name: Name of the planet/surface to deploy to (e.g., "arrival")
--   config: Configuration table with:
--     vehicle_item: Item name to deploy (e.g., "scout-o-tron-pod")
--     entity_name: Entity name to create (e.g., "scout-o-tron")
--     required_items: Table of item names that must exist in hub (e.g., {"scout-o-tron", "scout-o-tron-pod"})
--     equipment_grid: Table of equipment to add {name = "solar-cell-equipment", count = 2}, etc.
--     trunk_items: Table of items to add to trunk {name = "construction-robot", count = 8}, etc.
--     target_position: {x, y} position (default: {0, 0})
--   player_index: Player index (optional, for messages)
-- Returns: true, message if successful, false, error_message if failed
function api.deploy_from_hub(params)
    local hub = params.hub
    local surface_name = params.surface_name
    local config = params.config or {}
    local player_index = params.player_index
    
    if not hub or not hub.valid then
        return false, "Hub is not valid"
    end
    
    if not surface_name then
        return false, "Surface name is required"
    end
    
    if not config.vehicle_item then
        return false, "vehicle_item is required in config"
    end
    
    if not config.entity_name then
        return false, "entity_name is required in config"
    end
    
    -- Get or create the surface
    local surface = game.get_surface(surface_name)
    if not surface then
        local planet = game.planets[surface_name]
        if planet then
            planet.create_surface()
            surface = game.get_surface(surface_name)
        end
        
        if not surface then
            return false, "Could not create surface: " .. surface_name
        end
    end
    
    -- Get player if provided
    local player = nil
    if player_index then
        player = game.get_player(player_index)
    end
    
    if not player and hub.force then
        local players = hub.force.players
        if #players > 0 then
            player = players[1]
        end
    end
    
    if not player then
        return false, "No player found"
    end
    
    -- Check hub inventory for required items
    local hub_inventory = hub.get_inventory(defines.inventory.chest)
    if not hub_inventory then
        return false, "Hub has no inventory"
    end
    
    -- Check for required items
    local required_items = config.required_items or {config.vehicle_item}
    local found_items = {}
    
    for _, required_name in ipairs(required_items) do
        local found = false
        for i = 1, #hub_inventory do
            local stack = hub_inventory[i]
            if stack.valid_for_read and stack.name == required_name then
                found_items[required_name] = {
                    stack = stack,
                    index = i
                }
                found = true
                break
            end
        end
        if not found then
            return false, "Required item not found: " .. required_name
        end
    end
    
    -- Find the vehicle item to deploy
    local vehicle_stack = found_items[config.vehicle_item]
    if not vehicle_stack then
        return false, "Vehicle item not found: " .. config.vehicle_item
    end
    
    -- Try to get entity data from the actual vehicle item (e.g., scout-o-tron) if it exists
    -- Otherwise use the pod item or defaults
    local entity_data_stack = nil
    if config.entity_name and found_items[config.entity_name] then
        entity_data_stack = found_items[config.entity_name].stack
    end
    
    -- Get vehicle data from the stack (for color, name, quality)
    -- Safely access entity_label and entity_color (they may not exist on all items)
    local vehicle_name = config.entity_name
    local vehicle_color = nil  -- Only set if color data exists
    local vehicle_quality = nil
    
    -- Try to get data from entity item first, then pod item
    local source_stack = entity_data_stack or vehicle_stack.stack
    pcall(function()
        if source_stack.entity_label and source_stack.entity_label ~= "" then
            vehicle_name = source_stack.entity_label
        end
    end)
    pcall(function()
        if source_stack.entity_color then
            vehicle_color = source_stack.entity_color
        end
    end)
    pcall(function()
        if source_stack.quality then
            vehicle_quality = source_stack.quality
        end
    end)
    
    -- Get grid data from the vehicle stack if it has equipment
    local grid_data = {}
    local has_grid = false
    if vehicle_stack.stack.grid then
        has_grid = true
        for _, equipment in pairs(vehicle_stack.stack.grid.equipment) do
            table.insert(grid_data, {
                name = equipment.name,
                position = {x = equipment.position.x, y = equipment.position.y},
                energy = equipment.energy,
                quality = equipment.quality,
                quality_name = equipment.quality and equipment.quality.name or nil
            })
        end
    end
    
    -- Add equipment from config if specified
    if config.equipment_grid then
        for _, equip_config in ipairs(config.equipment_grid) do
            local count = equip_config.count or 1
            for i = 1, count do
                table.insert(grid_data, {
                    name = equip_config.name,
                    position = nil,  -- Let grid.put find a position
                    energy = equip_config.energy or nil
                })
            end
        end
    end
    
    -- Prepare trunk items from config
    local trunk_items = {}
    if config.trunk_items then
        for _, item_config in ipairs(config.trunk_items) do
            table.insert(trunk_items, {
                name = item_config.name,
                count = item_config.count or 1
            })
        end
    end
    
    -- Get target position
    local target_pos = config.target_position or {x = 0, y = 0}
    
    -- Store original render mode to restore later
    local original_render_mode = player.render_mode
    
    
    -- Create vehicle data structure
    local vehicle_data = {
        name = vehicle_name,
        color = vehicle_color,
        hub = hub,
        inv_type = defines.inventory.chest,
        inventory_slot = vehicle_stack.index,
        vehicle_name = config.vehicle_item,
        entity_name = config.entity_name,
        platform_name = hub.surface.name,
        quality = vehicle_quality,
        is_spider = true,
        -- API-specific: target surface and position
        api_target_surface = surface,
        api_target_position = target_pos,
        -- Store config for later use
        api_config = {
            equipment_grid = config.equipment_grid,
            trunk_items = config.trunk_items,
            required_items = required_items,
            found_items = found_items
        }
    }
    
    -- Call the deployment function (it will handle the pod creation, item removal, and animation)
    -- Don't teleport player - deployment will use api_target_surface if available
    local deploy_success, deploy_error = pcall(function()
        deployment.deploy_spider_vehicle(player, vehicle_data, "target", trunk_items)
    end)
    
    if not deploy_success then
        return false, "Deployment function error: " .. tostring(deploy_error)
    end
    
    -- Remove all required items from inventory (both scout-o-tron and pod)
    -- Do this AFTER deployment since deployment may have already removed some items
    for _, required_name in ipairs(required_items) do
        local item_data = found_items[required_name]
        if item_data and item_data.stack and item_data.stack.valid_for_read then
            item_data.stack.count = item_data.stack.count - 1
        end
    end
    return true, "Deployment initiated"
end

-- Vehicle deployment requirements registry
-- Format: {vehicle_item_name = {required_items = {"item1", "item2"}, ...}}
api.vehicle_requirements = {}

-- Vehicle default equipment and trunk items registry
-- Format: {vehicle_item_name = {equipment_grid = {...}, trunk_items = {...}}}
api.vehicle_defaults = {}

-- Register a vehicle and its deployment requirements
-- Parameters:
--   vehicle_item: The vehicle item name (e.g., "scout-o-tron")
--   requirements: Table with:
--     required_items: Array of item names that must exist in hub (e.g., {"scout-o-tron-pod"})
--     deploy_item: The item to actually deploy (e.g., "scout-o-tron-pod") - defaults to vehicle_item
--     entity_name: The entity name to create (e.g., "scout-o-tron") - defaults to vehicle_item
function api.register_vehicle_requirements(vehicle_item, requirements)
    if not vehicle_item then
        return false
    end
    
    api.vehicle_requirements[vehicle_item] = {
        required_items = requirements.required_items or {},
        deploy_item = requirements.deploy_item or vehicle_item,
        entity_name = requirements.entity_name or vehicle_item
    }
    
    return true
end

-- Check if a vehicle has all required items in the hub inventory
function api.check_vehicle_requirements(vehicle_item, hub)
    if not api.vehicle_requirements[vehicle_item] then
        -- No requirements registered, vehicle is deployable
        return true, {}
    end
    
    local requirements = api.vehicle_requirements[vehicle_item]
    local hub_inventory = hub.get_inventory(defines.inventory.chest)
    if not hub_inventory then
        return false, "Hub has no inventory"
    end
    
    local found_items = {}
    for _, required_name in ipairs(requirements.required_items) do
        local found = false
        for i = 1, #hub_inventory do
            local stack = hub_inventory[i]
            if stack.valid_for_read and stack.name == required_name then
                found_items[required_name] = {stack = stack, index = i}
                found = true
                break
            end
        end
        if not found then
            return false, "Missing required item: " .. required_name
        end
    end
    
    return true, found_items
end

-- Register default equipment grid and trunk items for a vehicle
-- Parameters:
--   vehicle_item: The vehicle item name (e.g., "scout-o-tron")
--   defaults: Table with:
--     equipment_grid: Array of equipment {name = "solar-cell-equipment", count = 2}, etc.
--     trunk_items: Array of items {name = "construction-robot", count = 8}, etc.
function api.register_vehicle_defaults(vehicle_item, defaults)
    if not vehicle_item then
        return false
    end
    
    api.vehicle_defaults[vehicle_item] = {
        equipment_grid = defaults.equipment_grid or {},
        trunk_items = defaults.trunk_items or {}
    }
    
    local equip_count = #(api.vehicle_defaults[vehicle_item].equipment_grid)
    local trunk_count = #(api.vehicle_defaults[vehicle_item].trunk_items)
    return true
end

-- Get default equipment and trunk items for a vehicle
function api.get_vehicle_defaults(vehicle_item)
    return api.vehicle_defaults[vehicle_item] or {equipment_grid = {}, trunk_items = {}}
end

-- Check if TFMG mod is active
function api.is_tfmg_active()
    return script.active_mods["TFMG"] ~= nil or script.active_mods["tfmg"] ~= nil
end

-- Register the remote interface
remote.add_interface("spider-launcher", {
    deploy_from_hub = api.deploy_from_hub,
    register_vehicle_requirements = api.register_vehicle_requirements,
    check_vehicle_requirements = api.check_vehicle_requirements,
    register_vehicle_defaults = api.register_vehicle_defaults,
    get_vehicle_defaults = api.get_vehicle_defaults
})

return api

