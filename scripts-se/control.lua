-- control.lua

script.on_event(defines.events.on_built_entity, function(event)
    local entity = event.created_entity or event.entity
    if not entity or not entity.valid then return end
    
    if entity.name == "ovd-deployment-container" then
      -- Snap position to grid (2x2 grid for cargo-bay alignment)
      local grid_size = 2
      local snapped_x = math.floor(entity.position.x / grid_size + 0.5) * grid_size
      local snapped_y = math.floor(entity.position.y / grid_size + 0.5) * grid_size
      local snapped_position = {snapped_x, snapped_y}
      
      -- Create the cargo bay visual on top
      local cargo_bay = entity.surface.create_entity{
        name = "ovd-cargo-bay",
        position = snapped_position,
        force = entity.force,
        create_build_effect_smoke = false
      }
      
      if cargo_bay and cargo_bay.valid then
        cargo_bay.destructible = false  -- Can't be damaged separately
        cargo_bay.minable = false  -- Can't be mined separately
        
        -- Store the link between them
        storage.cargo_bay_links = storage.cargo_bay_links or {}
        storage.cargo_bay_links[entity.unit_number] = cargo_bay
      end
    end
  end)
  
  script.on_event(defines.events.on_player_mined_entity, function(event)
    local entity = event.entity
    if not entity or not entity.valid then return end
    
    if entity.name == "ovd-deployment-container" then
      -- Destroy the linked cargo bay
      if storage.cargo_bay_links and storage.cargo_bay_links[entity.unit_number] then
        local cargo_bay = storage.cargo_bay_links[entity.unit_number]
        if cargo_bay and cargo_bay.valid then
          cargo_bay.destroy()
        end
        storage.cargo_bay_links[entity.unit_number] = nil
      end
    end
  end)
  
  script.on_event(defines.events.on_entity_died, function(event)
    local entity = event.entity
    if not entity or not entity.valid then return end
    
    if entity.name == "ovd-deployment-container" then
      -- Destroy the linked cargo bay
      if storage.cargo_bay_links and storage.cargo_bay_links[entity.unit_number] then
        local cargo_bay = storage.cargo_bay_links[entity.unit_number]
        if cargo_bay and cargo_bay.valid then
          cargo_bay.destroy()
        end
        storage.cargo_bay_links[entity.unit_number] = nil
      end
    end
  end)