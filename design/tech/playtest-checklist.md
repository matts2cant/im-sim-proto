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
- [ ] Landing off the 2 m and 5 m drops is audibly louder than a footstep; `actor.landed` shows ~10.6 and ~16.8 (a plain 1 m jump on concrete lands at ~7.5). Ramps lead back up without snagging.
- [ ] Walking off a hub doorway that leads nowhere respawns you at the hub spawn.

## Step climbing ([ADR 0058](../decisions/0058-step-climbing.md))

Movement course, steps strip left of the surface strips. Keep the Player tab open for height and grounded.

- [ ] Walk, sprint and crouch into the 0.15 and 0.3 m steps without pressing Space: you go up with no visible stop or slowdown, and no hitch forward.
- [ ] Walk and sprint up and down the 0.17 m stair: the view stays smooth (no pop per riser, about 0.1 s ease), you never feel airborne, and there is no landing thud going down (Event Log: no `actor.landed`); footsteps keep their rhythm.
- [ ] The 0.45 m "jump" step blocks walking; Space jumps onto it.
- [ ] Walk off the back of the 0.3 m step: no drop, no thud. The 1.0 m ledge still falls and lands.
- [ ] Tune the Player tab's step height (e.g. 0.5 m: now the 0.45 step walks up; 0.1 m: the 0.15 step blocks) and set it back to 0.35; note a value that feels better.
- [ ] Interact with, carry and shoot at something right after a step: the crosshair and the rays agree (rays use the eased camera).

## M2 Core framework

- [ ] Spawned test stimuli appear in the Event Log tab.
- [ ] Chains are visible and terminate (no runaway loops).
- [ ] Attribute and modifier changes show in the Stats tab.
- [ ] Walking in the hub logs `stimulus.emitted` noise entries (Event Log tab, filter `stimulus`) with the same loudness as the `actor.footstep` entry just before.
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

- [ ] Pick up a small crate, cardboard box and bottle with E (look at it within 2 m): it sits close in the lower part of the view (crate 0.75 m ahead), half see-through, the crosshair clear above it, and follows the view exactly without lag or jitter. The large and metal crates and the barrel refuse (`player.pickup_refused`).
- [ ] Knock a small crate onto its side (or spawn one and push it over), pick it up: within a blink it turns upright and square to the view (never diagonal), and turns with you as you look around.
- [ ] Carry a crate through a doorway and along a wall: it passes into the jambs and the wall (see-through) without snagging, stopping you or being dropped; you stop at walls exactly as without it.
- [ ] Walk up to a wall until you touch it and press E / Q / LMB: nothing is released, the prompt reads "No room to put down Small crate" (`player.release_refused`). Step back a little (about 0.7 m between you and the wall): E sets it down between you and the wall, never inside the wall or you.
- [ ] Stack crates: put one down, stand about a metre from it, look at the middle of its top and press E: the carried crate is set on top, upright, and stays. Stack a third one the same way (the second is at chest height).
- [ ] Walking with the small crate (10 kg) feels a bit slower (x0.8); with a box or bottle it does not. Mantling does nothing while carrying; jumping still works.
- [ ] E puts the object down gently; Q drops it; LMB throws it: a crate flies a short arc (4 m/s), a box or bottle flies fast and far (12 m/s). A throw starts from a free spot in front of you, never inside a wall or another object.
- [ ] Impacts: dropping and throwing objects makes sounds that match the material (wood thunk, metal clang, glass, soft cardboard) and get louder with harder hits; a crate set down gently is silent. A thrown bottle shatters on the wall with glass sounds and debris.
- [ ] Fire: Spawn two small crates side by side (touching), "Ignite looked-at" one. Light, flames and a quiet crackle start; the neighbour's Heat label climbs and it catches after about 3 s. A metal crate beside it never burns; a crate behind a wall never warms up.
- [ ] Brazier: spawn one and throw or place a crate against it: the crate catches in about 2 s. Standing next to the brazier logs `actor.damaged` (damage.fire, M4) a couple of times a second.
- [ ] Carry a burning crate: `actor.damaged` for all six parts every 0.5 s; carry it to a cold crate and it lights that one.
- [ ] A burning crate burns out after 20 s (cardboard 8 s): flames stop, it turns black for a moment and falls apart into debris that disappears after about 10 s. Debris never blocks walking.
- [ ] Explosive barrel: "Ignite looked-at" (or push burning crates against it): big bang, flash, fireball; nearby crates are knocked away and the ones within about 2 m catch fire at once; a second barrel 2 m away goes off right after. Very close crates are blown apart.
- [ ] Wooden barricade: spawn one, ignite it; it burns for 30 s, then disappears and the gap is passable.
- [ ] Stacking (ADR 0054): carry and stack 3 small crates into a column and a 2 + 1 pyramid. Jump onto a single crate, mantle onto the 2-crate column, jump in place 5 times on each, hop forward and back on the top, walk across the top and off the edge: nothing slides, wobbles, jitters or flies off; landings feel solid.
- [ ] Support (ADR 0055): stack 3 small crates, wait a few seconds, then ignite the bottom one (Ignite looked-at) or break it (Damage looked-at 10, three times): when it falls apart the two above drop straight down onto the floor (top at about 1.2 m), never left floating. Stack 2, wait, pick up the bottom one with E: the top crate drops to the floor.
- [ ] Pushing: walk and then sprint into a 2-crate column: it slides away together at a slow push (about 2 m/s, the player slows to match), the top crate stays on and nothing is launched; walking into a large crate does not move it. A crate dropped or knocked onto the player passes through it (known, ADR 0054): note whether that bothers you.
- [ ] Time tab: 0.25 x makes the fire and flying objects slow-motion; Reset returns to normal. Heat overlay labels are readable and disappear when unticked.
- [ ] Fire light and particles look right (orange flicker, soft flames, no square sprites); several fires do not tank the frame rate.

