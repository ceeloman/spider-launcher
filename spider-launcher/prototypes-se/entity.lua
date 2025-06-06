local data_util = require("__space-exploration__/data_util")

local scale = 0.4 -- Scale factor for the spidertron launcher
local vertical_shift = 2 -- Adjust this value to move the sprite down
local spread_factor = 0.2 -- Increase this value to spread the lights further

local function adjust_light_position(x, y)
    return util.by_pixel(
        x / (scale * spread_factor), 
        (y - 1.375) / (scale * spread_factor) + (vertical_shift-2) / scale
    )
end

-- Spidertron Launcher definition
local spidertron_launcher = {
    type = "rocket-silo",
    name = "spidertron-launcher",
    icon = "__base__/graphics/icons/rocket-silo.png",
    icon_size = 64,
    icon_mipmaps = 4,
    icons = {
        {
            icon = "__base__/graphics/icons/rocket-silo.png",
            icon_size = 64,
            icon_mipmaps = 4
        }
    },
    flags = {"placeable-player", "player-creation"},
    crafting_categories = {"rocket-building"},
    rocket_parts_required = 1,
    crafting_speed = 1,
    rocket_result_inventory_size = 1,
    fixed_recipe = "spidertron-rocket-launch",
    show_recipe_icon = false,
    allowed_effects = {"consumption", "speed", "productivity", "pollution"},
    minable = {mining_time = 1, result = "spidertron-launcher"},
    max_health = 5000,
    corpse = "rocket-silo-remnants",
    dying_explosion = "rocket-silo-explosion",
    collision_box = {{-4.40 * scale, -4.40 * scale}, {4.40 * scale, 4.40 * scale}},
    selection_box = {{-4.5 * scale, -4.5 * scale}, {4.5 * scale, 4.5 * scale}},
    hole_clipping_box = {{-2.75 * scale, -1.15 * scale}, {2.75 * scale, 2.25 * scale}},
    rocket_clipping_box = {{-1.5 * scale, -5 * scale}, {1.5 * scale, 11 * scale}},
    resistances = {
        {
            type = "fire",
            percent = 60
        },
        {
            type = "impact",
            percent = 60
        }
    },
    energy_source = {
        type = "electric",
        usage_priority = "primary-input"
    },
    energy_usage = "250kW",
    lamp_energy_usage = "0KW",
    active_energy_usage = "3990KW",
    rocket_entity = "spidertron-launcher-rocket",
    times_to_blink = 3,
    light_blinking_speed = 1 / (3 * 60),
    door_opening_speed = 1 / (4.25 * 60),

    base_engine_light = {
        intensity = 1 * scale,
        size = 25 * scale,
        shift = {0, 1.5 * scale}
    },

    shadow_sprite = {
        filename = "__base__/graphics/entity/rocket-silo/00-rocket-silo-shadow.png",
        priority = "medium",
        width = 304,
        height = 290,
        draw_as_shadow = true,
        dice = 2,
        shift = util.by_pixel(8 * scale, 2 * scale),
        scale = scale,
        hr_version = {
            filename = "__base__/graphics/entity/rocket-silo/hr-00-rocket-silo-shadow.png",
            priority = "medium",
            width = 612,
            height = 578,
            draw_as_shadow = true,
            dice = 2,
            shift = util.by_pixel(7 * scale, 2 * scale),
            scale = 0.5 * scale
        }
    },

    hole_sprite = {
        filename = "__base__/graphics/entity/rocket-silo/01-rocket-silo-hole.png",
        width = 202,
        height = 136,
        shift = util.by_pixel(-6 * scale, 16 * scale),
        scale = scale,
        hr_version = {
            filename = "__base__/graphics/entity/rocket-silo/hr-01-rocket-silo-hole.png",
            width = 400,
            height = 270,
            shift = util.by_pixel(-5 * scale, 16 * scale),
            scale = 0.5 * scale
        }
    },
    hole_light_sprite = {
        filename = "__base__/graphics/entity/rocket-silo/01-rocket-silo-hole-light.png",
        width = 202,
        height = 136,
        shift = util.by_pixel(-6 * scale, 16 * scale),
        tint = {1,1,1,0},
        scale = scale,
        hr_version = {
            filename = "__base__/graphics/entity/rocket-silo/hr-01-rocket-silo-hole-light.png",
            width = 400,
            height = 270,
            shift = util.by_pixel(-5 * scale, 16 * scale),
            tint = {1,1,1,0},
            scale = 0.5 * scale
        }
    },

    rocket_shadow_overlay_sprite = {
        filename = "__base__/graphics/entity/rocket-silo/03-rocket-over-shadow-over-rocket.png",
        width = 212,
        height = 142,
        shift = util.by_pixel(-2 * scale, 22 * scale),
        scale = scale,
        hr_version = {
            filename = "__base__/graphics/entity/rocket-silo/hr-03-rocket-over-shadow-over-rocket.png",
            width = 426,
            height = 288,
            shift = util.by_pixel(-2 * scale, 21 * scale),
            scale = 0.5 * scale
        }
    },
    rocket_glow_overlay_sprite = {
        filename = "__base__/graphics/entity/rocket-silo/03-rocket-over-glow.png",
        blend_mode = "additive",
        width = 218,
        height = 222,
        shift = util.by_pixel(-4 * scale, 36 * scale),
        scale = scale,
        hr_version = {
            filename = "__base__/graphics/entity/rocket-silo/hr-03-rocket-over-glow.png",
            blend_mode = "additive",
            width = 434,
            height = 446,
            shift = util.by_pixel(-3 * scale, 36 * scale),
            scale = 0.5 * scale
        }
    },

    door_back_sprite = {
        filename = "__base__/graphics/entity/rocket-silo/04-door-back.png",
        width = 158,
        height = 144,
        shift = util.by_pixel(36 * scale, 12 * scale),
        scale = scale,
        hr_version = {
            filename = "__base__/graphics/entity/rocket-silo/hr-04-door-back.png",
            width = 312,
            height = 286,
            shift = util.by_pixel(37 * scale, 12 * scale),
            scale = 0.5 * scale
        }
    },
    door_back_open_offset = {1.8 * scale, -1.8 * 0.43299225 * scale},
    door_front_sprite = {
        filename = "__base__/graphics/entity/rocket-silo/05-door-front.png",
        width = 166,
        height = 152,
        shift = util.by_pixel(-28 * scale, 32 * scale),
        scale = scale,
        hr_version = {
            filename = "__base__/graphics/entity/rocket-silo/hr-05-door-front.png",
            width = 332,
            height = 300,
            shift = util.by_pixel(-28 * scale, 33 * scale),
            scale = 0.5 * scale
        }
    },
    door_front_open_offset = {-1.8 * scale, 1.8 * 0.43299225 * scale},
    base_day_sprite = {
        layers = {
            {
                filename = "__base__/graphics/entity/rocket-silo/06-rocket-silo.png",
                width = 300,
                height = 300,
                shift = util.by_pixel(2 * scale, -2 * scale),
                scale = scale,
                hr_version = {
                    filename = "__base__/graphics/entity/rocket-silo/hr-06-rocket-silo.png",
                    width = 608,
                    height = 596,
                    shift = util.by_pixel(3 * scale, -1 * scale),
                    scale = 0.5 * scale
                }
            },
            {
                filename = "__space-exploration-graphics-5__/graphics/entity/probe/sr/06-rocket-silo-mask.png",
                width = 608/2,
                height = 596/2,
                shift = util.by_pixel(3 * scale, -1 * scale),
                scale = scale,
                tint = {r=1,b=0,g=0.5},
                hr_version = {
                    filename = "__space-exploration-graphics-5__/graphics/entity/probe/hr/06-rocket-silo-mask.png",
                    width = 608,
                    height = 596,
                    shift = util.by_pixel(3 * scale, -1 * scale),
                    tint = {r=1,b=0,g=0.5},
                    scale = 0.5 * scale
                }
            },
        }
    },

    red_lights_back_sprites = {
        layers = {
            {
                filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/red-light.png",
                width = 32,
                height = 32,
                shift = adjust_light_position(1.34375, 0.28125),
                scale = scale,
                hr_version = {
                    filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/hr-red-light.png",
                    width = 32,
                    height = 32,
                    shift = adjust_light_position(1.34375, 0.28125),
                    scale = 0.5 * scale
                }
            },
            {
                filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/red-light.png",
                width = 32,
                height = 32,
                shift = adjust_light_position(2.3125, 0.9375),
                scale = scale,
                hr_version = {
                    filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/hr-red-light.png",
                    width = 32,
                    height = 32,
                    shift = adjust_light_position(2.3125, 0.9375),
                    scale = 0.5 * scale
                }
            },
            {
                filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/red-light.png",
                width = 32,
                height = 32,
                shift = adjust_light_position(2.65625, 1.90625),
                scale = scale,
                hr_version = {
                    filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/hr-red-light.png",
                    width = 32,
                    height = 32,
                    shift = adjust_light_position(2.65625, 1.90625),
                    scale = 0.5 * scale
                }
            },
            {
                filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/red-light.png",
                width = 32,
                height = 32,
                shift = adjust_light_position(-2.65625, 1.90625),
                scale = scale,
                hr_version = {
                    filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/hr-red-light.png",
                    width = 32,
                    height = 32,
                    shift = adjust_light_position(-2.65625, 1.90625),
                    scale = 0.5 * scale
                }
            },
            {
                filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/red-light.png",
                width = 32,
                height = 32,
                shift = adjust_light_position(-2.3125, 0.9375),
                scale = scale,
                hr_version = {
                    filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/hr-red-light.png",
                    width = 32,
                    height = 32,
                    shift = adjust_light_position(-2.3125, 0.9375),
                    scale = 0.5 * scale
                }
            },
            {
                filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/red-light.png",
                width = 32,
                height = 32,
                shift = adjust_light_position(-1.34375, 0.28125),
                scale = scale,
                hr_version = {
                    filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/hr-red-light.png",
                    width = 32,
                    height = 32,
                    shift = adjust_light_position(-1.34375, 0.28125),
                    scale = 0.5 * scale
                }
            },
            {
                filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/red-light.png",
                width = 32,
                height = 32,
                shift = adjust_light_position(0, 0),
                scale = scale,
                hr_version = {
                    filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/hr-red-light.png",
                    width = 32,
                    height = 32,
                    shift = adjust_light_position(0, 0),
                    scale = 0.5 * scale
                }
            }
        }
    },

    red_lights_front_sprites = {
        layers = {
            {
                filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/red-light.png",
                width = 32,
                height = 32,
                shift = adjust_light_position(2.3125, 2.8125),
                scale = scale,
                hr_version = {
                    filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/hr-red-light.png",
                    width = 32,
                    height = 32,
                    shift = adjust_light_position(2.3125, 2.8125),
                    scale = 0.5 * scale
                }
            },
            {
                filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/red-light.png",
                width = 32,
                height = 32,
                shift = adjust_light_position(1.34375, 3.40625),
                scale = scale,
                hr_version = {
                    filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/hr-red-light.png",
                    width = 32,
                    height = 32,
                    shift = adjust_light_position(1.34375, 3.40625),
                    scale = 0.5 * scale
                }
            },
            {
                filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/red-light.png",
                width = 32,
                height = 32,
                shift = adjust_light_position(0, 3.75),
                scale = scale,
                hr_version = {
                    filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/hr-red-light.png",
                    width = 32,
                    height = 32,
                    shift = adjust_light_position(0, 3.75),
                    scale = 0.5 * scale
                }
            },
            {
                filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/red-light.png",
                width = 32,
                height = 32,
                shift = adjust_light_position(-1.34375, 3.40625),
                scale = scale,
                hr_version = {
                    filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/hr-red-light.png",
                    width = 32,
                    height = 32,
                    shift = adjust_light_position(-1.34375, 3.40625),
                    scale = 0.5 * scale
                }
            },
            {
                filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/red-light.png",
                width = 32,
                height = 32,
                shift = adjust_light_position(-2.3125, 2.8125),
                scale = scale,
                hr_version = {
                    filename = "__base__/graphics/entity/rocket-silo/07-red-lights-back/hr-red-light.png",
                    width = 32,
                    height = 32,
                    shift = adjust_light_position(-2.3125, 2.8125),
                    scale = 0.5 * scale
                }
            }
        }
    },
    satellite_animation = {
        filename = "__base__/graphics/entity/rocket-silo/15-rocket-silo-turbine.png",
        priority = "medium",
        width = 28,
        height = 46,
        frame_count = 32,
        line_length = 8,
        animation_speed = 0.4,
        shift = util.by_pixel(-100 * scale, (110-1.375) * scale),
        scale = scale,
        hr_version = {
            filename = "__base__/graphics/entity/rocket-silo/hr-15-rocket-silo-turbine.png",
            priority = "medium",
            width = 54,
            height = 88,
            frame_count = 32,
            line_length = 8,
            animation_speed = 0.4,
            shift = util.by_pixel(-100 * scale, (111-1.375) * scale),
            scale = 0.5 * scale
        }
    },
    arm_01_back_animation = {
        filename = "__base__/graphics/entity/rocket-silo/08-rocket-silo-arms-back.png",
        priority = "medium",
        width = 66,
        height = 76,
        frame_count = 32,
        line_length = 32,
        animation_speed = 0.3,
        shift = util.by_pixel(-54 * scale, -84 * scale),
        scale = scale,
        hr_version = {
            filename = "__base__/graphics/entity/rocket-silo/hr-08-rocket-silo-arms-back.png",
            priority = "medium",
            width = 128,
            height = 150,
            frame_count = 32,
            line_length = 32,
            animation_speed = 0.3,
            shift = util.by_pixel(-53 * scale, -84 * scale),
            scale = 0.5 * scale
        }
    },
    arm_02_right_animation = {
        filename = "__base__/graphics/entity/rocket-silo/08-rocket-silo-arms-right.png",
        priority = "medium",
        width = 94,
        height = 94,
        frame_count = 32,
        line_length = 32,
        animation_speed = 0.3,
        shift = util.by_pixel(100 * scale, -38 * scale),
        scale = scale,
        hr_version = {
            filename = "__base__/graphics/entity/rocket-silo/hr-08-rocket-silo-arms-right.png",
            priority = "medium",
            width = 182,
            height = 188,
            frame_count = 32,
            line_length = 32,
            animation_speed = 0.3,
            shift = util.by_pixel(101 * scale, -38 * scale),
            scale = 0.5 * scale
        }
    },
    arm_03_front_animation = {
        filename = "__base__/graphics/entity/rocket-silo/13-rocket-silo-arms-front.png",
        priority = "medium",
        width = 66,
        height = 114,
        frame_count = 32,
        line_length = 32,
        animation_speed = 0.3,
        shift = util.by_pixel(-52 * scale, 16 * scale),
        scale = scale,
        hr_version = {
            filename = "__base__/graphics/entity/rocket-silo/hr-13-rocket-silo-arms-front.png",
            priority = "medium",
            width = 126,
            height = 228,
            frame_count = 32,
            line_length = 32,
            animation_speed = 0.3,
            shift = util.by_pixel(-51 * scale, 16 * scale),
            scale = 0.5 * scale
        }
    },
  base_front_sprite = {
    layers = {
      {
        filename = "__base__/graphics/entity/rocket-silo/14-rocket-silo-front.png",
        width = 292,
        height = 132,
        shift = util.by_pixel(-2 * scale, 78 * scale),
        scale = scale,
        hr_version =
        {
          filename = "__base__/graphics/entity/rocket-silo/hr-14-rocket-silo-front.png",
          width = 580,
          height = 262,
          shift = util.by_pixel(-1 * scale, 78 * scale),
          scale = 0.5 * scale
        }
      },
      {
        filename = "__space-exploration-graphics-5__/graphics/entity/probe/sr/14-rocket-silo-front-mask.png",
        width = 580/2,
        height = 262/2,
        shift = util.by_pixel(-1 * scale, 78 * scale),
        tint = {r=1,b=0,g=0.5},
        scale = scale,
        hr_version =
        {
          filename = "__space-exploration-graphics-5__/graphics/entity/probe/hr/14-rocket-silo-front-mask.png",
          width = 580,
          height = 262,
          shift = util.by_pixel(-1 * scale, 78 * scale),
          tint = {r=1,b=0,g=0.5},
          scale = 0.5 * scale
        }
      },
    }
  },
-- of scaling and adjusting shift values

silo_fade_out_start_distance = 8 * scale,
silo_fade_out_end_distance = 15 * scale,

-- Keep the sound definitions as they are
alarm_sound = {
    filename = "__base__/sound/silo-alarm.ogg",
    volume = 1.0
},
clamps_on_sound = {
    filename = "__base__/sound/silo-clamps-on.ogg",
    volume = 1.0
},
clamps_off_sound = {
    filename = "__base__/sound/silo-clamps-off.ogg",
    volume = 0.8
},
doors_sound = {
    filename = "__base__/sound/silo-doors.ogg",
    volume = 0.8
},
raise_rocket_sound = {
    filename = "__base__/sound/silo-raise-rocket.ogg",
    volume = 1.0
},
flying_sound = {
    filename = "__base__/sound/silo-rocket.ogg",
    volume = 1.0,
    audible_distance_modifier = 3
}
}

