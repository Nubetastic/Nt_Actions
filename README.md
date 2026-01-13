# Nt_Actions

A RedM resource providing interactive action menu.
Some scenarios in the config do not work, working on filtering the config more.

## Features

- **Unified Scenario Menu**: Press **L** to open a context menu for nearby scenarios and group actions
  - While Idle, displays nearby scenarios in the world.
  - When in a scenario, it displays groups of other scenarios that are compatible with the current one.
  - Three different methods to using a scenario from idle.
    - Change pose performs them at coords.
    - On point anchors the player to the item, it uses scenario point.
- Leave and Unstuck
  - Leave ends the scenario normally, unstuck teleports you back to your original coords.
  
- **Gun Twirl Tricks**: Press **Page Down** to trigger and manage gun trick emotes
  - Multiple twirl animations (standard, dual, and variants A-B-D)
  - Navigate tricks with arrow keys (Up/Down)
  - Perform tricks with Right arrow, cancel with Left arrow

- **rsg-animations button**: Added a menu button for rsg-animations for easy unified access.

## Dependencies

- **[ox_lib](https://github.com/overextended/ox_lib)** - UI library for creating interactive menus (required)
- **[rsg-animations](https://github.com/Rexshack-RedM/rsg-animations)** - can be changed in config to another frameworks.

## Installation

1. Place the `Nt_Actions` folder in your RedM server's `resources` directory
2. Ensure `ox_lib` is installed and started before this resource
3. Add to your server config:
   ```lua
   ensure ox_lib
   ensure Nt_Actions
   ```

## Usage

### Scenario Menu
- Press **L** while in-game to open the scenario menu
- Select a scenario from the nearby list or your current group

### Gun Tricks
- Press **Page Down** to start the gun trick interface
- Use **Up/Down arrows** to navigate between different tricks
- Press **Right arrow** to perform the selected trick
- Press **Left arrow** to cancel/end the current trick

## Credits
Adapted the scenario script below and added some features, copied over the guntrwirl code.
ricx_Scencarios - https://github.com/zelbeus/ricx_scenarios
ricx_guntwirl - https://github.com/zelbeus/ricx_guntwirl