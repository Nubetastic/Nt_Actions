# Batch Offset Review

## Goal

Add a separate, admin-only workflow for reviewing another `object_offsets.json` dataset before merging any of it into the live `object_offsets.json`.

Admins paste candidate data into:

```text
object_offsets review.json
```

Nothing from that file is merged blindly. The workflow first removes data that does not need review, then lets an admin spawn each object and approve new poses and reusable points independently; unchecked candidates are removed only after confirmation.

This feature should be isolated from the normal pose library as much as practical, for example in dedicated client/server review scripts. Existing menu, pose, camera, storage, validation, and cleanup functions can be shared by removing `local` from only the specific functions the review scripts need.

## Access and entry point

- Access uses the dedicated `ReviewJobs` list, separate from `AdminJobs`. Duty status is not required.
- Run `/poseReview` to open the review entry menu.
- The player's job must be listed in `ReviewJobs`.
- The server determines whether the player is authorized and whether `object_offsets review.json` contains valid candidate data.

## Review menu overview

Opening **Upload Review** presents two explicit steps:

1. **Cleanup Review Data**
2. **Start Review**

Start Review should remain disabled until cleanup has successfully run for the current contents of the review file. If the file is changed afterward, cleanup is required again.

The menu should also show compact counts where useful:

- Candidate items
- Candidate pose records
- Records removed by cleanup
- Records remaining for review
- Approved and denied records during the active session

## Step 1: Cleanup Review Data

Cleanup validates and rewrites `object_offsets review.json`. It does not alter the live JSON.

### Remove poses already in the live library

A review pose is already present when its object model, configured group, and animation match a live record. Coordinate values are not part of this comparison because poses and reusable object points are independent.

A new animation using coordinates that already exist in the live library remains available for review. An already-published animation is removed from the review data even when the imported file also contains a new point. That point remains only when another genuinely new pose on the same object still needs it.

Live `show` and `noshow` records should both count as existing data so the batch process cannot silently re-add a pose that an admin previously hid.

### Remove non-reviewable data

Cleanup also removes:

- All review-file `noshow` data.
- Invalid item records.
- Invalid coordinates.
- Pose records whose group or animation is not present in the configured pose catalog.
- Pose records whose coordinate reference does not resolve.
- Coordinate records that are not referenced by any remaining review pose.
- Item records that have no remaining review poses, including items containing coordinates but no poses.
- Exact duplicate pose/coordinate records repeated inside the review file itself.

After records are removed, the remaining reusable coordinates are compacted. The rewritten review file uses the current `[animation]` pose format; temporary pose-to-coordinate associations exist only in server memory and are never persisted as legacy `[animation, number, coord]` records.

### Expected cleanup for the current sample files

Given the current live and review JSON files:

- The identical Seat Bench record is removed.
- The already-existing left Sleep Bed Pillow record is removed.
- The right Sleep Bed Pillow animation remains because it is a different animation, even though it uses the same coordinates.
- The three existing Sit at Table records at coordinate 1 are removed.
- `PROP_HUMAN_SEAT_CHAIR_TABLE_DRINKING` at the second coordinate remains for review.
- Any coordinate left without a remaining pose is removed from the review file.

This leaves only the genuinely new pose records for the admin to inspect.

## Step 2: Review

### Review unit

Review is organized by object item, matching the normal object pose picker.

- Spawn one object model at a time.
- List only genuinely new poses with their normal friendly labels and group descriptions.
- Show current live points as `1`, `2`, and so on in the left rail.
- Show unique new candidate points after them as `N1`, `N2`, and so on.
- Existing live points are selectable preview context and are never changed by review; existing poses are not listed.
- Every new pose and new point has its own green approval checkbox.
- The current ped may review gender-neutral poses plus poses matching that ped's gender. Other-gender poses stay visible in gray without a checkbox and show `Male` or `Female` on the right.

### Review controls

The review interface provides:

- **Back**: move to the previous item without committing undecided pose or point checks.
- **Next**: move to the next item without committing undecided pose or point checks.
- **Approve**: always open a read-only confirmation before independently merging checked new poses and points for the current item.
- The red warning explains that unchecked poses and new coordinates will be removed. **Poses to be processed** and **New coordinates to be processed** are separate sections, with approvals in green and removals in red.
- A clear item count and position, such as `Item 3 of 12`.
- A normal pose list and a current/new point rail that let the admin try any listed pose at the selected point before deciding.

### Object and pose preview

