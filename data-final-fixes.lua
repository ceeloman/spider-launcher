local function create_entity_sprite_from_item(item_prototype, item_name, prefix)
    local sprite_name = prefix .. item_name
    if data.raw["sprite"][sprite_name] then return end
    
    local icon_path = item_prototype.icon
    if not icon_path and item_prototype.icons then
        icon_path = item_prototype.icons[1] and item_prototype.icons[1].icon
    end
    
    if not icon_path then return end
    
    local icon_size = item_prototype.icon_size or 64
    local gui_size = 28 -- Target GUI size in pixels
    local scale = gui_size / icon_size -- Scale to match 28x28 GUI containers
    
    data:extend({
        {
            type = "sprite",
            name = sprite_name,
            filename = icon_path,
            priority = "medium",
            width = icon_size,
            height = icon_size,
            scale = scale,
            flags = {"gui-icon"},
            icon_size = icon_size
        }
    })
    
    return sprite_name
end

local function create_filtered_fuel_sprites()
    for name, item in pairs(data.raw["item"]) do
        -- Log every item being evaluated
        log("Evaluating item: " .. name)
        
        if item.fuel_value then
            log("Item " .. name .. " has fuel_value: " .. tostring(item.fuel_value))
            
            if item.fuel_category == "chemical" then
                log("Item " .. name .. " is in chemical category")
                
                if not string.find(name:lower(), "seed") and
                   not string.find(name:lower(), "egg") and
                   not string.find(name:lower(), "spoil") then
                    log("Item " .. name .. " passes name filters (no seed/egg/spoil)")
                    
                    if item.spoil_result == nil then
                        log("Item " .. name .. " has no spoil_result, creating sprite")
                        create_entity_sprite_from_item(item, name, "sl-")
                    else
                        log("Item " .. name .. " has spoil_result, skipping")
                    end
                else
                    log("Item " .. name .. " contains seed/egg/spoil, skipping")
                end
            else
                log("Item " .. name .. " is not in chemical category, skipping")
            end
        else
            log("Item " .. name .. " has no fuel_value, skipping")
        end
    end
end

-- Process all items that need entity sprites
local function create_special_item_sprites()
    -- Process repair tools
    for name, item in pairs(data.raw["repair-tool"]) do
        create_entity_sprite_from_item(item, name, "sl-")
    end
    
    -- Process ammo
    for name, item in pairs(data.raw["ammo"]) do
        create_entity_sprite_from_item(item, name, "sl-")
    end
    
    -- Process specific robot types
    local special_items = {
        "construction-robot",
        "logistic-robot"
    }
    
    for _, item_name in pairs(special_items) do
        local item = data.raw["item"][item_name]
        if item then
            create_entity_sprite_from_item(item, item_name, "sl-")
        end
    end
end

-- Function to create quality overlay sprites using data.raw.quality
local function create_quality_overlay_sprites()
    for name, quality in pairs(data.raw.quality or {}) do
        local quality_name = string.lower(name)
        -- Skip "unknown" quality
        if quality_name == "quality-unknown" then
            goto continue
        end
        local sprite_name = "sl-" .. quality_name
        
        -- Skip if sprite already exists
        if data.raw["sprite"][sprite_name] then
            goto continue
        end
        
        -- Determine the icon path, size, and tint
        local icon_path, icon_size, tint
        if quality.icons and quality.icons[2] then
            -- Use the second icon (tinted pip) for modded qualities
            icon_path = quality.icons[2].icon
            icon_size = quality.icons[2].icon_size or 64
            tint = quality.icons[2].tint
        elseif quality.icons and quality.icons[1] then
            -- Fallback to first icon if second is unavailable
            icon_path = quality.icons[1].icon
            icon_size = quality.icons[1].icon_size or 64
            tint = quality.icons[1].tint
        elseif quality.icon then
            -- Use single icon for vanilla qualities
            icon_path = quality.icon
            icon_size = quality.icon_size or 64
        else
            -- Fallback to vanilla path
            icon_path = "__base__/graphics/icons/" .. quality_name .. ".png"
            icon_size = 64
        end
        
        -- Verify the icon path exists

        
        -- Create the sprite
        local sprite = {
            type = "sprite",
            name = sprite_name,
            filename = icon_path,
            priority = "medium",
            width = icon_size,
            height = icon_size,
            scale = 14 / icon_size, -- Scale to match 14x14 GUI overlay
            flags = {"gui-icon"}
        }
        if tint then
            sprite.tint = tint
        end
        
        data:extend({ sprite })
        
        log("Created quality overlay sprite " .. sprite_name .. " with icon_size=" .. icon_size .. ", scale=" .. (14 / icon_size) .. ", tint=" .. (tint and string.format("{%g,%g,%g}", tint[1] or tint.r, tint[2] or tint.g, tint[3] or tint.b) or "none"))
        
        ::continue::
    end
