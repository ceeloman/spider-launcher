-- scripts-sa/platform-gui.lua
local map_gui = require("scripts-sa.map-gui")

local platform_gui = {}

-- Button name constant
platform_gui.DEPLOY_BUTTON_NAME = "spider_launcher_platform_deploy_button"

-- Check if platform is stopped above a planet
-- Returns planet_name if valid, nil if in transit or invalid
function platform_gui.get_platform_planet_name(player)
    if not player or not player.valid then
        return nil
    end
    
    -- Check if player is on a platform surface
    if not player.surface or not player.surface.platform then
        return nil
    end
    
    -- Check if platform has space_location (if not, it's in transit)
    if not player.surface.platform.space_location then
        return nil
    end
    
    -- Extract the planet name from the platform's space_location
    local location_str = tostring(player.surface.platform.space_location)
    local planet_name = location_str:match(": ([^%(]+) %(planet%)")
    
    return planet_name
end

-- Get or create the deploy button for platform GUI
-- Returns the button element, or nil if button shouldn't be shown
function platform_gui.get_or_create_deploy_button(player)
    if not player or not player.valid then
        return nil
    end
    
    -- Check if player has opened a platform hub
    local opened = player.opened
    if not opened or not opened.valid then
        -- Remove button if it exists and player closed the GUI
        platform_gui.remove_deploy_button(player)
        return nil
    end
    
    -- Check if opened is an entity (not an equipment grid or other type)
    -- Equipment grids don't have .surface property, so check that safely
    local hub_surface = nil
    local success, result = pcall(function()
        return opened.surface
    end)
    
    if not success or not result then
        -- Not an entity (could be equipment grid, etc.) - remove button if it exists
        platform_gui.remove_deploy_button(player)
        return nil
    end
    
    hub_surface = result
    
    -- Check if opened entity is on a platform surface
    -- Use the opened entity's surface, not the player's surface
    if not hub_surface or not hub_surface.platform then
        -- Not a platform hub - remove button if it exists
        platform_gui.remove_deploy_button(player)
        return nil
    end
    
    -- Check if platform is stopped above a planet
    -- Use the hub's surface to check platform status
    local planet_name = nil
    if hub_surface.platform.space_location then
        local location_str = tostring(hub_surface.platform.space_location)
        planet_name = location_str:match(": ([^%(]+) %(planet%)")
    end
    
    if not planet_name then
        -- Platform is in transit or invalid - remove button if it exists
        platform_gui.remove_deploy_button(player)
        return nil
    end
    
    -- Get the relative GUI
    local relative_gui = player.gui.relative
    if not relative_gui then
        return nil
    end
    
    -- Check if toolbar frame already exists
    local toolbar_frame = relative_gui[platform_gui.DEPLOY_BUTTON_NAME]
    
    -- Check if toolbar frame exists and is valid
    if toolbar_frame and toolbar_frame.valid then
        -- Find the button inside the frame structure
        local button_frame = toolbar_frame["button_frame"]
        if button_frame and button_frame.valid then
            local button_flow = button_frame["button_flow"]
            if button_flow and button_flow.valid then
                local button = button_flow[platform_gui.DEPLOY_BUTTON_NAME .. "_btn"]
                if button and button.valid then
                    -- Update button tooltip with current planet name
                    button.tooltip = {"", "Deploy a vehicle to ", planet_name}
                end
            end
        end
        return toolbar_frame
    end
    
    -- Try to find the correct GUI type for the opened entity
    local gui_type = nil
    local anchor = nil
    
    -- Check what type of entity is opened
    if opened.type == "container" then
        if defines.relative_gui_type.container_gui then
            gui_type = defines.relative_gui_type.container_gui
        end
    elseif opened.type == "cargo-bay" then
        if defines.relative_gui_type.cargo_bay_gui then
            gui_type = defines.relative_gui_type.cargo_bay_gui
        elseif defines.relative_gui_type.container_gui then
            gui_type = defines.relative_gui_type.container_gui
        end
    elseif opened.type == "space-platform-hub" or opened.name == "space-platform-hub" then
        -- Try space_platform_hub_gui first (this should be the correct one!)
        if defines.relative_gui_type.space_platform_hub_gui then
            gui_type = defines.relative_gui_type.space_platform_hub_gui
        elseif defines.relative_gui_type.platform_gui then
            gui_type = defines.relative_gui_type.platform_gui
        elseif defines.relative_gui_type.container_gui then
            gui_type = defines.relative_gui_type.container_gui
        elseif defines.relative_gui_type.cargo_bay_gui then
            gui_type = defines.relative_gui_type.cargo_bay_gui
        end
    end
    
    -- Try platform_gui as fallback
    if not gui_type and defines.relative_gui_type.platform_gui then
        gui_type = defines.relative_gui_type.platform_gui
    end
    
    -- Create anchor if we have a GUI type
    if gui_type then
        anchor = {
            gui = gui_type,
            position = defines.relative_gui_position.bottom
        }
    end
    
    -- Use styles with consistent appearance (like shared_toolbar)
    local frame_style = "frame"
    local inner_frame_style = "inside_shallow_frame"
    
    -- Create the toolbar frame (like shared_toolbar does)
    local frame_config = {
        type = "frame",
        name = platform_gui.DEPLOY_BUTTON_NAME,
        style = frame_style
    }
    
    -- Add anchor if we have one
    if anchor then
        frame_config.anchor = anchor
    end
    
    -- Try to create the frame
    local success, toolbar_frame = pcall(function()
        return relative_gui.add(frame_config)
    end)
    
    if not success then
        -- If creation failed with anchor, try without anchor
        frame_config.anchor = nil
        success, toolbar_frame = pcall(function()
            return relative_gui.add(frame_config)
        end)
    end
    
    if not success or not toolbar_frame then
        return nil
    end
    
    -- Apply style modifications to toolbar frame
    toolbar_frame.style.horizontally_stretchable = false
    toolbar_frame.style.vertically_stretchable = false
    toolbar_frame.style.top_padding = 3
    toolbar_frame.style.bottom_padding = 6
    toolbar_frame.style.left_padding = 6
    toolbar_frame.style.right_padding = 6
    
    -- Create button_frame (like shared_toolbar)
    local button_frame = toolbar_frame.add{
        type = "frame",
        name = "button_frame",
        direction = "vertical",
        style = inner_frame_style
    }
    
    -- Apply style modifications to button_frame
    button_frame.style.vertically_stretchable = false
    
    -- Create button_flow (like shared_toolbar)
    local button_flow = button_frame.add{
        type = "flow",
        name = "button_flow",
        direction = "vertical"
    }
    
    -- Create button with text only (no sprite for now)
    local deploy_button = button_flow.add{
        type = "button",
        name = platform_gui.DEPLOY_BUTTON_NAME .. "_btn",
        caption = {"", "Deploy a vehicle to ", planet_name},
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
    local planet_name = nil
    if hub_surface.platform.space_location then
        local location_str = tostring(hub_surface.platform.space_location)
        planet_name = location_str:match(": ([^%(]+) %(planet%)")
    end
    
    if not planet_name then
        player.print("Vehicle Deployment is not possible while the platform is in transit")
        return
    end
    
    -- Get the planet surface
    local planet_surface = game.get_surface(planet_name)
    if not planet_surface then
        player.print("Could not find planet surface: " .. planet_name)
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
