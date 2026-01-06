---
name: Factorio API Helper
description: Use Factorio 2.0 API syntax for queries
invokable: true
---
# Factorio 2.0 API Reference

**IMPORTANT:** Factorio 1.1 APIs are deprecated. Always use 2.0 syntax shown below.

---

## STORAGE SYSTEM

### 2.0 (Correct)
```lua
storage.pending_deployments = {}
```

### 1.1 (OUTDATED - DO NOT USE)
```lua
global.pending_deployments = {}
```

### Pattern for Storage Initialization
```lua
-- In on_init or on_configuration_changed
storage.my_data = storage.my_data or {}

-- Access anywhere
storage.my_data[player.index] = value
```

---

## PROTOTYPE ACCESS

### 2.0 (Correct)
```lua
prototypes.item[name]
prototypes.entity[name]
prototypes.quality[name]
```

### 1.1 (OUTDATED - DO NOT USE)
```lua
game.item_prototypes[name]
game.entity_prototypes[name]
```

### Examples
```lua
-- Get item prototype
local item_proto = prototypes.item["iron-plate"]

-- Get entity prototype
local entity_proto = prototypes.entity["assembling-machine-1"]

-- Check if exists
if prototypes.item[item_name] then
    -- item exists
end
```

---

## QUALITY SYSTEM (NEW IN 2.0)

Quality is now a first-class property on items and entities.

### Check Quality on Item Stack
```lua
if stack.quality then
    quality_name = stack.quality.name
end
```

### Quality Names
- `"normal"`
- `"uncommon"`
- `"rare"`
- `"epic"`
- `"legendary"`

### Insert with Quality
```lua
inventory.insert({
    name = "steel-plate",
    count = 100,
    quality = stack.quality
})
```

### Get Quality Prototype
```lua
local quality_proto = prototypes.quality["legendary"]
```

---

## EQUIPMENT GRID CHANGES

### Check if Item Can Be Equipment
```lua
local item_prototype = prototypes.item[item_name]
if item_prototype.place_as_equipment_result then
    -- this item places equipment
end
```

### Detect Equipment Ghosts
```lua
if equipment.prototype.type == "equipment-ghost" then
    base_name = equipment.ghost_name
end
```

---

## CARGO PODS (NEW IN 2.0)

### Create Cargo Pod
```lua
local pod = hub.create_cargo_pod()
```

### Set Destination
```lua
pod.cargo_pod_destination = {
    type = defines.cargo_destination.surface,
    surface = target_surface,
    position = pos
}
```

### Event When Pod Lands
```lua
script.on_event(defines.events.on_cargo_pod_finished_descending, handler)
```

---

## REMOTE VIEW & CONTROLLER

### Set Player to Remote View
```lua
player.set_controller({
    type = defines.controllers.remote,
    surface = surface,
    position = pos
})
```

### Distinguish Positions
- `player.physical_position` - actual character location
- `player.position` - current view/camera position

### Check Render Mode
```lua
if player.render_mode == defines.render_mode.chart then
    -- player is in map view
end
```

---

## RECIPE CHANGES

### 2.0 (Correct)
Recipes use `results` array, even for single output:
```lua
data:extend({
    {
        type = "recipe",
        name = "my-recipe",
        results = {
            {type = "item", name = "iron-plate", amount = 2}
        }
    }
})
```

### 1.1 (OUTDATED - DO NOT USE)
Single output used `result` field.

---

## RED FLAGS - OUTDATED 1.1 CODE

Watch for these patterns that need updating:

- ❌ `global.anything` → ✅ `storage.anything`
- ❌ `game.item_prototypes[name]` → ✅ `prototypes.item[name]`
- ❌ `game.entity_prototypes[name]` → ✅ `prototypes.entity[name]`
- ❌ `player.print()` → ✅ context-dependent, may need `game.print()`
- ❌ Recipe with `result =` → ✅ use `results = {}`

---

## DEBUGGING TIPS

- Use `storage` instead of `global` EVERYWHERE
- Always check prototype existence before accessing
- Quality-aware code: check `stack.quality` when relevant
- Test with quality variations (normal, uncommon, rare, epic, legendary)

---

## COMMON MIGRATION TASKS

1. Search and replace: `global.` → `storage.`
2. Update prototype access: `game.item_prototypes` → `prototypes.item`
3. Update prototype access: `game.entity_prototypes` → `prototypes.entity`
4. Review recipe definitions: `result` → `results`
5. Add quality handling where items are created/moved
6. Test with Space Age features (if applicable)