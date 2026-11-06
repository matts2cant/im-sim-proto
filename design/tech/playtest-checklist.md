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

Until the gallery room exists: start the hub, open the debug panel (`) and use the Spawn tab (objects appear 2 m in front of you). Keep the Event Log tab (filter `object.` / `player.`) and Overlays > Heat at hand. See [../game/objects-and-fire.md](../game/objects-and-fire.md).

- [ ] Pick up a small crate, cardboard box and bottle with E (look at it within 2 m): it floats 1.2 m ahead slightly below the eyes, follows the view smoothly without lag or jitter, and bumps into walls instead of passing through them. The large and metal crates and the barrel refuse (`player.pickup_refused`).
- [ ] Walking with the small crate (10 kg) feels a bit slower (x0.8); with a box or bottle it does not. Mantling does nothing while carrying; jumping still works.
- [ ] E puts the object down gently; Q drops it; LMB throws it: a crate flies a short arc (4 m/s), a box or bottle flies fast and far (12 m/s). Pushing a held crate into a corner and walking away drops it (`how: stuck`) rather than dragging it through the wall.
- [ ] Impacts: dropping and throwing objects makes sounds that match the material (wood thunk, metal clang, glass, soft cardboard) and get louder with harder hits; a crate set down gently is silent. A thrown bottle shatters on the wall with glass sounds and debris.
- [ ] Fire: Spawn two small crates side by side (touching), "Ignite looked-at" one. Light, flames and a quiet crackle start; the neighbour's Heat label climbs and it catches after about 3 s. A metal crate beside it never burns; a crate behind a wall never warms up.
- [ ] Brazier: spawn one and throw or place a crate against it: the crate catches in about 2 s. Standing next to the brazier logs `actor.damaged` (damage.fire, M4) a couple of times a second.
- [ ] Carry a burning crate: `actor.damaged` for all six parts every 0.5 s; carry it to a cold crate and it lights that one.
- [ ] A burning crate burns out after 20 s (cardboard 8 s): flames stop, it turns black for a moment and falls apart into debris that disappears after about 10 s. Debris never blocks walking.
- [ ] Explosive barrel: "Ignite looked-at" (or push burning crates against it): big bang, flash, fireball; nearby crates are knocked away and the ones within about 2 m catch fire at once; a second barrel 2 m away goes off right after. Very close crates are blown apart.
- [ ] Wooden barricade: spawn one, ignite it; it burns for 30 s, then disappears and the gap is passable.
- [ ] Time tab: 0.25 x makes the fire and flying objects slow-motion; Reset returns to normal. Heat overlay labels are readable and disappear when unticked.
- [ ] Fire light and particles look right (orange flicker, soft flames, no square sprites); several fires do not tank the frame rate.

## M4 Damage and weapons (Shooting range)

Until the gallery room exists: start the hub, open the debug panel (`) and use the Spawn tab to place training dummies (they appear 2 m ahead facing away from you), medkits and barrels. Keep the Event Log tab (filter `actor.` / `weapon.`) and the Player tab at hand. See [../game/damage.md](../game/damage.md) and [../game/weapons-and-aiming.md](../game/weapons-and-aiming.md).

