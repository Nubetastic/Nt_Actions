# Nt_Actions

A RedM object-pose library with a separate utility menu for gun tricks and external animations.

## Interfaces

### L-key utility menu

Press **L** to open the small utility menu when not using an object pose. It contains:

- **Gun Twirl**
- The configured external animation menu, such as **rsg-animations**

Scenario and object-pose controls are intentionally not shown in this menu.
While `inPose` is true, pressing **L** skips the utility menu and opens the cached object's pose list directly.

### Object pose menu

Target any object with **ox_target** and select **Object poses**. The menu lists every pose that players have published for that object model.

- Selecting a pose starts it at the saved object-relative position and heading.
- **Add Pose** selects a configured group, then one pose from that group, and opens the existing offset editor. Saving publishes only that pose.
- When adding from an active pose on the same object, the new pose starts from the active pose's offset.
- Starting Add Pose blocks the L menu for `AddPoseMenuDelay` (`5000` ms by default), preventing the pose list and offset editor from opening together.
- **Exit** closes the menu when the player is not using an object pose.
- While using a pose, the bottom actions become **Add Pose**, **Modify**, and **Leave Pose**.
- **Modify** reopens the offset editor for the active pose.
- **Leave Pose** exits the active scenario.
- Entering a pose from a non-pose position caches that starting transform. Leave Pose teleports the player to that cached position, immediately clears all pose tasks, sets the stamina core to `100`, and resurrects at the cached coordinates and heading while preserving health.
- Targeting a different object while posed still provides **Leave Pose** for the currently active pose.

The client globals `inPose` and `cachedPoseObject` track the active state and object. Selecting or saving an object pose sets them; leaving the pose or losing the scenario clears them.

Offsets and published poses are shared by object model and stored in `object_offsets.json`. Adding a pose to one chair model makes that pose available on all objects with the same model.

## Pose groups

Pose groups are configured as `group > list of poses` in `shared/configGroups.lua`. The included groups are:

- Ground
- Seat Chair
- Seat Bench
- Sit at Table
- Piano
- Camp Fire
- Sleep Bed Pillow

Groups organize the full configured pose list in the menus, but poses are added and positioned individually. The client builds every configured pose with `show = false`, then marks an object's saved poses with their stored `show` value. Only poses with `show = true` appear in the main object menu.

Each object model has one JSON entry. Its offsets are numbered once, and each pose stores only the number of its offset. Poses are divided into `show` and `noshow`, then by configured group:

```json
{
  "item": 123456,
  "offsets": [
    { "x": 0.0, "y": 0.0, "z": 0.5, "heading": 180.0 }
  ],
  "poses": {
    "show": {
      "Seat Chair": {
        "PROP_HUMAN_SEAT_CHAIR": 1
      }
    },
    "noshow": {}
  }
}
```

Unused offsets are removed and the pose numbers are compacted whenever the file is saved.

## Deletion permissions

Authorized users see a minus button beside each published pose. Clicking it moves only that pose from `poses.show` to `poses.noshow`; its group and other poses remain available.

Admins receive an **Undo** tab at the bottom of the object pose menu whenever hidden poses exist. Undo opens the hidden-pose list, where a green plus restores one pose at a time. Hidden poses remain stored and are excluded from Add, so restoration is only accepted through the server-authorized Undo callback.

Configure `DeletePermissionMode` in `shared/configTarget.lua`:

- `job`: the player must be on duty and have a job listed in `AdminJobs`.
- `server`: the player must have the configured ACE permission or one of the configured RSG permissions (`admin` or `god` by default).

Example job configuration:

```lua
DeletePermissionMode = 'job',
AdminJobs = {
    "sheriff",
    "police",
},
```

Example ACE configuration:

```cfg
add_ace group.admin nt_actions.admin allow
```

Then use:

```lua
DeletePermissionMode = 'server'
```

All add, modify, and hide requests are validated by the server. Player building and modification can be disabled with `AllowPlayerBuild` and `AllowPlayerModify`.

## Offset editor

The existing Old West interface, colors, camera orbit, movement, height, rotation, and zoom controls are retained. The editor now uses the same width and saved scale as the main menu without displaying another scale bar.

**Get Point Coords** starts the selected pose, waits for `PointSearchDelay` (`3000` ms by default), and then searches around the character's updated coordinates using `PointSearchDistance` (`0.5` by default). When a scenario point is found, checking it copies that point's coordinates and heading into the object-relative offset. When no point exists, the option remains unchecked, disabled, and grey. Cancel restores the previous active pose or the player's position before editing.

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [rsg-animations](https://github.com/Rexshack-RedM/rsg-animations) is optional and can be replaced through `Config.EmotesEvent`.
- `rsg-core` is used when job or RSG server permissions are selected.

## Installation

```cfg
ensure ox_lib
ensure ox_target
ensure Nt_Actions
```

Object targeting labels, distance, default offsets, editor steps, permission mode, and administrative access are configured in `shared/configTarget.lua`.

When `Config.Debug = true` in `shared/config.lua`, Leave Pose prints focused diagnostics with the `[Nt_Actions][LeavePose]` prefix. These include the original and posed Z values, the detected exit condition, timeout or collision fallbacks, and the final resurrection coordinates.

The `MenuText` section controls the object menu title, Add/Modify/Leave/Exit labels, and empty-list messages. The `PoseEditor` section controls the Add/Modify editor:

```lua
PoseEditor = {
    AddTitle = 'Add pose',
    ModifyTitle = 'Modify pose',
    DefaultStep = 0.025,
    DefaultCameraZoom = 3.0,
},
```

`DefaultStep` is clamped by `FineTuneStepMin` and `FineTuneStepMax`. `DefaultCameraZoom` is clamped by `CameraZoomMin` and `CameraZoomMax`.

## Credits

Adapted from `ricx_scenarios` and `ricx_guntwirl` by zelbeus.