Gallery room 3 (Physics and fire):

- [ ] Walk in from the hub: doorway 3, both corridor ends, the side-room doorway and the parapet show plain walls, no striped (z-fighting) faces or gaps; every station sign reads from about 6 m and from the entrance the room reads as six separate stations.
- [ ] A Fire spread: ignite crate 1 (Ignite looked-at, or set a crate lit at the brazier against it). Fire walks along the row about every 5 s; it stops at the metal crate (crates 6 and 7 stay at heat 0.0 in the Heat overlay); the crate tucked behind the thin wall never warms. The burning row lights the back wall and floor orange.
- [ ] B Brazier: throw a box and place a crate against the brazier: the box flares almost at once, the crate catches in about 2 s; carrying the burning crate hurts (`player.hurt`) and lights what you set it against.
- [ ] C Barrel chain: from behind the parapet, "Damage looked-at" barrel 1 until it blows (or throw a burning box at it): barrel 2 goes off right after, the crate stack is thrown and burns (since ADR 0057 all three stack crates usually catch at once). The pushes look as strong as before (blast push is now a `force.blast` stimulus). The blast reads well from the parapet; nothing at the fire row or the brazier is touched.
- [ ] D Barricade: set a burning crate in the barricaded doorway: the barricade catches within about 10 s, burns for 30 s, then disappears and you can walk into the side room. Throw or break its crate: two glass bottles drop out whole.
- [ ] E Throwables: bottles thrown at a wall shatter; boxes and crates thrown onto the metal floor sound and log louder (`object.impact` loudness) than on concrete; the table items are easy to pick off the 1.0 m table.
- [ ] F Too heavy: E on the large and the metal crate is refused (`player.pickup_refused`), the sign explains why.
- [ ] Reset level (Spawn tab) after a few fires: the hub reloads with every object back, nothing still burning, the panel still works, and the time scale you set stays.

## M4 Damage and weapons (Shooting range)

