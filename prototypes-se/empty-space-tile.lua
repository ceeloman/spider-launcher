-- prototypes-se/empty-space-tile.lua

-- Only create empty-space tile if it doesn't already exist
if not data.raw.tile["empty-space"] then
    local empty_space = table.deepcopy(data.raw.tile["out-of-map"])
    empty_space.name = "empty-space"
    data:extend{empty_space}
  end