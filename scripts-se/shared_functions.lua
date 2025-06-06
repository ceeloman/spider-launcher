local shared = {}

--function shared.create_smoke_and_fire(surface, position)
--    surface.create_entity({name = "huge-explosion", position = position})
--    for i = 1, 10 do
--        local smoke_position = {
--            x = position.x + (math.random() - 0.5) * 2,
--            y = position.y + (math.random() - 0.5) * 2
--        }
--        surface.create_entity({name = "explosion-remnants-particle", position = smoke_position})
--    end
--    surface.create_entity({name = "fire-flame", position = position})
--end

function shared.create_fragments(surface, position)
    local fragment_types = {"small-remnants", "medium-remnants", "big-remnants"}
    for i = 1, 5 do
        local fragment_position = {
            x = position.x + (math.random() - 0.5) * 10,
            y = position.y + (math.random() - 0.5) * 10
        }
        surface.create_entity({
            name = fragment_types[math.random(#fragment_types)],
            position = fragment_position
        })
    end
end

function shared.distribute_items(spidertron, chest)
    local items_to_distribute = {
        "construction-robot",
        "repair-pack",
        "copper-plate",
        "iron-plate",
        "steel-plate",
        "explosive-rocket"
    }
    
    for _, item_name in ipairs(items_to_distribute) do
        local total_amount = math.random(50, 200)
        local spider_amount = math.random(0, total_amount)
        local chest_amount = total_amount - spider_amount
        
        if spider_amount > 0 then
            spidertron.get_inventory(defines.inventory.spider_trunk).insert({name = item_name, count = spider_amount})
        end
        if chest_amount > 0 then
            chest.insert({name = item_name, count = chest_amount})
        end
    end
end

return shared