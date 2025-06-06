-- In data.lua
local orbital_spidertron_shortcut = {
    type = "shortcut",
    name = "orbital-spidertron-deploy",
    order = "o[spidertron]-a[deploy]",
    action = "lua",
    localised_name = {"", "Orbital Deployment"},
    icon = "__base__/graphics/icons/cargo-pod.png",  -- Main icon
    small_icon = "__base__/graphics/icons/cargo-pod.png",  -- Small icon (required)
    technology_to_unlock = "space-platform"
}

data:extend({orbital_spidertron_shortcut})