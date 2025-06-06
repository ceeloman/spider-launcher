data:extend({
  -- Spidertron launch silo
  {
    type = "recipe",
    name = "spidertron-launcher",
    energy_required = 30,
    ingredients = {
        {"rocket-silo", 1},
        {"rocket-control-unit", 10},
        {"low-density-structure", 50},
        {"radar", 5}
    },
    result = "spidertron-launcher",
    enabled = false
  },
  -- Spidertron Probe
  {
      type = "recipe",
      name = "orbital-rocket-spidertron",
      energy_required = 30,
      enabled = false, -- Set to true if you want it available immediately
      ingredients = {
        -- Ingredients for the rocket
        { "rocket-control-unit", 10},
        { "se-cargo-rocket-cargo-pod", 2},
        { "rocket-fuel", 200},
        { "se-cargo-rocket-section", 5},
        -- Supplies for the Spider
        { "explosive-rocket", 800 },
        { "se-iron-ingot", 50 },
        { "se-copper-ingot", 50},
        { "se-steel-ingot", 50},
        { "construction-robot", 50}
      },
      result = "orbital-rocket-spidertron"
  }
})