Summary of scripts-sa/deployment.lua
What it does
This script manages orbital deployment of vehicles and supplies in Factorio using cargo pods. It enables players to deploy spider vehicles (e.g., spidertron, scout-o-tron) and robots (supply drops) from orbit to specific locations on the map. The system:

Checks for valid deployment conditions (hub, inventory, target surface).
Handles equipment grid (e.g., guns, batteries) from the vehicle's stored grid.
Processes extra items (e.g., ammo, fuel, utility items) and distributes them appropriately.
Uses cargo pods to transport items, with special logic for same-surface deployments.
Supports quality preservation (e.g., advanced bots, equipment).
Handles post-deployment effects like smoke, messages, and entity creation.
Key Functions Exported
The module exports a deployment table with the following functions:

deploy_spider_vehicle(player, vehicle_data, deploy_target, extras)
Deploys a spider vehicle from orbit with optional extra items (e.g., ammo, equipment).

Validates hub and inventory.
Checks for valid deployment target.
Processes equipment grid and extra items.
Creates a cargo pod for transport.
Stores deployment data in storage.pending_pod_deployments.
deploy_supplies(player, target_surface, selected_bots)
Deploys robots (bots) from orbit without a vehicle.

Finds a hub with the required bots.
Collects bots from hub inventory.
Creates a cargo pod with bots.
Stores deployment data for landing.
Events Handled
The script listens for and responds to the following event:

on_cargo_pod_finished_descending
Triggered when a cargo pod finishes descending and lands.
Looks up the pod in storage.pending_pod_deployments.
Teleports the pod to the correct surface/position if needed.
Deploys vehicles or robots based on deployment type.
Applies equipment grid, ammo, fuel, and other extras.
Creates smoke effects and messages.
Storage Variables Used
The script uses the global storage table to persist data:

storage.pending_pod_deployments
A dictionary of pending cargo pod deployments.
Each entry has:

pod: The cargo pod entity.
player: The deploying player.
is_supplies_deployment: Boolean (true for robot drops).
bots: List of collected robots (for supplies).
vehicle_name, vehicle_color, has_grid, grid_data, quality, entity_name, extras: Deployment-specific data (for vehicles).
actual_surface, actual_position: Used for same-surface teleportation.
This storage persists until the pod lands and the deployment is processed.

Additional Notes
The script includes debug logging (commented out) for equipment and grid handling.
It uses quality-aware inventory checks to ensure correct item types are used.
It handles fallbacks (e.g., carbon fuel, trunk storage) when deployment fails.
get_ammo_category() and find_compatible_slots_by_category() are helper functions (not exported) for ammo handling.