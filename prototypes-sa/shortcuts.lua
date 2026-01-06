-- In data.lua
local orbital_spidertron_shortcut = {
    type = "shortcut",
    name = "orbital-spidertron-deploy",
    order = "o[spidertron]-a[deploy]",
    action = "lua",
    localised_name = {"shortcut.orbital-deployment"},
    icon = "__base__/graphics/icons/cargo-pod.png",  -- Main icon
    small_icon = "__base__/graphics/icons/cargo-pod.png",  -- Small icon (required)
    technology_to_unlock = "space-platform"
}

-- TFMG compatibility: Remove technology unlock requirement if TFMG mod is active
if mods["TFMG"] or mods["tfmg"] then
    orbital_spidertron_shortcut.technology_to_unlock = nil
end

data:extend({orbital_spidertron_shortcut})
