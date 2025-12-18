local function create_entity_sprite_from_item(item_prototype, item_name, prefix)
    local sprite_name = prefix .. item_name
    if data.raw["sprite"][sprite_name] then return end
    
    local icon_path = item_prototype.icon
    local icon_size = item_prototype.icon_size
    local icon_mipmaps = item_prototype.icon_mipmaps
    
    -- Handle icons table (layered icons)
    if not icon_path and item_prototype.icons then
        local first_icon = item_prototype.icons[1]
        if first_icon then
            icon_path = first_icon.icon
            -- Use icon_size from the first icon layer if available, otherwise from prototype
            icon_size = first_icon.icon_size or item_prototype.icon_size
            icon_mipmaps = first_icon.icon_mipmaps or item_prototype.icon_mipmaps
        end
    end
    
    if not icon_path then return end
    
    -- Default to 64 only if no icon_size is found anywhere
    icon_size = icon_size or 64
    
    local gui_size = 28 -- Target GUI size in pixels
    local scale = gui_size / icon_size -- Scale to match 28x28 GUI containers
    
    local sprite_def = {
        type = "sprite",
        name = sprite_name,
        filename = icon_path,
        priority = "medium",
        width = icon_size,
        height = icon_size,
        scale = scale,
        flags = {"gui-icon"}
    }
    
    -- Only add icon_mipmaps if it exists
    if icon_mipmaps then
        sprite_def.icon_mipmaps = icon_mipmaps
    end
    
    data:extend({sprite_def})
    
    return sprite_name
end

local function create_filtered_fuel_sprites()
    for name, item in pairs(data.raw["item"]) do
        if item.fuel_value then
            if item.fuel_category == "chemical" then
                if not string.find(name:lower(), "seed") and
                   not string.find(name:lower(), "egg") and
                   not string.find(name:lower(), "spoil") then
                    if item.spoil_result == nil then
                        create_entity_sprite_from_item(item, name, "sl-")
                    end
                end
            end
        end
    end
end

-- Process all items that need entity sprites
local function create_special_item_sprites()
    -- Process repair tools
    for name, item in pairs(data.raw["repair-tool"]) do
        create_entity_sprite_from_item(item, name, "sl-")
    end
    
    -- Process ammo
    for name, item in pairs(data.raw["ammo"]) do
        create_entity_sprite_from_item(item, name, "sl-")
    end
    
    -- Process specific robot types
    local special_items = {
        "construction-robot",
        "logistic-robot"
    }
    
    for _, item_name in pairs(special_items) do
        local item = data.raw["item"][item_name]
        if item then
            create_entity_sprite_from_item(item, item_name, "sl-")
        end
    end
end


-- Function to create quality overlay sprites using data.raw.quality
local function create_quality_overlay_sprites()
    -- Check if quality system exists (Space Age feature)
    if not data.raw.quality then
        return
    end
    
    for name, quality in pairs(data.raw.quality) do
        local quality_name = string.lower(name)
        -- Skip "unknown" quality
        if quality_name == "quality-unknown" then
            goto continue
        end
        local sprite_name = "sl-" .. quality_name
        
        -- Skip if sprite already exists
        if data.raw["sprite"][sprite_name] then
            goto continue
        end
        
        -- Determine the icon path, size, and tint
        local icon_path, icon_size, tint
        if quality.icons and quality.icons[2] then
            -- Use the second icon (tinted pip) for modded qualities
            icon_path = quality.icons[2].icon
            icon_size = quality.icons[2].icon_size or 64
            tint = quality.icons[2].tint
        elseif quality.icons and quality.icons[1] then
            -- Fallback to first icon if second is unavailable
            icon_path = quality.icons[1].icon
            icon_size = quality.icons[1].icon_size or 64
            tint = quality.icons[1].tint
        elseif quality.icon then
            -- Use single icon for vanilla qualities
            icon_path = quality.icon
            icon_size = quality.icon_size or 64
        else
            -- Fallback to vanilla path
            icon_path = "__base__/graphics/icons/" .. quality_name .. ".png"
            icon_size = 64
        end
        
        -- Create the sprite
        local sprite = {
            type = "sprite",
            name = sprite_name,
            filename = icon_path,
            priority = "medium",
            width = icon_size,
            height = icon_size,
            scale = 14 / icon_size, -- Scale to match 14x14 GUI overlay
            flags = {"gui-icon"}
        }
        if tint then
            sprite.tint = tint
        end
        
        data:extend({ sprite })
        
        ::continue::
    end
end

