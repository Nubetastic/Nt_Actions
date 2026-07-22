# Nt_Actions

## [Showcase](youtube.com/watch?v=2Ik6fkwJ1nw&feature=youtu.be)

A RedM object-pose library for publishing reusable poses and object-relative points, with job-restricted moderation and batch review.

## Usage

Target an object with **ox_target** and select **Object poses**. Choose a numbered point, then select a pose. While posed, press **L** (`Config.StartKey`) to reopen the cached pose menu.

- **Leave Pose** exits the scenario and returns the player to their original position.
### Job Moderators have
- **Add Pose** selects a configured group and animation, then opens the offset editor.
- **Modify** edits the active shared point. Enable **Add as new point** to save it as another point instead.


- Saved points are shared by object model, so they apply to every object using that model and can be reused by all published poses.
- Nearby native scenario points detected by the editor appear temporarily as `P1`, `P2`, and so on. Saving converts the selected transform into a normal object-relative point.

Add and Modify are available only to jobs in `AdminJobs` after enabling **Mod**. Authorized moderators can also hide or restore poses, permanently delete hidden poses, remove points, and use **Multi Add** to publish several configured poses at once. Job checks use `rsg-core`; duty status and grade are not required.

## Batch review

Authorized jobs in `ReviewJobs` can run `/poseReview` to review candidate data from `object_offsets review.json` (configurable).

1. Paste a JSON array using the same format as `object_offsets.json` into the review file.
2. Run **Cleanup Review Data** after every file change.
3. Select **Start Review** to preview and approve new poses and points.

Review supports gender-specific poses and preserves incompatible entries for a later reviewer using the required ped gender. Only one reviewer can own a review session at a time. Approvals merge into the live library without changing existing live points.

## Data and configuration

The live library is stored in `object_offsets.json`. Each object model has reusable `offsets` and poses grouped under `show` or `noshow`. Older supported formats are migrated automatically when the resource starts. Both the live and review files must be writable by the server.

- `shared/config.lua`: interface scale, debug options, and general settings
- `shared/configGroups.lua`: pose groups and allowed scenarios
- `shared/configTarget.lua`: targeting, editor controls, offsets, jobs, storage, and review settings

Only configured group/scenario pairs can be saved. With `Config.Debug = true`, Leave Pose diagnostics use the `[Nt_Actions][LeavePose]` prefix.

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
