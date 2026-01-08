-- scripts-sa/vehicles-list.lua
local vehicles_list = {}

-- Excluded vehicle types (e.g., locomotives, wagons)
-- Probably should exclude locomotives vehicle types, rather than by name
-- at the same time we only search for cars / spider-vehicles so it shouldnt be an issue
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
    
    if not vehicles_list.construction_robots then
        vehicles_list.construction_robots = {}
    end
    
    if not vehicles_list.logistic_robots then
        vehicles_list.logistic_robots = {}
    end
    
    if not vehicles_list.repair_tools then
        vehicles_list.repair_tools = {}
    end

    -- Iterate over all entity prototypes for vehicles
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
        
        -- Check for robot types
        if prototype.type == "construction-robot" then
            local minable = prototype.mineable_properties
            if minable and minable.products and #minable.products > 0 then
                local item_name = minable.products[1].name
                table.insert(vehicles_list.construction_robots, item_name)
            end
        elseif prototype.type == "logistic-robot" then
            local minable = prototype.mineable_properties
            if minable and minable.products and #minable.products > 0 then
                local item_name = minable.products[1].name
                table.insert(vehicles_list.logistic_robots, item_name)
            end
        end
    end
    
    -- Iterate over item prototypes for repair tools
    for name, prototype in pairs(prototypes.item) do
        if prototype.type == "repair-tool" then
            table.insert(vehicles_list.repair_tools, name)
        end
    end

    -- Log the found items
    -- log("Found " .. #vehicles_list.all_vehicles .. " valid vehicles")
    -- log("Found " .. #vehicles_list.spider_vehicles .. " spider vehicles")
    -- log("Found " .. #vehicles_list.construction_robots .. " construction robots")
    -- log("Found " .. #vehicles_list.logistic_robots .. " logistic robots")
    -- log("Found " .. #vehicles_list.repair_tools .. " repair tools")

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

-- Function to check if an item is a construction robot
function vehicles_list.is_construction_robot(item_name)
    -- Initialize lists if not done
    if not vehicles_list.construction_robots then
        vehicles_list.initialize()
    end
    
    for _, name in ipairs(vehicles_list.construction_robots) do
        if item_name == name then
            return true
        end
    end
    
    return false
end

-- Function to check if an item is a logistic robot
function vehicles_list.is_logistic_robot(item_name)
    -- Initialize lists if not done
    if not vehicles_list.logistic_robots then
        vehicles_list.initialize()
    end
    
    for _, name in ipairs(vehicles_list.logistic_robots) do
        if item_name == name then
            return true
        end
    end
    
    return false
end

-- Function to check if an item is a repair tool
function vehicles_list.is_repair_tool(item_name)
    -- Initialize lists if not done
    if not vehicles_list.repair_tools then
        vehicles_list.initialize()
    end
    
    for _, name in ipairs(vehicles_list.repair_tools) do
        if item_name == name then
            return true
        end
    end
    
    return false
end

return vehicles_list