# Playtest checklist

Manual checks for feel and anything automated tests cannot cover. Run the section for the milestone before merging its branch. Items are derived from the milestone scope; refine them as each milestone settles its numbers.

## M0 Skeleton

- [ ] Project opens and runs; hub graybox loads.
- [ ] Tests and lint run via `tools/run_tests.sh` and `tools/lint.sh`; pre-commit hook fires.
- [ ] Input map contains the actions in [../game/controls.md](../game/controls.md).
- [ ] ` opens and closes the debug panel; Time tab changes time scale.

## M1 Player controller (Movement course)

Start the main scene (hub), walk through doorway "1 Movement". Keep the debug panel's Player tab and Event Log tab at hand (` key).

- [ ] Mouse is captured on start; look feels right at 0.0025 rad/px; pitch stops just short of straight up/down. Esc frees the mouse, a click recaptures it; opening and closing the debug panel restores capture.
- [ ] Walk (4 m/s), sprint (6 m/s, only roughly forward) and crouch (2 m/s) feel responsive; start and stop are snappy but not twitchy (accel 40, decel 50).
- [ ] Crouch camera drop (0.15 s) feels smooth, not jarring; crouched eye height does not clip into the 1.0 m vent ceiling.
- [ ] Jump (1.0 m apex) feels right; air control (0.3) allows small corrections, not mid-air turns.
- [ ] Mantle the 0.5, 1.0, 1.5 and 1.9 m ledges by pressing Space while facing them; 2.3 m refuses, also when jumping first and holding Space. Mantle speed (0.25 s + 0.15 s/m) feels right.
- [ ] Mantle into the vent on the 1.5 m ledge line: ends crouched inside. Crawl through the 90° turn and the down-ramp to the floor exit and back. Standing up is impossible inside.
- [ ] Under the 1.2 m ceiling, releasing Ctrl keeps you crouched; you stand up on your own after leaving it.
- [ ] Gaps: 2 m clears with a walk jump; 4 m needs a sprint jump. Note how forgiving holding Space in the air (ledge catch) makes the gaps.
- [ ] Footsteps: walk each surface strip; sound and the Player tab's surface/loudness change per strip (concrete 6, carpet 3, wood 7.2, metal 9.6, grass 4.2 when walking). Sprint and crouch change step rate and loudness.
- [ ] Landing off the 2 m and 5 m drops is audibly louder than a footstep; `player.landed` shows ~7.5 and ~11.9. Ramps lead back up without snagging.
- [ ] Walking off a hub doorway that leads nowhere respawns you at the hub spawn.

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
