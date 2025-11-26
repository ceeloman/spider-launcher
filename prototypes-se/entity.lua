-- prototypes-se/entity.lua

local cargo_hatch = require("prototypes-se.cargo-hatch")
local procession_graphic_catalogue_types = require("__base__/prototypes/planet/procession-graphic-catalogue-types")

data:extend({
    {
      type = "container",
      name = "ovd-deployment-container",
      icon = "__spider-launcher__/graphics/icons/cargo-bay.png",
      icon_size = 64,
      flags = {"placeable-neutral", "player-creation"},
      minable = {mining_time = 0.5, result = "ovd-deployment-container"},
      max_health = 350,
      corpse = "steel-chest-remnants",
      collision_box = {{-1.9, -1.9}, {1.9, 1.9}},
      selection_box = {{-2, -2}, {2, 2}},
      build_grid_size = 2,
      inventory_size = 50,
      circuit_wire_max_distance = 9,
      circuit_connector = circuit_connector_definitions["chest"],
      se_allow_in_space = true,
      picture = {
        layers = {
          util.sprite_load("__spider-launcher__/graphics/entity/cargo-hubs/bays/shared-cargo-bay-0",
          {
            scale = 0.5,
            shift = {0, -1}
          }),
          util.sprite_load("__spider-launcher__/graphics/entity/cargo-hubs/bays/planet-cargo-bay-3",
          {
            scale = 0.5,
            shift = {0, -1}
          }),
          util.sprite_load("__spider-launcher__/graphics/entity/cargo-hubs/bays/shared-cargo-bay-shadow",
          {
            scale = 0.5,
            shift = {3, 0.5},
            draw_as_shadow = true
          }),
          util.sprite_load("__spider-launcher__/graphics/entity/cargo-hubs/bays/shared-cargo-bay-emission",
          {
            scale = 0.5,
            shift = {0, -1},
            draw_as_glow = true,
            blend_mode = "additive"
          }),
          util.sprite_load("__spider-launcher__/graphics/entity/cargo-hubs/hatches/planet-cargo-bay-occluder",
          {
            scale = 0.5,
            shift = {0, -1}
          })
        }
      }
    },
    {
      type = "cargo-bay",
      name = "ovd-cargo-bay",
      icon = "__spider-launcher__/graphics/icons/cargo-bay.png",
      icon_size = 64,
      flags = {"not-deconstructable", "not-blueprintable", "not-on-map"},
      selectable_in_game = false,
      minable = nil,
      max_health = 350,
      corpse = "steel-chest-remnants",
      dying_explosion = "electric-furnace-explosion",
      collision_box = {{-1.9, -1.9}, {1.9, 1.9}},
      selection_box = {{-2, -2}, {2, 2}},
      inventory_size_bonus = 1,
      hatch_definitions =
      {
        cargo_hatch.shared_bay_hatch({-0.32, -1.5}, procession_graphic_catalogue_types.hatch_emission_bay)
      },
      graphics_set =
      {
        water_reflection =
        {
          pictures =
          {
            filename = "__spider-launcher__/graphics/entity/cargo-hubs/bays/planet-bay-reflections.png",
            priority = "extra-high",
            width = 32,
            height = 32,
            shift = util.by_pixel(0, 100),
            variation_count = 1,
            scale = 4
          },
          rotate = false,
          orientation_to_variation = false
        },
        connections = require("__base__.graphics.entity.cargo-hubs.connections.planet-connections"),
        picture =
        {
          {
            render_layer = "lower-object-above-shadow",
            layers =
            {
              util.sprite_load("__spider-launcher__/graphics/entity/cargo-hubs/bays/shared-cargo-bay-0",
              {
                scale = 0.5,
                shift = {0, -1}
              }),
            }
          },
          {
            render_layer = "object",
            layers =
            {
              util.sprite_load("__spider-launcher__/graphics/entity/cargo-hubs/bays/planet-cargo-bay-3",
              {
                scale = 0.5,
                shift = {0, -1}
              }),
              util.sprite_load("__spider-launcher__/graphics/entity/cargo-hubs/bays/shared-cargo-bay-shadow",
              {
                scale = 0.5,
                shift = {3, 0.5},
                draw_as_shadow = true
              }),
              util.sprite_load("__spider-launcher__/graphics/entity/cargo-hubs/bays/shared-cargo-bay-emission",
              {
                scale = 0.5,
                shift = {0, -1},
                draw_as_glow = true,
                blend_mode = "additive"
              })
            }
          },
          {
            render_layer = "cargo-hatch",
            layers =
            {
              util.sprite_load("__spider-launcher__/graphics/entity/cargo-hubs/hatches/planet-cargo-bay-occluder",
              {
                scale = 0.5,
                shift = {0, -1}
              }),
            }
          }
        }
      },
      platform_graphics_set =
      {
        connections = require("__spider-launcher__.graphics.entity.cargo-hubs.connections.platform-connections"),
        picture =
        {
          {
            render_layer = "lower-object-above-shadow",
            layers =
            {
              util.sprite_load("__spider-launcher__/graphics/entity/cargo-hubs/bays/shared-cargo-bay-0",
              {
                scale = 0.5,
                shift = {0, -1}
              }),
            }
          },
          {
            render_layer = "object",
            layers =
            {
              util.sprite_load("__spider-launcher__/graphics/entity/cargo-hubs/bays/platform-cargo-bay-3",
              {
                scale = 0.5,
                shift = {0, -1}
              }),
              util.sprite_load("__spider-launcher__/graphics/entity/cargo-hubs/bays/shared-cargo-bay-shadow",
              {
                scale = 0.5,
                shift = {3, 0.5},
                draw_as_shadow = true
              }),
              util.sprite_load("__spider-launcher__/graphics/entity/cargo-hubs/bays/shared-cargo-bay-emission",
              {
                scale = 0.5,
                shift = {0, -1},
                draw_as_glow = true,
                blend_mode = "additive"
              })
            }
          },
          {
            render_layer = "cargo-hatch",
            layers =
            {
              util.sprite_load("__spider-launcher__/graphics/entity/cargo-hubs/hatches/platform-cargo-bay-occluder",
              {
                scale = 0.5,
                shift = {0, -1}
              }),
            }
          }
        }
      }
    }
  })