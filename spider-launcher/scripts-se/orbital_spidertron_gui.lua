local OrbitalSpidertronGui = {}

local deploy_function

function OrbitalSpidertronGui.set_deploy_function(func)
    deploy_function = func
end

local function get_spidertron_data(inventory, index)
    local contents = inventory.get_contents()
    local spidertron_count = contents["spidertron"] or 0
    
    if index > spidertron_count then
        return nil
    end
    
    local current_count = 0
    for i = 1, #inventory do
        local item = inventory[i]
        if item.valid_for_read and item.name == "spidertron" then
            current_count = current_count + 1
            if current_count == index then
                return {
                    color = item.entity_color,
                    health = item.durability,
                    inventory = item.get_inventory(defines.inventory.item_main) and item.get_inventory(defines.inventory.item_main).get_contents() or {},
                    ammo = item.get_inventory(defines.inventory.item_ammo) and item.get_inventory(defines.inventory.item_ammo).get_contents() or {},
                    trash = item.get_inventory(defines.inventory.item_trash) and item.get_inventory(defines.inventory.item_trash).get_contents() or {},
                    equipment = global.spidertron_grids and global.spidertron_grids[index] or {},
                    label = item.label
                }
            end
        end
    end
    return nil
end

local function add_titlebar(gui, caption, close_button_name, refresh_button_name)
    local titlebar = gui.add{type = "flow", direction = "horizontal"}
    
    -- Add title label (frame title)
    titlebar.add{
        type = "label",
        style = "frame_title",
        caption = caption,
        ignored_by_interaction = true,
    }

    -- Add a spacer element to push the buttons to the right
    titlebar.add{
        type = "empty-widget",
        style = "draggable_space",
        ignored_by_interaction = true, 
        style_mods = {
            horizontally_stretchable = true,
            height = 24,
        }
    }

    -- Add the refresh button
    titlebar.add{
        type = "sprite-button",
        name = refresh_button_name,
        style = "close_button", -- Use a small button style
        sprite = "utility/refresh",
        tooltip = {"gui.refresh-instruction"},
    }

    -- Add the close button
    titlebar.add{
        type = "sprite-button",
        name = close_button_name,
        style = "close_button",
        sprite = "utility/close_white",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        tooltip = {"gui.close-instruction"},
    }
end

function OrbitalSpidertronGui.create(player)
    if player.gui.left["orbital_spidertron_frame"] then
        player.gui.left["orbital_spidertron_frame"].destroy()
    end

    local frame = player.gui.left.add{
        type = "frame",
        name = "orbital_spidertron_frame",
        direction = "vertical"
    }

    -- Add titlebar with refresh button
    add_titlebar(frame, "Orbital Spidertrons", "orbital_spidertron_close", "orbital_spidertron_refresh")

    local content_flow = frame.add{type="flow", name="orbital_spidertron_content", direction="vertical"}
    local list_flow = content_flow.add{type="scroll-pane", name="orbital_spidertron_list", direction="vertical"}
    list_flow.style.maximal_height = 300

    OrbitalSpidertronGui.update_list(player)
end


function OrbitalSpidertronGui.update_list(player)
    local frame = player.gui.left["orbital_spidertron_frame"]
    if not frame then return end

    local list_flow = frame["orbital_spidertron_content"]["orbital_spidertron_list"]
    list_flow.clear()

    if not global.orbital_inventory or not global.orbital_inventory.valid then
        list_flow.add{type="label", caption="Orbital inventory is not valid"}
        return
    end

    local spidertron_count = 0

    for i = 1, #global.orbital_inventory do
        local item = global.orbital_inventory[i]
        if item.valid_for_read and item.name == "spidertron" then
            spidertron_count = spidertron_count + 1
            local row = list_flow.add{type="flow", direction="horizontal"}
            
            -- Add spidertron icon
            row.add{
                type = "sprite",
                sprite = "item/spidertron",
                tint = item.entity_color or {r=1, g=1, b=1}
            }
            
            -- Add colored "Spidertron" text
            local label = row.add{
                type = "label",
                caption = "Spidertron",
                style = "caption_label"
            }
            label.style.font_color = item.entity_color or {r=1, g=1, b=1}
            
            -- Add deploy button
            row.add{
                type = "button",
                name = "orbital_spidertron_deploy_" .. spidertron_count,
                caption = "Deploy"
            }
        end
    end

    if spidertron_count == 0 then
        list_flow.add{type="label", caption="No orbital spidertrons available"}
    end
end

function OrbitalSpidertronGui.deploy_spidertron(player, spidertron_index)
    if global.deployment_in_progress then
        player.print("[color=red]A deployment is already in progress. Please wait.[/color]")
        return
    end

    if not deploy_function then
        player.print("Error: Deploy function not set.")
        return
    end

    if not global.orbital_inventory or not global.orbital_inventory.valid then
        player.print("Error: Orbital inventory is not valid.")
        return
    end

    local spidertron_item = nil
    local current_index = 0

    for i = 1, #global.orbital_inventory do
        local item = global.orbital_inventory[i]
        if item.valid_for_read and item.name == "spidertron" then
            current_index = current_index + 1
            if current_index == spidertron_index then
                spidertron_item = item
                break
            end
        end
    end

    if not spidertron_item then
        player.print("Error: Spidertron #" .. spidertron_index .. " not found in orbital inventory.")
        return
    end

    -- Store necessary information before removing the item
    local spidertron_data = {
        name = "spidertron",
        color = spidertron_item.entity_color or {r=1, g=1, b=1},
        grid = {}
    }

    -- Capture grid information
    if spidertron_item.grid then
        for _, equipment in pairs(spidertron_item.grid.equipment) do
            table.insert(spidertron_data.grid, {
                name = equipment.name,
                position = equipment.position
            })
        end
    end

    -- Remove the spidertron from the orbital inventory
    global.orbital_inventory.remove({name="spidertron", count=1})

    -- Set deployment in progress
    global.deployment_in_progress = true

    -- Call deploy function with stored data
    deploy_function(player.surface, player.position, spidertron_data, player.force)
    --player.print("Orbital Spidertron deployment initiated!")
    OrbitalSpidertronGui.update_list(player)
end

function OrbitalSpidertronGui.on_gui_click(event)
    local player = game.get_player(event.player_index)
    
    -- Ensure event.element is valid before accessing its name
    if not event.element or not event.element.valid then
        return -- Exit the function if no valid element was clicked
    end

    local element_name = event.element.name -- Safely accessing element name

    -- Close the frame if the close button is pressed
    if element_name == "orbital_spidertron_close" then
        if player.gui.left["orbital_spidertron_frame"] then
            player.gui.left["orbital_spidertron_frame"].destroy()
        end
    end

    -- Close and recreate the GUI if the refresh button is pressed
    if element_name == "orbital_spidertron_refresh" then
        if player.gui.left["orbital_spidertron_frame"] then
            player.gui.left["orbital_spidertron_frame"].destroy()
        end
        -- Recreate the GUI (this will also refresh the list)
        OrbitalSpidertronGui.create(player)
    end

    -- Handle any other button clicks (like deploy buttons)
    if element_name:match("^orbital_spidertron_deploy_") then
        local spidertron_index = tonumber(element_name:match("^orbital_spidertron_deploy_(%d+)$"))
        if spidertron_index then
            OrbitalSpidertronGui.deploy_spidertron(player, spidertron_index)
        end      
    end
end

function OrbitalSpidertronGui.close(player)
    if player.gui.left["orbital_spidertron_frame"] then
        player.gui.left["orbital_spidertron_frame"].destroy()
    end
end


return OrbitalSpidertronGui