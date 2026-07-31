# Nt_Actions

## [Showcase](https://www.youtube.com/watch?v=2Ik6fkwJ1nw)

A RedM object-pose library for publishing reusable poses and object-relative points, with presets, point groups, global pose corrections, job-restricted moderation, and batch review.

## Usage

Target an object with **ox_target** and select **Object poses**. Choose a numbered point, then select a pose. While posed, press **L** (`Config.StartKey`) to reopen the cached pose menu.

- **Leave Pose** exits the scenario and returns the player to their original position.
- The point list is organized by point group. Poses shown for the selected point belong to that point's group.
- Saved points are shared through the object's assigned preset and can be reused by every compatible pose in their point group.

## Moderator UI

On-duty jobs in `ConfigTarget.AdminJobs` can target unregistered objects, enable **Mod**, and manage object libraries. Off-duty admins see the same ox_target options as regular players: only object models already registered in the live cache. Job and duty checks use `rsg-core`; grade is not required.

- **Add Pose** selects a configured pose group and scenario, then opens the offset editor.
- **Multi Add** publishes several compatible configured poses at once.
- **Modify** edits the active point. Enable **Add as new point** to preserve the original and create another point.
- **Object Offset** applies one correction to the current object model/preset assignment. The editor opens in manual mode first, shows the player and object world coordinates, and accepts X, Y, Z, and heading directly. Manual values can be saved without entering a pose. Select **Move Set** to enable the movement controls and pose/camera preview.
- **Group Edit** creates, renames, and removes point groups and assigns saved points and poses to them.
- **Presets** previews, applies, removes, and renames reusable object-pose libraries.
- **Undo** restores hidden poses or permanently deletes them.

Nearby native scenario points detected by the Add/Modify editor appear temporarily as `P1`, `P2`, and so on. Saving one converts its transform into a normal object-relative point.

### Pose Offset

**Pose Offset** is available in Mod mode while an on-duty authorized reviewer is using a pose. It applies a global X, Y, Z, and heading correction to that scenario everywhere it is used. These corrections are stored separately in `pose_offset.json` and require a job listed in `ConfigTarget.ReviewJobs`.

Use Pose Offset for a scenario-wide animation alignment problem. Use Object Offset when every pose on a particular object model or preset needs the same correction. Modify an individual point when only one placement needs adjustment.

### Presets

A preset is a reusable library containing points, point-group assignments, and published/hidden poses. Object models can be assigned to an existing preset so they share that setup instead of maintaining duplicate libraries.

The Presets window provides a point selector and pose preview before applying a preset. The active preset can be removed from the object, and presets can be renamed by authorized moderators. Adding poses to an object without a preset prompts for a preset name.

### Point groups

Point groups control which poses are available at which points. Every pose assigned to a group can use every point assigned to that same group. This supports objects with distinct placement areas, for example left/right seats or separate standing and seated positions, inside one preset.

The Group Editor requires at least one valid group, and groups containing poses must retain usable points. Group and pose ordering follows `ConfigGroups.ScenarioOrder` and each group's `Poses` list in `shared/configGroups.lua`.

## Pose configuration

Pose definitions are configured in `shared/configGroups.lua`:

```lua
["Seat Chair"] = {
    objectOffset = true,
    truncate = { "PROP_HUMAN_SEAT_CHAIR_" },
    Poses = {
        { "PROP_HUMAN_SEAT_CHAIR", "Sit Chair", "" },
    },
},
```

Each pose entry is `{ scenario name, unique display name, gender }`. Gender may be `"male"`, `"female"`, or an empty string for both. `ScenarioOrder` controls group ordering, while the order of `Poses` controls pose ordering.

`objectOffset` controls the Add Pose editor workflow:

- `true`: starts from an existing object-relative point when available.
- `false`: starts from the player's placement and derives the object-relative point after the scenario settles.

Only configured group/scenario pairs can be saved.

## Batch review

Authorized jobs in `ReviewJobs` can run `/poseReview` to review candidate data from `object_offsets review.json` (configurable).

1. Paste a JSON array using the same format as `object_offsets.json` into the review file.
2. Run **Cleanup Review Data** after every file change.
3. Select **Start Review** to preview and approve new presets, poses, and points.

Review supports gender-specific poses and preserves incompatible entries for a later reviewer using the required ped gender. Only one reviewer can own a review session at a time. Approvals merge into the live library without changing existing live points.

## Data and configuration

- `object_offsets.json`: live presets, model-to-preset assignments, object offsets, points, point groups, and published/hidden poses.
- `pose_offset.json`: global per-scenario pose corrections.
- `object_offsets review.json`: candidate batch-review data.
- `shared/config.lua`: interface scale, debug options, and general settings.
- `shared/configGroups.lua`: pose groups, ordering, display names, gender restrictions, and Add Pose behavior.
- `shared/configTarget.lua`: targeting, permissions, editor controls, offset limits, storage files, and review settings.

Older supported object-offset formats are migrated automatically when the resource starts. Live and review data files must be writable by the server. With `Config.Debug = true`, Leave Pose diagnostics use the `[Nt_Actions][LeavePose]` prefix.

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- `rsg-core` for job-restricted moderation and batch review

## Installation

Keep the resource folder named `Nt_Actions`, then add:

```cfg
ensure Nt_Actions
```

## Credits

Adapted from `ricx_scenarios` by zelbeus.
