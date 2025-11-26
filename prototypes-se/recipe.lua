-- prototypes-se/recipe.lua

data:extend({
    {
      type = "recipe",
      name = "ovd-deployment-container",
      enabled = true,
      ingredients = {
        {type = "item", name = "steel-plate", amount = 20},
        {type = "item", name = "electronic-circuit", amount = 10}
      },
      results = {{type = "item", name = "ovd-deployment-container", amount = 1}}
    }
  })