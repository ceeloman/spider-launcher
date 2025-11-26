# Space Exploration Compatibility Port - Summary

## Project Overview
This document summarizes the work done to port the Orbital Vehicle Deployment mod from Space Age (SA) compatibility to Space Exploration (SE) compatibility. The mod allows players to deploy vehicles (Spidertrons, cars, tanks, etc.) from orbit to planets below, with optional ammo, fuel, and construction robots.

## Completed Work

### 1. Entity Definitions (`prototypes-se/`)
- ✅ **entity.lua**: 
  - Created `ovd-deployment-container` (container entity with inventory)
  - Created `ovd-cargo-bay` (cargo-bay entity for visual overlay)
  - Added grid alignment (`build_grid_size = 2`)
  - Configured graphics sets for both planet and platform surfaces
  - Added water reflections and connections

- ✅ **cargo-hatch.lua**: 
  - Helper functions for hatch definitions
  - `shared_bay_hatch()` function
  - `platform_upper_hatch()` and `platform_lower_hatch()` functions
  - Sound definitions commented out (to be implemented later)

- ✅ **item.lua**: Item definitions (assumed complete)
- ✅ **recipe.lua**: Recipe definitions (assumed complete)
- ✅ **shortcuts.lua**: Shortcut definitions

### 2. Graphics Integration
- ✅ Ported all cargo-bay and hub graphics from Space Age
- ✅ Updated all graphics paths to use `__spider-launcher__` mod name
- ✅ Created sprite definition files (`.lua` files) for graphics positioning
- ✅ Updated `platform-connections.lua` to use correct mod paths
- ✅ Graphics include:
  - Bay graphics (shared, planet, platform variants)
  - Hatch graphics (shared, planet, platform variants)
  - Connection graphics
  - Shadow and emission graphics

### 3. Control Scripts (`scripts-se/`)

#### ✅ **control.lua**
- Event handlers for entity creation/destruction
- Cargo-bay visual creation on container placement
- Grid snapping for cargo-bay alignment
- Shortcut handling
- GUI event handlers (clicks, value changes, text changes)
- Comprehensive logging for debugging
- Player initialization and cleanup

#### ✅ **deployment.lua**
- `on_cargo_pod_finished_descending()` function implemented
- `deploy_spider_vehicle()` function fully implemented
- Vehicle deployment with quality preservation
- Equipment grid transfer
- Fuel and ammo distribution
- Extras (utilities, ammo, fuel) handling
- Smoke effects on landing
- Landing position calculation with walkable tile checking
- Chunk generation for unexplored areas
- Light animation sequences for landing target
- Inventory validation for extras

#### ✅ **map-gui.lua**
- `find_orbital_vehicles()` - Finds vehicles on orbit surfaces
  - Handles both orbit and planet surfaces
  - Searches for `ovd-deployment-container` entities
  - Comprehensive logging
- `show_deployment_menu()` - Vehicle selection GUI
- `show_extras_menu()` - Full extras selection GUI with tabs
  - Utilities tab (construction robots, repair packs)
  - Ammo tab (compatible ammo for vehicle)
  - Fuel tab (chemical fuel items)
  - Quality-aware item selection
  - Sliders, text fields, and stack buttons
- `scan_platform_inventory()` - Scans container inventories
- Event handlers for surface changes, render mode changes
- Player shortcut initialization
- GUI event handlers for extras menu (clicks, slider changes, text field changes)

#### ✅ **vehicles-list.lua**
- Vehicle detection functions
- Spider vehicle identification

### 4. Key Differences: SA vs SE

#### Space Age (SA)
- Uses **platforms** (surfaces with "platform" in name)
- Uses **cargo-hubs** (separate hub entities)
- Platform checking via surface name pattern matching
- Research gate: `space-platform` technology

#### Space Exploration (SE)
- Uses **orbits** (surfaces with zone type "orbit")
- Uses **containers** directly (`ovd-deployment-container` = hub)
- Zone checking via Space Exploration remote interface
- Orbit naming: `"PlanetName Orbit"` (e.g., "Nauvis Orbit")
- Research gate: `spidertron` technology
- Zone parent-child relationships for orbit-to-planet matching

### 5. Current Issues/Known Bugs


2. **Sound Definitions**:
   - Opening/closing sounds commented out
   - Need proper sound prototype definitions

4. **Flashing Error**:
   - Flashing error needs fixing