- The script loads and spawns the candidate item near the admin in a controlled review position.
- The object is frozen and treated as a temporary review entity.
- Selecting a current or new point and then a pose starts that animation at the selected point.
- Selecting another pose safely exits the previous preview and starts the next one on the same object.
- The camera can orbit around the admin/player and includes the existing camera-distance slider.
- Review preview never writes to either JSON file.
- Model load, spawn, collision, missing-model, and scenario-start failures must time out cleanly and mark the record as unable to preview instead of trapping the admin.

## Approval and merge behavior

Approved records must pass the normal live-library server validation again before being merged.

For each approved decision:

- Append an approved point only when an identical live point does not already exist.
- Add an approved pose to `poses.show` only when it is not already live or hidden.
- Pose and point approval do not depend on one another.
- Preserve all unrelated live poses, hidden poses, and points.

Denied records are never added to the live library.

The server performs one controlled live save for the submitted item rather than rewriting `object_offsets.json` once per checked pose or point.

## Temporary entity and player cleanup

Cleanup must be centralized and safe to call repeatedly.

It should:

- Exit the current preview pose using the normal Leave Pose behavior.
- Remove scenario tasks and pose props.
- Stop and destroy the review camera.
- Delete the spawned review object.
- Release NUI focus and review state when leaving the workflow.

Run cleanup:

- Before spawning a new item.
- Before replacing the current spawned object.
- When **Approve** is clicked.
- When the review menu is closed or cancelled.
- When the resource stops.
- When the player disconnects or the spawned entity becomes invalid, where applicable.

The next item is not spawned until cleanup of the previous item completes.

## Server authority and concurrency

- Reading, cleaning, rewriting, and merging review data are server operations.
- Every callback rechecks `ReviewJobs`; opening the menu once does not grant lasting authority.
- Only one active batch-review owner should be allowed at a time. A short-lived server lock prevents two admins from approving the same records concurrently.
- The lock is released on completion, cancel, disconnect, timeout, or resource stop.
- Before every merge, compare against the current in-memory live library again because another player may have added the pose after cleanup.
- Writes to both JSON files use the resource's existing deterministic encoder and server-side validation.
- A failed write must not report success or discard the candidate record.

## Suggested file separation

Conceptually:

- `server/review.lua`: review-file loading, validation, cleanup, session lock, approval merge, progress persistence.
- `client/review.lua`: `/poseReview` command, spawned review entity, pose preview, camera, navigation, and cleanup.
- Existing `server/target.lua`, `client/target.lua`, and `client/ui.lua`: expose only the narrowly reusable globals/callbacks required by the review scripts.
- `shared/configTarget.lua`: review filename, spawn distance, model timeout, session timeout, and review menu text.

The exact split can change, but batch-review state should not be mixed into the normal pose editor state unless a shared function genuinely requires it.

## Implemented decisions

1. **Immediate item merge:** Approve writes checked poses and checked points to the live library as one item operation. There is no later global commit step.

2. **Persistent progress:** Approval processes only poses compatible with the current ped. Processed data is removed only after the live save succeeds. Incompatible poses remain for a later reviewer using the required gender, and candidate coordinates remain pending while any such pose is left to test. The item is removed from `object_offsets review.json` only after no review poses remain.

3. **Checkbox submission:** Green checks beside new poses and new points control approval independently. Approve always shows confirmation; leaving every candidate unchecked removes all of them after confirmation.

4. **Undecided navigation:** Back and Next may move between items without submitting them. Pose checks, point checks, and selected preview points persist for the active client session.

5. **Spawn location:** Each temporary object spawns `SpawnDistance` in front of the admin at their current review origin. The previous preview is fully cleaned before another page spawns.

6. **Input compatibility:** Cleanup accepts the current record-array format and uses the live library normalizer to migrate the older `"POSE": coordNumber` group maps.

7. **Preview failures:** A failed model or pose preview reports an error but leaves the item reviewable. The admin may navigate away or leave it unchecked for removal during approval.

## Acceptance examples

- A non-admin never sees Upload Review and cannot call its server callbacks successfully.
- An admin sees the red button only while valid candidate data remains in `object_offsets review.json`.
- Cleanup removes a live pose regardless of its imported coordinate but retains a different animation using that same coordinate.
- Cleanup removes all `noshow`, invalid references, orphan coordinates, and empty items only from the review file.
- One item is spawned at a time, and the prior item is deleted before the next appears.
- An item with several candidate poses and points lets the admin preview every pose at the selected current or new point and approve independent subsets.
- Approving a pose or point does not disturb matching or unrelated live data.
- Denied or undecided poses and new points are not merged.
- Closing review, resource stop, or a preview failure leaves no spawned object, camera, pose task, or attached prop behind.
- Two admins cannot merge the same review batch concurrently.