end

-- Verify rocket-silo entity definition
local function verify_cargo_landing_pad()
    local cargo_bay_prototype = data.raw["rocket-silo"]["ovd-cargo-bay"]
    if not cargo_bay_prototype then
        log("[OVD] ERROR: ovd-cargo-bay prototype not found!")
        return
    end
    
    log("[OVD] Verifying ovd-cargo-bay prototype...")
    log("[OVD]   Type: " .. cargo_bay_prototype.type)
    log("[OVD]   Name: " .. cargo_bay_prototype.name)
    log("[OVD]   Procession style: " .. tostring(cargo_bay_prototype.procession_style))
    log("[OVD]   Inventory size: " .. tostring(cargo_bay_prototype.inventory_size))
    
    -- Check cargo_station_parameters (hatch_definitions are inside this)
    if cargo_bay_prototype.cargo_station_parameters then
        log("[OVD]   cargo_station_parameters found:")
        log("[OVD]     is_input_station: " .. tostring(cargo_bay_prototype.cargo_station_parameters.is_input_station))
        log("[OVD]     is_output_station: " .. tostring(cargo_bay_prototype.cargo_station_parameters.is_output_station))
        
        -- Check hatch_definitions inside cargo_station_parameters
        if cargo_bay_prototype.cargo_station_parameters.hatch_definitions then
            log("[OVD]   hatch_definitions found in cargo_station_parameters: " .. #cargo_bay_prototype.cargo_station_parameters.hatch_definitions .. " hatches")
            for i, hatch_def in ipairs(cargo_bay_prototype.cargo_station_parameters.hatch_definitions) do
                log("[OVD]     Hatch " .. i .. ": offset=" .. tostring(hatch_def.offset))
                log("[OVD]     Hatch " .. i .. ": cargo_unit_entity_to_spawn=" .. tostring(hatch_def.cargo_unit_entity_to_spawn))
            end
        else
            log("[OVD]   ERROR: hatch_definitions not found in cargo_station_parameters!")
        end
    else
        log("[OVD]   ERROR: cargo_station_parameters not found!")
    end
    
    -- Verify procession definitions
    local procession_names = {
        "ovd-cargo-bay-departure",
        "ovd-cargo-bay-intermezzo",
        "ovd-cargo-bay-arrival"
    }
    
    log("[OVD] Verifying custom procession definitions...")
    for _, name in ipairs(procession_names) do
        local procession_prototype = data.raw["procession"][name]
        if procession_prototype then
            if procession_prototype.procession_style == 99 then
                log("[OVD]   ✓ " .. name .. " procession found with style 99")
                log("[OVD]     Usage: " .. (procession_prototype.usage or "unknown"))
                log("[OVD]     Timeline duration: " .. (procession_prototype.timeline and procession_prototype.timeline.duration or "unknown"))
            else
                log("[OVD]   ERROR: " .. name .. " procession found but style is " .. tostring(procession_prototype.procession_style) .. " (expected 99)!")
            end
        else
            log("[OVD]   ERROR: " .. name .. " procession NOT found!")
        end
    end
    
    -- Verify that no other processions use style 99 (to avoid conflicts)
    log("[OVD] Checking for other processions using style 99...")
    local other_processions_with_99 = {}
    for name, procession in pairs(data.raw["procession"] or {}) do
        -- Exclude our own processions (they all start with "ovd-cargo-bay-")
        if procession.procession_style == 99 and not (string.sub(name, 1, 13) == "ovd-cargo-bay") then
            table.insert(other_processions_with_99, name)
        end
    end
    if #other_processions_with_99 > 0 then
        log("[OVD]   WARNING: Found other processions using style 99: " .. table.concat(other_processions_with_99, ", "))
        log("[OVD]   This may cause conflicts with our custom processions!")
    else
        log("[OVD]   ✓ No other processions use style 99 - our custom processions are unique")
    end
end

-- Register all functions to run at data-final-fixes stage
create_special_item_sprites()
create_filtered_fuel_sprites()
create_quality_overlay_sprites()
verify_cargo_landing_pad()
-- Register all functions to run

-- TFMG compatibility: Remove technology unlock requirement for orbital shortcut
if mods["TFMG"] or mods["tfmg"] then
    local shortcut = data.raw["shortcut"]["orbital-spidertron-deploy"]
    if shortcut then
        shortcut.technology_to_unlock = nil
    end
end

data:extend({
    {
      type = "planet",
      name = "ovd-se-generic",
      icon = "__base__/graphics/icons/iron-ore.png",  -- Use any simple icon
      icon_size = 64,
    --   starmap_icon = "__TFMG-assets-0__/icons/planets/arrival-starmap.png",
    --   starmap_icon_size = 512,
      gravity_pull = 10,
      distance = 30,
      orientation = 0.275,
      magnitude = 1,
      order = "a[arrival]",
    --   subgroup = "planets",
      map_seed_offset = 0,
    --   map_gen_settings = planet_map_gen.arrival(),
      pollutant_type = nil,
      solar_power_in_space = 100,
      planet_procession_set =
      {
        arrival = {"default-b"},
        departure = {"default-a"}
      },
      surface_properties =
      {
        ["day-night-cycle"] = 85 * minute,
        ["solar-power"] = 10,
        pressure = 135,
        gravity = 1.35,
      },
    --   surface_render_parameters =
    --   {
    --     clouds = effects.default_clouds_effect_properties(),
    --   },
    --   --Asteroid code
    --   asteroid_spawn_influence = 1,
    --   asteroid_spawn_definitions = asteroid_util.spawn_definitions(asteroid_util.arrival_arrival, 0.1),
    --   persistent_ambient_sounds =
    --   {
    --     base_ambience = {filename = "__space-age__/sound/wind/base-wind-aquilo.ogg", volume = 0.5},
    --     wind = {filename = "__space-age__/sound/wind/wind-aquilo.ogg", volume = 0.8},
    --     crossfade =
    --     {
    --       order = {"wind", "base_ambience"},
    --       curve_type = "cosine",
    --       from = {control = 0.35, volume_percentage = 0.0},
    --       to = {control = 2, volume_percentage = 100.0}
    --     },
        -- semi_persistent =
        -- {
        --   {
        --     sound =
        --     {
        --       variations = sound_variations("__space-age__/sound/world/semi-persistent/ice-cracks", 5, 0.7),
        --       advanced_volume_control =
        --       {
        --         fades = {fade_in = {curve_type = "cosine", from = {control = 0.5, volume_percentage = 0.0}, to = {2, 100.0}}}
        --       }
        --     },
        --     delay_mean_seconds = 10,
        --     delay_variance_seconds = 5
        --   },
        --   {
        --     sound = {variations = sound_variations("__space-age__/sound/world/semi-persistent/cold-wind-gust", 5, 0.3)},
        --     delay_mean_seconds = 15,
        --     delay_variance_seconds = 9
        --   }
        -- }
    --   },
    --   procession_graphic_catalogue =
    --   {
    --     {
    --       index = procession_graphic_catalogue_types.planet_hatch_emission_in_1,
    --       sprite = util.sprite_load("__base__/graphics/entity/cargo-hubs/hatches/planet-lower-hatch-pod-emission-A",
    --       {
    --         priority = "medium",
    --         draw_as_glow = true,
    --         blend_mode = "additive",
    --         scale = 0.5,
    --         shift = util.by_pixel(-16, 96) --32 x ({0.5, -3.5} + {0, 0.5})
    --       })
    --     },
    --     {
    --       index = procession_graphic_catalogue_types.planet_hatch_emission_in_2,
    --       sprite = util.sprite_load("__base__/graphics/entity/cargo-hubs/hatches/planet-lower-hatch-pod-emission-B",
    --       {
    --         priority = "medium",
    --         draw_as_glow = true,
    --         blend_mode = "additive",
    --         scale = 0.5,
    --         shift = util.by_pixel(-64, 96) --32 x ({2, -3.5} + {0, 0.5})
    --       })
    --     },
    --     {
    --       index = procession_graphic_catalogue_types.planet_hatch_emission_in_3,
    --       sprite = util.sprite_load("__base__/graphics/entity/cargo-hubs/hatches/planet-lower-hatch-pod-emission-C",
    --       {
    --         priority = "medium",
    --         draw_as_glow = true,
    --         blend_mode = "additive",
    --         scale = 0.5,
    --         shift = util.by_pixel(-40, 64) --32 x ({1.25, -2.5} + {0, 0.5})
    --       })
    --     }
    --   }
    }
  })

log("[OVD] Created ovd-se-generic space-location")
-- Register all functions to run