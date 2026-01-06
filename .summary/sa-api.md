What it does
This file provides an API for other mods to interact with the spider-launcher deployment system in Factorio. It allows external mods to:

Deploy vehicles (e.g., scout robots) from a space platform hub to a target surface.
Register vehicle deployment requirements and default configurations.
Check if required items are available in the hub.
Interact with the deployment system via a remote interface.
It's designed to be used by other mods that want to integrate with or extend the spider-launcher mod's functionality.

Key Functions Exported
The API exports the following public functions via remote.add_interface:

deploy_from_hub(params)

Deploys a vehicle from a hub to a target surface.
Takes a params table with:
hub: The platform hub entity.
surface_name: Target surface name (e.g., "arrival").
config: Deployment config including:
vehicle_item: Item to deploy (e.g., "scout-o-tron-pod").
entity_name: Entity to create (e.g., "scout-o-tron").
required_items: List of items needed in the hub.
equipment_grid: Equipment to add to the vehicle.
trunk_items: Items to put in the vehicle's trunk.
target_position: Optional spawn position.
player_index: Optional player index for messages.
Returns success status and message.
Uses deployment.deploy_spider_vehicle internally.
register_vehicle_requirements(vehicle_item, requirements)

Registers deployment requirements for a vehicle.
Parameters:
vehicle_item: Name of the vehicle item (e.g., "scout-o-tron").
requirements: Table with:
required_items: List of required items.
deploy_item: Item to actually deploy (defaults to vehicle_item).
entity_name: Entity name to create (defaults to vehicle_item).
check_vehicle_requirements(vehicle_item, hub)

Checks if all required items for a vehicle are present in a hub.
Returns success and found item data.
register_vehicle_defaults(vehicle_item, defaults)

Registers default equipment and trunk items for a vehicle.
Parameters:
vehicle_item: Name of the vehicle.
defaults: Table with:
equipment_grid: List of default equipment.
trunk_items: List of default trunk items.
get_vehicle_defaults(vehicle_item)

Retrieves default equipment and trunk items for a vehicle.
Returns a table with equipment_grid and trunk_items.
is_tfmg_active()

Checks if the TFMG mod is active (case-insensitive check).
Storage Variables Used
The API maintains two global tables to store mod configuration data:

api.vehicle_requirements

Maps vehicle_item_name → {required_items = {...}, deploy_item = ..., entity_name = ...}
Used to store deployment prerequisites.
api.vehicle_defaults

Maps vehicle_item_name → {equipment_grid = {...}, trunk_items = {...}}
Stores default equipment and trunk items for vehicles.
Events Handled
This file does not handle any events directly. It is a pure API module that:

Exposes functions via remote.add_interface.
Imports and uses scripts-sa.deployment module for actual deployment logic.
Does not register any on_event, on_init, or on_load handlers.
Summary Table
Category	Details
Purpose	Provides an API for other mods to deploy vehicles via the spider-launcher system
Key Functions	deploy_from_hub, register_vehicle_requirements, check_vehicle_requirements, register_vehicle_defaults, get_vehicle_defaults, is_tfmg_active
Storage Variables	vehicle_requirements, vehicle_defaults
Events Handled	None