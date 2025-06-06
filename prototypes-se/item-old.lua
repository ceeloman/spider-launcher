data:extend({

  {
      type = "item",
      name = "spidertron-launcher",
      icon = "__base__/graphics/icons/rocket-silo.png",
      icon_size = 64,
      subgroup = "transport",
      order = "b[personal-transport]-c[spidertron]-b[launcher]",
      place_result = "spidertron-launcher",
      stack_size = 1
  }
})

local data_util = require("__space-exploration__/data_util")

--__space-exploration-graphics__/graphics/icons/target.png

local orbital_spidertron_remote = table.deepcopy(data.raw["capsule"]["raw-fish"])
orbital_spidertron_remote.name = "orbital-spidertron-remote"
orbital_spidertron_remote.icon = "__space-exploration-graphics__/graphics/icons/target.png"
orbital_spidertron_remote.icon_size = 64
orbital_spidertron_remote.icon_mipmaps = 4
orbital_spidertron_remote.subgroup = "capsule"
orbital_spidertron_remote.order = "z[orbital-spidertron-targeter]"
orbital_spidertron_remote.stack_size = 1
orbital_spidertron_remote.capsule_action = {
    type = "throw",
    attack_parameters = {
        type = "projectile",
        activation_type = "throw",
        ammo_category = "capsule",
        cooldown = 30,
        range = 1000,
        ammo_type = {
            category = "capsule",
            target_type = "position",
            action = {
                type = "direct",
                action_delivery = {
                    type = "instant",
                    target_effects = {
                        {
                            type = "script",
                            effect_id = "orbital-spidertron-deploy"
                        }
                    }
                }
            }
        }
    }
}

data:extend({orbital_spidertron_remote})

  -- Keep the dummy flare definition as is
  data:extend({
    {
      type = "artillery-flare",
      name = data_util.mod_prefix .. "dummy-orbital-spidertron-flare",
      icon = "__space-exploration-graphics__/graphics/icons/target.png",
      icon_size = 64, icon_mipmaps = 4,
      flags = {"placeable-off-grid", "not-on-map"},
      map_color = {r=0, g=1, b=0},
      life_time = 0 * 60,
      initial_height = 0,
      initial_vertical_speed = 0,
      initial_frame_speed = 1,
      shots_per_flare = 0,
      early_death_ticks = 60 * 60, -- 1 minute
      pictures =
      {
        {
          filename = "__core__/graphics/shoot-cursor-green.png",
          priority = "low",
          width = 258,
          height = 183,
          frame_count = 1,
          scale = 1,
          flags = {"icon"}
        }
      }
    }
  })