Start the hub and go through doorway "4 Shooting Range" (east wall, south of doorway 3) into the gallery room ([../levels/hub-and-gallery.md](../levels/hub-and-gallery.md#4-shooting-range)); the debug panel (`) Spawn tab still places extra training dummies (2 m ahead, facing away from you), medkits and barrels. Keep the Event Log tab (filter `actor.` / `weapon.`) and the Player tab at hand. See [../game/damage.md](../game/damage.md) and [../game/weapons-and-aiming.md](../game/weapons-and-aiming.md).

- [ ] (Since M5 take the pistol, baton and ammo from the hub's loadout table beside the spawn, or Spawn > Give item, first.) 1 draws the pistol (box in the lower right), 2 the baton, the same key again holsters. HUD bottom right shows "Silenced pistol" and "10 / <rounds in the inventory>"; nothing for the baton's ammo.
- [ ] Baton look: drawn (2), it is held like a nightstick at the lower right, grip at the bottom, pointing up and forward (about 60 degrees) and slightly inwards. LMB chops it down across the centre of the view, pivoting about the grip (the hand end stays put), then it returns a little slower. Hits still land at the moment of the click.
- [ ] Reticle: standing still the circle shrinks to a small ring in under a second (0.8 s settle); walking widens it to about 4.5 degrees, sprinting or jumping to 7.5, right away; flicking the mouse and every shot bloom it; it never exceeds 10. The settle speed feels fair, not sluggish.
- [ ] Shots land inside the circle (shoot a wall at 10 m and compare the impact noise sphere in Overlays > Stimuli); at rest a dummy's head at 5 m is reliable.
- [ ] Pistol: shot sound reads as suppressed, not as a punch; 0.35 s between shots; empty magazine clicks; R reloads in 1.6 s (sound plays) and the counter shows "reloading". Shot noise 6 m at the muzzle and 4 m at the impact show in Overlays > Stimuli.
- [ ] Shoot a dummy: head 50 (it dies and tips over backwards), torso 25, arms and legs 25; floating numbers name the part and are readable, do not overlap badly and fade in about a second. E on the dummy resets it.
- [ ] Shoot an explosive barrel: one shot blows it up. Shoot a medkit or a small crate: it is knocked away a little (the push is a `force.impact` stimulus since ADR 0057: same strength, hit near the top and a crate tips back).
- [ ] Baton: swing with a visible chop; from behind an unaware dummy (Spawn puts it facing away) one hit shows "stun 200" and "KO" and it tips over; from the front three hits ("stun 20" each). Hitting a crate damages it a little (blunt 5), never through stun.
- [ ] Player damage (Spawn tab "Damage looked-at" does not target yourself; use barrels and fire): standing about 2 m from an exploding barrel takes roughly 20 torso and 6 elsewhere; the screen flashes red; the silhouette (bottom left) turns yellow/red per part.
- [ ] Jump off the movement course's 5 m drop: both legs lose about 32 (silhouette legs yellow). A second fall disables them: you crawl at 1 m/s and cannot stand. One disabled leg: walking is clearly slower (x0.6).
- [ ] Medkit (since M5 from the belt; since ADR 0059 its belt key puts it in hand and LMB uses it): LMB heals 30 spread over the damaged parts and the count drops by one; at full health nothing is used (`item.use_refused`). Using it from the inventory screen (game paused) heals at once: the silhouette updates before you close the screen.
- [ ] Death (stand next to two barrels): "You died" overlay, nothing but E works; E reloads the level. The Spawn tab's "Reset level" does the same.
- [ ] Carrying a burning crate slowly hurts every part (`actor.damaged`, damage.fire).

Gallery room 4 (Shooting range):

- [ ] Walk in from the hub: doorway 4 and both corridor ends show plain walls, no striped (z-fighting) faces; from the door the booth reads as firing line ahead, melee corner to the right, medkit table beside the door, counter gap on the left. Every sign reads from about 6 m; the lane signs on the counter read when you step up to it.
- [ ] Reticle settling at the firing line: draw the pistol, stand still at the counter: the ring settles onto the 10 m dummy's torso in under a second; look around and back: it blooms and settles again. On lane 4 the 40 m dummy is clearly visible inside the settled ring (lit, not lost against the wall).
- [ ] Shots: 5 m and 10 m torso shots are reliable at rest; the 20 m dummy takes a few tries, the 40 m one several (settled cone ≈ 1 m wide there). Floating numbers read at 10 m, and at 20-40 m are at least visible.
- [ ] Headshot x2: the 5 m dummy's head takes 50 ("head 50", it dies and tips over backwards); E on it (walk round the counter gap) resets it.
- [ ] Baton KO rules (melee corner): sneak up behind the unaware dummy (facing the east wall): one swing shows "stun 200", "KO" and it tips over. From behind the aware one (facing the door): "stun 20" three times before it goes down. From the front of either: three hits.
- [ ] Falloff on the blast lines: stand on the 6 m line, shoot the barrel: nothing (the bang, the crates thrown and lit). Reset level, stand on the 3 m line: about 23 in total, clearly less than at 2 m. Reset, 2 m line: about 46 in total (torso about 19, other parts about 6, silhouette yellow-ish, red flash). The "2 m" and "3 m" floor labels sit at opposite ends of their lines and both read from the 6 m line. The far-wall barrels go off one at a time (3 m apart: no chain).
- [ ] Medkit heal: after the 2 m blast, E on a table medkit puts it in the inventory (and on the belt); its belt key puts it in hand and LMB heals 30 split over the hurt parts and the count drops; a second one tops up; at full health the third is kept (`item.use_refused`, "You are not hurt").
- [ ] Death + Reset: a barrel shot from about 1 m does roughly 30 to the torso (of 100), so take the blast lane barrel and then the three far-wall barrels point blank without healing (or spawn barrels with the Spawn tab): the fourth kills. "You died", nothing but E works; E reloads the hub with every barrel, dummy and medkit back. The Spawn tab's "Reset level" does the same.
- [ ] Settled aim: draw the pistol and stand still for about 1 s (crouched even tighter): the reticle ring shrinks to a small circle around the dot (0.5 degrees, a head-sized spread at 20 m) and stays there, never stalling wider. A shot at a dummy head at 20 m with no movement hits the head most of the time. Walking, sprinting, shooting and arm injuries still widen it clearly.
- [ ] Silhouette after a graze: after the 3 m blast line (a few points of damage) the hurt parts are already yellow-green, not the untouched pure green; the silhouette is pure green again after Reset level and after a medkit heals everything.

## M5 Inventory (Inventory bay)

Start the hub: the player starts with an empty inventory; the loadout table right of the spawn holds the starting kit. Gallery room 7 is behind doorway "7 Inventory & Abilities" (west wall, south half) ([../levels/hub-and-gallery.md](../levels/hub-and-gallery.md#7-inventory-and-abilities-bay)). Spawn > Give item in the debug panel (`) still adds anything. Keep the Event Log tab (filter `item.`) at hand. See [../game/inventory.md](../game/inventory.md).

- [ ] Look at an item on the floor within 2 m: the prompt under the reticle reads "E: pick up Multitool (3)" (the count only above 1); a small crate says "E: carry Small crate", a large crate "Too heavy", a training dummy "E: reset Training dummy"; carrying, "E: put down ...". The prompt is readable and does not flicker when the crosshair sits on an edge.
- [ ] E picks the item up; the pistol, baton, medkit, multitool, lockpick and biocell appear in the first free belt slot; ammo and keycard do not.
- [ ] Fill the grid (Give item: keycard stack x30): E on another item says "No room in inventory" for about 2 s and the item stays. A big ammo pickup with little room leaves the rest on the floor with the smaller count.
- [ ] 1-0 put the slot's item in hand and use nothing (ADR 0059): the pistol draws, the same key again holsters; the slot is highlighted on the belt HUD and the item's name shows just above the belt for about 1.5 s, then fades. A multitool shows "Multitool" bottom right and LMB does nothing.
- [ ] LMB uses the item in hand: a medkit heals when hurt (one per click, it stays in hand while any are left; the last one empties the slot and the hands) and is refused when not ("You are not hurt"); a biocell says "Nothing happens". With empty hands LMB does nothing; carrying a crate, LMB still throws it.
- [ ] Mouse wheel through the belt (give the pistol, baton and medkits, leave a gap): from empty hands wheel down takes the first item from the left, wheel up the last; each notch moves exactly one item, empty slots are skipped, the ends wrap around. Scrolling onto a medkit while hurt does not heal. Scrolling fast feels responsive (no missed or doubled notches, also on a touchpad); scrolling during a reload cancels it like a number key does.
- [ ] H holsters whatever is in hand: the pistol view goes, the belt highlight and the name above the belt disappear, the bottom-right name clears; H with empty hands does nothing. The wheel and H do nothing in the inventory screen, while reading or when dead.
- [ ] R reloads from the ammo stacks: "2 / 103" becomes "10 / 95"; the smallest ammo stack is used up first and its cell frees up in the grid.
- [ ] Q with the pistol drawn drops it about a metre ahead; it clatters (impact noise in Overlays > Stimuli); picking it up again keeps its magazine (tooltip "Magazine: n"). Q while carrying a crate still just lets go of the crate. Dropping against a wall never puts the item through it.
- [ ] I opens the inventory: the game is paused (a falling object freezes, footsteps stop), the mouse is free, I or Esc closes and the mouse is captured again. It does not open while dead or with the debug panel open.
- [ ] Items of every footprint fit and block correctly on the 6x5 grid: dragging shows a green footprint where it fits and red where it overlaps or sticks out; releasing on red changes nothing.
- [ ] Drag an item onto a belt slot to assign it; drag a belt item off the belt to clear the slot; drag an item out of the panel to drop it. Hover an item and press a number to assign it.
- [ ] Right-click: Use / Equip, Drop, Split stack (halves it into a free cell), Assign to belt slot. The tooltip shows name, description and count; it does not cover the item under the mouse.
- [ ] The inventory reads as Deus Ex: dark panel, thin grid lines, coloured item blocks with legible short names at 1152x648 and at the 840x648 window this machine opens.

Hub loadout table and gallery room 7 (Inventory bay):

- [ ] At the spawn the "Loadout" table is in view to the front right and does not get in the way of walking straight to doorways 1 and 2. E takes each item: pistol, baton, medkit, multitool, lockpick and biocell land on belt slots 1-6, the 60 rounds do not; 1 draws the pistol and R has rounds.
- [ ] Walk in through doorway 7: the doorway and both corridor ends show plain walls, no striped (z-fighting) faces. From the door the room reads as: item table along the left wall, stack and "Fill the grid" tables on the right, metal drop zone in the middle, red dais and datapad pedestal at the back. Every station sign reads from the door.
- [ ] Item table: each item's tag ("Silenced pistol 2×1" ...) reads when you stand at it and sits behind the right item; the prompt names the item you look at, never its neighbour. After taking all eight, I shows every footprint in the grid (pistol 2×1, baton 1×3, the rest 1×1).
- [ ] Stacks (start without that item, e.g. skip the loadout table): E on "Multitool (12)" gives a stack of 10 and one of 2; medkits 16 give 15 + 1; ammo 150 gives 100 + 50; I shows the split stacks with their counts.
- [ ] Fill the grid: take the pistols, batons and ammo one by one: before the table is empty E says "No room in inventory" for about 2 s and the item stays on the table.
- [ ] Datapad pedestal (ADR 0060): looking at each datapad the prompt reads "E: read Inventory bay" / "E: read Storage access", never the neighbour's. E opens the text (game paused), E or Esc closes it without also re-reading or picking anything up; "Added to log: Storage access" shows for about 2 s after closing. The datapad stays on the pedestal, the inventory is unchanged. Reading it again shows the text but no new "Added to log".
- [ ] Datapads are props: a blast or walking into the pedestal pushes them like other small objects; E never carries or picks them up.
- [ ] L opens the personal log (paused, mouse free); L or Esc closes it. Entries are listed newest first, the newest selected; clicking an entry shows its text on the right; long text scrolls with the mouse wheel. Under "Codes": "Storage Door: 2817  (Storage access)". L does nothing while the inventory or the text overlay is open, or when dead; I does nothing while the log is open.
- [ ] Debug panel Give item no longer lists a datapad; the inventory right-click menu has no "Read".
- [ ] Drop zone: Q drops the item in hand onto the metal floor with a louder clatter than on concrete (Overlays > Stimuli: bigger impact sphere); dropped items can be picked up again.
- [ ] Abilities dais: see M6 (abilities station).

## M6 Abilities and saving (Inventory bay)

- [ ] HUD: an energy bar (blue, number above it) stands right of the body silhouette; with an augmentation on, a chip "F1 Cloak" etc. appears beside it (Combat Strength always listed while installed) and the bar falls steadily; chips do not cover the belt.
- [ ] F1 Cloak: the held weapon turns see-through and the screen gets a faint blue tint; F1 again restores both. The energy bar empties in about 25 s from full; at 0 every augmentation switches off with "Energy depleted", and F1-F4 then refuse with the same message.
- [ ] F2 Run Silent on the station's metal strip ("Run Silent (F2) · sprint here"): with Overlays > Stimuli on, sprinting draws yellow noise spheres and you hear metal steps; with Run Silent on there are no spheres and no step sounds, also on landing from a jump.
- [ ] F3 Speed Enhancement: sprint feels about 1.5x faster (9 m/s, Player tab speed), jumps reach visibly higher (1.6 m), landings are louder. At the "Speed (F3) · mantle me" ledge (2.3 m): without Speed, jump does nothing useful; with Speed, jump (from standing) climbs onto it. Stepping off the top does not hurt (2.3 m drop).
- [ ] F4 Regeneration: after a hurt leg (e.g. a blast lane barrel) the silhouette's leg goes back to green within a few seconds while the bar drains; with nothing hurt it keeps draining but heals nothing.
- [ ] Combat Strength (passive, installed by default): E on the large crate ("Combat Strength · lift me") and on the physics room's "Too heavy (Combat Strength)" crates picks them up; uninstall it in the Stats tab and they are "Too heavy" again. With it the baton knocks a dummy out from the front in 2 hits instead of 3.
- [ ] Biocells: the dais holds one pickup of 10; E takes them. LMB with a biocell in hand at full energy says "Energy full" and keeps it; after some drain it adds 25 (watch the number) and uses one.
- [ ] Stats tab (`): set Pistols to Master: the standing reticle is much smaller and settles faster after a shot; reload is quicker; a torso shot on a range dummy shows 32.5 (Untrained 25). With a disabled arm the Master reticle still widens.
- [ ] Crouch (any skill): after mouse movement or a shot, the reticle tightens noticeably faster crouched than standing.
- [ ] Stats tab: Low-Tech Advanced: a frontal baton knockout takes 2 hits (Combat Strength uninstalled), swings come faster at Master. Medicine Master: a medkit heals 90 (watch several parts recover).
- [ ] Stats tab: unchecking "installed" switches an augmentation off and its F-key does nothing ("on" greyed); the energy slider and "Refill energy" change the HUD bar at once; F-key toggles show up in the tab while it is open.
- [ ] F5 quicksave and F9 quickload restore state (skill tiers, installed and active augmentations, energy included).

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

## Generic character components (ADR 0056)

- [ ] Footsteps and landings sound and log as before (walk, sprint, crouch on each surface; `actor.footstep` / `actor.landed` in the Event Log). Sprinting while injured (one leg) still logs `mode: sprint`.
- [ ] The 5 m drop in the movement course still hurts both legs by about 32 (HUD silhouette), the 2 m drop does not; the Event Log shows `damage.fall` emitted by the Player and the `fall_damage` receptron firing.
- [ ] Throw a small crate at a wall so it bounces back into you, or have a crate fall on you from a stack: the HUD flashes and the torso takes about the damage the dummy takes from the same throw (`actor.struck` in the log). Walking or pushing into crates never hurts.
- [ ] Blow up a barrel about 2 m away: you are shoved clearly away (about a metre), never thrown into the air, and you can walk normally right after. A wall behind you stops the shove without snagging. Standing next to the barrel does not launch you over obstacles.
