# Playtest checklist

Manual checks for feel and anything automated tests cannot cover. Run the section for the milestone before merging its branch. Items are derived from the milestone scope; refine them as each milestone settles its numbers.

## M0 Skeleton

- [ ] Project opens and runs; hub graybox loads.
- [ ] Tests and lint run via `tools/run_tests.sh` and `tools/lint.sh`; pre-commit hook fires.
- [ ] Input map contains the actions in [../game/controls.md](../game/controls.md).
- [ ] ` opens and closes the debug panel; Time tab changes time scale.

## M1 Player controller (Movement course)

- [ ] Walk, crouch, sprint, jump feel responsive.
- [ ] Mantle works on ledges and crates.
- [ ] Vents are only passable while crouched.
- [ ] Footstep noise differs by movement mode and floor surface.

## M2 Core framework

- [ ] Spawned test stimuli appear in the Event Log tab.
- [ ] Chains are visible and terminate (no runaway loops).
- [ ] Attribute and modifier changes show in the Stats tab.

## M3 Physics objects and fire (Physics and fire)

- [ ] Objects can be picked up, carried and thrown; impacts make noise.
- [ ] Fire spreads to flammable neighbours only.
- [ ] Explosive objects explode when shot or burned.

## M4 Damage and weapons (Shooting range)

- [ ] Per-part damage readouts match the part hit.
- [ ] Leg, arm, head and torso effects behave per [../game/damage.md](../game/damage.md).
- [ ] Reticle shows the spread cone and shots land inside it; settle time feels right.
- [ ] Baton knockout from behind on an unaware target; several hits otherwise.

## M5 Inventory (Inventory bay)

- [ ] Items of every footprint fit and block correctly on the 6x5 grid.
- [ ] Belt slots 1-0 reference grid items; consumables stack.
- [ ] Dropped items become physics objects and make noise.

## M6 Abilities and saving (Inventory bay)

- [ ] Each augmentation toggles, drains energy and has its stated effect.
- [ ] Biocells refill energy; skill tier edits in the Stats tab change behaviour.
- [ ] F5 quicksave and F9 quickload restore state.

## M7 Light and AI (Perception lab, AI arena)

- [ ] HUD light indicator tracks light level; shooting lights and breaker change it.
- [ ] Guards move through Unaware, Suspicious, Searching, Alerted/Combat and back; `?` / `!` icons and barks show.
- [ ] Guards discover bodies and wake unconscious guards; unconscious guards do not wake alone.
- [ ] Cloak hides the player from guards.

## M8 Security (Security wing)

- [ ] Cameras see a cloaked player; alarm panel triggers level-wide alarm.
- [ ] Turret engages intruders.
- [ ] Every door and lock type can be opened by its intended methods.
- [ ] Terminal unlocks with credentials found in the world.

## M9 Mission

- [ ] All four routes are completable.
- [ ] Death leads to reload/restart; extraction shows the summary (time, alarms, kills/knockouts, route).
- [ ] Mission is playable start to finish without debug tools.
