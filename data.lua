-- First check which mods are available
local is_space_age_active = mods["space-age"] ~= nil
local is_space_exploration_active = mods["space-exploration"] ~= nil

-- Require at least one of the space mods
if not is_space_age_active and not is_space_exploration_active then
  error("spider-launcher requires either 'space-age' or 'space-exploration' to be installed and enabled!")
end

-- Load the appropriate entity file based on active mods
if is_space_exploration_active then
  require("prototypes-se.entity")
  require("prototypes-se.item")
  require("prototypes-se.recipe")
  require("prototypes-se.shortcuts")  -- SE shortcut definition
  -- require("prototypes-se.technology")  -- commented out for now
  -- require("prototypes-se.custom-inputs")
  -- require("prototypes-se.launch")
  -- require("prototypes-se.projectiles")
  -- require("prototypes-se.smoke")
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

data:extend({
  {
    type = "sprite",
    name = "ovd_stack",
    filename = "__spider-launcher__/graphics/icons/stack.png",
    size = 64,
    mipmap_count = 4,
    flags = {"icon"}
  }
})