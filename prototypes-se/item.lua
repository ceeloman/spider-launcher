-- Define the spidertron launcher item
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

data:extend({
  {
      type = "item",
      name = "orbital-rocket-spidertron",
      icon = "__base__/graphics/icons/rocket.png",
      icon_size = 64,
      icon_mipmaps = 4,
      icons = {
          {
              icon = "__base__/graphics/icons/rocket.png",
              icon_size = 64,
              icon_mipmaps = 4
          }
      },
      subgroup = "transport",
      order = "b[personal-transport]-c[spidertron]-b[launcher]",
      stack_size = 1
  }
})