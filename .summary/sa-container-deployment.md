Summary of container-deployment.lua

What it does

This script enables remote deployment of robots and spider vehicles from containers in Factorio. It provides a GUI interface that allows players to:

View deployable items (spider vehicles, construction robots, logistic robots) in a container.
Deploy them directly from the container’s position.
Select quantity via a slider/textfield for items with stack sizes > 1.
Automatically assign robots to the correct roboport or vehicle network based on position.
The GUI is anchored to the container and includes:

Sprite buttons for each deployable item.
Quality-based grouping for robots (e.g., Normal, Advanced, etc.).
A settings panel with a slider/textfield to choose how many to deploy.
Deployment confirmation with validation and inventory updates.
Key Functions Exported

container_deployment.has_deployable_items(container) → boolean

Checks if a container has any deployable items (spider vehicles or bots).

container_deployment.scan_deployable_items(container) → table

Scans the container’s inventory and returns a structured list of deployable items grouped by type and quality.

container_deployment.get_or_create_gui(player, container) → frame

Creates or returns the deployment GUI for a given player and container.

container_deployment.remove_gui(player)

Removes the deployment GUI from the player’s interface.

container_deployment.on_button_click(player, button_name, tags)

Handles button clicks (vehicle/bot deployment) and shows quantity selection if needed.

container_deployment.show_slider(player, tags)

Displays the deployment settings panel (slider/textfield) for quantity selection.

container_deployment.on_confirm_deployment(player)

Handles confirmation of deployment (reads slider/textfield, deploys, updates GUI).

container_deployment.on_slider_changed(player, slider)

Updates textfield when slider value changes.

container_deployment.on_textfield_changed(player, textfield)

Updates slider when textfield value changes.

container_deployment.deploy_vehicle(player, container, tags, quantity)

Deploys a spider vehicle, preserving its name, color, and equipment grid.

container_deployment.deploy_bot(player, container, tags, quantity)

Deploys robots, assigning them to the nearest network (vehicle or roboport).

Storage Variables Used

storage.container_deployment_containers

Maps player.index → container — stores the container currently being viewed via GUI.

storage.container_deployment_selected

Maps player.index → tags — stores the currently selected item and its tags (used for deployment confirmation).

Events Handled

This script does not register events directly (e.g., via script.on_event). Instead, it relies on external event handlers to call its functions:

on_gui_click — triggers on_button_click, on_confirm_deployment
on_gui_text_changed — triggers on_textfield_changed
on_gui_value_changed — triggers on_slider_changed
These are expected to be handled by the main mod script or another event handler, which calls the appropriate functions based on GUI element events.

Let me know if you'd like this exported as a .txt file or formatted for documentation!