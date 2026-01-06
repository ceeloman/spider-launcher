Summary of platform-gui.lua

What it does:
This script manages the graphical user interface (GUI) for the Space Age mod's platform deployment system. It displays a deploy button in the player's relative GUI when they are on a space platform hub that is stopped above a planet. The button allows players to deploy vehicles to the planet surface. When clicked, it closes any open GUIs, switches the player to the target planet surface, and prepares the deployment menu for the next game tick.

Key functions it exports:

get_platform_planet_name(player): Checks if the player is on a platform above a planet and returns the planet name and surface if valid.
get_or_create_deploy_button(player, opened_entity): Creates or updates the deploy button in the player's GUI if conditions are met.
remove_deploy_button(player): Removes the deploy button from the player's GUI.
on_deploy_button_click(player): Handles the click event of the deploy button, switching the player to the target planet surface and scheduling deployment.
Storage variables it uses:

storage.pending_deployment: A table that stores pending deployment data (planet surface and name) for each player, used to show the deployment menu after switching surfaces.
Events it handles:

This script does not directly register any event handlers. It is intended to be used in conjunction with other systems (like the shortcut handler) that trigger the on_deploy_button_click function via player interactions.