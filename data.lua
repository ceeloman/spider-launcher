-- First check which mods are available
local is_space_age_active = mods["space-age"] ~= nil
--local is_space_exploration_active = mods["space-exploration"] ~= nil

-- Load the appropriate entity file based on active mods
if is_space_exploration_active then
  require("prototypes-se.entity")
  require("prototypes-se.item")
  require("prototypes-se.recipe")
  require("prototypes-se.technology")
  require("prototypes-se.custom-inputs")
  require("prototypes-se.launch")
  require("prototypes-se.projectiles")
  require("prototypes-se.smoke")
else
  require("prototypes-sa.shortcuts")
end

-- Create a sprite definition
data:extend({
    {
        type = "sprite",
        name = "sl_undo",
        filename = "__base__/graphics/icons/shortcut-toolbar/mip/undo-x56.png",
        priority = "medium",
        width = 56,
        height = 56,
    }
})