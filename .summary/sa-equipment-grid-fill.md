Summary of scripts-sa/equipment-grid-fill.lua

What it does:
This script adds functionality to automatically fill equipment ghosts in vehicle equipment grids from the player's inventory. It provides a UI button that allows players to quickly fill ghost equipment slots with matching items from their inventory, including quality-aware matching. It also supports placing equipment from the inventory directly into the player's cursor (for manual placement) and opens an orbital deployment menu via a cargo pod button.

Key functions it exports:

equipment_grid_fill.get_equipment_grid_context(player) – Extracts context (grid, inventory, stack index) for a vehicle equipment grid.
equipment_grid_fill.get_ghost_equipment(grid) – Returns a list of ghost equipment in a grid.
equipment_grid_fill.find_matching_items(inventory, ghosts) – Finds items in inventory that can fill ghost equipment.
equipment_grid_fill.find_all_equipment_items(inventory) – Finds all equipment items in inventory (for toolbar display).
equipment_grid_fill.get_or_create_fill_button(player) – Creates or refreshes the fill button and equipment toolbar.
equipment_grid_fill.refresh_equipment_toolbar(player) – Updates the equipment toolbar with current inventory data.
equipment_grid_fill.remove_fill_button(player) – Removes the fill button and toolbar.
equipment_grid_fill.find_item_for_equipment(equipment_name, equipment_quality) – Finds the item that places a given equipment.
equipment_grid_fill.on_fill_button_click(player) – Handles the fill button click to fill ghosts and remove marked equipment.
equipment_grid_fill.on_equipment_item_click(player, button_name, tags) – Handles clicks on equipment item buttons to place the correct item in the player’s cursor.
equipment_grid_fill.on_cargo_pod_button_click(player) – Handles the cargo pod button to open the orbital deployment menu.
Storage variables it uses:

storage.pending_deployment – Stores deployment data for the next tick when opening the orbital menu.
Events it handles:

This script does not directly handle events. It is invoked by external code (likely via GUI button clicks or player interactions) and relies on the game's existing event system for context (e.g., player opening a GUI, clicking buttons).