data:extend({spidertron_launcher})
local scale = 0.4

local function copy_and_scale_animation(original, scale, vertical_shift)
    if not original then return nil end
    local copy = table.deepcopy(original)
    copy.scale = (copy.scale or 1) * scale
    copy.shift = {
        ((copy.shift and copy.shift[1]) or 0) * scale,
        ((copy.shift and copy.shift[2]) or 0) * scale + vertical_shift
    }
    if copy.hr_version then
        copy.hr_version.scale = (copy.hr_version.scale or 0.5) * scale
        copy.hr_version.shift = {
            ((copy.hr_version.shift and copy.hr_version.shift[1]) or 0) * scale,
            ((copy.hr_version.shift and copy.hr_version.shift[2]) or 0) * scale + vertical_shift
        }
    end
    return copy
end
local spidertron_rocket = table.deepcopy(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"])
spidertron_rocket.name = "spidertron-launcher-rocket"

-- Create scaled copies of all rocket animations
local rocket_sprite = copy_and_scale_animation(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"].rocket_sprite, scale, vertical_shift)
local rocket_shadow_sprite = copy_and_scale_animation(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"].rocket_shadow_sprite, scale, vertical_shift)
local rocket_glare_overlay = copy_and_scale_animation(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"].rocket_glare_overlay, scale, vertical_shift)
local rocket_smoke_top1 = copy_and_scale_animation(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"].rocket_smoke_top1_animation, scale, vertical_shift)
local rocket_smoke_top2 = copy_and_scale_animation(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"].rocket_smoke_top2_animation, scale, vertical_shift)
local rocket_smoke_top3 = copy_and_scale_animation(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"].rocket_smoke_top3_animation, scale, vertical_shift)
local rocket_smoke_bottom1 = copy_and_scale_animation(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"].rocket_smoke_bottom1_animation, scale, vertical_shift)
local rocket_smoke_bottom2 = copy_and_scale_animation(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"].rocket_smoke_bottom2_animation, scale, vertical_shift)
local rocket_smoke_bottom3 = copy_and_scale_animation(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"].rocket_smoke_bottom3_animation, scale, vertical_shift)
local rocket_flame = copy_and_scale_animation(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"].rocket_flame_animation, scale, vertical_shift)
local rocket_flame_left = copy_and_scale_animation(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"].rocket_flame_left_animation, scale, vertical_shift)
local rocket_flame_right = copy_and_scale_animation(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"].rocket_flame_right_animation, scale, vertical_shift)


-- Assign scaled animations
spidertron_rocket.rocket_sprite = rocket_sprite
spidertron_rocket.rocket_shadow_sprite = rocket_shadow_sprite
spidertron_rocket.rocket_glare_overlay = rocket_glare_overlay
spidertron_rocket.rocket_smoke_top1_animation = rocket_smoke_top1
spidertron_rocket.rocket_smoke_top2_animation = rocket_smoke_top2
spidertron_rocket.rocket_smoke_top3_animation = rocket_smoke_top3
spidertron_rocket.rocket_smoke_bottom1_animation = rocket_smoke_bottom1
spidertron_rocket.rocket_smoke_bottom2_animation = rocket_smoke_bottom2
spidertron_rocket.rocket_smoke_bottom3_animation = rocket_smoke_bottom3
spidertron_rocket.rocket_flame_animation = rocket_flame
spidertron_rocket.rocket_flame_left_animation = rocket_flame_left
spidertron_rocket.rocket_flame_right_animation = rocket_flame_right

-- Adjust the rocket launch animation
spidertron_rocket.rocket_rising_animation = copy_and_scale_animation(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"].rocket_rising_animation, scale, 0)
spidertron_rocket.rocket_falling_animation = copy_and_scale_animation(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"].rocket_falling_animation, scale, 0)

-- Adjust the rocket launch offset and height
spidertron_rocket.rocket_launch_offset = {0, -256 * scale}
spidertron_rocket.rocket_shadow_sprite.shift = {-1.2, 1 * scale}

-- Adjust clipping for the rocket entity
spidertron_rocket.rocket_visible_distance_from_center = 2.5 * scale
--spidertron_rocket.rocket_render_layer_switch_distance = 5.5 * scale


-- Function to adjust animation shifting
local function adjust_animation_shift(animation, vertical_adjust)
    if animation then
        animation.shift = {
            animation.shift[1],
            (animation.shift[2] or 0) + vertical_adjust
        }
        if animation.hr_version then
            animation.hr_version.shift = {
                animation.hr_version.shift[1],
                (animation.hr_version.shift[2] or 0) + vertical_adjust
            }
        end
    end
end

-- Adjust smoke and flame animations to align with the scaled rocket
local vertical_adjust = -2 * scale  -- Adjust this value as needed
adjust_animation_shift(spidertron_rocket.rocket_smoke_top1_animation, vertical_adjust+0.8)
adjust_animation_shift(spidertron_rocket.rocket_smoke_top2_animation, vertical_adjust+0.8)
adjust_animation_shift(spidertron_rocket.rocket_smoke_top3_animation, vertical_adjust+0.8)
adjust_animation_shift(spidertron_rocket.rocket_smoke_bottom1_animation, vertical_adjust+0.8)
adjust_animation_shift(spidertron_rocket.rocket_smoke_bottom2_animation, vertical_adjust+0.8)
adjust_animation_shift(spidertron_rocket.rocket_smoke_bottom3_animation, vertical_adjust+0.8)
adjust_animation_shift(spidertron_rocket.rocket_flame_animation, vertical_adjust+0.8)
adjust_animation_shift(spidertron_rocket.rocket_flame_left_animation, vertical_adjust+0.8)
adjust_animation_shift(spidertron_rocket.rocket_flame_right_animation, vertical_adjust+0.8)
adjust_animation_shift(spidertron_rocket.rocket_shadow_sprite, vertical_adjust+0.8)

-- Add the new spidertron rocket to the game data
data:extend({spidertron_rocket})