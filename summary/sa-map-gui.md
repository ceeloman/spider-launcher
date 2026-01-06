Summary of map-gui.lua

What it does:
This script implements a GUI system for deploying vehicles and supplies from orbit in Factorio, primarily focusing on spidertrons and construction/logistic robots. It allows players to view available vehicles and supplies on orbital platforms, configure loadouts (including ammo, fuel, and equipment), and deploy items to specific locations on the surface. The system supports multiplayer, handles GUI state management, and integrates with the deployment system.

Key functions it exports:

map_gui.show_deployment_menu(player, vehicles): Displays the main deployment menu with available vehicles.
map_gui.show_extras_menu(player, vehicle_data, deploy_target): Opens the extras menu to configure loadouts for a selected vehicle.
map_gui.find_orbital_vehicles(player_surface): Scans all platforms orbiting the player's planet to find deployable vehicles.
map_gui.scan_platform_inventory(vehicle_data): Scans a platform's inventory for available supplies (robots, repair packs).
map_gui.list_compatible_items_in_inventory(inventory, compatible_items_list, available_items): Identifies compatible items in an inventory.
map_gui.destroy_deploy_button(player): Closes and destroys the deployment menu.
map_gui.initialize_player_shortcuts(player): Enables/disables the "orbital-spidertron-deploy" shortcut based on game state.
map_gui.initialize_all_players(): Sets up shortcuts for all players at startup.
map_gui.setup_cleanup_task(): Sets up a periodic cleanup task for stale deployment data.
Storage variables it uses:

storage.deployment_vehicles: Stores the list of vehicles available for deployment for each player.
storage.temp_deployment_data: Stores temporary deployment data (vehicle, target, available items, equipment grid) for the current player.
storage.pending_deployment: Stores pending deployment requests for players who opened the GUI during a transition.
storage.supplies_available_bots: Stores available robot items (construction/logistic) for supply deployment.
storage.current_equipment_grid_vehicle: Tracks the currently open equipment grid for editing.
storage.pending_pod_deployments: Tracks pending pod deployment tasks for cleanup.
Events it handles:

on_gui_click: Handles clicks on GUI elements (buttons, sliders, text fields) to trigger actions like closing menus, deploying, or opening equipment grids.
on_gui_confirmed: Handles the confirmation of the extras menu to deploy selected items.
on_player_changed_surface: Closes the deployment menu when a player changes surface.
on_player_changed_render_mode: Updates the availability of the deployment shortcut based on render mode.
on_lua_shortcut: Triggers the deployment menu when the player activates the "orbital-spidertron-deploy" shortcut.
on_gui_closed: Cleans up equipment grid tracking when a GUI is closed.