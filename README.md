# LAN of DOOM Spawn Protection
A SourceMod plugin that grants a limited period of invulnerability after player
spawn for CS:S and CS:GO servers.

# Building
Check out the repository and run the ``./build.sh`` script.

# Installation
Copy ``lan_of_doom_spawn_protection.smx`` to your server's
``css/cstrike/addons/sourcemod/plugins`` directory.

# Console Variables

``sm_lanofdoom_spawn_protection_time`` Controls the amount of time in seconds
after spawn for which a player is protected from damage. ``4.0`` by default.
Protection is removed after a delay controlled by 
``sm_lanofdoom_spawn_protection_remove_delay`` if the player uses a weapon.

``sm_lanofdoom_spawn_protection_remove_delay`` Controls the maximum amount of
time in seconds that a player can retain their spawn protection after using a
weapon. ``1.0`` by  default.