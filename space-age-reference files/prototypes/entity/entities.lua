{
    type = "cargo-bay",
    name = "cargo-bay",
    flags = {"placeable-player", "player-creation"},
    icon = "__space-age__/graphics/icons/cargo-bay.png",
    corpse = "cargo-bay-remnants",
    dying_explosion = "electric-furnace-explosion",
    collision_box = {{-1.9, -1.9}, {1.9, 1.9}},
    selection_box = {{-2, -2}, {2, 2}},
    max_health = 1000,
    minable = {mining_time = 1, result = "cargo-bay"},
    inventory_size_bonus = 20,
    hatch_definitions =
    {
      shared_bay_hatch({-0.32, -1.5}, procession_graphic_catalogue_types.hatch_emission_bay)
    },
    graphics_set =
    {
      water_reflection =
      {
        pictures =
        {
          filename = "__space-age__/graphics/entity/cargo-hubs/bays/planet-bay-reflections.png",
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
            util.sprite_load("__space-age__/graphics/entity/cargo-hubs/bays/shared-cargo-bay-0",
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
            util.sprite_load("__space-age__/graphics/entity/cargo-hubs/bays/planet-cargo-bay-3",
            {
              scale = 0.5,
              shift = {0, -1}
            }),
            util.sprite_load("__space-age__/graphics/entity/cargo-hubs/bays/shared-cargo-bay-shadow",
            {
              scale = 0.5,
              shift = {3, 0.5},
              draw_as_shadow = true
            }),
            util.sprite_load("__space-age__/graphics/entity/cargo-hubs/bays/shared-cargo-bay-emission",
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
            util.sprite_load("__space-age__/graphics/entity/cargo-hubs/hatches/planet-cargo-bay-occluder",
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
      connections = require("__space-age__.graphics.entity.cargo-hubs.connections.platform-connections"),
      picture =
      {
        {
          render_layer = "lower-object-above-shadow",
          layers =
          {
            util.sprite_load("__space-age__/graphics/entity/cargo-hubs/bays/shared-cargo-bay-0",
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
            util.sprite_load("__space-age__/graphics/entity/cargo-hubs/bays/platform-cargo-bay-3",
            {
              scale = 0.5,
              shift = {0, -1}
            }),
            util.sprite_load("__space-age__/graphics/entity/cargo-hubs/bays/shared-cargo-bay-shadow",
            {
              scale = 0.5,
              shift = {3, 0.5},
              draw_as_shadow = true
            }),
            util.sprite_load("__space-age__/graphics/entity/cargo-hubs/bays/shared-cargo-bay-emission",
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
            util.sprite_load("__space-age__/graphics/entity/cargo-hubs/hatches/platform-cargo-bay-occluder",
            {
              scale = 0.5,
              shift = {0, -1}
            }),
          }
        }
      }
    }
  },