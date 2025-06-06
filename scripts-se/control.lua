local OrbitalSpidertronGui = require("scripts.orbital_spidertron_gui")

-- Debug logging function
local function debug_log(message)
    log("[Orbital Spidertron] " .. message)
end

-- Function to create or recreate the orbital inventory
local function create_orbital_inventory()
    if not global.orbital_inventory or not global.orbital_inventory.valid then
        global.orbital_inventory = game.create_inventory(100)
        debug_log("Created new orbital inventory")
    end
end

-- Initialize global variables
local function init_globals()
    global.orbital_inventory = global.orbital_inventory or nil  -- We'll create it when needed
    global.spidertron_labels = global.spidertron_labels or {}  -- Ensure the labels table exists
    global.deployment_in_progress = false  -- New variable to track deployment status
    debug_log("Globals initialized")
end

local function create_smoke_cloud(surface, position)
    for _ = 1, 6 do
        local offset_x = (math.random() - 0.5) * 0.5
        local offset_y = (math.random() - 0.5) * 0.5
        local smoke_position = {
            x = position.x + offset_x,
            y = position.y + offset_y
        }
        surface.create_trivial_smoke{name = "train-smoke", position = smoke_position}
    end
end

local function deploy_function(surface, target_position, spidertron_data, force)
    -- Determine random landing spot within 50 tiles of target
    local landing_x = target_position.x + (math.random() - 0.5) * 25
    local landing_y = target_position.y + (math.random() - 0.5) * 25
    local landing_position = {x = landing_x, y = landing_y}

    -- Calculate starting position 50 tiles away from landing spot
    local angle = math.random() * 2 * math.pi
    local start_x = landing_x + math.cos(angle) * 25
    local start_y = landing_y + math.sin(angle) * 25
    local start_position = {x = start_x, y = start_y}

    local landing_time = 60 -- 3 seconds
    local current_tick = 0

    local cargo_pod = surface.create_entity({
        name = "cargo-pod-visual",
        position = start_position,
        force = force
    })

    local shadow = surface.create_entity({
        name = "cargo-pod-shadow-visual",
        position = {start_x + 2, start_y + 2},
        force = force
    })

    script.on_nth_tick(1, function(event)
        current_tick = current_tick + 1
        local progress = current_tick / landing_time
        
        if cargo_pod and cargo_pod.valid then
            -- Calculate new position using linear interpolation
            local new_x = start_position.x + (landing_position.x - start_position.x) * progress
            local new_y = start_position.y + (landing_position.y - start_position.y) * progress
            
            -- Add a slight curve to the trajectory
            local curve_height = 3
            local curve_offset = math.sin(progress * math.pi) * curve_height
            new_y = new_y - curve_offset
            
            cargo_pod.teleport({new_x, new_y})
            
            -- Update shadow position
            if shadow and shadow.valid then
                local shadow_offset = 2 * (1 - progress)
                shadow.teleport({new_x + shadow_offset, new_y + shadow_offset + curve_offset})
            end
        end

        if current_tick == landing_time then
            if cargo_pod and cargo_pod.valid then cargo_pod.destroy() end
            if shadow and shadow.valid then shadow.destroy() end

            -- Create impact effect
        --    surface.create_entity({name = "massive-explosion", position = landing_position})

            -- Create the actual chest (Space Exploration cargo pod)
            local chest = surface.create_entity({
                name = "se-cargo-rocket-cargo-pod",
                position = landing_position,
                force = force
            })

            -- Deploy spidertron next to the chest
            local spidertron_position = {
                x = landing_position.x + 2,
                y = landing_position.y
            }

            local spidertron = surface.create_entity{
                name = spidertron_data.name,
                position = spidertron_position,
                force = force,
                create_build_effect_smoke = true
            }

            if spidertron and spidertron.valid and chest and chest.valid then
                spidertron.color = spidertron_data.color

                -- Apply grid equipment
                if spidertron.grid then
                    for _, eq in ipairs(spidertron_data.grid) do
                        spidertron.grid.put({name = eq.name, position = eq.position})
                    end
                end
                
                -- Distribute items between spidertron and chest
                local spider_trunk = spidertron.get_inventory(defines.inventory.spider_trunk)
                local chest_inventory = chest.get_inventory(defines.inventory.chest)
                
                local items_to_distribute = {
                    {name = "construction-robot", count = 50},
                    {name = "repair-pack", count = 50},
                    {name = "se-iron-ingot", count = 50},
                    {name = "se-copper-ingot", count = 50},
                    {name = "se-steel-ingot", count = 50}
                }
                
                for _, item in ipairs(items_to_distribute) do
                    local chest_count = math.random(1, item.count-1)
                    local spider_count = item.count - chest_count
                    
                    chest_inventory.insert({name = item.name, count = chest_count})
                    -- debug_log("chest count complete")
                    spider_trunk.insert({name = item.name, count = spider_count})
                    -- debug_log("spidercount complete")
                end
                
                -- Add explosive rockets to spidertron's ammo inventory
                local spider_ammo = spidertron.get_inventory(defines.inventory.spider_ammo)
                spider_ammo.insert({name = "explosive-rocket", count = 800})
                
                -- Mark the chest for deconstruction
                chest.order_deconstruction(force)
                
                -- Spidertron deployed successfully with supply chest!")
            else
                game.print("Error: Failed to deploy Orbital Spidertron or chest.")
            end
            
            -- Reset deployment status
            global.deployment_in_progress = false
            
            return true  -- Remove this on_nth_tick handler
        end
    end)
