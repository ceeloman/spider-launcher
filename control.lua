-- Determine which mods are active
local is_space_age_active = script.active_mods["space-age"] ~= nil
local is_space_exploration_active = script.active_mods["space-exploration"] ~= nil

-- Debug logging function
local function debug_log(message)
    log("[Orbital Spidertron] " .. message)
end

-- debug_log("Loading orbital spidertron launcher mod")

-- Load the appropriate compatibility script
if is_space_exploration_active then
    -- debug_log("Loading Space Exploration compatibility")
    require("scripts-se.control")
elseif is_space_age_active then
    -- debug_log("Loading Space Age compatibility")
    require("scripts-sa.control")
else
    -- debug_log("ERROR: Neither Space Exploration nor Space Age is active!")
end

-- debug_log("Control script loaded")