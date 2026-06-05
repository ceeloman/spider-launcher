-- scripts/maraxsis-compat.lua
-- Maraxsis submarine deployment compatibility

local maraxsis_compat = {}

local MARAXSIS_PLANET_NAME = "maraxsis"
local submarine_list_cache = nil

function maraxsis_compat.is_active()
    return script.active_mods["maraxsis"] ~= nil
end

local function get_submarine_list()
    if submarine_list_cache then
        return submarine_list_cache
    end

    if not maraxsis_compat.is_active() then
        submarine_list_cache = {}
        return submarine_list_cache
    end

    if remote.interfaces["maraxsis"] then
        local ok, result = pcall(function()
            return remote.call("maraxsis", "get_submarine_list")
        end)
        if ok and result then
            submarine_list_cache = result
            return submarine_list_cache
        end
    end

    submarine_list_cache = {}
    return submarine_list_cache
end

function maraxsis_compat.is_maraxsis_planet_surface(surface)
    if not surface or not surface.valid then
        return false
    end
    if not maraxsis_compat.is_active() then
        return false
    end
    return surface.planet and surface.planet.name == MARAXSIS_PLANET_NAME
end

local function resolve_entity_name(item_or_entity_name)
    if not item_or_entity_name then
        return nil
    end

    local subs = get_submarine_list()
    if subs[item_or_entity_name] then
        return item_or_entity_name
    end

    local item_proto = prototypes.item[item_or_entity_name]
    if item_proto and item_proto.place_result then
        local pr = item_proto.place_result
        return type(pr) == "string" and pr or pr.name
    end

    return item_or_entity_name
end

function maraxsis_compat.is_submarine(item_or_entity_name)
    if not maraxsis_compat.is_active() or not item_or_entity_name then
        return false
    end

    local subs = get_submarine_list()
    if subs[item_or_entity_name] then
        return true
    end

    local entity_name = resolve_entity_name(item_or_entity_name)
    return entity_name and subs[entity_name] == true
end

function maraxsis_compat.is_orbital_vehicle_allowed(item_name, entity_name, player_surface)
    if not maraxsis_compat.is_active() then
        return true
    end

    local is_sub = maraxsis_compat.is_submarine(item_name) or maraxsis_compat.is_submarine(entity_name)
    local on_maraxsis = maraxsis_compat.is_maraxsis_planet_surface(player_surface)

    if on_maraxsis then
        return is_sub
    end

    return not is_sub
end

function maraxsis_compat.can_deploy_vehicle_to_surface(item_name, entity_name, surface)
    if not maraxsis_compat.is_active() then
        return true, nil
    end

    local is_sub = maraxsis_compat.is_submarine(item_name) or maraxsis_compat.is_submarine(entity_name)
    local on_maraxsis = maraxsis_compat.is_maraxsis_planet_surface(surface)

    if on_maraxsis then
        if is_sub then
            return true, nil
        end
        return false, "maraxsis-no-land-vehicles"
    end

    if is_sub then
        return false, "maraxsis-submarines-only"
    end

    return true, nil
end

function maraxsis_compat.print_deploy_error(player, err_key)
    if not player or not player.valid or not err_key then
        return
    end

    if err_key == "maraxsis-no-land-vehicles" then
        player.print({"string-mod-setting.maraxsis-no-land-vehicles"})
    elseif err_key == "maraxsis-submarines-only" then
        player.print({"string-mod-setting.maraxsis-submarines-only"})
    end
end

local function is_valid_landing_tile(surface, position, entity_name)
    local tile = surface.get_tile(position.x, position.y)
    if not tile or not tile.valid then
        return false
    end

    if maraxsis_compat.is_active()
        and maraxsis_compat.is_maraxsis_planet_surface(surface)
        and maraxsis_compat.is_submarine(entity_name) then
        return true
    end

    return not tile.prototype.fluid
end

function maraxsis_compat.find_landing_position(surface, center_pos, entity_name, radius)
    radius = radius or 5
    local valid_positions = {}

    for dx = -radius, radius do
        for dy = -radius, radius do
            local check_pos = {x = center_pos.x + dx, y = center_pos.y + dy}
            if is_valid_landing_tile(surface, check_pos, entity_name) then
                table.insert(valid_positions, check_pos)
            end
        end
    end

    if #valid_positions > 0 then
        return valid_positions[math.random(1, #valid_positions)]
    end

    return nil
end

function maraxsis_compat.blocks_supplies_deploy(surface)
    if not maraxsis_compat.is_active() then
        return false
    end
    return maraxsis_compat.is_maraxsis_planet_surface(surface)
end

return maraxsis_compat
