data:extend({
-- Dummy launch ingredient
   {
    type = "item",
    name = "spidertron-launcher-rocket",
    icon = "__base__/graphics/entity/rocket-silo/02-rocket.png",
    icon_size = 64,
    order = "q[rocket-part]-d",
    stack_size = 1,
    subgroup = "rocket-part",
    flags = {"hidden"}
   },
  -- Dummy launch result
   {
    type = "item",
    name =  "spidertron-rocket-launch",
    icon = "__base__/graphics/entity/rocket-silo/02-rocket.png",
    icon_size = 64,
    order = "q[rocket-part]-e",
    stack_size = 1,
    subgroup = "rocket-part",
    flags = { "hidden" },
   },
   -- Dummy launch recipe
   {
    type = "recipe",
    name = "spidertron-rocket-launch",
    result = "spidertron-rocket-launch",    
    icon = "__base__/graphics/icons/rocket.png",
    icon_size = 64,
    icon_mipmaps = 4,
    category = "rocket-building",
    enabled = false,
    energy_required = 0.01,
    hidden = true,
    ingredients = {
      { "orbital-rocket-spidertron", 1 }
    },
    always_show_made_in = true,
  }
})