local vehicles_list = {}

-- Excluded vehicle types (e.g., locomotives, wagons)
vehicles_list.excluded_names = {
    ["locomotive"] = true,
    ["cargo-wagon"] = true,
    ["fluid-wagon"] = true,
}

-- Initialize vehicle lists
function vehicles_list.initialize()
    -- Ensure lists are initialized
    if not vehicles_list.all_vehicles then
        vehicles_list.all_vehicles = {}
    end

    if not vehicles_list.spider_vehicles then
        vehicles_list.spider_vehicles = {}
    end

    -- Iterate over all entity prototypes
    for name, prototype in pairs(prototypes.entity) do
        -- Check if the prototype is a car or spider-vehicle
        if (prototype.type == "car" or prototype.type == "spider-vehicle") and not vehicles_list.excluded_names[name] then
            local minable = prototype.mineable_properties
            if minable and minable.products and #minable.products > 0 then
                local item_name = minable.products[1].name
                table.insert(vehicles_list.all_vehicles, item_name)
                if prototype.type == "spider-vehicle" then
                    table.insert(vehicles_list.spider_vehicles, item_name)
                end
            end
        end
    end

    -- Log the found vehicles
    --log("Found " .. #vehicles_list.all_vehicles .. " valid vehicles")
    --log("Found " .. #vehicles_list.spider_vehicles .. " spider vehicles")

    return vehicles_list.all_vehicles, vehicles_list.spider_vehicles
end

-- Function to check if an item is a spider vehicle
function vehicles_list.is_spider_vehicle(item_name)
    -- Initialize vehicles list if it hasn't been done
    if not vehicles_list.all_vehicles then
        vehicles_list.initialize()
    end

    for _, name in ipairs(vehicles_list.spider_vehicles) do
        if item_name == name then
            return true
        end
    end

    return false
end

-- Function to check if an item is a valid vehicle
function vehicles_list.is_vehicle(item_name)
    -- Initialize vehicles list if it hasn't been done
    if not vehicles_list.all_vehicles then
        vehicles_list.initialize()
    end

    for _, name in ipairs(vehicles_list.all_vehicles) do
        if item_name == name then
            return true
        end
    end

    return false
end

return vehicles_list

