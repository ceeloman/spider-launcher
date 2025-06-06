data:extend({
    {
      type = "technology",
      name = "spidertron-launcher-rocket",
      icon_size = 256,
      icon = "__base__/graphics/entity/rocket-silo/06-rocket-silo.png",
      effects = {
        {
          type = "unlock-recipe",
          recipe = "spidertron-launcher"
        },
        {
          type = "unlock-recipe",
          recipe = "spidertron-rocket-launch"
        },
        {
            type = "unlock-recipe",
            recipe = "orbital-rocket-spidertron"
        }
      },
      prerequisites = {"spidertron", "rocket-silo"},
      unit = {
          count = 1000,
          ingredients = {
              {"automation-science-pack", 1},
              {"logistic-science-pack", 1},
              {"chemical-science-pack", 1},
              {"production-science-pack", 1},
              {"utility-science-pack", 1},
              {"space-science-pack", 1}
          },
          time = 60
      },
      order = "d-e-g"
  }
})