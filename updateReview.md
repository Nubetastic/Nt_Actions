# Update Review

## My understanding

This update expands the existing object-pose library so one furniture model can have several reusable coordinate sets. In the current JSON these coordinate sets are the entries in `offsets`, and each named animation under `poses.show` or `poses.noshow` stores the number of one of those entries. To keep the language clear in this review:

- **Animation** means a configured scenario such as `PROP_HUMAN_SEAT_BENCH`.
- **Pose number** means a numbered coordinate/heading set in the object's `offsets` list.
- Each animation still has one saved/default pose number.

### Normal menu mode

- Add a red **Mod** button beside **Close**.
- The pose-removal minus buttons and **Undo** are hidden initially.
- Clicking **Mod** toggles modification mode. While it is enabled, the minus buttons and **Undo** are visible; clicking **Mod** again hides them.
- Animation labels show their assigned number as `Pose Name (#)` with the number aligned to the far right in a matching style to the 1-4 down below.
- Pose numbers are shown horizontally at the bottom of the pose menu.
- A pose number is white normally and green when it is selected or when the player entered an animation using that number.

### Using multi-pose furniture

- The bottom buttons 1-4 are optional, player-controlled pose-number overrides. They do not edit JSON.
- Only one override number is selected at a time.
- Clicking an unselected number selects it. Clicking the selected number again unselects it, leaving no override active.
- When an override is selected, choosing an animation uses the selected number's coordinates instead of the animation's saved pose number. For example, if 1 is selected, the script uses pose number 1.
- When no override is selected, choosing an animation uses that animation's saved/default pose number.
- Selecting a different override while already in an animation should move/restart that animation at the newly selected number's coordinates.

### Managing pose numbers

- The main menu displays up to a max of four pose numbers (based on the reference to "the 4 shown numbers"). We will have 1-4 always shown, but gray out numbers not in use.
- A pose number can be removed only if no animation uses it.
- Removable numbers get a red minus beneath them; non-removable numbers retain blank space so the horizontal layout stays aligned.
- Removing a number compacts the active numbering so later numbers shift down. Animation references must shift with them so they continue to point at the same coordinates.
- Removing a number, or overwriting its coordinates, saves the old coordinate set in an undo cache. Cached entries are displayed as a separate sequence numbered from 1.

### Modifying an animation

- **Modify Pose** lets a player assign the animation to an existing pose number or create coordinates for a new pose number.
- Existing pose numbers are listed at the bottom as choices.
- An existing number that is not assigned to any animation is red and can be overwritten with the editor's new coordinates.
- Saving must update the animation's assigned pose number as well as any new/overwritten coordinates involved.

### Undo menu

There appear to be two kinds of recoverable items:

1. **Old pose numbers:** coordinate sets cached after a pose number is removed or overwritten. Each has a green plus and red minus. The plus restores it to the active pose-number list when fewer than four active numbers exist; the minus permanently removes it from the cache.
2. **Hidden animations:** the current deleted-pose records. These also get a red minus so an admin can permanently remove the hidden record. Once permanently removed, regular players can add that animation again through **Add Pose**. The existing green plus continues to restore it.

All of this should remain scoped per object model, as the current library is, and server-side validation should remain authoritative for shared JSON changes.

## Differences from current behavior

- Delete minus buttons and **Undo** are currently always shown to an authorized admin; there is no Mod toggle.
- Pose-number controls are not currently rendered in the menu.
- Selecting an animation always uses its saved offset; there is no temporary number selection.
- Unused offsets are currently deleted automatically on every save, so an unused active number cannot remain available or be overwritten later.
- There is no separate old-number undo cache.
- Hidden animations can be restored but cannot be permanently removed, and hidden animations are intentionally blocked from **Add Pose**.
- The current save process deduplicates identical coordinate sets and compacts their numbering. The requested stable active slots and undo cache will require more explicit rules than the current automatic compaction.

## Questions before implementation

1. Is **Mod** visible only to admins, and should it merely be colored red, or should its label literally be something like `Mod` in red? The current **Modify** action is available to regular players when `AllowPlayerModify` is enabled, while delete/undo is admin-only.

2. Is four a hard maximum number of active pose numbers per object model? If existing data contains more than four, should all existing numbers remain visible, or should the data be migrated/reduced?

3. Please confirm that "pose number" means a coordinate/heading set, while the named menu poses are animations that each reference one coordinate set.

4. When should a player's temporary override reset: when the menu closes, when they leave the animation, when they target a different object/model, or only when they manually unclick the number?

5. When **Modify Pose** assigns an animation to another existing number, are the animation's prior coordinates left as an unused active number, or immediately moved to the old-number undo cache if nothing else uses them?

6. How is a brand-new number created? Should the editor show an **Add Number** choice whenever fewer than four exist, or should saving new coordinates automatically append a number?

7. Does "not in use" include references from hidden animations in the Undo menu, or only visible animations? Removing a number referenced by a hidden animation would otherwise leave that hidden animation with no valid coordinates to restore.

8. When an old number is restored with the green plus, should it append as the next available active number, return to its former number (shifting current numbers), or fill a selected empty slot? Does restoring it also restore any former animation assignments, or only the coordinates?

9. Should the old-number undo cache persist in `object_offsets.json` across restarts, and is it unlimited? Also, if an overwritten/removed coordinate is identical to one already active or cached, should it be deduplicated or retained as a separate undo entry?

10. In the hidden-animation section of Undo, is red minus intended as permanent deletion with no further recovery? I understand that this deletes only the hidden assignment, not the animation from configuration, which is why players can then add it again.

11. Should pose-number removal, old-number restoration/deletion, and permanent hidden-animation deletion all use the same admin permission as the current pose hide/restore actions?

12. When Mod mode is off, should the pose-number row remain visible for normal override selection, with only its removal controls hidden? My current reading is yes.

## Suggested acceptance examples

- A bench has numbers 1 and 2. Sit A uses 1 and Sit B uses 2. Entering either animation highlights and uses its saved number.
- With no override selected, Sit A uses its saved number 1. Selecting button 2 makes Sit A (and subsequently selected animations) use number 2 without changing any saved assignments.
- Clicking selected button 2 again clears the override. The next animation uses its own saved number.
- An unused number can be removed in Mod mode. Higher active numbers compact, all animation references remain correct, and the removed coordinates appear in old-number Undo.
- Overwriting an unused number keeps that number active with new coordinates and places its former coordinates in old-number Undo.
- Restoring an old number fails cleanly when all four active slots are occupied.
- Permanently deleting a hidden animation removes its hidden assignment, after which the animation is available in Add Pose again.