- [ ] (Since M5 give the pistol, baton and ammo with Spawn > Give item first.) 1 draws the pistol (box in the lower right), 2 the baton, the same key again holsters. HUD bottom right shows "Silenced pistol" and "10 / <rounds in the inventory>"; nothing for the baton's ammo.
- [ ] Reticle: standing still the circle shrinks to a small ring in under a second (0.8 s settle); walking widens it to about 4.5 degrees, sprinting or jumping to 7.5, right away; flicking the mouse and every shot bloom it; it never exceeds 10. The settle speed feels fair, not sluggish.
- [ ] Shots land inside the circle (shoot a wall at 10 m and compare the impact noise sphere in Overlays > Stimuli); at rest a dummy's head at 5 m is reliable.
- [ ] Pistol: shot sound reads as suppressed, not as a punch; 0.35 s between shots; empty magazine clicks; R reloads in 1.6 s (sound plays) and the counter shows "reloading". Shot noise 6 m at the muzzle and 4 m at the impact show in Overlays > Stimuli.
- [ ] Shoot a dummy: head 50 (it dies and tips over backwards), torso 25, arms and legs 25; floating numbers name the part and are readable, do not overlap badly and fade in about a second. E on the dummy resets it.
- [ ] Shoot an explosive barrel: one shot blows it up. Shoot a medkit or a small crate: it is knocked away a little.
- [ ] Baton: swing with a visible chop; from behind an unaware dummy (Spawn puts it facing away) one hit shows "stun 200" and "KO" and it tips over; from the front three hits ("stun 20" each). Hitting a crate damages it a little (blunt 5), never through stun.
- [ ] Player damage (Spawn tab "Damage looked-at" does not target yourself; use barrels and fire): standing about 2 m from an exploding barrel takes roughly 20 torso and 6 elsewhere; the screen flashes red; the silhouette (bottom left) turns yellow/red per part.
- [ ] Jump off the movement course's 5 m drop: both legs lose about 32 (silhouette legs yellow). A second fall disables them: you crawl at 1 m/s and cannot stand. One disabled leg: walking is clearly slower (x0.6).
- [ ] Medkit (since M5 from the belt): its belt key heals 30 spread over the damaged parts and the count drops by one; at full health nothing is used (`item.use_refused`).
- [ ] Death (stand next to two barrels): "You died" overlay, nothing but E works; E reloads the level. The Spawn tab's "Reset level" does the same.
- [ ] Carrying a burning crate slowly hurts every part (`actor.damaged`, damage.fire).

## M5 Inventory (Inventory bay)

Until the gallery room exists: start the hub, open the debug panel (`) and use Spawn > Give item (and the object buttons: "medkit" spawns a medkit pickup). Keep the Event Log tab (filter `item.`) at hand. See [../game/inventory.md](../game/inventory.md).

- [ ] Look at an item on the floor within 2 m: the prompt under the reticle reads "E: pick up Multitool (3)" (the count only above 1); a small crate says "E: carry Small crate", a large crate "Too heavy", a training dummy "E: reset Training dummy"; carrying, "E: put down ...". The prompt is readable and does not flicker when the crosshair sits on an edge.
- [ ] E picks the item up; the pistol, baton, medkit, multitool, lockpick and biocell appear in the first free belt slot; ammo, keycard and datapad do not.
- [ ] Fill the grid (Give item: keycard stack x30): E on another item says "No room in inventory" for about 2 s and the item stays. A big ammo pickup with little room leaves the rest on the floor with the smaller count.
- [ ] 1-0: the pistol draws / holsters, the slot is highlighted on the belt HUD; a multitool shows "Multitool" bottom right and LMB does nothing; a medkit heals when hurt and is refused when not ("You are not hurt"); a biocell says "Nothing happens"; a datapad opens the reading panel and E or Esc closes it without also picking up what you look at.
- [ ] R reloads from the ammo stacks: "2 / 103" becomes "10 / 95"; the smallest ammo stack is used up first and its cell frees up in the grid.
- [ ] Q with the pistol drawn drops it about a metre ahead; it clatters (impact noise in Overlays > Stimuli); picking it up again keeps its magazine (tooltip "Magazine: n"). Q while carrying a crate still just lets go of the crate. Dropping against a wall never puts the item through it.
- [ ] I opens the inventory: the game is paused (a falling object freezes, footsteps stop), the mouse is free, I or Esc closes and the mouse is captured again. It does not open while dead or with the debug panel open.
- [ ] Items of every footprint fit and block correctly on the 6x5 grid: dragging shows a green footprint where it fits and red where it overlaps or sticks out; releasing on red changes nothing.
- [ ] Drag an item onto a belt slot to assign it; drag a belt item off the belt to clear the slot; drag an item out of the panel to drop it. Hover an item and press a number to assign it.
- [ ] Right-click: Use / Equip / Read, Drop, Split stack (halves it into a free cell), Assign to belt slot. The tooltip shows name, description and count; it does not cover the item under the mouse.
- [ ] The inventory reads as Deus Ex: dark panel, thin grid lines, coloured item blocks with legible short names at 1152x648 and at the 840x648 window this machine opens.

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