5. **Same Surface Launch Failure**:
   - Doesn't launch if player is on the same surface - fails silently

6. **Space Vehicle Validation**:
   - If in space - non space allowed vehicles shouldn't be allowed to land, and maybe greyed out in the list of vehicles?

7. **Cargo Bay Placement Restriction**:
   - Cargobays should only be placed on space tiles

## Remaining Work / TODO

### High Priority

1. ✅ **Complete `deploy_spider_vehicle()` function** (`scripts-se/deployment.lua`) - **COMPLETED**
   - Full implementation ported from SA version with orbit check
   - Inventory validation
   - Extras collection with quality preservation
   - Grid data extraction
   - Landing position calculation
   - Chunk generation
   - Walkable tile checking
   - Cargo pod creation and configuration
   - Animation sequences (light effects)

2. ✅ **Complete `show_extras_menu()` function** (`scripts-se/map-gui.lua`) - **COMPLETED**
   - Full GUI implementation ported from SA version
   - Tabbed pane with Utilities, Ammo, Fuel tabs
   - Sliders and text fields for quantity selection
   - Quality selection for items
   - Stack buttons (+50, +100, etc.)
   - Deploy button with item counts
   - Back button to deployment menu
   - GUI event handlers for all interactions

3. **Check for other Surfaces / Zones** 
   - Planets are the only ground surface
   - There are multiple Space surfaces which should operate similar to Orbits
   - Test with various planet/orbit combinations

### Medium Priority

4. **Sound Implementation**
   - Create sound prototype definitions
   - Uncomment sound references in `cargo-hatch.lua`
   - Test sound playback

5. **Ammo Slot Compatibility** (`scripts-se/deployment.lua`)
   - SE version has simplified ammo distribution
   - SA version has complex slot-by-category matching
   - Consider porting full ammo slot logic if needed

6. **Testing & Bug Fixes**
   - Test vehicle deployment from orbit to planet
   - Test deployment with extras
   - Test quality preservation
   - Test equipment grid transfer
   - Test fuel and ammo distribution
   - Verify grid alignment works correctly

### Low Priority / Nice to Have

7. **Code Cleanup**
   - Remove debug logging (or make it optional)
   - Consolidate duplicate code patterns
   - Add comments for complex logic

8. **Documentation**
   - User guide for SE version
   - Differences from SA version documented
   - Known limitations

9. **Performance Optimization**
   - Optimize surface iteration in `find_orbital_vehicles()`
   - Cache zone lookups if possible

## File Structure

```
spider-launcher_2.8.0/
├── prototypes-se/
│   ├── cargo-hatch.lua      ✅ Complete
│   ├── entity.lua            ✅ Complete
│   ├── item.lua              ✅ (assumed)
│   ├── recipe.lua            ✅ (assumed)
│   └── shortcuts.lua         ✅ Complete
├── scripts-se/
│   ├── control.lua           ✅ Complete (with logging)
│   ├── deployment.lua         ✅ Complete (all functions implemented)
│   ├── map-gui.lua           ✅ Complete (all GUI functions implemented)
│   └── vehicles-list.lua     ✅ Complete
└── graphics/
    └── entity/cargo-hubs/    ✅ Complete (all graphics ported)
```

## Testing Checklist

- [ ] Container placement works correctly
- [ ] Cargo-bay visual appears on container placement
- [ ] Grid alignment works (containers snap to grid)
- [ ] Vehicles can be found on orbit surfaces
- [ ] Deployment menu shows available vehicles
- [ ] Vehicle deployment works (basic, no extras)
- [ ] Extras menu appears (when implemented)
- [ ] Extras selection works (when implemented)
- [ ] Deployment with extras works (when implemented)
- [ ] Quality preservation works
- [ ] Equipment grid transfer works
- [ ] Fuel distribution works
- [ ] Ammo distribution works
- [ ] Works from orbit surface
- [ ] Works from planet surface (finds orbit automatically)

## Notes

- The SE version uses Space Exploration's zone system instead of surface name patterns
- Containers in SE are standalone (no separate hub entities)
- Orbit surfaces are named `"PlanetName Orbit"` (with space, capital O)
- The mod should work with both Space Exploration and Space Age (different code paths)

## Reference Files

- `space-age-reference files/` - Reference implementations from Space Age (to be deleted on release)
- `scripts-sa/` - Space Age implementation (for comparison)
- `scripts-se/` - Space Exploration implementation (current work)

