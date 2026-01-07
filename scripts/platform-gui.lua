-- scripts-sa/platform-gui.lua
local map_gui = require("scripts.map-gui")

local platform_gui = {}

-- Button name constant
platform_gui.DEPLOY_BUTTON_NAME = "spider_launcher_platform_deploy_button"

-- Check if platform is stopped above a planet
-- Returns planet_name, planet_surface if valid, nil if in transit or invalid
function platform_gui.get_platform_planet_name(player)
    if not player or not player.valid then
        return nil, nil
    end

    -- Check if player is on a platform surface
    if not player.surface or not player.surface.platform then
        return nil, nil
    end

    -- Check if platform has space_location (if not, it's in transit)
    local space_location = player.surface.platform.space_location
    if not space_location then
        return nil, nil
    end

    -- Try to get planet name from space_location
    local planet_name = nil
    local planet_surface = nil

    -- Try multiple approaches to get the planet name
    local success, name_result = pcall(function()
        return space_location.name
    end)
    if success and name_result then
        planet_name = name_result
        local surface_success, is_surface = pcall(function()
            return space_location.index ~= nil
        end)
        if surface_success and is_surface then
            planet_surface = space_location
        end
    end

    -- Fallback: string parsing
    if not planet_name then
        local location_str = tostring(space_location)
        planet_name = location_str:match(": ([^%(]+) %(planet%)")
        if not planet_name then
            planet_name = location_str:match(": ([^:]+)$")
            if planet_name then
                planet_name = planet_name:match("^%s*(.-)%s*$")
            end
        end
        if planet_name then
            planet_surface = game.get_surface(planet_name)
        end
    end

    -- If we got a name but not a surface, try to get the surface
    if planet_name and not planet_surface then
        planet_surface = game.get_surface(planet_name)
    end

    return planet_name, planet_surface
end

-- Get or create the deploy button for platform GUI
-- Returns the button element, or nil if button shouldn't be shown
function platform_gui.get_or_create_deploy_button(player, opened_entity)
    if not player or not player.valid then
        return nil
    end

    -- Use passed entity if provided, otherwise fall back to player.opened
    local opened = opened_entity or player.opened
    if not opened or not opened.valid then
        platform_gui.remove_deploy_button(player)
        return nil
    end

    -- Check if opened is an entity (not an equipment grid or other type)
    if not opened.surface then
        platform_gui.remove_deploy_button(player)
        return nil
    end

    local hub_surface = opened.surface

    -- Check if opened entity is on a platform surface
    if not hub_surface or not hub_surface.platform then
        platform_gui.remove_deploy_button(player)
        return nil
    end

    -- Check if platform is stopped above a planet
    local planet_name = nil
    local planet_surface = nil

    local space_location = hub_surface.platform.space_location
    if space_location then
        -- Get display name
        planet_name = space_location.localised_name
        
        -- Get the actual surface using space_location.name
        if space_location.name then
            planet_surface = game.get_surface(space_location.name)
        end
    end

    -- Platform is in transit or invalid - remove button if it exists
    if not planet_name or not planet_surface then
        platform_gui.remove_deploy_button(player)
        return nil
    end

    -- Get the relative GUI
    local relative_gui = player.gui.relative
    if not relative_gui then
        return nil
    end

    -- Check if toolbar frame already exists - if so, destroy and recreate to ensure proper anchoring
    local toolbar_frame = relative_gui[platform_gui.DEPLOY_BUTTON_NAME]
    if toolbar_frame and toolbar_frame.valid then
        toolbar_frame.destroy()
    end

    -- Try to find the correct GUI type for the opened entity
    local gui_type = nil

    if opened.type == "space-platform-hub" or opened.name == "space-platform-hub" then
        if defines.relative_gui_type.space_platform_hub_gui then
            gui_type = defines.relative_gui_type.space_platform_hub_gui
        elseif defines.relative_gui_type.platform_gui then
            gui_type = defines.relative_gui_type.platform_gui
        end
    elseif opened.type == "container" and defines.relative_gui_type.container_gui then
        gui_type = defines.relative_gui_type.container_gui
    elseif opened.type == "cargo-bay" then
        if defines.relative_gui_type.cargo_bay_gui then
            gui_type = defines.relative_gui_type.cargo_bay_gui
        elseif defines.relative_gui_type.container_gui then
            gui_type = defines.relative_gui_type.container_gui
        end
    end

    if not gui_type and defines.relative_gui_type.platform_gui then
        gui_type = defines.relative_gui_type.platform_gui
    end

    local anchor = nil
    if gui_type then
        anchor = {
            gui = gui_type,
            position = defines.relative_gui_position.bottom
        }
    end

    local frame_config = {
        type = "frame",
        name = platform_gui.DEPLOY_BUTTON_NAME,
        style = "frame",
        anchor = anchor
    }

    toolbar_frame = relative_gui.add(frame_config)
    if not toolbar_frame then
        frame_config.anchor = nil
        toolbar_frame = relative_gui.add(frame_config)
    end

    if not toolbar_frame then
        return nil
    end

    toolbar_frame.style.horizontally_stretchable = false
    toolbar_frame.style.vertically_stretchable = false
    toolbar_frame.style.top_padding = 3
    toolbar_frame.style.bottom_padding = 6
    toolbar_frame.style.left_padding = 6
    toolbar_frame.style.right_padding = 6

    local button_frame = toolbar_frame.add{
        type = "frame",
        name = "button_frame",
        direction = "vertical",
        style = "inside_shallow_frame"
    }

    button_frame.style.vertically_stretchable = false

    local button_flow = button_frame.add{
        type = "flow",
        name = "button_flow",
        direction = "vertical"
    }

    local deploy_button = button_flow.add{
        type = "button",
        name = platform_gui.DEPLOY_BUTTON_NAME .. "_btn",
        caption = {"", "[img=ovd_cargo_pod]", " Deploy a vehicle to ", planet_name},
        style = "button",
        tooltip = {"", "Open deployment menu to deploy a vehicle to ", planet_name}
    }

    if deploy_button and deploy_button.valid then
        return toolbar_frame
    else
        return nil
    end
end

-- Remove the deploy button
function platform_gui.remove_deploy_button(player)
    if not player or not player.valid then
        return
    end

    local relative_gui = player.gui.relative
    if not relative_gui then
        return
    end

    local toolbar_frame = relative_gui[platform_gui.DEPLOY_BUTTON_NAME]
    if toolbar_frame and toolbar_frame.valid then
        toolbar_frame.destroy()
    end
end

-- Handle button click
function platform_gui.on_deploy_button_click(player)
    if not player or not player.valid then
    return
    end

    -- Check if player has opened a platform hub
    local opened = player.opened
    if not opened or not opened.valid then
        return
    end

    -- Check if opened is an entity (not an equipment grid or other type)
    local hub_surface = nil
    local success, result = pcall(function()
        return opened.surface
    end)

    if not success or not result then
        return
    end

    hub_surface = result

    -- Check if opened entity is on a platform surface
    if not hub_surface or not hub_surface.platform then
        return
    end

    -- Check if platform is stopped above a planet
    local planet_name = nil  -- For display (can be LocalisedString)
    local planet_surface_name = nil  -- For surface lookup (must be string)
    local planet_surface = nil

    local space_location = hub_surface.platform.space_location
    if space_location then
        -- Try to get localised_name from space_location first (LuaSpaceLocationPrototype has localised_name)
        local space_localised_success, space_localised = pcall(function()
            return space_location.localised_name
        end)
        if space_localised_success and space_localised then
            planet_name = space_localised  -- Use LocalisedString directly
        end
        
        -- Also get the actual name (string) for surface lookup
        local space_name_success, space_name = pcall(function()
            return space_location.name
        end)
        if space_name_success and space_name then
            planet_surface_name = space_name
        end
        
        -- Try to get planet from hub_surface.platform.planet
        local planet_success, planet_result = pcall(function()
            return hub_surface.platform.planet
        end)
        if planet_success and planet_result then
            planet = planet_result
        end
        
        -- If that didn't work, try getting planet from space_location
        if not planet then
            local space_planet_success, space_planet_result = pcall(function()
                return space_location.planet
            end)
            if space_planet_success and space_planet_result then
                planet = space_planet_result
            end
        end
        
        -- If we have a planet, try to get associated_surfaces
        if planet then
            local surfaces_success, associated_surfaces = pcall(function()
                return planet.associated_surfaces
            end)
            if surfaces_success and associated_surfaces then
                -- Check specifically for "arrival" in associated surfaces (check both name and localised_name)
                local arrival_surface = nil
                for _, surface in ipairs(associated_surfaces) do
                    local is_arrival = false
                    -- Check name
                    if surface.name:lower():find("arrival") then
                        is_arrival = true
                    end
                    -- Check localised_name
                    if not is_arrival then
                        local localised_success, localised_name = pcall(function()
                            return surface.localised_name
                        end)
                        if localised_success and localised_name then
                            -- Can't easily check LocalisedString for "arrival", skip this check
                            -- We'll rely on surface.name check above
                        end
                    end
                    if is_arrival then
                        arrival_surface = surface
                        break
                    end
                end
                
                -- Get the first associated surface (usually the main planet surface)
                if #associated_surfaces > 0 then
                    -- Prefer arrival surface if found, otherwise use first
                    planet_surface = arrival_surface or associated_surfaces[1]
                    
                    -- If we don't already have planet_name from space_location.localised_name, try surface
                    if not planet_name then
                        -- Fallback to surface localised_name
                        local localised_success, localised_name = pcall(function()
                            return planet_surface.localised_name
                        end)
                        if localised_success and localised_name then
                            planet_name = localised_name  -- Use LocalisedString directly
                        else
                            planet_name = planet_surface.name
                        end
                    end
                end
            end
            
            -- If we still don't have a surface, try planet.name
            if not planet_surface then
                -- Note: LuaPlanet doesn't have localised_name, skip this
                -- We already got it from space_location above
                -- Try planet.name
                local planet_name_success, planet_name_result = pcall(function()
                    return planet.name
                end)
                if planet_name_success and planet_name_result then
                    planet_surface_name = planet_name_result
                    if not planet_name then
                        planet_name = planet_name_result
                    end
                    planet_surface = game.get_surface(planet_surface_name)
                end
            end
        end
        
        -- Fallback: Try to get planet name from space_location.name (prototype name)
        if not planet_name then
            local success, name_result = pcall(function()
                return space_location.name
            end)
            if success and name_result then
                -- Try to get planet from game.planets using this name
                local planet_lookup = game.planets[name_result]
                if planet_lookup then
                    planet = planet_lookup
                    -- Try associated_surfaces again
                    local surfaces_success, associated_surfaces = pcall(function()
                        return planet.associated_surfaces
                    end)
                    if surfaces_success and associated_surfaces and #associated_surfaces > 0 then
                        -- Check for arrival
                        local arrival_surface = nil
                        for _, surface in ipairs(associated_surfaces) do
                            if surface.name:lower():find("arrival") then
                                arrival_surface = surface
                                break
                            end
                        end
                        planet_surface = arrival_surface or associated_surfaces[1]
                        
                        -- Try to get localised_name from the planet first
                        local planet_localised_success, planet_localised = pcall(function()
                            return planet.localised_name
                        end)
                        -- Note: LuaPlanet doesn't have localised_name, skip this
                        -- Fallback to surface localised_name
                        local localised_success, localised_name = pcall(function()
                            return planet_surface.localised_name
                        end)
                        if localised_success and localised_name then
                            planet_name = localised_name  -- Use LocalisedString directly
                        else
                            planet_name = planet_surface.name
                        end
                    end
                end
            end
        end
        
        -- Final fallback: string parsing
        if not planet_surface_name then
            local location_str = tostring(space_location)
            planet_surface_name = location_str:match(": ([^%(]+) %(planet%)")
            if planet_surface_name then
                if not planet_name then
                    planet_name = planet_surface_name
                end
                planet_surface = game.get_surface(planet_surface_name)
            end
        end
        
        -- If we got a name but not a surface, try to get the surface
        if planet_surface_name and not planet_surface then
            planet_surface = game.get_surface(planet_surface_name)
        end
    end

    if not planet_name or not planet_surface then
        player.print({"string-mod-setting.vehicle-deployment-not-possible-in-transit"})
        return
    end

    -- Close any open GUIs first (like the shortcut handler does)
    if player.opened then
        player.opened = nil
    end

    -- Switch to the planet surface and show deployment menu (like shortcut handler does)
    local target_position = {x = 0, y = 0}
    player.set_controller{
        type = defines.controllers.remote,
        surface = planet_surface,
        position = target_position
    }

    -- Store data needed for next tick to show deployment menu
    -- This matches the shortcut handler pattern
    storage.pending_deployment = storage.pending_deployment or {}
    storage.pending_deployment[player.index] = {
        planet_surface = planet_surface,
        planet_name = planet_name
    }
end

return platform_gui
