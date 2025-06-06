local smoke_animations = require "__base__/prototypes/entity/smoke-animations"

-- Calls generator function from base.prototypes.entity.smoke-animations.lua
local smoke = smoke_animations.trivial_smoke{
  name = "orbital-spidertron-deploy-smoke",
  duration = 60,
  fade_away_duration = 30,
  spread_duration = 20,
  start_scale = 0.5,
  end_scale = 1.5,
  color = {r=0.9, g=0.9, b=0.9, a=0.6},
  affected_by_wind = false
}
smoke.animation.shift = {-0.2, -0.3}

data:extend{smoke}

-- Optionally, add a sound effect for deployment
data:extend{
  {
    type = "sound",
    name = "orbital-spidertron-deploy-sound",
    filename = "__base__/sound/spidertron/spidertron-activate.ogg",
    volume = 0.7
  }
}