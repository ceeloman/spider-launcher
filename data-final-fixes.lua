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

local function create_quality_overlay_sprites()
    for name, quality in pairs(data.raw.quality or {}) do
        local quality_name = string.lower(name)
        if quality_name == "quality-unknown" then goto continue end
        local sprite_name = "sl-" .. quality_name
        if data.raw["sprite"][sprite_name] then goto continue end
        
        local layers = {}
        if not quality.icons or #quality.icons == 0 then
            -- Fallback to quality prototype's icon field
            local icon_path = quality.icon or "__core__/graphics/quality-pips/" .. quality_name .. ".png"
            local icon_size = 64 -- Force 32x32 for base quality pips
            --log("No icons defined for base quality " .. quality_name .. ", using fallback icon: " .. icon_path .. " with icon_size: " .. icon_size)
            table.insert(layers, {
                filename = icon_path,
                width = icon_size,
                height = icon_size,
                scale = 14 / icon_size, -- Scale to 14x14 for overlay
                flags = {"gui-icon"}
            })
        else
            -- Use all layers from quality.icons
            for _, layer in ipairs(quality.icons) do
                local icon_path = layer.icon
                local icon_size = layer.icon_size or 64
                local scale = 14 / icon_size -- Scale to 14x14 for overlay
                local tint = layer.tint
                --log("Layer for quality " .. quality_name .. ": " .. icon_path .. ", icon_size: " .. icon_size)
                table.insert(layers, {
                    filename = icon_path,
                    width = icon_size,
                    height = icon_size,
                    scale = scale,
                    tint = tint,
                    flags = {"gui-icon"}
                })
            end
        end
        
        -- Create a layered sprite
        data:extend({
            {
                type = "sprite",
                name = sprite_name,
                layers = layers
            }
        })
        --log("Created quality overlay sprite: " .. sprite_name .. " with " .. #layers .. " layers")
        
        ::continue::
    end
end

local function create_filtered_fuel_sprites()
    for name, item in pairs(data.raw["item"]) do
        --log("Evaluating item: " .. name)
        if item.fuel_value then
            --log("Item " .. name .. " has fuel_value: " .. tostring(item.fuel_value))
            if item.fuel_category == "chemical" then
                --log("Item " .. name .. " is in chemical category")
                if not string.find(name:lower(), "seed") and
                   not string.find(name:lower(), "egg") and
                   not string.find(name:lower(), "spoil") then
                    --log("Item " .. name .. " passes name filters (no seed/egg/spoil)")
                    if item.spoil_result == nil then
                        --log("Item " .. name .. " has no spoil_result, creating sprite")
                        create_entity_sprite_from_item(item, name, "sl-")
                    else
                        --log("Item " .. name .. " has spoil_result, skipping")
                    end
                else
                    --log("Item " .. name .. " contains seed/egg/spoil, skipping")
                end
            else
                --log("Item " .. name .. " is not in chemical category, skipping")
            end
        else
            --log("Item " .. name .. " has no fuel_value, skipping")
        end
    end
end

local function create_special_item_sprites()
    for name, item in pairs(data.raw["repair-tool"]) do
        create_entity_sprite_from_item(item, name, "sl-")
    end
    for name, item in pairs(data.raw["ammo"]) do
        create_entity_sprite_from_item(item, name, "sl-")
    end
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

-- Register functions to run at data-final-fixes stage
create_special_item_sprites()
create_filtered_fuel_sprites()
create_quality_overlay_sprites()