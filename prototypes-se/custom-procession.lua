-- prototypes-se/custom-procession.lua
local procession_graphic_catalogue_types = require("__base__/prototypes/planet/procession-graphic-catalogue-types")

local OVD_PROCESSION_STYLE = 99

data:extend({
  -- DEPARTURE - Absolute minimum
  {
    type = "procession",
    name = "ovd-cargo-bay-departure",
    usage = "departure",
    procession_style = OVD_PROCESSION_STYLE,
    timeline = {
      duration = 100,
      layers = {
        {
          type = "pod-movement",
          frames = {
            {
              offset = {0, 0},
              offset_t = {0, -40},
              tilt = 0,
              tilt_t = 0,
              timestamp = 0
            },
            {
              offset = {0, -70},
              offset_t = {0, 0},
              tilt = 0,
              tilt_t = 0,
              timestamp = 100
            }
          }
        },
        {
          type = "pod-opacity",
          lut = "__core__/graphics/color_luts/lut-day.png",
          frames = {
            {
              outside_opacity = 1,
              timestamp = 100
            },
            {
              outside_opacity = 0,
              timestamp = 150
            }
          }
        }
      }
    }
  },
  
  -- INTERMEZZO
  {
    type = "procession",
    name = "ovd-cargo-bay-intermezzo",
    usage = "intermezzo",
    procession_style = OVD_PROCESSION_STYLE,
    timeline = {
      duration = 60,
      layers = {
        {
          type = "pod-movement",
          frames = {
            {
              offset = {0, 0},
              tilt = 0,
              tilt_t = 0,
              timestamp = 0
            },
            {
              offset = {0, 0},
              tilt = 0,
              tilt_t = 0,
              timestamp = 60
            }
          }
        }
      }
    }
  },
  
  -- ARRIVAL
  {
    type = "procession",
    name = "ovd-cargo-bay-arrival",
    usage = "arrival",
    procession_style = OVD_PROCESSION_STYLE,
    timeline = {
      duration = 100,
      layers = {
        {
          type = "pod-movement",
          frames = {
            {
              offset = {0, 0},
              offset_t = {0, -40},
              tilt = 0,
              tilt_t = 0,
              timestamp = 0
            },
            {
              offset = {0, -70},
              offset_t = {0, 0},
              tilt = 0,
              tilt_t = 0,
              timestamp = 100
            }
          }
        },
        {
          type = "pod-opacity",
          lut = "__core__/graphics/color_luts/lut-day.png",
          frames = {
            {
              outside_opacity = 1,
              timestamp = 100
            },
            {
              outside_opacity = 0,
              timestamp = 150
            }
          }
        }
      }
    }
  }
})