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
- [ ] Jump (1.0 m apex, player gravity 19.6 m/s², launch 6.26 m/s, airtime 0.64 s) feels snappy rather than floaty; a flat jump is about 2.5 m from walk and 3.8 m from sprint; air control (0.3) allows small corrections, not mid-air turns.
- [ ] Mantle the 1.0, 1.5 and 1.9 m ledges by pressing Space while facing them; 2.3 m refuses, also when jumping first and holding Space. Facing the 0.5 m "jump up" ledge, Space is a normal jump (steer onto it and land on top); holding Space in the air beside it does not mantle. Mantle speed (0.25 s + 0.15 s/m) feels right.
- [ ] Mantle into the vent on the 1.5 m ledge line: ends crouched inside. Crawl through the 90° turn and the down-ramp to the floor exit and back. Standing up is impossible inside.
- [ ] Under the 1.2 m ceiling, releasing Ctrl keeps you crouched; you stand up on your own after leaving it.
- [ ] Gaps: 2 m clears with a walk jump; 3.3 m needs a sprint jump (a walk jump falls short). Holding Space in the air does not catch the same-level far platform (a ledge catch needs a ledge 1.0 m or more above where you last stood).
- [ ] Footsteps: walk each surface strip; sound and the Player tab's surface/loudness change per strip (concrete 6, carpet 3, wood 7.2, metal 9.6, grass 4.2 when walking). Sprint and crouch change step rate and loudness. Metal steps sound like a dull metal plate, not a spoon on glass (impactPlate sounds, pitch 0.8).
- [ ] Landing off the 2 m and 5 m drops is audibly louder than a footstep; `player.landed` shows ~10.6 and ~16.8 (a plain 1 m jump on concrete lands at ~7.5). Ramps lead back up without snagging.
- [ ] Walking off a hub doorway that leads nowhere respawns you at the hub spawn.

## M2 Core framework

- [ ] Spawned test stimuli appear in the Event Log tab.
- [ ] Chains are visible and terminate (no runaway loops).
- [ ] Attribute and modifier changes show in the Stats tab.
- [ ] Walking in the hub logs `stimulus.emitted` noise entries (Event Log tab, filter `stimulus`) with the same loudness as the `player.footstep` entry just before.
- [ ] Debug panel Overlays tab, tick "Stimuli", close the panel: each footstep draws a yellow wire sphere of the loudness radius at the feet for about 1.5 s; sprinting on metal draws visibly bigger spheres than crouching on carpet. Lines are readable, not distracting, and do not tank the frame rate.
- [ ] Run `tests/ui/debug_panel/fixtures/overlay_demo.tscn` (two rooms, navmesh baked at start, listener behind the wall): the yellow noise path goes round through the doorway, not through the wall; the orange fire sphere is distinct from the yellow noise sphere.

## M2 Graybox kit

See [../levels/kit.md](../levels/kit.md).

- [ ] Open `levels/kit/kit_showcase.tscn` in the editor: every part shows; changing a part's properties in the inspector rebuilds it immediately, without errors in the Output panel.
- [ ] Typing an illegal value (Ledge height 1.95, Ramp rise above 40°, vent interior height 2.0, a door 0.6 m wide) shows a warning triangle on the node with a readable message; the geometry stays sane.
- [ ] Ctrl+D on a part duplicates it once (no doubled geometry); saving the scene stores only the part's properties.
- [ ] Hub and movement course play exactly as in M1 (re-run the M1 movement checks): doorways, strips, ledges, vent crawl (mouth, turn, slope, exit), gaps, drop tower.
- [ ] Above and around the "1 Movement" doorway, and above the corridor's exit into the hall seen from the hall: plain wall, no dark or striped (z-fighting) slab.
- [ ] The grid reads as a 1 m scale reference; surface strips are told apart at a glance; signs are readable from about 6 m.
- [ ] Debug > Visible Navigation while running the hub: navmesh covers the hub, corridor, hall floor, strips, ramps and walkway tops; nothing inside the vent or under the 1.2 m ceiling.

## M3 Physics objects and fire (Physics and fire)