end

-- Event Handlers
script.on_init(function()
    init_globals()
    create_orbital_inventory()
    debug_log("Mod initialized")
end)

script.on_load(function()
    debug_log("Mod loaded")
end)

script.on_configuration_changed(function(data)
    init_globals()
    create_orbital_inventory()
    debug_log("Configuration changed, globals reinitialized")
end)

script.on_event(defines.events.on_rocket_launched, function(event)
    local rocket = event.rocket
    local inventory = rocket.get_inventory(defines.inventory.rocket)
    local launch_item = inventory[1]
    
    if launch_item and launch_item.valid_for_read and launch_item.name == "spidertron" then
        create_orbital_inventory()
        
        -- Store grid data separately
        local grid_data = {}
        if launch_item.grid then
            for _, equipment in pairs(launch_item.grid.equipment) do
                table.insert(grid_data, {
                    name = equipment.name,
                    position = equipment.position
                })
            end
        end
        
        local inserted = global.orbital_inventory.insert(launch_item)
        if inserted > 0 then
            local entity_label = launch_item.label or "Spidertron"
            table.insert(global.spidertron_labels, entity_label)
            
            -- Store grid data
            if not global.spidertron_grids then global.spidertron_grids = {} end
            global.spidertron_grids[#global.spidertron_labels] = grid_data
            
            --game.print("Spidertron '" .. entity_label .. "' launched into orbit! Total in orbit: " .. global.orbital_inventory.get_item_count("spidertron"))
        else
            game.print("Failed to launch Spidertron. Orbital storage is full.")
        end
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    -- Ensure OrbitalSpidertronGui.on_gui_click exists before calling it
    if OrbitalSpidertronGui and OrbitalSpidertronGui.on_gui_click then
        OrbitalSpidertronGui.on_gui_click(event)
    else
        game.print("Error: OrbitalSpidertronGui.on_gui_click is not defined.")
    end
end)

script.on_event(defines.events.on_player_created, function(event)
    local player = game.players[event.player_index]
    OrbitalSpidertronGui.create(player)
    player.print("Orbital Spidertron Launcher mod initialized")
    debug_log("Mod initialized for player " .. player.name)
end)

-- Add a custom input for toggling the GUI
script.on_event("toggle-orbital-spidertron-gui", function(event)
    local player = game.players[event.player_index]
    if player.gui.left["orbital_spidertron_frame"] then
        player.gui.left["orbital_spidertron_frame"].destroy()
    else
        OrbitalSpidertronGui.create(player)
    end
end)

-- Set the deploy function in the GUI module
OrbitalSpidertronGui.set_deploy_function(deploy_function)

debug_log("Control script loaded")

commands.add_command("orbital_spidertron_info", "Print information about spidertrons in orbit", function(command)
    local player = game.get_player(command.player_index)
    if not player then return end

    if not global.orbital_inventory or not global.orbital_inventory.valid then
        player.print("Orbital inventory is not valid.")
        return
    end

    local spidertron_count = global.orbital_inventory.get_item_count("spidertron")
    player.print("Total spidertrons in orbit: " .. spidertron_count)

    for i = 1, #global.orbital_inventory do
        local item = global.orbital_inventory[i]
        if item.valid_for_read and item.name == "spidertron" then
            player.print("-----------------------------------")
            player.print("Spidertron #" .. i)
            player.print("Label: " .. (item.label or "Spidertron"))
            player.print("Health: " .. (item.durability or "N/A"))
            
            -- Print inventory contents
            local main_inventory = item.get_inventory(defines.inventory.item_main)
            if main_inventory then
                player.print("Inventory contents:")
                for name, count in pairs(main_inventory.get_contents()) do
                    player.print("  " .. name .. ": " .. count)
                end
            else
                player.print("No main inventory")
            end

            -- Print equipment grid contents
            if global.spidertron_grids and global.spidertron_grids[i] then
                player.print("Equipment grid contents:")
                for _, eq in ipairs(global.spidertron_grids[i]) do
                    player.print("  " .. eq.name .. " at position " .. serpent.line(eq.position))
                end
            elseif item.grid then
                player.print("Equipment grid contents (from item):")
                for _, eq in pairs(item.grid.equipment) do
                    player.print("  " .. eq.name .. " at position " .. serpent.line(eq.position))
                end
            else
                player.print("No equipment grid data")
            end
        end
    end
end)