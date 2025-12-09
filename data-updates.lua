-- data-updates.lua
local procession_graphic_catalogue_types = require("__base__/prototypes/planet/procession-graphic-catalogue-types")

-- Create 40 planets for SE surface cargo pod support
for i = 1, 40 do
    data:extend({
        {
            type = "planet",
            name = "ovd-se-planet-" .. i,
            icon = "__base__/graphics/icons/cargo-pod.png",
            --icon_size = 1,
            gravity_pull = 10,
            distance = 30,
            orientation = 0.275,
            magnitude = 1,
            order = "z[hidden-" .. i .. "]", 
            map_seed_offset = i,
            pollutant_type = nil,
            solar_power_in_space = 100,
            localised_name = " ",
            hidden = true,
            planet_procession_set = {
                arrival = {"default-b"},
                departure = {"default-a"}
            },
            surface_properties = {
                ["day-night-cycle"] = 85 * 60,
                ["solar-power"] = 10,
            },
            procession_graphic_catalogue = {
                {
                    index = procession_graphic_catalogue_types.planet_hatch_emission_in_1,
                    sprite = util.sprite_load("__base__/graphics/entity/cargo-hubs/hatches/planet-lower-hatch-pod-emission-A", {
                        priority = "medium",
                        draw_as_glow = true,
                        blend_mode = "additive",
                        scale = 0.5,
                        shift = util.by_pixel(-16, 96)
                    })
                },
                {
                    index = procession_graphic_catalogue_types.planet_hatch_emission_in_2,
                    sprite = util.sprite_load("__base__/graphics/entity/cargo-hubs/hatches/planet-lower-hatch-pod-emission-B", {
                        priority = "medium",
                        draw_as_glow = true,
                        blend_mode = "additive",
                        scale = 0.5,
                        shift = util.by_pixel(-64, 96)
                    })
                },
                {
                    index = procession_graphic_catalogue_types.planet_hatch_emission_in_3,
                    sprite = util.sprite_load("__base__/graphics/entity/cargo-hubs/hatches/planet-lower-hatch-pod-emission-C", {
                        priority = "medium",
                        draw_as_glow = true,
                        blend_mode = "additive",
                        scale = 0.5,
                        shift = util.by_pixel(-40, 64)
                    })
                }
            }
        }
    })
end

log("[OVD] Created 40 SE-compatible planets")

-- Unlock deployment container recipe with se-space-capsule-navigation technology
local tech = data.raw["technology"]["se-space-capsule-navigation"]
if tech then
    if not tech.effects then
        tech.effects = {}
    end
    table.insert(tech.effects, {
        type = "unlock-recipe",
        recipe = "ovd-deployment-container"
    })
    log("[OVD] Added ovd-deployment-container recipe unlock to se-space-capsule-navigation technology")
else
    log("[OVD] WARNING: se-space-capsule-navigation technology not found!")
end