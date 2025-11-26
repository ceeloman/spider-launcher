-- prototypes-se/item.lua

data:extend({
    {
      type = "item",
      name = "ovd-deployment-container",
      icon = "__spider-launcher__/graphics/icons/cargo-bay.png",
      icon_size = 64,
      subgroup = "storage",
      order = "a[items]-c[ovd-deployment]",
      stack_size = 10,
      place_result = "ovd-deployment-container"
    }
  })