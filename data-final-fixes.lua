local function create_entity_sprite_from_item(item_prototype, item_name, prefix)
    local sprite_name = prefix .. item_name
    if data.raw["sprite"][sprite_name] then return end
    
    local icon_path = item_prototype.icon
    if not icon_path and item_prototype.icons then
        icon_path = item_prototype.icons[1] and item_prototype.icons[1].icon
    end
    
    if not icon_path then return end
    
    local icon_size = item_prototype.icon_size or 64
    local gui_size = 28 -- Target GUI size in pixels
    local scale = gui_size / icon_size -- Scale to match 28x28 GUI containers
    
    data:extend({
        {
            type = "sprite",
            name = sprite_name,
            filename = icon_path,
            priority = "medium",
            width = icon_size,
            height = icon_size,
            scale = scale,
            flags = {"gui-icon"},
            icon_size = icon_size
        }
    })
    
    return sprite_name
end

local function create_filtered_fuel_sprites()
    for name, item in pairs(data.raw["item"]) do
        -- Log every item being evaluated
        log("Evaluating item: " .. name)
        
        if item.fuel_value then
            log("Item " .. name .. " has fuel_value: " .. tostring(item.fuel_value))
            
            if item.fuel_category == "chemical" then
                log("Item " .. name .. " is in chemical category")
                
                if not string.find(name:lower(), "seed") and
                   not string.find(name:lower(), "egg") and
                   not string.find(name:lower(), "spoil") then
                    log("Item " .. name .. " passes name filters (no seed/egg/spoil)")
                    
                    if item.spoil_result == nil then
                        log("Item " .. name .. " has no spoil_result, creating sprite")
                        create_entity_sprite_from_item(item, name, "sl-")
                    else
                        log("Item " .. name .. " has spoil_result, skipping")
                    end
                else
                    log("Item " .. name .. " contains seed/egg/spoil, skipping")
                end
            else
                log("Item " .. name .. " is not in chemical category, skipping")
            end
        else
            log("Item " .. name .. " has no fuel_value, skipping")
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
    for name, quality in pairs(data.raw.quality or {}) do
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
        
        -- Verify the icon path exists

        
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
        
        log("Created quality overlay sprite " .. sprite_name .. " with icon_size=" .. icon_size .. ", scale=" .. (14 / icon_size) .. ", tint=" .. (tint and string.format("{%g,%g,%g}", tint[1] or tint.r, tint[2] or tint.g, tint[3] or tint.b) or "none"))
        
        ::continue::
    end
end

-- Register all functions to run at data-final-fixes stage
create_special_item_sprites()
create_filtered_fuel_sprites()
create_quality_overlay_sprites()