Start the hub and go through doorway "3 Physics & Fire" (east wall) into the gallery room ([../levels/hub-and-gallery.md](../levels/hub-and-gallery.md#3-physics-and-fire)); the debug panel (`) Spawn tab spawns more objects 2 m in front of you and "Reset level" brings everything back. Keep the Event Log tab (filter `object.` / `player.`) and Overlays > Heat at hand. See [../game/objects-and-fire.md](../game/objects-and-fire.md).

- [ ] Pick up a small crate, cardboard box and bottle with E (look at it within 2 m): it floats 1.2 m ahead slightly below the eyes, follows the view smoothly without lag or jitter, and bumps into walls instead of passing through them. The large and metal crates and the barrel refuse (`player.pickup_refused`).
- [ ] Walking with the small crate (10 kg) feels a bit slower (x0.8); with a box or bottle it does not. Mantling does nothing while carrying; jumping still works.
- [ ] E puts the object down gently; Q drops it; LMB throws it: a crate flies a short arc (4 m/s), a box or bottle flies fast and far (12 m/s). Pushing a held crate into a corner and walking away drops it (`how: stuck`) rather than dragging it through the wall.
- [ ] Impacts: dropping and throwing objects makes sounds that match the material (wood thunk, metal clang, glass, soft cardboard) and get louder with harder hits; a crate set down gently is silent. A thrown bottle shatters on the wall with glass sounds and debris.
- [ ] Fire: Spawn two small crates side by side (touching), "Ignite looked-at" one. Light, flames and a quiet crackle start; the neighbour's Heat label climbs and it catches after about 3 s. A metal crate beside it never burns; a crate behind a wall never warms up.
- [ ] Brazier: spawn one and throw or place a crate against it: the crate catches in about 2 s. Standing next to the brazier logs `player.hurt` (damage.fire) a couple of times a second.
- [ ] Carry a burning crate: `player.hurt` with shape `contact` every 0.5 s; carry it to a cold crate and it lights that one.
- [ ] A burning crate burns out after 20 s (cardboard 8 s): flames stop, it turns black for a moment and falls apart into debris that disappears after about 10 s. Debris never blocks walking.
- [ ] Explosive barrel: "Ignite looked-at" (or push burning crates against it): big bang, flash, fireball; nearby crates are knocked away and the ones within about 2 m catch fire at once; a second barrel 2 m away goes off right after. Very close crates are blown apart.
- [ ] Wooden barricade: spawn one, ignite it; it burns for 30 s, then disappears and the gap is passable.
- [ ] Time tab: 0.25 x makes the fire and flying objects slow-motion; Reset returns to normal. Heat overlay labels are readable and disappear when unticked.
- [ ] Fire light and particles look right (orange flicker, soft flames, no square sprites); several fires do not tank the frame rate.

Gallery room 3 (Physics and fire):

- [ ] Walk in from the hub: doorway 3, both corridor ends, the side-room doorway and the parapet show plain walls, no striped (z-fighting) faces or gaps; every station sign reads from about 6 m and from the entrance the room reads as six separate stations.
- [ ] A Fire spread: ignite crate 1 (Ignite looked-at, or set a crate lit at the brazier against it). Fire walks along the row about every 5 s; it stops at the metal crate (crates 6 and 7 stay at heat 0.0 in the Heat overlay); the crate tucked behind the thin wall never warms. The burning row lights the back wall and floor orange.
- [ ] B Brazier: throw a box and place a crate against the brazier: the box flares almost at once, the crate catches in about 2 s; carrying the burning crate hurts (`player.hurt`) and lights what you set it against.
- [ ] C Barrel chain: from behind the parapet, "Damage looked-at" barrel 1 until it blows (or throw a burning box at it): barrel 2 goes off right after, the crate stack is thrown and burns. The blast reads well from the parapet; nothing at the fire row or the brazier is touched.
- [ ] D Barricade: set a burning crate in the barricaded doorway: the barricade catches within about 10 s, burns for 30 s, then disappears and you can walk into the side room. Throw or break its crate: two glass bottles drop out whole.
- [ ] E Throwables: bottles thrown at a wall shatter; boxes and crates thrown onto the metal floor sound and log louder (`object.impact` loudness) than on concrete; the table items are easy to pick off the 1.0 m table.
- [ ] F Too heavy: E on the large and the metal crate is refused (`player.pickup_refused`), the sign explains why.
- [ ] Reset level (Spawn tab) after a few fires: the hub reloads with every object back, nothing still burning, the panel still works, and the time scale you set stays.

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