-- Verify rocket-silo entity definition
-- local function verify_cargo_landing_pad()
--     local cargo_bay_prototype = data.raw["rocket-silo"]["ovd-cargo-bay"]
--     if not cargo_bay_prototype then
--         --log("[OVD] ERROR: ovd-cargo-bay prototype not found!")
--         return
--     end
    
--     --log("[OVD] Verifying ovd-cargo-bay prototype...")
--     --log("[OVD]   Type: " .. cargo_bay_prototype.type)
--     --log("[OVD]   Name: " .. cargo_bay_prototype.name)
--     --log("[OVD]   Procession style: " .. tostring(cargo_bay_prototype.procession_style))
--     --log("[OVD]   Inventory size: " .. tostring(cargo_bay_prototype.inventory_size))
    
--     -- Check cargo_station_parameters (hatch_definitions are inside this)
--     if cargo_bay_prototype.cargo_station_parameters then
--         --log("[OVD]   cargo_station_parameters found:")
--         --log("[OVD]     is_input_station: " .. tostring(cargo_bay_prototype.cargo_station_parameters.is_input_station))
--         --log("[OVD]     is_output_station: " .. tostring(cargo_bay_prototype.cargo_station_parameters.is_output_station))
        
--         -- Check hatch_definitions inside cargo_station_parameters
--         if cargo_bay_prototype.cargo_station_parameters.hatch_definitions then
--             --log("[OVD]   hatch_definitions found in cargo_station_parameters: " .. #cargo_bay_prototype.cargo_station_parameters.hatch_definitions .. " hatches")
--             for i, hatch_def in ipairs(cargo_bay_prototype.cargo_station_parameters.hatch_definitions) do
--                 --log("[OVD]     Hatch " .. i .. ": offset=" .. tostring(hatch_def.offset))
--                 --log("[OVD]     Hatch " .. i .. ": cargo_unit_entity_to_spawn=" .. tostring(hatch_def.cargo_unit_entity_to_spawn))
--             end
--         else
--             --log("[OVD]   ERROR: hatch_definitions not found in cargo_station_parameters!")
--         end
--     else
--         --log("[OVD]   ERROR: cargo_station_parameters not found!")
--     end
    
--     -- Verify procession definitions
--     local procession_names = {
--         "ovd-cargo-bay-departure",
--         "ovd-cargo-bay-intermezzo",
--         "ovd-cargo-bay-arrival"
--     }
    
--     --log("[OVD] Verifying custom procession definitions...")
--     for _, name in ipairs(procession_names) do
--         local procession_prototype = data.raw["procession"][name]
--         if procession_prototype then
--             if procession_prototype.procession_style == 99 then
--                 --log("[OVD]   ✓ " .. name .. " procession found with style 99")
--                 --log("[OVD]     Usage: " .. (procession_prototype.usage or "unknown"))
--                 --log("[OVD]     Timeline duration: " .. (procession_prototype.timeline and procession_prototype.timeline.duration or "unknown"))
--             else
--                 --log("[OVD]   ERROR: " .. name .. " procession found but style is " .. tostring(procession_prototype.procession_style) .. " (expected 99)!")
--             end
--         else
--             --log("[OVD]   ERROR: " .. name .. " procession NOT found!")
--         end
--     end
    
--     -- Verify that no other processions use style 99 (to avoid conflicts)
--     --log("[OVD] Checking for other processions using style 99...")
--     local other_processions_with_99 = {}
--     for name, procession in pairs(data.raw["procession"] or {}) do
--         -- Exclude our own processions (they all start with "ovd-cargo-bay-")
--         if procession.procession_style == 99 and not (string.sub(name, 1, 13) == "ovd-cargo-bay") then
--             table.insert(other_processions_with_99, name)
--         end
--     end
--     if #other_processions_with_99 > 0 then
--         --log("[OVD]   WARNING: Found other processions using style 99: " .. table.concat(other_processions_with_99, ", "))
--         --log("[OVD]   This may cause conflicts with our custom processions!")
--     else
--         --log("[OVD]   ✓ No other processions use style 99 - our custom processions are unique")
--     end
-- end

-- Register all functions to run at data-final-fixes stage
create_special_item_sprites()
create_filtered_fuel_sprites()
create_quality_overlay_sprites()
-- verify_cargo_landing_pad()
-- Register all functions to run

-- TFMG compatibility: Remove technology unlock requirement for orbital shortcut
if mods["TFMG"] or mods["tfmg"] then
    local shortcut = data.raw["shortcut"]["orbital-spidertron-deploy"]
    if shortcut then
        shortcut.technology_to_unlock = nil
    end
end