local data_util = require("__space-exploration__/data_util")

data:extend({
    {
      type = "simple-entity",
      name = "cargo-pod-visual",
      flags = {"placeable-neutral", "player-creation", "not-on-map", "placeable-off-grid"},
      icon = "__space-exploration-graphics__/graphics/icons/cargo-pod.png",
      icon_size = 64,
      collision_box = {{-0.4, -0.4}, {0.4, 0.4}},
      collision_mask = {},
      picture = {
        filename = "__space-exploration-graphics__/graphics/entity/cargo-pod/cargo-pod.png",
        width = 147,
        height = 194,
        scale = 0.5,
      },
      render_layer = "air-object",
    },
    {
      type = "simple-entity",
      name = "cargo-pod-shadow-visual",
      flags = {"placeable-neutral", "player-creation", "not-on-map", "placeable-off-grid"},
      icon = "__space-exploration-graphics__/graphics/icons/cargo-pod.png",
      icon_size = 64,
      collision_box = {{-0.4, -0.4}, {0.4, 0.4}},
      collision_mask = {},
      picture = {
        filename = "__space-exploration-graphics__/graphics/entity/cargo-pod/cargo-pod-shadow.png",
        width = 167,
        height = 164,
        scale = 0.5,
        draw_as_shadow = true,
      },
      render_layer = "air-object",
    }
  })