Summary of control.lua

This script manages a mod for Factorio that enables orbital deployment of spidertron vehicles and related equipment, with features for container deployment, equipment grid management, and platform integration. It integrates with the Space Age mod and extends its functionality with additional GUIs, deployment logic, and player interactions.

What it does:

Handles player interactions with container and equipment grids, including stack buttons, sliders, and text fields.
Manages orbital deployment of spidertron vehicles from space platforms to planets.
Provides GUIs for container deployment, equipment grid filling, and platform deployment.
Tracks and manages deployment data, vehicle states, and player interactions.
Responds to game events such as GUI interactions, player movement, research completion, and cargo pod landings.
Includes debug tools and command-line utilities for testing and debugging.
Key functions it exports (via event handlers and internal modules):

init_storage(): Initializes mod storage variables.
init_players(): Sets up player shortcuts and GUIs.
map_gui.on_gui_click(): Handles GUI click events for deployment and platform buttons.
container_deployment.on_button_click(): Processes container deployment button clicks.
container_deployment.on_confirm_deployment(): Confirms deployment of containers.
platform_gui.on_deploy_button_click(): Handles platform deployment button clicks.
equipment_grid_fill.on_fill_button_click(): Initiates equipment grid filling.
equipment_grid_fill.on_cargo_pod_button_click(): Handles cargo pod deployment.
equipment_grid_fill.on_equipment_item_click(): Processes equipment item clicks.
container_deployment.on_slider_changed() and container_deployment.on_textfield_changed(): Updates container deployment values.
map_gui.show_deployment_menu(): Displays deployment selection menu.
map_gui.find_orbital_vehicles(): Finds deployable spidertron vehicles.
deployment.on_cargo_pod_finished_descending(): Handles cargo pod landing events.
commands.add_command("test_deploy_message"): Sends a test deployment message.
commands.add_command("debug_hub_inventory"): Debugs hub inventory contents.
Storage variables it uses:

storage.pending_deployments: Stores pending vehicle deployment requests.
storage.pending_pod_deployments: Stores pending cargo pod deployment requests.
storage.temp_deployment_data: Holds temporary deployment data.
storage.pending_grid_open: Tracks entities that opened GUIs for platform buttons.
storage.current_equipment_grid_vehicle: Stores the current vehicle associated with an equipment grid.
storage.spidertrons: List of tracked spidertron vehicles (used in debug commands).
storage.pending_deployment: Tracks pending deployment requests (used in on_tick).
Events it handles:

on_init: Initializes storage and player shortcuts.
on_load: No specific action (placeholder).
on_configuration_changed: Reinitializes storage and player state.
on_gui_click: Handles GUI button clicks (stack buttons, deployment, platform, equipment grid).
on_gui_value_changed: Updates slider values and text fields.
on_gui_text_changed: Validates and updates text field inputs.
on_gui_closed: Cleans up GUIs and removes stored data.
on_gui_opened: Creates deployment buttons and checks for equipment grids.
on_tick: Processes pending GUI opens and deployments.
on_lua_shortcut: Handles the "orbital-spidertron-deploy" shortcut.
on_player_changed_surface: Updates map GUI when player changes surface.
on_player_render_mode_changed: Updates GUI based on render mode.
on_player_created: Initializes shortcuts for new players.
on_cargo_pod_finished_descending: Processes cargo pod landings.
on_research_finished: Updates player shortcuts when "space-platform" research is completed.
on_player_left_game: Cleans up deployment data for leaving players.
on_nth_tick(300): Cleans up stale deployment records every 5 seconds.