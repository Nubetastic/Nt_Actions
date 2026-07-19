# Nt_Actions

A RedM resource providing a unified action menu.
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

- **Object Target**: Select an object with ox_target, choose a scenario group and pose, then fine tune the player position with on-screen arrows. Confirming with the save checkbox enabled stores the object-model/group offset in `object_offsets.json` for future use.

- **Custom NUI**: All action, scenario, pose, emote, and object-target navigation uses the same right-side menu and `html/assets/background.png` artwork.

## Dependencies

- **[ox_lib](https://github.com/overextended/ox_lib)** - UI library for creating interactive menus (required)
- **[ox_target](https://github.com/overextended/ox_target)** - One-use object selection for positioned scenarios (required)
- **[rsg-animations](https://github.com/Rexshack-RedM/rsg-animations)** - can be changed in config to another frameworks.

## Installation

1. Place the `Nt_Actions` folder in your RedM server's `resources` directory
2. Ensure `ox_lib` is installed and started before this resource
3. Add to your server config:
   ```lua
   ensure ox_lib
   ensure ox_target
   ensure Nt_Actions
   ```

## Usage

### Scenario Menu
- Press **L** while in-game to open the scenario menu
- Select a scenario from the nearby list or your current group
- Select **Object Target**, target an object once, then choose a group and scenario
- Use the position arrows, height controls, shared movement/rotation step slider, and rotation buttons to align the scenario; confirm to keep playing and optionally save that offset
- Fine tuning preserves the current gameplay-camera pitch and places the scripted camera behind the player using the selected scenario heading; hold right mouse to orbit it
- The positioning camera starts at a distance equal to `MaxOffset`; use the camera zoom slider to change its orbit distance
- Fine-tune controls immediately reapply the scenario at its updated position and heading

Object targeting labels, distance, movement step, maximum offset, and default X/Y/Z/heading offsets can be changed in `shared/configTarget.lua`.

### Gun Tricks
- Press **Page Down** to start the gun trick interface
- Use **Up/Down arrows** to navigate between different tricks
- Press **Right arrow** to perform the selected trick
- Press **Left arrow** to cancel/end the current trick

## Credits
Adapted the scenario script below and added some features, copied over the guntrwirl code.
ricx_Scencarios - https://github.com/zelbeus/ricx_scenarios
ricx_guntwirl - https://github.com/zelbeus/ricx_guntwirl
