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

- [ ] (Since M5 take the pistol, baton and ammo from the hub's loadout table beside the spawn, or Spawn > Give item, first.) 1 draws the pistol (the Kenney pistol model in the lower right since ADR 0085), 2 the baton, the same key again holsters. HUD bottom right shows "Pistol" and "10 / <rounds in the inventory>"; nothing for the baton's ammo.
- [ ] Baton look: drawn (2), it is held like a nightstick at the lower right, grip at the bottom, pointing up and forward (about 60 degrees) and slightly inwards. LMB chops it down across the centre of the view, pivoting about the grip (the hand end stays put), then it returns a little slower. Hits still land at the moment of the click.
- [ ] Reticle: standing still the circle shrinks to a small ring in under a second (0.8 s settle); walking widens it to about 4.5 degrees, sprinting or jumping to 7.5, right away; flicking the mouse and every shot bloom it; it never exceeds 10. The settle speed feels fair, not sluggish.
- [ ] Shots land inside the circle (shoot a wall at 10 m and compare the impact noise sphere in Overlays > Stimuli); at rest a dummy's head at 5 m is reliable.
- [ ] Pistol (loud since ADR 0085): a gunshot with a brief flash at the barrel; 0.35 s between shots; empty magazine clicks; R reloads in 1.6 s (sound plays) and the counter shows "reloading". Shot noise 25 m at the muzzle and 4 m at the impact show in Overlays > Stimuli. With the silencer fitted: a muffled thud, no flash, 6.25 m at the muzzle.
- [ ] Shoot a dummy: head 50 (it dies and tips over backwards), torso 25, arms and legs 25; floating numbers name the part and are readable, do not overlap badly and fade in about a second. E on the dummy resets it.
- [ ] A dummy lying down (dead or knocked out) can be walked through like a guard's body (audit S4: it uses the guards' `DownedPose`); a thrown crate still bounces off it. The range's "Reset dummies" button stands every lying dummy up and clears their numbers.
- [ ] Shoot an explosive barrel: one shot blows it up. Shoot a medkit or a small crate: it is knocked away a little (the push is a `force.impact` stimulus since ADR 0057: same strength, hit near the top and a crate tips back).
- [ ] Baton: swing with a visible chop; from behind an unaware dummy (Spawn puts it facing away) one hit shows "stun 200" and "KO" and it tips over; from the front three hits ("stun 20" each). Hitting a crate damages it a little (blunt 5), never through stun.
- [ ] Player damage (Spawn tab "Damage looked-at" does not target yourself; use barrels and fire): standing about 2 m from an exploding barrel takes roughly 20 torso and 6 elsewhere; the screen flashes red; the silhouette (bottom left) turns yellow/red per part.
- [ ] Jump off the movement course's 5 m drop: both legs lose about 32 (silhouette legs yellow). A second fall disables them: you crawl at 1 m/s and cannot stand. One disabled leg: walking is clearly slower (x0.6).
- [ ] Medkit (since M5 from the belt; since ADR 0059 its belt key puts it in hand and LMB uses it): LMB heals 30 spread over the damaged parts and the count drops by one; at full health nothing is used (`item.use_refused`). Using it from the Inventory tab (the world keeps running) heals at once.
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
- [ ] Weapons rack (ADR 0085, west of the door): from the door it reads as a table of guns against the wall beside the door, the sniper rifle and shotgun at the back, the assault rifle, three ammo boxes and the silencer crate in front; its four signs read from the booth and none runs into the corner or the doorway. E takes each item (prompt names the one you look at); the guns go on the belt.
- [ ] Shotgun feel: one shot on the 5 m dummy's torso drops it; at 10 m about half the pellets hit; the 20 m dummy takes several shots. 0.9 s between shots feels like a pump; the flash and bang feel heavier than the pistol; R reloads all six in 2.4 s.
- [ ] Sniper rifle from the hip: the reticle ring is huge (6 degrees) and shots wander. RMB: the view zooms in about 0.15 s to a black scope with the HUD's four-arm crosshair at the lens centre; the gun disappears. Hold still: the arms close in about 1.4 s; mouse look moves the crosshair about as far per mouse movement as at the hip (not twitchy). One shot at the 40 m dummy's torso kills it. RMB again zooms out. R, a belt key, H or being knocked out also zoom out; RMB while reloading does nothing. Nothing pauses.
- [ ] Assault rifle: hold LMB on the 10 m dummy: it fires 10 shots a second and the dummy drops in well under a second and a half; the ring grows during the burst and shrinks back within about a second after you let go; letting go stops at once (never a runaway burst); an empty magazine just stops (no clicking). A tap fires one shot.
- [ ] Silencer: take the hub's loadout silencer, open the inventory (I), drag it: the pistol (and any sniper or assault rifle) light up blue on the grid and the belt, the shotgun does not. Drop it on the pistol: "Silencer fitted: Pistol (silenced)", the silencer is gone from the grid, the pistol's icon shows "SIL" and its tooltip "Fitted: silenced". Draw it: the silencer is on the barrel. Drop the silencer on the shotgun instead: nothing happens (it stays where it was). Drop the silenced pistol with Q: the silencer is on the pickup; take it back: still silenced. Save, load: still silenced.
- [ ] Silenced shots in Overlays > Stimuli: pistol 6.25 m, sniper 8.75 m, assault rifle 7 m at the muzzle; no flash light on the wall in a dark spot.
- [ ] Silhouette after a graze: after the 3 m blast line (a few points of damage) the hurt parts are already yellow-green, not the untouched pure green; the silhouette is pure green again after Reset level and after a medkit heals everything.

## M5 Inventory (Inventory bay)

Start the hub: the player starts with an empty inventory; the loadout table right of the spawn holds the starting kit. Gallery room 7 is behind doorway "7 Inventory & Abilities" (west wall, south half) ([../levels/hub-and-gallery.md](../levels/hub-and-gallery.md#7-inventory-and-abilities-bay)). Spawn > Give item in the debug panel (`) still adds anything. Keep the Event Log tab (filter `item.`) at hand. See [../game/inventory.md](../game/inventory.md).

- [ ] Look at an item on the floor within 2 m: the prompt under the reticle reads "E: pick up Lockpick (3)" (the count only above 1); a small crate says "E: carry Small crate", a large crate "Too heavy", a training dummy "E: reset Training dummy"; carrying, "E: put down ...". The prompt is readable and does not flicker when the crosshair sits on an edge.
- [ ] E picks the item up; the pistol, baton, medkit, lockpick and biocell appear in the first free belt slot; ammo and keycard do not.
- [ ] Fill the grid (Give item: keycard stack x30): E on another item says "No room in inventory" for about 2 s and the item stays. A big ammo pickup with little room leaves the rest on the floor with the smaller count.
- [ ] 1-0 put the slot's item in hand and use nothing (ADR 0059): the pistol draws, the same key again holsters; the slot is highlighted on the belt HUD and the item's name shows just above the belt for about 1.5 s, then fades. A lockpick shows "Lockpick" bottom right and LMB does nothing (the multitool was removed in M8, [ADR 0076](../decisions/0076-computer-skill-multitool-removed.md)).
- [ ] LMB uses the item in hand: a medkit heals when hurt (one per click, it stays in hand while any are left; the last one empties the slot and the hands) and is refused when not ("You are not hurt"); a biocell says "Nothing happens". With empty hands LMB does nothing; carrying a crate, LMB still throws it.
- [ ] Mouse wheel through the belt (give the pistol, baton and medkits, leave a gap): from empty hands wheel down takes the first item from the left, wheel up the last; each notch moves exactly one item, empty slots are skipped, the ends wrap around. Scrolling onto a medkit while hurt does not heal. Scrolling fast feels responsive (no missed or doubled notches, also on a touchpad); scrolling during a reload cancels it like a number key does.
- [ ] H holsters whatever is in hand: the pistol view goes, the belt highlight and the name above the belt disappear, the bottom-right name clears; H with empty hands does nothing. The wheel and H do nothing with the Tab interface open, while reading or when dead.
- [ ] R reloads from the ammo stacks: "2 / 103" becomes "10 / 95"; the smallest ammo stack is used up first and its cell frees up in the grid.
- [ ] Q with the pistol drawn drops it about a metre ahead; it clatters (impact noise in Overlays > Stimuli); picking it up again keeps its magazine (tooltip "Magazine: n"). Q while carrying a crate still just lets go of the crate. Dropping against a wall never puts the item through it.
- [ ] I opens the inventory: the game is paused (a falling object freezes, footsteps stop), the mouse is free, I or Esc closes and the mouse is captured again. It does not open while dead or with the debug panel open.
- [ ] Items of every footprint fit and block correctly on the 6x5 grid: dragging shows a green footprint where it fits and red where it overlaps or sticks out; releasing on red changes nothing.
- [ ] Drag an item onto a belt slot to assign it; drag a belt item off the belt to clear the slot; drag an item out of the panel to drop it. Hover an item and press a number to assign it.
- [ ] Right-click: Use / Equip, Drop, Split stack (halves it into a free cell), Assign to belt slot. The tooltip shows name, description and count; it does not cover the item under the mouse.
- [ ] The inventory reads as Deus Ex: dark panel, thin grid lines, coloured item blocks with legible short names at 1152x648 and at the 840x648 window this machine opens.

Hub loadout table and gallery room 7 (Inventory bay):

- [ ] At the spawn the "Loadout" table is in view to the front right and does not get in the way of walking straight to doorways 1 and 2. E takes each item: pistol, baton, medkit, lockpick and biocell land on belt slots 1-5, the silencer and the 60 rounds do not; 1 draws the pistol and R has rounds. The pistol and silencer read as separate items on the table (the prompt names each).
- [ ] Walk in through doorway 7: the doorway and both corridor ends show plain walls, no striped (z-fighting) faces. From the door the room reads as: item table along the left wall, stack and "Fill the grid" tables on the right, metal drop zone in the middle, red dais and datapad pedestal at the back. Every station sign reads from the door.
- [ ] Item table: each item's tag ("Pistol 2×1" ...) reads when you stand at it and sits behind the right item (tags alternate two heights since ADR 0085); the prompt names the item you look at, never its neighbour. After taking them all, I shows every footprint in the grid (pistol 2×1, baton 1×3, shotgun 3×1, sniper rifle 4×1, assault rifle 2×2, the rest 1×1).
- [ ] Stacks (start without that item, e.g. skip the loadout table): E on "Lockpick (12)" gives a stack of 10 and one of 2; medkits 16 give 15 + 1; ammo 150 gives 100 + 50; I shows the split stacks with their counts.
- [ ] Fill the grid: take the pistols, batons and ammo one by one: before the table is empty E says "No room in inventory" for about 2 s and the item stays on the table.
- [ ] Datapad pedestal (ADR 0060): looking at each datapad the prompt reads "E: read Inventory bay" / "E: read Storage access", never the neighbour's. E opens the text (the world keeps running), E or Esc closes it without also re-reading or picking anything up; "Added to log: Storage access" shows for about 2 s after closing. The datapad stays on the pedestal, the inventory is unchanged. Reading it again shows the text but no new "Added to log".
- [ ] Datapads are props: a blast or walking into the pedestal pushes them like other small objects; E never carries or picks them up.
- [ ] L opens the Tab interface on the Journal (the world keeps running, mouse free); L or Esc closes it. Notes are listed newest first, the newest shown; clicking one shows its text on the right. Under "Codes and logins": "Storage door 2817" from "Storage access". L does nothing while the text overlay is open, or when dead (M11 checklist for the rest).
- [ ] Debug panel Give item no longer lists a datapad; the inventory right-click menu has no "Read".
- [ ] Drop zone: Q drops the item in hand onto the metal floor with a louder clatter than on concrete (Overlays > Stimuli: bigger impact sphere); dropped items can be picked up again.
- [ ] Abilities dais: see M6 (abilities station).

## M6 Abilities and saving (Inventory bay)

- [ ] HUD: an energy bar (blue, number above it) stands right of the body silhouette; with an augmentation on, a chip "F1 Cloak" etc. appears beside it (Combat Strength reads "F5 Combat Strength") and the bar falls steadily; chips do not cover the belt.
- [ ] F1 Cloak: the held weapon turns see-through and the screen gets a faint blue tint; F1 again restores both. The energy bar empties in about 25 s from full; at 0 every augmentation switches off with "Energy depleted", and F1-F5 then refuse with the same message.
- [ ] F2 Run Silent on the station's metal strip ("Run Silent (F2) · sprint here"): with Overlays > Stimuli on, sprinting draws yellow noise spheres and you hear metal steps; with Run Silent on there are no spheres and no step sounds, also on landing from a jump.
- [ ] F3 Speed Enhancement: sprint feels about 1.5x faster (9 m/s, Player tab speed), jumps reach visibly higher (1.6 m), landings are louder. At the "Speed (F3) · mantle me" ledge (2.3 m): without Speed, jump does nothing useful; with Speed, jump (from standing) climbs onto it. Stepping off the top does not hurt (2.3 m drop).
- [ ] F4 Regeneration: after a hurt leg (e.g. a blast lane barrel) the silhouette's leg goes back to green within a few seconds while the bar drains; with nothing hurt it keeps draining but heals nothing.
- [ ] Combat Strength is off by default: the large crate ("F5 Combat Strength · lift me") and the physics room's "Too heavy (F5 Combat Strength)" crates say "Too heavy", and the baton needs 3 frontal hits on a dummy. F5: the chip "F5 Combat Strength" appears, the bar falls slowly (1/s), E picks those crates up, and the baton knocks a dummy out from the front in 2 hits.
- [ ] Carrying the large crate, F5 again: it drops in front of you (not into you) with "Too heavy". Carry it with Combat Strength on and little energy left (Stats tab slider ~3): when the energy runs out it drops the same way. A small crate stays in your hands when F5 goes off.
- [ ] Biocells: the dais holds one pickup of 10; E takes them. LMB with a biocell in hand at full energy says "Energy full" and keeps it; after some drain it adds 25 (watch the number) and uses one.
- [ ] Stats tab (`): set Pistols to Master: the standing reticle is much smaller and settles faster after a shot; reload is quicker; a torso shot on a range dummy shows 32.5 (Untrained 25). With a disabled arm the Master reticle still widens.
- [ ] Crouch (any skill): after mouse movement or a shot, the reticle tightens noticeably faster crouched than standing.
- [ ] Rifles and Sniper (ADR 0101), shooting range, Stats tab: with Rifles at Master the assault rifle's full-auto group on the far wall is visibly tighter than Untrained and the reload is quicker; at Master a shotgun shot at a 10 m dummy's torso puts nearly every pellet on it (Untrained: about half miss). With Sniper at Master the scope's crosshair barely drifts and the red ring shrinks to a dot about four times faster after scoping in. Guards with rifles shoot as before.
- [ ] Ammo boxes (ADR 0101): on the shooting range rack, in the hub and in the Inventory tab, shells are yellow, rifle rounds green, sniper rounds purple and pistol ammo red, the box in the world the same colour as its icon.
- [ ] Held weapons (ADR 0101): every weapon (pistol, silenced pistol, shotgun, sniper rifle with and without silencer, assault rifle, baton) sits lower in the bottom-right corner than before but stays readable; firing kicks it back and it returns; the baton's chop still crosses the view; the scope still hides the model and it reappears when you scope out or reload.
- [ ] Stats tab: Low-Tech Advanced: a frontal baton knockout takes 2 hits (Combat Strength off), swings come faster at Master. Medicine Master: a medkit heals 90 (watch several parts recover).
- [ ] Stats tab: unchecking "installed" switches an augmentation off and its F-key does nothing ("on" greyed); the energy slider and "Refill energy" change the HUD bar at once; F-key toggles show up in the tab while it is open.
- [ ] Esc game menu ([ADR 0064](../decisions/0064-game-menu.md)): Esc pauses the game, frees the mouse and shows Resume / Save / Load / Quit game in the log screen's style, Resume highlighted; Up/Down move, Enter presses; Esc or Resume closes it and the mouse is captured again (looking works at once, Space jumps, it does not re-press a button).
- [ ] With the Tab interface, the reading overlay or the keypad open, Esc closes only that screen; the next Esc opens the menu. Tab, I and L do nothing while the menu is open. With the debug panel open (`), Esc does not open the menu.
- [ ] Save: "Saved" shows in the menu, which stays open; the line under Load reads "Saved <your local time> · Hub". Load: the menu closes, the HUD says "Loaded" and you are back where you stood, facing the same way, with the same health (body silhouette), inventory, belt and item in hand.
- [ ] Quit game: "Quit? Unsaved progress is lost." with Yes / No (No highlighted); No or Esc goes back to the menu; Yes closes the game.
- [ ] Physics and fire room: set a crate burning, break another (Spawn tab: Damage, or throw it), burn the barricade, save, walk on; load: the burning crate is still burning, the broken and burnt ones and the barricade stay gone, the bottles that fell out of the side room crate lie where they were; nothing flashes or explodes on load.
- [ ] After a load the doorway the burnt barricade blocked is open: you walk through it (no invisible wall).
- [ ] Drop two items (Q) and spawn a crate from the Spawn tab, save, pick the items up and push the crate away, load: the items and the crate are back where they were saved.
- [ ] Carry a crate, save, load: the crate drops in front of you, not inside you, and you are not carrying it.
- [ ] Read a datapad, save, read another, load: the log (L) has only the first.
- [ ] Die (fall or a barrel): the death screen says "E: restart level · Esc: menu"; E restarts; Esc opens the menu, Save says "Cannot save while dead", Load loads the save.
- [ ] Knocked out (AI arena: stand still in front of a baton guard; the third hit): you cannot move, the screen says "Knocked out" and "E: restart level · Esc: menu"; E restarts; Esc opens the menu, Save says "Cannot save while knocked out", Load loads the save. A pistol guard kills instead ("You died").
- [ ] No save (delete `%APPDATA%/Godot/app_userdata/ImSimProto/saves/quicksave.save`): Load is greyed out and the line under it says "No save".
- [ ] F5 toggles Combat Strength (chip "F5 Combat Strength"); F9 does nothing.
- [ ] Save and load restore state (skill tiers, installed and active augmentations, energy included).

## M7 Light and AI (Perception lab, AI arena)

- [ ] Perception lab (doorway 2): walk the three lanes. The HUD light gauge (gem and bar above the body and energy bar) reads dark blue and nearly empty on the carpet lane, amber about a third on the wood lane, pale yellow nearly full on the metal lane; the debug Overlays tab shows the number (about 0.04 / 0.31 / 0.93).
- [ ] Crouch (hold Ctrl) in the dim and lit lanes: the gauge drops a little (dim about 0.21, lit about 0.88); in the dark lane it stays empty.
- [ ] What you see matches the gauge: the carpet lane looks dark, the wood lane has a weak pool of light, the metal lane is clearly lit; walls far from lamps look dark, not grey.
- [ ] Breaker on the west wall by the doorway (lit by its own wall lamp): "E: switch off lab lights" clunks, the lever drops, the lane lamps and their bulbs go out and the gauge empties in every lane; the apron lamps stay on. E again ("switch on lab lights") brings them back.
- [ ] Shoot a lane lamp with the pistol: glass breaks (sound, green shards), its light goes out, the gauge under it drops. Save, load: the lamp stays broken; an open breaker stays open.
- [ ] Stand near a burning crate (room 3): the gauge rises.
- [ ] Guards move through Unaware, Suspicious, Searching, Alerted/Combat and back; `?` / `!` icons and barks show.
- [ ] Guards discover bodies and wake unconscious guards; unconscious guards do not wake alone.
- [ ] Cloak hides the player from guards.

## M9g Darkness and flashlights ([ADR 0095](../decisions/0095-darkness-and-flashlights.md))

- [ ] Dark spot about 5 m in front of a guard at its post (perception lab dark lane or a warehouse hiding spot): standing still you stay unseen for as long as you like; walking upright across its view it turns to look (the "?" indicator) in about 2 s and is Alerted in about 6 s if you keep moving in view; crouch-walking takes noticeably longer (about 2.5 s / 8 s). Feels fair, not psychic: stopping in the dark lets the meter fall again.
- [ ] Warehouse west yard at night (breakers on or off): the west yard patrol's flashlight (halo and the pool on the ground) is visible from 15 m and more; you can read where it looks. It never lights the far side of a wall or a container.
- [ ] Step into that patrol's beam about 8 m ahead while walking: the light gauge goes amber and it is Alerted within about 3 s. Out of the beam, in the dark, crouching still: it walks past.
- [ ] Alert a guard indoors (G6 break room): its flashlight comes on while it chases and searches and goes off when it gives up; knock it out: the light goes off with it. A body lying in a dark corner is found when a searching guard's beam falls on it.
- [ ] Save while a guard searches with its light on, load: the light is on; knock out a yard patrol, save, load: its light stays off.

## M8 Security (Security wing)

Room 5, behind hub doorway "5 Security" ([hub-and-gallery.md](../levels/hub-and-gallery.md#5-security-wing)). Take the loadout table's pistol, baton and lockpicks first.

- [ ] Entry hall: the five lock-row doors read at a glance from the hub door, each with its sign; the west wall left of the table holds the four practice locks (M10d) and their signs; the hub doorway shows no seam or flicker from either side.
- [ ] Table: E on the "Closet code" datapad shows it and adds it to the log (L); the two lockpicks go into the inventory.
- [ ] D1 keypad: "E: enter code" opens the entry screen (the world keeps running) showing "Note: 5309, from 'Closet code'"; a wrong code beeps and says "Wrong code"; 5309 + Enter opens the door; Esc leaves halfway without opening the game menu. The keycard lies on the shelf inside.
- [ ] D2 pin lock: "Locked: lockpick"; LMB with a lockpick drawn starts the lockpicking minigame (see "M10 Lockpicking minigame"); once picked the door opens and the lockpick count does not change. The "Booth login" datapad is on the shelf.
- [ ] D3 keycard: "Locked: keycard" without the card, "E: open (keycard)" with it; the booth has the computer, breaker B and the alarm controller with the radio base station, and you can turn round in it. From the booth door the two east-wall devices read apart: the dark red box under "Alarm controller", the dark blue box with the antenna under "Radio base station".
- [ ] D4 electronic: breaker A (hall north wall, "E: switch off D4 power") clunks and the door's control light goes dark; the door stays shut until E opens it; switching A back on locks nothing that is open.
- [ ] D5 breakable: pistol rounds and baton hits do nothing; shoot the barrel from the hub door: the blast blows the panel away for good, D4 next door stays shut, the hall lamps survive.
- [ ] Booth computer (M12a): "E: use security booth computer" opens Halcyon OS; after reading the D2 datapad its login lists "rvoss · from Booth login" with Fill in. The rest: see "M12a Computers" below.
- [ ] Debug panel Overlays "Network" in the security wing: every device labelled (name, status) through walls, cables from the hall switch to each device in green; breaker B off turns every switch cable red and the switch reads "offline (unpowered)"; unticked, nothing is left in the world.
- [ ] (The terminal's Network map moved to the deck in M12a: its checks belong to the deck's Map.)
- [ ] Breaker B / switch: breaker B off (booth) or two pistol rounds (or two baton swings) in the switch (hall north wall): within a second every device in the booth computer's Security app is grey "offline" with no actions (never "broken"), the camera's live view shows "No signal", and the vault door's controls go dark; the camera still turns red on you but no siren rings; the panic button does nothing. A device shot to pieces with the switch on also just reads "offline".
- [ ] Camera corridor: from the corridor mouth the camera over the vault door sweeps ±40° with a pause at each end (green lamp). Walk in lit: it stops on you, amber, then red with a beep in about 1.3 s; both sirens sound and the HUD shows "ALARM". Crouched in either alcove you are in the dark (light gauge empty) and it never sees you, even when it points at you; time the sweep to move alcove to alcove. Cloaked (F1) it still sees you in the light. One pistol round breaks it; a shot siren loses its horn and stays silent.
- [ ] Guard: the baton guard by the vault door is lit and faces the door; crouch-walk up behind it from the second alcove and knock it out. Press the hall panic button instead: the sirens ring and the guard leaves its post searching around it (and runs to where the camera saw you when the camera raised the alarm).
- [ ] Vault: from the booth computer's Security app, Disable the turret (its laser and head go idle), then Open the vault door: it slides open while still locked and locks again when closed. Enabled instead, the turret behind the opened door turns to you in the corridor and fires after its beep; Target guards makes it shoot the guard and ignore you; standing in its open field you are dead in about 4 s; three pistol rounds break it. With breaker B off the vault never opens. The loot table holds 5 biocells, 2 medkits and 40 rounds.
- [ ] Rewards: 2 biocells behind D4, a medkit behind D5.
- [ ] Baton on devices ([ADR 0104](../decisions/0104-devices-breakable-by-the-baton.md), [security.md](../game/security.md#breaking-devices)): with the baton (2), the hall switch breaks in two swings and the network goes offline as with a pistol; the panic button, a siren (3 m up over the hall: step about half a metre off the wall and look up), the corridor camera and a laser array emitter or receiver each break in one swing; the alarm controller and the radio base station in the booth in two. Each swing is quiet (no guard in the next room turns); the device goes dark, keeps its husk and reads "offline" in the Security app. The turret, disabled from the Security app or clubbed from behind, takes six swings; walking up to it from the front while it is on is deadly.
- [ ] Baton reach: the hall ceiling lamps (3.6 m) cannot be hit standing; a jump with a swing near the top of it breaks one. A keypad or card reader box beside a locked door takes swings and shots without any effect: the door stays locked and shut.
- [ ] Quicksave and quickload in the wing: open and broken doors, picked items, breaker positions, the booth computer's login and a disabled turret are restored.
- [ ] AI arena (room 6, alarm devices on their own): its panic button rings both sirens and every guard runs to the button (base station dispatch); shooting its switch silences the sirens within about 2.5 s.
- [ ] Debug panel "Raise alarm" / "Clear alarm" ring and stop the sirens in rooms 5 and 6; the HUD "ALARM" goes within about 1.5 s of the last siren pulse you can hear (about 34 m of walking distance).
- [ ] Doors anywhere: a door does not close on you standing in the doorway; no gap or flicker where the closed panel meets the jambs and the lintel or where the open panel hides in the wall; guards walk through unlocked doors and never through locked ones they have no access for.
- [ ] Laser hall ([ADR 0096](../decisions/0096-laser-tripwires.md), [ADR 0100](../decisions/0100-laser-arrays-alarm-time-downed-targets.md), behind D1): the beams read as thin red lines from the doorway, standing and crouched. Walking into the low beam (0.4 m) beeps and rings both sirens; a walking jump from about a step and a half before it clears it without a beep. Crouching under the high beam (1.3 m) never trips it; walking under it upright does. Standing in a beam gives one beep, not a beep per second. The two-beam array stops both a jump and a crouch; its two heads read as one emitter (a mast joins them), and walking through both beams gives one beep, not two.
- [ ] Throwing the box through a beam rings the alarm; the vault guard comes looking (base station). A knocked-out guard dropped into a beam trips it; an awake guard walking through does not.
- [ ] In the booth computer's Security app the three laser arrays (Laser Low, Laser High, Laser Pair: one row each, under Laser arrays) read enabled · clear (tripped right after a break); Disable turns all of an array's beams off (no line, no trip) and Enable brings them back. Breaker B off: every array goes dark and reads offline. One pistol round at any of an array's boxes (the pair's mast too) breaks it for good (all its beams go, the Security app says offline). Quicksave and load keep a disabled or broken array.
- [ ] Turret on guards (M9h, [ADR 0100](../decisions/0100-laser-arrays-alarm-time-downed-targets.md)): log in at the booth computer, Target guards, open the vault: the turret kills the post guard, then turns back to rest; its beep stops and nothing loops (the sirens ring for 45 s, then stop). Knock a guard out in a turret's view while it targets guards: it never fires at the body.
- [ ] Alarm length (M9h): after one incident the sirens ring for about 45 s and stop; a second incident while ringing restarts the 45 s. In the warehouse the reinforcements still arrive 30 s after the first alarm.

## M9 Mission

- [ ] All four routes are completable.
- [ ] Death leads to reload/restart; extraction shows the summary (time, alarms, kills, knockouts, optional objectives, badges).
- [ ] Mission is playable start to finish without debug tools.
- [ ] Systems ([ADR 0087](../decisions/0087-mission-systems.md), [ADR 0088](../decisions/0088-weapon-drops-and-bursts.md)); until the warehouse is built, `tests/levels/mission/mission_kit/fixtures/mission_fixture.tscn` (run it with F6, or point the hub's `MissionExit` at it) plays the same systems:
  - [ ] Hub: walking into the west wall's north doorway ("Mission") loads the mission; nothing you carried in the hub comes along.
  - [ ] The briefing shows at the start with the objectives and pauses the game; E, Enter and Esc each close it, and E does not also pick up or use something.
  - [ ] Start kit: baton, pistol with 10 rounds, 10 spare rounds, 1 medkit; energy at 50; F-keys toggle Cloak, Speed Enhancement and Combat Strength only. The objectives are in the log (L).
  - [ ] Reaching the extraction before the manifest shows "Read the manifest first"; completing an objective shows a toast at the top; extraction after the manifest opens the summary (paused, mouse free; Esc does nothing; Restart mission and Return to hub work, the hub starts at its spawn with an empty inventory).
  - [ ] Badges: sneak through unseen (Suspicious is fine) -> Ghost; a guard reaching Alerted, an alarm or a found body loses it. Knock guards out -> Pacifist kept; kill one (also with a barrel you shot, a fire you started or the turret you retargeted at guards) -> Pacifist lost.
  - [ ] A knocked-out or killed guard's weapon lies beside the body with the rounds it had; pick it up. Wake the guard (another guard tends it): it searches but never attacks. You keep your own weapons when knocked out.
  - [ ] The catwalk rifle guard fires bursts of 3-5 rounds with short pauses, and is survivable at 15 m behind partial cover for a few seconds.
  - [ ] About 30 s after the first alarm, two guards come in at the front gate and search where the alarm was raised; a second alarm brings nobody else.
  - [ ] Quicksave in the mission, return to the hub, Load: you are back in the mission where you saved, objectives, timer and badges as they were, no briefing.
- [ ] Warehouse layout (M9 wave 1, [mission-warehouse.md](../levels/mission-warehouse.md#level); review shots: run `tests/levels/mission/fixtures/warehouse_shots.tscn` with `-- shots=all out=res://reports/screenshots/warehouse`, `lit=1` for a bright layout review, `dark=1` with both breakers off):
  - [ ] Start at the van: the fence, the lit gate and booth, the dock floodlights, the hall and the water tower on the skyline read as a place you can study before choosing a way in; the yard is visible through the palisade fence.
  - [ ] Over the fence: pallets, container, a walking jump over the fence onto the inside container, then down the pallets; no damage.
  - [ ] West yard: the container chain (pallets, container, crate) to the annex roof; the roof door onto the west catwalk; the caged stair up to the main roof. Nothing needs a precise jump.
  - [ ] Roof: walk off the open side of a rack skylight onto the goods, down to the rack top and the bridge without damage; a sprint into it lands harder (a little leg damage). Duct A from the roof down to the catwalk alcove and back up; duct B down onto the manager office's cabinet, and back up: mantle onto the 1.6 m cabinet (you end crouched under the hatch), keep walking north and jump: a 1.45 m mantle into the duct (the hatch lip on the hole's north edge is what the mantle catches).
  - [ ] Fire escape: mantle onto the raised bottom landing, up to the office door and on to the roof; the cages and railings stop every fall.
  - [ ] Underground: ditch ramp, culvert crawl to the drain chamber, out into the east yard under its floodlight or through the tunnel to the boiler room; hatch stair up into the hall; duct C up into the security room; service stair up into the office stairwell.
  - [ ] Water tower: the stair tower up to the 20 m deck; from the west railing the yard and, through the skylights, the catwalks are in view.
  - [ ] Night: hiding spots (behind the containers, under the trailer crouched, the hall's south-west corner, rack decks, the roof, the ditch) look dark and the HUD gem reads dark; lit pools (gate, dock apron, side door, corridors) look lit. Breaker circuits: `warehouse_yard` (outdoor) and `warehouse_building` (hall, offices, basement) each darken only their own lamps (debug panel or a breaker once wave 2 places them).
  - [ ] Footsteps: metal on containers, catwalks, ducts and stairs (loud), carpet in the manager office and upper corridor (quiet).
- [ ] Warehouse people and props (M9 wave 2, [ADR 0091](../decisions/0091-warehouse-population.md); review shots `-- shots=people_g1_gate,...` (every `people_*` shot) in `warehouse_shots.tscn`):
  - [ ] Guards read as a set of problems you can study: the gate guard (G1) by the booth door watching the gate lane; the west yard patrol (G2, baton) past the side door and round the annex (lap about 57 s); the east yard patrol (G3, pistol) past the drain chamber exit, the fire escape and the back gate (lap about 42 s); the catwalk rifle guard (G4) along the north catwalk, the west catwalk and the bridge, lit at both ends (lap about 61 s); the security operator (G5) at the console, the break-room guard (G6), the vault-door guard (G7) in the upper corridor, the off-duty guard (G8) by his cot in the basement store.
  - [ ] Waiting in cover at a crossing (side door, drain chamber exit, fire escape foot, back gate, annex roof door, bridge end, duct A alcove), a patrol passes and leaves a window of many seconds (15 s or more) to cross; nothing needs tight timing.
  - [ ] Equipment: silencer and rifle rounds in the open lockers of the locker room; sniper rifle and rounds on the water tower deck; shotgun and shells on the security room's gun table (behind G5); lockpicks on the basement store shelf; biocells in the annex and the drain chamber; pistol rounds on the 4.4 m rack deck (step off the bridge between the rack posts) and in the break room; a medkit in the boiler room. Each says "E: pick up ...".
  - [ ] Vault: the prototype (dark case with a glowing core) on its pedestal; picking it up shows the optional objective's toast.
  - [ ] Shipment (dock, "OUTGOING" sign): shooting the fuel drum blows it up and completes optional B; setting a crate on fire does too. The crates burn for a long time near the dock: check guards react to the noise and the light.
  - [ ] Weak wall: shooting one gas cylinder chain-explodes all three and blows the ribbed panel out of the south wall (heard across the compound); you can walk through. A gas cylinder (15 kg) can be carried and thrown, e.g. into the shipment.
  - [ ] Knock out the rifle guard: its assault rifle lies beside the body on the catwalk.
  - [ ] Throwables: glass bottles on the break-room table, cardboard boxes west of the booth, small crates on the back strip, a metal crate and a box by roller door 2.
  - [ ] The boat at the pontoon reads as the way out (bow, cabin, motor).
- [ ] Warehouse doors and security (M9 wave 2, [mission-warehouse.md](../levels/mission-warehouse.md#doors-locks-and-keys-m9-wave-2), [ADR 0090](../decisions/0090-door-size-free-side-locks-warehouse-security.md); review shots: `warehouse_shots.tscn` with `-- shots=door_front_gate_road,door_roller_yard,console_cameras,view_camera_hall,... out=res://reports/screenshots/m9c`, names in `tests/levels/mission/fixtures/warehouse_security_shots.gd`):
  - [ ] The front gate slides along the outside of the fence in about 3 s and reads as a gate, not a wall; the roller doors rise into the wall in about 2.5 s and are clearly loud; nothing clips through posts or walls while they move.
  - [ ] Back gate: from the quay it says "Locked: lockpick" and is picked with the lockpicking minigame (4 pins); from inside it just opens ("E: open") and locks again once closed. Same for the tunnel gate (picked from the ditch), the annex roof door and the fire escape door (opened from inside).
  - [ ] Side door: the code note in the dumpster gives 2390 and the keypad shows the reminder. Manager office: 4471 from the night shift notes in the break room; from inside (after duct B) the door just opens.
  - [ ] Keycards: the security keycard on the locker room bench opens the security room; the vault keycard on the security room desk opens the vault. The console login is on the manager's desk next to the manifest.
  - [ ] Security console (Network tab): every device is listed with readable labels; it disables the turret, opens the vault, locks or opens the front gate. Cutting breaker B or shooting the switch in the basement store turns everything offline.
  - [ ] Cameras: the gate, yard, hall and office cameras spot you lit within a couple of seconds and every siren rings; the dark corners (dumpster corner, truck gap, behind the containers) stay unseen. With the switch broken, the cameras still turn red but nothing rings.
  - [ ] Sirens: when the alarm rings, guards in the yard, on the catwalks, in the offices and in the basement react; you can hear a siren from every guard post.
  - [ ] Office PCs (second office, picked door): the sticky note and the shift notes log in; they show only the office network.
- [ ] Warehouse polish (M9e, [mission-warehouse.md](../levels/mission-warehouse.md#design-review-m9e), [ADR 0092](../decisions/0092-warehouse-polish.md); review shots: `warehouse_shots.tscn` with `-- shots=gate_bars_road,back_gate_bars_out,booth_controller,panel_office_entrance,panel_bridge_door,panel_fire_escape_door,panel_catwalk_stairs_in,panel_catwalk_stairs_out,console_cameras,upper_corridor,office_front out=res://reports/screenshots/m9e/after`):
  - [ ] Patrols: the yard, the back strip and the catwalks feel watched (a guard comes by every 10-45 s at each crossing; patrols walk at 1.5 m/s since M9h) but every crossing still leaves a window of several seconds; a careful first ghost run gets spotted at least once and can recover. G9 walks the back strip (weak wall to the east strip by the fire escape), G10 the west catwalk and the bridge, G4 the north catwalk.
  - [ ] Two alarm networks: shooting the yard switch through the booth's west window (silenced pistol) silences the yard cameras and outdoor sirens while the hall camera still rings the indoor sirens; breaking the store's switch (or cutting breaker B) silences the building while the gate camera still rings the yard's sirens; with both broken nothing rings. Cutting breaker A darkens the yard and silences its alarms.
  - [ ] The front and back gates are grilles: from the road you see the gate lane, the guard and the dock through the closed gate, and can shoot through it; they still stop you and guards.
  - [ ] The bridge door's status box hangs on the corridor's side wall, readable, not half inside a wall (since ADR 0098 the other corridor doors have no box: their handle is on the leaf).
  - [ ] Signs over the office doors (OFFICES, MANAGER, VAULT, SECURITY, STAIRS, FIRE EXIT) read at night from the hall and the corridors and lead to the manager's office without markers.
  - [ ] The security console's Network tab: no label hides another; statuses (the front gate's "unlocked") are readable; the graph does not jump when a status changes.
  - [ ] Guards chase you out through doors that open freely from their side (the side door into the west yard, the back gate onto the quay); they never follow you in through such a door without its key.
- [ ] Warehouse routes and additions (M9f, [mission-warehouse.md](../levels/mission-warehouse.md#routes-covered-by-tests-m9f), [ADR 0093](../decisions/0093-warehouse-route-tests.md); review shots: `warehouse_shots.tscn` with `-- shots=m9f_window_out,m9f_window_in,m9f_window_sill,m9f_cache,m9f_cache_open,m9f_office_stair_top,m9f_drum_skylight,m9f_duct_c_exit,m9f_corridor_g7 out=res://reports/screenshots/m9f`):
  - [ ] Play the routes by hand (next section, "Warehouse routes (by hand)").
  - [ ] Annex window: the two small crates beside the annex's south wall invite stacking; carrying and putting one on the other under the window works at the first or second try; from the stack the window is a mantle (ends crouched in the window); inside, the ledge breaks the drop, and the way back out works (ledge, sill, drop onto the stack).
  - [ ] Cache shed: from the back strip's dark corner the large crate in the shed's opening reads as something to move ("Too heavy" without Combat Strength); with Combat Strength on it lifts, can be put aside, and the medkit and rounds inside are picked up crouched.
  - [ ] Office stair: off the stair's top west onto the upper floor without snagging on the hole railing's end.
  - [ ] Loud: after the gate camera's alarm, the containers north-west of the gate are a place to hold (guards cannot climb them) and shoot from; the compound converging within seconds feels tight, not hopeless. The fuel drum can be shot from the roof through the dock's west skylight.
  - [ ] Vault without a fight: duct C into the security room behind G5 between two of his glances, the console (credentials from the manager's audit note) disables the turret and the office camera and opens the vault; G7 can be knocked out from behind as he glances east.
- [ ] Warehouse roof security (M9g, [mission-warehouse.md](../levels/mission-warehouse.md#roof-security-m9g), [ADR 0097](../decisions/0097-warehouse-roof-security.md); review shots: `warehouse_shots.tscn` with `-- shots=roof_beam_west,roof_beam_west_crouch,roof_beam_east,roof_beam_east_crouch,roof_camera_east,roof_camera_east_crouch,roof_camera_west,roof_camera_west_crouch,roof_west_arrival,view_camera_roof,console_cameras out=res://reports/screenshots/m9g_roof`, without `dark=1`: it cuts breaker A and the beams go off):
  - [ ] The rush: sprint from the van over the north-west fence, up the annex chain and the annex stair and through the gap onto the roof: the beam beeps and the sirens ring before you reach duct B.
  - [ ] At the top of the annex stair and of the fire escape, the red beam between the two posts reads at night as something to crouch under; crouched you pass without a beep, upright you trip it.
  - [ ] From the dark beside duct B's housing, the lit forecourt, the camera on its mast and its green lamp read; you can tell when it looks away (it sweeps east) and reach the duct's mouth in time walking or crouching. Looking down through the east skylight shows the north catwalk guard: crossing the forecourt while he walks east toward you gets you noticed.
  - [ ] Coming back up duct B, wait inside the mouth's slope: the camera does not see you there; step out when it turns away.
  - [ ] Breaker A (the annex, through the high window): the roof's beams and lamp go off with the yard's lights; the roof is then walked upright without a beep. The security console's Network tab lists Camera Roof, Laser Roof West and Laser Roof East with readable labels; Disable turns each off.
- [ ] Warehouse routes (by hand; the scripted route tests were dropped, [ADR 0106](../decisions/0106-drop-scripted-warehouse-route-tests.md)). Starting kit only, guards at work; the waits are readable from where the player hides (G2 leaving the annex for the yard's north end, G9 turning back west at the fire escape, G3 leaving the drain chamber, the roof camera turning east, G4 walking west or east of the catwalk's west half):
  - [ ] Fence (ghost A): road, over the north-west fence, west strip, annex chain, roof (crouched under the west beam), duct B to the manifest, back up, fire escape down (crouched under the east beam), back strip, back gate, boat. Ghost and Pacifist badges, no alarm, no guard above Unaware on the roof.
  - [ ] Culvert (ghost B): road, ditch, culvert, drain chamber (out once G3 leaves), east strip, fire escape up, roof, duct B to the manifest, back across the roof, annex stair (crouched under the west beam), annex chain down, west strip, back strip behind G9, back gate, boat. Ghost and Pacifist, no alarm, nothing above Unaware on the roof.
  - [ ] Vault (ghost, two knockouts): manifest and console audit, up duct B, fire escape, drain chamber, tunnel, boiler room, duct C into the security room; knock G5 out from behind between two glances and carry him out of the window's sight; at the console disable the vault turret and the office camera and open the vault; office stair, knock G7 out as he glances away, carry him into the vault, take the prototype (optional A); fire escape door, back gate, boat. Ghost and Pacifist, both bodies unfound.
  - [ ] Loud: shoot G1 through the gate's bars, open the gate into the gate camera's view (both controllers ring, reinforcements arrive 30 s later), hold the outside containers and shoot the guards who come close, then over the fence, annex chain, roof, shoot the shipment's fuel drum through the dock's west skylight (optional B), duct B to the manifest, fire escape once the back strip is clear, back gate, boat. Alarms, kills, no Ghost, no Pacifist.
  - [ ] Rush: sprint from the van over the fence, down the west strip, up the annex chain and stair, upright through the west beam into duct B: the beam trips at about 15 s and the alarm rings; in duct B by about 23 s.
  - [ ] Breaker A roof walk (guards irrelevant): in through the annex's high window, breaker A off, out, annex chain, annex stair, upright through the west gap and across the dark forecourt into duct B: no beam trip, the camera sees nothing, no alarm.
- [ ] Noise through walls ([ADR 0094](../decisions/0094-noise-reach-on-partial-paths.md)): crawl down duct B and drop onto the manager office's cabinet: no guard's `?` appears (debug panel Overlays: icons), then open the office door: G7 stands at his post, not at the door. With Speed Enhancement on, the same drop brings G7 to the door (`?`). Shots and impacts in the open (the loud route) still bring guards as before; a noise on a crate top or a container is still heard across the open yard.

## Generic character components (ADR 0056)

- [ ] Footsteps and landings sound and log as before (walk, sprint, crouch on each surface; `actor.footstep` / `actor.landed` in the Event Log). Sprinting while injured (one leg) still logs `mode: sprint`.
- [ ] Surfaces from tags ([ADR 0138](../decisions/0138-surfaces-jamming-tag-and-tuning-configs.md)): walking on a metal crate your steps sound like metal and log `surface: metal`; on a wooden crate `wood`. Shooting either still sparks or splinters as before. Footsteps on floors sound as before.
- [ ] The 5 m drop in the movement course still hurts both legs by about 32 (HUD silhouette), the 2 m drop does not; the Event Log shows `damage.fall` emitted by the Player and the `fall_damage` receptron firing.
- [ ] Throw a small crate at a wall so it bounces back into you, or have a crate fall on you from a stack: the HUD flashes and the torso takes about the damage the dummy takes from the same throw (`actor.struck` in the log). Walking or pushing into crates never hurts.
- [ ] Blow up a barrel about 2 m away: you are shoved clearly away (about a metre), never thrown into the air, and you can walk normally right after. A wall behind you stops the shove without snagging. Standing next to the barrel does not launch you over obstacles.

## M7 Guards ([ADR 0067](../decisions/0067-vision-and-detection.md), [ADR 0068](../decisions/0068-awareness-states-and-guard-behaviour.md))

No gallery room yet: open `tests/scenarios/fixtures/guard_post_player.tscn` and run it (F6). Two lamps light it (north of the wall and behind the guard); the HUD light gauge shows your level. The guard patrols A (0, 0, 2) -> B (5, 0, 6) -> C (-5, 0, 6); the player starts at the far corner (12, 0, -12). Debug panel Overlays: "Guard state" on shows state, meter and wary time. Event Log: `actor.awareness`, `actor.heard`, `actor.bark`.

- [ ] The guard walks its route at a walking pace (1.5 m/s, [ADR 0102](../decisions/0102-guard-speeds.md)), turns smoothly (240°/s, no snapping), waits 2 s at A and 1 s elsewhere; footsteps are audible but quieter than the player's.
- [ ] Guard pace ([ADR 0102](../decisions/0102-guard-speeds.md)): a patrol looks like a person walking, not a brisk march; alerted, it runs (4 m/s) with louder footsteps. Sprinting away (6 m/s) you pull away from a running guard; walking away (4 m/s, its speed) you do not gain on it. An investigating guard walks briskly (2.5 m/s), between the two.
- [ ] Walking into its view in the open: `?` (yellow) with a bark ("Huh?") after a moment, then `!` (red, "There you are!") within about a second at 4-9 m. It runs at you and stops about 1.5 m away facing you, not bumping into you.
- [ ] Light: in the Perception lab's dark corners guards would barely notice you (dark at 6 m: never; within 2 m always); here, compare standing under a lamp with standing far from both lamps (the light gauge low): detection is slower in the dim.
- [ ] Crouch-walking at 8 m in its view takes noticeably longer to be noticed than standing (x0.7); at the edge of its view (45°, 6 m) it takes about 2 s. Behind it you are never seen.
- [ ] Sprinting behind it within about 13 m is heard: `?`, it turns to the spot for 2 s, walks there, looks around (sweeps ±60°) and gives up ("Must be nothing."). Walking behind it at 4 m or more is not heard (concrete).
- [ ] Throw a small crate near it: it investigates; a crate breaking or a barrel exploding nearby makes it run there at once.
- [ ] Once alerted, break line of sight (behind the wall at x 1..7 or round the closet): after 4 s it searches (`?` orange, "Where did they go?"), runs then walks to points around where it lost you for up to 30 s, then returns to its route ("They're gone."). While wary (60 s, "Guard state" text) it notices you faster.
- [ ] Cloak (F1) makes you invisible to it even right in front (it still hears your footsteps).
- [ ] Baton from behind while it is Unaware or Suspicious knocks it out in one hit: it tips over backwards, the icon and barks stop, and it ignores noise. From the front or once Alerted it takes several hits; hitting it from the front alerts it.
- [ ] It pushes small crates out of its way gently (at most 2 m/s), cannot shove the large crate, and never flings props.
- [ ] Guard icons toggle off and on in the Overlays tab; barks are readable at a distance and disappear after about 2 s.

## Character models and animation ([ADR 0103](../decisions/0103-character-models-and-animation.md))

Guards are the Kenney blocky police officer, training dummies the crash-test figure. Review shots: run `tests/actors/common/animation/fixtures/character_shots.tscn` with `-- shots=all` (PNGs in `reports/screenshots/characters/`). Tuning lives in `actors/common/animation/blocky_character_anim.tres`.

- [ ] A patrolling guard's legs keep pace with the ground (no obvious skating or moonwalking at 1.5 m/s; `walk_clip_speed` 2.6); an investigating guard (2.5 m/s) walks faster, an alerted one sprints (4 m/s) without its feet sliding.
- [ ] Switching between idle, walk and sprint blends (about 0.2 s) without pops; turning on the spot does not look broken.
- [ ] Every drawn weapon raises the right arm only (ADR 0105: rifles too); walking with a gun drawn, the legs walk while the arm holds. The weapon sits in the fist and points where the guard aims, also up or down a stair.
- [ ] Every shot kicks the arms and torso; the muzzle flash shows at the gun in the hand. A baton swing raises the arm overhead and chops. Shots still come from the guard's eyes (cover that hides its hand but not its head does not stop its shots, as before).
- [ ] Knocked out or killed, the guard falls backwards and lies flat on the floor (nothing sinks into it or floats); you can walk over it and pick it up; carried, it stays in its lying pose (translucent). A revived guard gets up smoothly (about 0.5 s) and idles.
- [ ] Quicksave with a guard lying down, quickload: it is already lying (no fall replayed).
- [ ] Headshots (ADR 0105): the whole blocky head is the hit zone now; its edges and top count. Report whether guards die too easily (a snapped pistol shot at a head 10 m away usually kills within 2 s), and whether the shotgun is too strong at 15 m (often one or two shots now).
- [ ] Training dummies stand still on their base, arms down, like mannequins (ADR 0105), fall over when knocked out or killed, and stand up again on E (reset).
- [ ] Guards cast a blocky shadow under lamps (a static proxy: it does not swing its limbs); performance with the whole warehouse populated feels unchanged.
- [ ] A guard fits through the levels' 1.2 m doors without its arms visibly passing through the frame.

### Playtest fixes ([ADR 0105](../decisions/0105-character-model-playtest-fixes.md))

New review shots in `character_shots.tscn`: `hold_*` (each weapon), `patrol_light_6m`, `patrol_light_15m`, `patrol_light_side`, `aim_light`, `aim_light_dark`, `light_pose_front`, `light_pose_top`, `light_off_belt`, `dead_light`.

- [ ] Guards and dummies are lit like the walls around them: in the dark warehouse yard away from lamps a guard is about as dark as the wall next to him; in a lamp's pool he is clearly lit; at the shooting range the dummies are shaded (darker on the side away from the lights), not flat bright yellow.
- [ ] A guard's baton stands upright in his fist (like a real baton), not along the arm; it swings overhead and chops with the arm.
- [ ] Pistol, assault rifle, shotgun and sniper rifle are all held in the right hand; the long guns sit with their grip in the fist and the stock along the forearm, and read as guns from the side and the front.
- [ ] A guard with his flashlight on holds a flashlight in his left fist across his chest, below the chin; the beam and the glow come from it and point where he looks, also while he walks, runs (he runs upright), aims and shoots. With it off, the flashlight hangs at the front left of his belt and the left arm swings while walking.
- [ ] Knock out a guard whose flashlight is on: it goes off and stays in his fist; carry him: it comes along.
- [ ] Yard patrols at night (warehouse west yard): the light reads from 15 m and more as before, and you are noticed in its beam about as quickly as before (2-3 s at 8 m).

## M7 Bodies, shouts, radio, alarm ([ADR 0071](../decisions/0071-bodies-discovery-waking-carrying.md), [ADR 0072](../decisions/0072-shouts-radio-level-alarm.md))

In the hub: AI arena (doorway "6 AI Arena", south wall) and the Perception lab. Debug panel Overlays: "Guard state" shows state, meter and wary time; Event Log: `actor.body_found`, `actor.wake`, `actor.revived`, `actor.shout`, `actor.radio`, `actor.heard_call`, `alarm.raised`, `alarm.ended`.

- [ ] AI arena: shortly after loading, patrol A walks down the A3 > A0 leg, sees the unconscious guard lying lit beside it ("Man down!", `?` orange), runs to it, stands by it about 3 s and wakes it ("My head..."); both then search around and later return to routine.
- [ ] Start the game and stand at the hub spawn (or at the loadout table) for a minute: the arena's opening (patrol A finds and wakes the downed guard, the arena searches) stays inside the arena; no arena guard comes into the hub or shoots at you. The baton post (turned 30° east) never reacts to the downed guard first.
- [ ] From the hub door the baton post guard has its back to you: sneak up and knock it out with the baton without it turning, even during its ±45° glances.
- [ ] E on a downed guard's body: "E: carry Guard baton post"-style prompt; carried see-through, about 1.35 m ahead and low, you move clearly slower (0.6); E puts it down, Q drops it, LMB tosses it gently. It lands on the floor, stays down, never sinks in. In a narrow spot "No room to put down" shows.
- [ ] Walk straight over a downed guard (dead or unconscious): you are not stopped and do not need to jump; the view does not bob. A guard whose path crosses a body walks through it. Wake one (a patrol tends it, or wait for it): standing, it blocks you again. A body in a doorway still keeps the door from closing.
- [ ] Carry a downed guard into the dark corner (far right, light gauge dark): patrol B at B1, 2 m away, does not find it; leave it lit on a route and a patrol finds it within about a second of looking.
- [ ] Alert a guard in the hall: it shouts (others within about 17 m walking distance turn orange `?`, "On my way!", and run to it); the radio guard at the far end of the radio room reacts only through the radio (it is too far to hear the shout). A guard that is shooting at you does not stop to wake a body.
- [ ] Debug panel (`): "Raise alarm": the HUD shows a red "ALARM", every guard (the radio guard too) searches and keeps searching until it ends 45 s later (90 s before M9h; or "Clear alarm"); the panel shows the seconds left. (From M8 the alarm rings the arena's sirens: see M8.)
- [ ] Quicksave while carrying a body and quickload: the body is on the floor where you held it, still down.
- [ ] Perception lab: the guard holds the post at the back, facing the lanes. Standing in the lit lane, it sees you; open the breaker and it no longer does until you are within about 2 m.
- [ ] Walls and corners from the arena doorway, the radio room door from both sides, the dark corner: no seams; the dark corner looks dark, not grey.

## M7 Guard combat ([ADR 0070](../decisions/0070-guard-combat-and-loadouts.md))

No arena yet: open `tests/scenarios/fixtures/combat_yard_playtest.tscn` and run it (F6). You start hidden behind a 12 m wall (z -12) with a training dummy and a small crate; a pistol guard stands at (-3, 0, 0) and a baton guard at (3, 0, 0), both facing you across the lit yard. Event Log: `actor.engaged`, `actor.disengaged`, `weapon.fired`, `weapon.swung`.

- [ ] Step out from behind the wall: once a guard shows `!` the pistol guard draws (a dark box in its right hand) and after about half a second fires; each shot has a visible yellow flash at the gun and a loud report, every 0.6-0.9 s. The HUD flashes and the silhouette loses health on hits.
- [ ] Standing in the open at about 10 m you have time (3 s or more) to get back behind the wall; at 4 m it kills you in about 2 s of fire. Crouched and still far away (about 15 m), most shots miss; running across its view at 6 m, most hit.
- [ ] Walk up close to the pistol guard: it backs away, keeping its face to you, to about 7 m before shooting again; run far away (beyond 12 m) and it follows to about 11 m.
- [ ] Break line of sight behind the wall: the shooting stops at once, the guard runs to where it last saw you and, 4 s later, searches (`?` orange). Its magazine empties after 10 shots: it pauses about 1.6 s to reload.
- [ ] The baton guard runs straight at you and swings a blue box every 0.6 s when about 1.5 m away; three hits knock you out (no one-hit knockout from behind).
- [ ] Stand so that the baton guard is between you and the pistol guard: the pistol guard does not fire through its colleague; after about a second it steps aside and fires past it.
- [ ] Knock a guard out (baton from behind while it is still Unaware): it drops its weapon box from view and never fires again.
- [ ] Throw the small crate at the training dummy: it bounces off (no longer passes through) and the dummy shows about 12 damage once. The guards still push crates gently out of their way.

## M12 Hacking feel ([ADR 0074](../decisions/0074-network-hacking.md), tuning in [hacking.md](../game/hacking.md#tuning))

- [ ] No crack feels like dead waiting: Trained on a Medium password (18 s) and Advanced on a Strong one (25 s). Note any wait that drags.
- [ ] One crack against a default tracer leaves room to spare; two in a row without a pause trip it; a short pause (about 8 s) drains it.
- [ ] A sensitive tracer makes Trained brute force on Medium fail, so finding the password or an exploit item feels worth it.
- [ ] Guessing an implicit-clue password: a couple of wrong guesses are forgiven, careless guessing is not.
- [ ] The 30 s lockout plus the alarm feels like a real penalty without stalling the player.
- [ ] Door lock hardware (M9h, [ADR 0098](../decisions/0098-door-lock-hardware-and-keycard-relock.md); review shots: `wing_shots.tscn` with `-- shot=hw_d1_keypad|hw_d2_hall|hw_d2_closet|hw_d3_reader|hw_d3_open|hw_d4|hw_vault|hw_vault_inside out=<png>`, and `warehouse_shots.tscn` with `-- shots=door_manager,door_security,door_vault,door_back_gate_inside,door_back_gate_out,door_roller_inside,door_side,panel_bridge_door,door_front_gate_inside,panel_fire_escape_door out=res://reports/screenshots/m9h_doors/warehouse`):
  - [ ] No yellow panel anywhere. Pin-lock doors show a handle with a keyhole on both faces; keypads and card readers are small boxes beside the frame on both sides of the wall; the vault, D4, the front gate and the bridge door show a status box; the roller doors a control box. Every box's light reads red (locked), green (unlocked or open), dark (power off or broken).
  - [ ] E on what you look at: the leaf opens or closes the door and is where the lockpick works (from either side); the keypad box opens the keypad; the reader box swipes the card. The leaf of a keypad or keycard door says what opens it ("Locked: keypad").
  - [ ] An open pocket door: its handle stands out of the jamb and E there closes it; it is easy enough to aim at.
  - [ ] Keycard doors (D3, the warehouse's security and vault doors): open with the card, walk through, close it: it is locked again and needs the card again. They never close by themselves. A guard with the card opens them; from a free side they open without a card. Keypad doors stay unlocked once the code is in.
  - [ ] Save with a keycard door open, load, close it: it is locked.
- [ ] Warehouse wall devices clear of doors and signs (M9h; review shots: `warehouse_shots.tscn` with `-- shots=siren_office_ground,fire_exit_sign,view_camera_office out=res://reports/screenshots/m9h_after`):
  - [ ] Ground corridor west end: the siren hangs on the north wall east of the office entrance, not over the door leaf; the alarm is still heard in the break room and the security room.
  - [ ] Upper corridor east end: FIRE EXIT reads in full; the office camera hangs on the north wall and still sweeps the corridor from the vault door to the manager's door.

## M12a Network and deck ([ADR 0113](../decisions/0113-network-layer-tracers-and-the-deck.md))

Take the deck from the hub's loadout table (or the network lab's entrance table). The deck lab fixture's review shots stay useful (`tests/ui/deck/fixtures/deck_shots.tscn` with `SHOT=map_start|map_hacked|map_chained|menu|menu_router|ice_trained|ice_advanced|full_trace`) and set the Computer tier in the debug panel's Stats tab.

- [ ] LMB with the deck on a wall jack: the screen rises at once; nothing else in the world stops (guards keep walking). Esc and ✕ lower it without opening the game menu; LMB on the jack raises it again.
- [ ] Plugging in (or joining a Wi-Fi) shows your own subnet at once, with no scan (ADR 0121); only a subnet behind a router is scanned, and its scan reads as "the deck is working", not as lag.
- [ ] Walking away unplugs the deck at a sensible distance (3 m): not so short that a step sideways unplugs it, not so long that it looks like a wireless deck.
- [ ] The Map's amber (access) reads apart from the orange of devices doing something (ringing, firing) and from the online green.
- [ ] Hacking a router: the subnet behind it appearing after its scan feels like a reveal; a second router inside it is clearly the next step.
- [ ] Icebreaker scramble: while it runs, the next letter's cell flickers through random characters (about 22 a second, teal and blue) and each letter flashes as it locks; Stop or walking out of reach leaves a dot there, Resume starts the flicker again. Readable, not distracting?
- [ ] The Icebreaker's letters locking in feel like progress; Stop / Resume keep the progress; the menu's "Icebreaker (40 %)" makes a saved crack easy to find again.
- [ ] Assists: Trained times, Advanced trace estimates, Master hidden routes are readable and not noisy.
- [ ] A full trace: the alarm rings (if the tracer's host reaches the controller), the bar says "blocked N s", running tools stop with a message; plugging into another port (a new address) is a way out.
- [ ] Panic button and radio base station: disable / enable from a device menu (an account on them) work and show in their status.
- [ ] Clicks with a still mouse (ADR 0099 amendment, 2026-11-11): rest the cursor on a device, on the menu's Icebreaker / Log in / Open its desktop, on Stop / Resume and on the remote desktop's Back to the map; each shows its hover while still and a slow click (hold it half a second) acts every time. Dragging from a device or a button never moves the map; dragging the background does.

### Shared window frame (2026-11-11, [ADR 0113](../decisions/0113-network-layer-tracers-and-the-deck.md#amendment-shared-window-frame-and-theme-2026-11-11) / [0114](../decisions/0114-computers-halcyon-os.md#amendment-shared-window-frame-and-theme-2026-11-11) amendments)

- [ ] At your monitor's full resolution (and at 1152 x 648 windowed): the deck (Map, Icebreaker, Firewall), a computer's login card and its desktop show all four rounded corners and an unbroken border; nothing square pokes out at a corner.
- [ ] The header title, the tools' / dock's names and the body's content start on one line from the left; the ✕ sits as far from the top-right corner as the title from the top-left.
- [ ] The dock at the deck's sidebar width (icon and name in a row) reads well on the desktop and on a remote desktop inside the deck.

### M12b Wireless ([ADR 0117](../decisions/0117-wireless-access-points-and-the-decks-wifi.md))

No level has an access point yet: use the review shots (`tests/ui/deck/fixtures/wireless_shots.tscn` with `SHOT=map|crack|paused|joined|joined_map|world`, run through `tools/run_windowed.sh`) until the levels brief places them, then check in the lab and the warehouse.

- [ ] Aiming the deck at an access point across a room and pressing LMB feels like pointing an antenna: the Wi-Fi key screen rises at once in range; out of range the HUD message says how far it is and your range.
- [ ] The Wi-Fi key screen reads at a glance: signal bars fall as you step back (lower the deck, walk, aim again), "Line of sight blocked" and "Paused: line of sight lost" show the moment a door or a wall cuts the view, and the crack goes on by itself when you can see it again.
- [ ] The ranges by skill (8 / 12 / 18 / 25 m) feel right: Untrained has to come close and be seen; Master cracks from across a yard.
- [ ] Joined: the Map from the Wi-Fi reads like one from a wall jack (the access point outlined as your entry point); walking with the deck lowered keeps the tools running; stepping out of range drops it with a message and stops the Icebreaker.
- [ ] Dashed light-blue wireless links read apart from green cables and from grey dashed dead cables; breaking or unpowering the access point turns its wireless devices offline on the Map and their links grey.
- [ ] The trace while cracking a key (the access point's subnet's tracers) feels fair next to cracking an account.

### M12b Intrusion: exploit items, Firewall, logs ([ADR 0121](../decisions/0121-exploits-as-items-and-map-fixes.md), [ADR 0116](../decisions/0116-exploits-firewall-tool-and-device-logs.md))

Review shots: `tests/ui/deck/fixtures/deck_shots.tscn` with `SHOT=map_hacked|menu_exploit|scanning|firewall`, and `tests/ui/tab_interface/fixtures/tab_shots.tscn -- shot=inventory_exploits` (through `tools/run_windowed.sh`); then the lab and the warehouse.

- [ ] Every box on the Map has an icon that says what it is (camera, turret, door, alarm device, computer, router, switch, access point, wall jack) at the default zoom.
- [ ] Carrying an exploit item, a device of its kind offers "Use <kind> exploit (N left)" in its menu, other kinds nothing; using it is instant, no trace, and the menu then says "access: admin (exploit)". Does one use per item feel scarce but fair?
- [ ] A router exploit on RTR-01: the Firewall opens, and the subnet behind it shows its scan where it will appear (blinking dashed box, "Scanning SECURITY 10.0.20.0/24…", progress bar, seconds left, marching link from the router), then the devices appear in that box. The world keeps running meanwhile.
- [ ] The Firewall table is readable and editable with the mouse alone: selecting a row by its number, the From / To lists, ALLOW / DENY in green / red, Move up / down, Delete. "ALARM → SIREN · DENY" above the rest silences that siren when the alarm rings; deleting it lets it ring again.
- [ ] The line under the table makes it clear that your own traffic passes with an account unless a rule names "you".
- [ ] The inventory: exploit items show a chip icon and their kind (X-CAM, X-RTR), stack to 5 in one square, and the description says where to use them.

### M12b Map: the plugged network only ([ADR 0113 amendment](../decisions/0113-network-layer-tracers-and-the-deck.md#amendment-the-map-draws-the-plugged-network-only-2026-11-11))

- [ ] Use the deck in the network lab, then plug into a device in the security wing: the Map draws only the security wing's network; plug back in the lab: its map is there at once, no new scan. Raised unplugged from the Wi-Fi key screen, the Map button shows only "Plug the deck into a device to see its network."

### M12b gallery: the lab annex stations and the security wing's network ([hub-and-gallery.md](../levels/hub-and-gallery.md#m12b-annex))

Review shots: `lab_shots.tscn -- shots=annex_overview,wifi_station,wifi_pillar,exploit_station,firewall_station` (the deck shots one per run: `deck_map_wifi`, `deck_wifi_paused`, `deck_map_cctv`, `deck_map_alarm`), `wing_shots.tscn -- shot=deck_map_jack_rtr05` (also `network_wall`, `jack`).

- [ ] Wi-Fi station: with the lab's deck, Untrained, stand on the 6 m mark, aim at AP-LAB and hold LMB: the Wi-Fi key screen, Crack the key runs (about 10 s). Step behind the pillar: "Paused: line of sight lost"; step out: it goes on. From the 10 m mark it says out of range; with the Computer skill Trained (debug panel) it is in range. Joined, the Map shows AP-LAB with CAM-WIFI and LASER-WIFI dashed, SW-WIFI and RTR-03.
- [ ] Shoot AP-LAB, or cut its breaker: CAM-WIFI and LASER-WIFI turn grey on the Map and the deck's Wi-Fi drops; the breaker back on brings them back. The marks and the pillar read clearly from the doorway.
- [ ] Exploits station: take the two chips from the table, plug into the CCTV jack: the CCTV subnet is there at once; "Use camera exploit" on CAM-EX1 gives admin without trace (the Watchdog bar stays at 0); "Use router exploit" on RTR-03 opens its Firewall and the Wi-Fi subnet behind it gets scanned. The sign explains it.
- [ ] Firewall station: press PANIC-LAB: both sirens ring. Read the note, plug into the alarm jack, log in on RTR-04 from the Map, Firewall: add ALARM-LAB → SIRENS (or SIREN-A, SIREN-B) DENY; press the button again: silence, the controller still shows ringing. Is the sign enough to find the rule without help?
- [ ] Security wing: the entry hall's network wall (SW-OPS, RTR-05, SW-SECURITY) and the wall jack read as network gear; plugged into the jack the Map shows Operations and RTR-05 only; the booth computer's mail "RTR-05 login" (or a 10 s crack) reveals the Security subnet: SW-SECURITY with its booth, lasers, vault and corridor switches, no crossing. Every station works as before (D4 now also opens from the booth computer).

### Routers and subnet boxes (ADR 0112 amendment)

Review shots: `lab_shots.tscn -- shots=deck_map_start,deck_map_rtr01,deck_map_chained,console_security`, `warehouse_shots.tscn -- shots=deck_map_office,deck_map_hacked,office_pc1_dock`.

- [ ] Every screen, sign, note and toast says "router" (RTR-01, RTR-02), never "gateway".
- [ ] Each subnet's box reads as a place: its colour (Office blue, Security orange, Servers purple) is clear but faint behind the devices, its name and range are readable at the fitted zoom; a router clearly stands between two boxes and its two addresses make sense.
- [ ] Hacking a router: the new box appearing with its devices feels like the reveal; nothing about the hidden subnet shows before (no box, no count).
- [ ] The warehouse Map after hacking RTR-01 (fit zoom about 0.48): the switch tree (main switch on top, the four area switches below) is easy to follow without crossings; zooming in to read the labels is comfortable.
- [ ] The office PCs' dock shows Mail and Files only, bare-handed and as a remote desktop; the consoles still have Security.

## M10 Lockpicking sounds ([ADR 0108](../decisions/0108-lockpick-sounds.md))

Audition scene: run `items/lockpick/audio/fixtures/lockpick_audio_audition.tscn` (F6), keys 1-0 or the buttons play the cues, the sliders drive the voices. Compare with the prototype (`design/prototypes/lockpicking_bench.html`, sound on).
- [ ] Each cue sounds like the prototype's: a crisp set click, a quieter muffled click, a tiny tick, a deep clunk, a low creak, a dull jam, a loud snap, two short blips for the drop, the open's clack and thump. Pressing a noisy cue several times varies it slightly without changing pitch or level.
- [ ] Relock: the creak, then three quick pin settles falling in pitch, at the level of the other cues.
- [ ] Mashing keys quickly: overlapping cues all ring out; none cuts another off.
- [ ] Scraping slider up: a hiss that rises in pitch as Tension goes up, with no clicks or zipper noise while sweeping; back to 0 fades out quickly.
- [ ] Strain slider: silent up to about 0.12, then a buzzing tone that rises in pitch and level towards 1; Stop all (Space) fades everything out at once, without a click.
- [ ] The voices follow the sliders without a noticeable lag.

## M10 Lockpicking minigame ([ADR 0107](../decisions/0107-lockpicking-minigame.md), reworked by [ADR 0109](../decisions/0109-lockpicking-side-view-and-mouse-pick.md))

In the security wing (D2's pin lock) or any pin lock, with lockpicks; set the Lockpicking tier in the debug panel's Stats tab. Practice locks: the four on the security wing hall's west wall (take the lockpicks from the table); review shots `tests/levels/gallery/security_wing/fixtures/wing_shots.tscn -- shot=practice_wall|practice_wall_near|practice_simple|practice_standard|practice_standard_crouched|practice_secure|practice_high`. Review shots: `tests/ui/lockpick/fixtures/lockpick_shots.tscn` with `SHOT=untrained|trained|advanced|master|relock|rake|overset|room`. Compare the feel with the final prototype (`design/prototypes/lockpicking_bench.html`, wheel scheme).
- [ ] LMB with the pick on the lock: the camera turns smoothly to the lock in about a quarter second, the panel (wide, about half the screen) opens over the live view with the world visible around it, the player does not move with W / S / A / D and keeps crouching if crouched; guards and the world keep running.
- [ ] Tension: the wheel up raises it 3 % a notch, down lowers it, Shift + wheel 1 %; it stays where left; the wrench arm swings with it; the belt does not change item.
- [ ] Lift: mouse up raises the pick tip, it stays where left; the tip lags behind on the binding pin and the pick bows with the force; the sensitivity feels right (tuning `lift_pixels`, 300 px for the full lift).
- [ ] Sideways: with the tip down (bottom 10 %), mouse left / right slides it smoothly along the pins (tuning `slot_pixels`, 60 px a pin); lifted, it stays under its pin and slides on once lowered; it never lifts a pin on the way; resting halfway between two pins does not flicker between them.
- [ ] A / D: with the tip down they step to the previous / next pin; lifted they do nothing.
- [ ] The rigid pick looks right: it pivots in the keyway mouth and slides in and out, the hook always at the tip, the handle sticking out to the left (it may leave the panel at the front pin); on a brass lock it is solid in the groove and outside, faded behind the brass; it pales under strain.
- [ ] Feel of the pins matches the prototype: holding a pin at the shear line a moment sets it (a crisp click); lifting through it fast oversets it ("clunk, a pin is overset: release the tension to reset"); after a click the tip stays where it was and a small extra lift does not overset; lowering the mouse and lifting again lifts the set pin's key pin with the tip; shoving a set pin well past the line oversets it; nothing oversets below the sweet spot. The muffled click above the sweet spot; a deep clunk on a spool, the plug pushing back (creak) while you ease tension with the wheel and lift; serrated ticks; pins dropping one by one below the drop zone and all at 0 %; the strain rising before a snap at high tension.
- [ ] Assists: Untrained shows a brass lock, no gauge, no captions; Trained adds the gauge (its green band, 40-55 % untrained, widens with each tier to 31-64 %); Advanced adds the captions; Master shows the clear lock (pins, springs, shear line, labels). A practice lock shows everything at any tier.
- [ ] Leaving: E and Esc leave (Esc never opens the game menu; E never also opens the door), so does getting hit; the progress is lost; holding LMB while leaving does not restart it.
- [ ] A broken pick uses up one lockpick ("SNAP" caption, the count on the belt drops); with none left the panel closes and the HUD says "Out of lockpicks".
- [ ] A picked door: the lock tints green, the scrape and strain stop at once, the panel closes and the door swings open; the pick count is unchanged.
- [ ] Practice lock: once open, about 3 s later the relock sound plays, the pins drop and settle at new heights in the view, the caption says "new pin layout" and the panel reads "Layout 2"; the new layout picks differently.
- [ ] Practice-lock wall (M10d): from the hall the four locks and their signs read at a glance (header, then Simple 3 pins, Standard 5, Secure 5, High-security 6 from left to right facing the wall; High-security is the one next to the table); each prop shows its tier's pin count through the acrylic and sits flush on the wall with no gap or flicker; each can be picked standing and crouched from in front of it, every assist shows on each at Untrained, its pin count matches its sign, and once open each re-locks with a new layout ("Layout 2", the pins on the wall prop shift too).
- [ ] Raking: with the tip down, a fast left-right wiggle ticks and scrapes on every lock. Master on a Simple or Standard lock with light tension (from the drop line to the top of the sweet spot) sets a pin every 3 strokes (a Standard lock in about 2-3 s); too slow or with pauses it does not; on a Secure lock only the rattle. With no tension, too much, or an overset pin, a caption says why (at most every 1.5 s).
- [ ] A guard nearby hears a snapped pick (about 5 m) but not the clicks or the raking beyond about 1 m.
- [ ] Timing targets (a player who understands the mechanic): Simple about 5 s untrained; Standard about 15 s untrained, 7 s at Master; Secure about 30 s / 15 s; High-security about 60 s / 25 s.

## M11 Tab interface ([ADR 0110](../decisions/0110-tab-interface.md), [ADR 0111](../decisions/0111-character-tabs-and-per-part-medkit.md))

In the hub, the inventory bay and the warehouse mission, with a mixed loadout (debug panel's Give item). Review shots: `tests/ui/tab_interface/fixtures/tab_shots.tscn -- shot=inventory|inventory_medkit|health|augmentations|skills|objectives|codes|notes|hit` (through `tools/run_windowed.sh`). Compare with the mockup (`design/prototypes/tab_interface.html`).
- [ ] Tab opens the interface on the last tab used, Tab again closes it; I and L open on Inventory / Journal, switch to it when another tab shows and close it when it already shows; 1-5 and Q / E change tabs; Esc and the close button (top right) close it, and that Esc never opens the game menu (the next Esc does, and pauses).
- [ ] While open the world keeps running (guards patrol, a thrown crate keeps rolling, fire keeps burning), the player does not move or look and the mouse is free; on close the mouse is captured again at once and no key still held (E, Q, LMB) fires in game.
- [ ] The panel covers about 85 % of the screen over the dimmed world; the HUD is hidden while it is open and back on close.
- [ ] Getting shot or burnt while it is open: the screen edges flash red over the panel and it stays open; the inventory and health figures update live (a medkit count, a magazine).
- [ ] Dying or being knocked out closes it and shows the losing screen (Esc: the game menu, Load works).
- [ ] It does not open over a computer, the lockpicking screen, the keypad, a datapad being read, the briefing, the summary, the game menu or the debug panel; with it open, E does not use anything and the debug panel key does nothing.
- [ ] Inventory tab: a click selects an item (amber outline) and the right panel shows its icon, name, count, description and details; a weapon's damage, magazine, ammo carried, how far it is heard and the muzzle row match the item (fit a silencer: "Heard to" drops and the muzzle row names it; raise Pistols in the Stats tab: the damage goes up); the ammo-type and credits placeholders read right.
- [ ] Inventory tab actions: Use heals with a medkit while guards keep moving (refused with "You are not hurt" when unhurt); Equip / Put away changes the item in hand behind the panel; Drop puts it on the floor in front of you; the belt picker moves the item to another slot (the belt row updates) or takes it off; drag and drop, right-click menu and tooltips work as before.
- [ ] Journal tab, in the warehouse: Objectives shows "Warehouse", a short briefing line and the three objectives with their state (a completed one turns DONE while the tab is open); in the hub it says there is no mission. Codes and logins lists the door codes and logins you read with what they open ("Manager's office door", "Security console login"), logins as "user / password"; the "learned from" link opens that note. Notes lists everything read, newest first, with the reader.
- [ ] The keypad and the datapad reading view no longer pause: guards keep moving while you type a code or read; being knocked out closes them.

Character tabs (Health, Augmentations, Skills; [ADR 0111](../decisions/0111-character-tabs-and-per-part-medkit.md)):
Open the Tab interface on its Health, Augmentations and Skills pages (the world keeps running behind it). Compare with the mockup (`design/prototypes/tab_interface.html`). Review shots: `SHOT=health|augmentations|skills|skills_lockpicking tools/screenshot.sh res://tests/ui/tab_interface/fixtures/character_tab_shots.tscn 40`.
- [ ] Health: get hurt (a guard's shots, a fall, the dummy room's explosive): the silhouette and the bars change colour while the page is open, the values read "value / max", a part at 0 says what it does in red; Current effects lists "Injuries: move speed x0.6" for a disabled leg, "Injuries: aim spread +3°, sway x2" for an arm (+6°, x4 for both), "Legs disabled" / "Arms disabled" for both, and "Burning", "Cloaked" as plain state names (audit S10).
- [ ] Health: clicking a part on the silhouette or its row selects it (amber outline); the button reads "Use a medkit on the <part>" and is greyed while that part is full; using it heals only that part by 30 (45 / 60 / 90 with Medicine), the medkit count drops by one and "Healed N" shows; a full part is refused with "You are not hurt" and the medkit kept. "Heal all" spreads one medkit over the hurt parts like the belt; a medkit from the belt in play still heals the whole body.
- [ ] Augmentations: the energy bar drains live while an augmentation is on; "N s left at D / s" and "N s alone" count down; the switch turns an augmentation on and off exactly like its F-key (the HUD chip follows); at 0 energy everything switches off and switching on is refused with "Energy depleted"; uninstalled slots (Stats tab) are greyed "Not installed".
- [ ] Skills: each skill's pips and tier name; clicking a skill shows its description and the tier table with the current tier's column in amber; TESTING − / + change the tier (the debug Stats tab and the game follow: e.g. Pistols spread, the medkit heal on the Health page), − greyed at Untrained, + at Master.
- [ ] Every page fits the panel at 1152 x 648 with nothing cut off (the Lockpicking table is the widest).

## M12a Computers ([ADR 0114](../decisions/0114-computers-halcyon-os.md), [hacking.md](../game/hacking.md))

In the gallery's security wing booth and the warehouse (security console, the two office PCs upstairs in the second office). Compare with the mockup (`design/prototypes/hacking_screens.html`, "Office PC 2" and "Security console"). Review shots: `wing_shots.tscn -- shot=computer_login|computer_camera|computer_door|computer_states`, `warehouse_shots.tscn -- shots=console_cameras,console_door,console_alarm,office_pc2_mail,office_pc2_files,office_pc1_dock`, `tests/objects/fixtures/showcase/security_shots.tscn` with `SHOT=console_login|console_camera|console_mail|console_files|console_cut|console_remote`.
- [ ] E on a computer opens Halcyon OS over the dimmed world (about 85 % of the screen); guards keep moving behind it, the player stands still, the mouse is free and the HUD is hidden; on close everything comes back.
- [ ] Login: the title bar shows the host name; "Logins you know for this machine" lists only this computer's logins (a keypad code or another PC's login never shows), each with Fill in; Fill in then Enter logs in. A wrong guess shows "Wrong user or password." in red with a quiet beep; a guard in the next room does not hear it. With no login known it says so and points to the deck.
- [ ] Esc or ✕ leaves at once, also while typing in a field, and never opens the game menu; E never leaves; walking away (pushed) closes it; being knocked out or killed closes it and gives the controls back.
- [ ] Desktop: the dock shows Mail, Files and Security with their icons, the account and "user", Log out. Logged in, the computer stays logged in when you come back (and after quicksave / quickload) until Log out.
- [ ] Mail and Files: the list and the reader read well; opening the app or clicking an item adds it to the Journal (the HUD says it was added; the Journal's Notes show it with source Mail or Files) without the datapad reading overlay. On office PC 2, L. Petrova's "Re: password reset" mail and the birthday card file say "A clue, not a login: nothing is learned": the Journal's Codes and logins gains nothing; typing "lpetrova" / "tulip24" on office PC 1 works.
- [ ] Security app (booth computer, warehouse console): devices grouped under Cameras and turrets, Doors, Alarm and Laser arrays, each with its kind's icon and a short status in green / red (disabled) / amber (ringing, alert) / grey (offline); switches and computers are not listed. The camera's and the turret's live views move smoothly (the frame rate holds); a door, the alarm controller and a laser array show no view. Each action button does what it says within a fraction of a second (Disable a camera: "No signal"; Lock / Unlock / Open the vault door; Disarm the alarm; Disable a laser array: its beams go out), and the line under the buttons says "<device>: <action> sent.".
- [ ] Office PCs: their Security app says "This computer controls no security devices." and points to the deck.
- [ ] Panic buttons and radio base stations are listed with their status but have no buttons yet (their disable / enable comes later).

## M12a Network lab and warehouse network ([hacking.md](../game/hacking.md#levels), [hub-and-gallery.md](../levels/hub-and-gallery.md#8-network-lab), [mission-warehouse.md](../levels/mission-warehouse.md#network-m12a))

Network lab (hub doorway "8 Network Lab", west wall), Computer skill Untrained unless noted:

- [ ] The lab is found easily from the hub (the sign over the new west doorway; the mission doorway beside it now shows the lab's outer wall behind it: does that read as odd?). Each station's sign is readable from where you stand to use it, and says what to do next.
- [ ] Deck table: E takes the deck; selecting it on the belt and LMB on the wall jack (0.45 m up) is easy to aim; the Map shows the office and RTR-01 only.
- [ ] Office PC 1: the sticky note, then Fill in, logs in; the "Re: my password" mail reads as a fair clue. Office PC 2: after reading the photo on its desk, the guess (`jnovak` / `mishka2029`) feels findable, not a riddle; a wrong guess shows the Sentry tracer's bar rising.
- [ ] RTR-01: cracking it Untrained (10 s) from the Map, then the Security subnet appearing after its scan, feels like the payoff; the trace bar (about 60 % at the peak) teaches the tracer without locking you out.
- [ ] Security console (login from PC 2's mail): its Security app shows only the closet camera and the closet door; Disable the camera and Open the closet; the biocells inside are a fair reward. The same from the console's remote desktop on the deck.
- [ ] Breaker beside the closet switch: off, the camera and the door go grey (offline) in the console and on the Map while the console and RTR-02 stay up; the closet stays shut (fail-secure); on again, everything returns.
- [ ] RTR-02: "Log in (from rtr02.txt)" after reading the console's file; the server subnet appears; cracking the file server and opening its desktop remotely shows `well_done.txt`. The chain office -> RTR-01 -> Security -> RTR-02 -> servers reads on the Map.

Warehouse network:

- [ ] The deck on office PC 2's desk is noticed; the office wall jack (second office, east wall, low) is easy to find and plug into; the Map shows the office, RTR-01 and nothing behind it.
- [ ] Without the Computer skill, RTR-01 says "too strong"; the console in the security room (audit note login) is the other way. With Trained (debug panel), cracking RTR-01 (18 s, about +58 % trace) reveals the Security subnet and its five switches; the full Map is readable once zoomed (note where cables cross).
- [ ] The office PCs' dock shows Mail and Files only (no Security app); the console's Security app controls every camera, door, turret, laser array and alarm device as before, named as on the deck's Map (CAM-HALL, DOOR-VAULT).
- [ ] Area switches (in the second office's bay since M13c): shooting the vault's switch silences the vault, the upper corridor's camera and siren only; the roof's switch silences the roof's camera only (M12b: the beams are on AP-YARD); the main switch still cuts the building from the yard. Breakers A and B behave as before (B also takes RTR-01 and its tracer down).

### M12b warehouse: the Wi-Fi route, exploits, the Firewall ([mission-warehouse.md](../levels/mission-warehouse.md#wireless-and-intrusion-m12b))

- [ ] AP-YARD (on a bracket over the north parapet, above the dock between the roller doors) is findable at night: from the roof north of the dock skylights and from the gap between the truck's trailer and the hall wall, is its silhouette against the sky enough, or does it need the field service notes (water tower) to be found? Aiming the deck at it (LMB) is easy at 6 and 10 m.
- [ ] Untrained, from the roof spot (about 6.4 m): Crack the key (10 s, about +40 % on the Sentry tracer) while crouched in the dark; nobody notices. Then walk to the gap behind the truck (crouch under the trailer): Untrained says "out of the deck's Wi-Fi range (10 m; yours 8 m)", Trained (debug panel) cracks it there (7.5 s).
- [ ] Joined over AP-YARD: the Map shows the Security subnet and RTR-01, not the office; the console, the cameras, the lasers and both alarm controllers are there. Walking more than the deck's range away drops the Wi-Fi.
- [ ] Shooting AP-YARD (from the gap or the apron): the yard camera and both roof lasers go offline (grey on the console), the gate camera and the roof camera stay up; walking upright through a roof beam then rings nothing. Is that quiet route worth a pistol shot, and is the shot heard?
- [ ] Exploit items: the camera exploit on office desk 1 (beside the sticky note) and the alarm exploit on the water tower deck (beside the field service notes and the sniper rifle) are findable and read as loot. From AP-YARD, the alarm exploit on ALARM-YARD disarms the yard without any trace; the camera exploit takes any one camera. Is the tower detour worth it for one alarm device?
- [ ] Firewall: with admin on RTR-01 (Trained crack from the office jack), the Firewall tool lists four rules since M12c (Security -> Office allow, Office -> SEC-CONSOLE allow, Office -> MAIL-01 allow, Office -> Security deny) and they read sensibly. No rule there silences a siren: the alarm controllers and the sirens share the Security subnet (does a player expect otherwise?).

## M12c consequences ([ADR 0115](../decisions/0115-m12b-intrusion-and-m12c-consequences.md), [hacking.md](../game/hacking.md#m12c-consequences-as-built))

- [ ] Network lab, east wall (M13c): MAIL-PC (E, unlocked) shows two mails; flip the "edge router" breaker: both mails are still listed (the mail is on the PC).
- [ ] Warehouse (M13c): shoot RTR-01 (the second office's bay) and use office PC 1: its mail is all still there (no mail servers since ADR 0130).
- [ ] Warehouse: shoot one camera, then later a second one (more than 10 s apart): no alarm, two "lost signal" notes on the console's Security app (under the device list). Shoot SW-VAULT instead: a network fault rings within a second, the sirens play the short low double beep (not the intruder tone), guards go to the vault switch. Is the double beep distinguishable from the intruder alarm in play?
- [ ] Warehouse: breaker B now raises a network fault from the yard's controller (the yard's sirens ring, nobody is dispatched by radio). Does that make breaker B a worse choice than before in a way the player can foresee (the notes, the sirens), or does it feel like a gotcha?
- [ ] The vault doors (warehouse, security wing) show a yellow FAIL-SECURE plate on the corridor face, readable from 1-2 m; with their power cut they stay locked, while the warehouse bridge door (fail-safe) opens. Does the plate make the rule clear before you try?
- [ ] Mission summary: a run that breaks nothing earns Clean hands; shooting a crate, a camera, a switch or a barrel (and what its blast breaks) loses it. A crate thrown to pieces does not (known gap: thrown props are not attributed). Is Clean hands too strict with the hall's crates around?

## M12c readability ([ADR 0122](../decisions/0122-network-readability-lights-plates-ar.md), [hacking.md](../game/hacking.md#m12c-readability-as-built))

- [ ] Warehouse basement network closet, at 1 m: each switch and RTR-01 has a green LED top-left, a row of green port lights (SW-SECURITY: 8 and a "+") and a plate under it ("SW-SECURITY / feeds CAM-HALL, ..., +6") readable without stepping closer; the panel behind with its orange stripe and "NETWORK". Same on the security wing's network wall. Do the plates clutter the wall?
- [ ] Shoot SW-OFFICE from the closet: its LED turns red, its port lights go dark, and the HUD says "SW-OFFICE down: 3 devices offline (OFFICE-JACK, OFFICE-PC1, +1)" for about 4 s. Upstairs, the office jack's LED blinks amber. Is the amber blink noticeable from across the office?
- [ ] Cut breaker B from far away (more than 30 m from the switches it feeds): the line still shows (your breaker). A guard breaking something far away shows nothing.
- [ ] Deck in hand (not plugged in), RMB: "AR: cables (RMB)" and the remembered network drawn over the world: ceiling runs in the subnet colours, AP-YARD's wireless links dashed blue, dead links dim. RMB again, switching item or opening any screen turns it off. Is it readable in the office (runs from the basement rise through the floor) or too busy? Do runs fading with distance matter?
- [ ] A cut device's amber blink, a disabled device's red LED and a dark unpowered one: is the colour language clear without the Map?
- [ ] M13 fix: walk past every networked device kind at an angle (camera, siren, panic button, alarm controller, radio base station, computer, wall jack, access point, switch, router, mail server, turret, door, fence gate, laser array): each LED sits on the device (turret: its base; a door without wall boxes: the leaf's top-left in the doorway, sliding away with it), never in the air in front of or above it.
- [ ] One light per device (ADR 0122 amendment 2): no device shows two lights. The camera shows only its lamp (green, amber when it notices you, red when it detects you; dark when disabled or unpowered); a door with a keypad, card reader or status box shows only the box light on each face (red locked, green open; the boxes are its door controller since M13c, and a door without boxes shows no light at all). Shoot or unpower the switch feeding a camera or such a door: the camera lamp and the box lights blink amber even while the camera sees you; restore power: their own colours come back. The alarm controller, panic button, radio base station, siren and mail server keep their dark lens shapes but only the LED glows. Is a blinking amber lock light still readable as "no network" rather than "locked"? Reference shots: `tests/objects/fixtures/showcase/status_light_shots.tscn`.

## M13a Weapon feel loop ([ADR 0120](../decisions/0120-weapon-feel.md), [ADR 0123](../decisions/0123-recoil-and-skill-aim.md))

Tests measure the targets (pistol 56 / 80 / 92 / 100 % on a torso at 10 m by tier, the compensated rifle spray 31 / 49 / 67 / 87 %); these checks are how it feels.

- [ ] Range, Untrained (tier button): aimed well at the 10 m dummy, tapping the pistol about once a second still misses about half the shots; Master: the first still shot lands exactly on the crosshair's centre. Trained and Advanced feel like steps between.
- [ ] Assault rifle, hold LMB at the spray wall without pulling: the camera climbs (mostly up, then sideways), then comes back by itself within about half a second of letting go. Pulling the mouse down against it keeps the spray on the 10 m dummy; is the pattern learnable after a few magazines?
- [ ] Submachine gun (second rack, pistol ammo): faster, drifts more sideways than up; kills the 5 m dummy in about 0.6-0.7 s; at the 20 m dummy it is clearly weaker than the rifle (damage falls off past 8 m).
- [ ] Tapping the pistol needs no correction (the kick is back before the next shot); the shotgun and the sniper kick hard; scoped, a sniper shot blacks the lens out for a moment.
- [ ] Crosshair: four arms around the dot open and close with accuracy (sprint, jump, spray, Master standing still); the arms get "T" caps on a dummy, guard or breakable thing within the gun's range, not on walls or past range; baton and empty hands show the dot only; the scope keeps its own overlay. Readable on bright walls?
- [ ] Crosshair (playtest 2026-11-12): the arms are thin (1 px at 1080 p) with a faint edge, readable on a bright wall and a dark corner; at Master standing still (pistol, and the sniper scoped) the four arms stay round the dot with a small gap, never a dot alone.
- [ ] Sniper scope: the four-arm crosshair sits exactly at the centre of the lens circle while swaying, right after a shot (the lens moves with it) and during the blackout; the thin lines stop short of the arms; "T" caps on a dummy in range.
- [ ] Moving: running clearly worse, walking and crouch-walking close to standing, jumping bad.
- [ ] Settings, camera motion 0 %: the camera stays still during a spray, the crosshair climbs instead and the bullets follow it.
- [ ] Warehouse: the east yard patrol and the vault door guard carry submachine guns (bursts) and drop one when downed; they aim as the pistol guards do (M13b changes guards).
- [ ] Tuning panel (range): the held gun's recoil (pattern scale, kick, noise, return delay and time, scope blackout), aim (still cone, movement terms, bloom, cap, settle) and damage falloff sliders change it live.

### M13a shooting range ([ADR 0125](../decisions/0125-shooting-range-tools.md), [hub-and-gallery.md](../levels/hub-and-gallery.md#4-shooting-range))

- [ ] From the firing line the six targets read at a glance: 5, 10, 20, 40 m dummies, the spray wall (10 m) and the walking dummy (15 m); lane signs on the counter name them.
- [ ] The walking dummy crosses its lane at a guard's walking pace (about 4 m, 1.5 m/s) and is a fair moving target at 15 m; shot down it stops and lies still; "Reset dummies" stands it up and it walks on.
- [ ] A 30-round spray at the spray wall leaves a pattern you can read from the firing line (5 cm marks); "Clear wall" empties it; the marks never run out mid-session (500 kept, oldest go first).
- [ ] The stats board (above lanes 5 and 6) is readable from the counter: each target's hits / shots, hit share and group (cm) for the last 10 shots; a miss near a target counts against it, a wild one against nothing; "Reset stats" zeroes it.
- [ ] The tuning terminal (E) opens the panel on the right with the range still visible and running; every slider of the gun in hand changes it at once (fire again with the panel closed); Esc or ✕ closes; Save then a restart keeps the values (editor or a run from the project folder only); Revert brings the saved values back.
- [ ] Tier buttons in the panel and the "Skill tier" button (E: next, its label says which) change the Weapons skill of the gun in hand; the Skills tab shows the same tier.
- [ ] "Reset dummies" stands up every downed dummy in the room (lanes, walker and melee pair), dead or knocked out.
- [ ] The second rack (east of the medkits) holds a pistol, the submachine gun and 60 pistol rounds for each.
- [ ] M13 fix: the SMG is the red Kenney `blaster-n` (like the pistol, they share ammo): in first person it sits where the old one did, with and without the silencer (the silencer on its muzzle, the flash and tracers from its end); lying on the rack, held by a warehouse guard and dropped by one, it looks the same size.
- [ ] Settings (Esc menu): every setting takes effect and survives a restart; camera motion at 0 % stops shake and the camera's recoil climb, but bullets still follow the pattern.
- [ ] Esc, Settings: the game stays paused; Esc (or Back) returns to the Esc menu with Settings focused, a second Esc resumes. Keyboard only: Up/Down reach every row, Left/Right move sliders, Enter flips switches; the focused row's name is white.
- [ ] Mouse sensitivity ×2 turns twice as far per mouse move; ×0.5 half; through the sniper scope the crosshair still moves as far on screen as at the hip.
- [ ] Invert Y: mouse forward looks down; off again: normal.
- [ ] Field of view: dragging the slider widens or narrows the view behind the dimmed menu at once; 100° and 70° feel right; the sniper scope still zooms to the same view at any setting.
- [ ] Volumes: master, effects (gunshots, footsteps, alarms, lockpicking clicks) change at once; 0 % is silent; music has nothing to play yet.
- [ ] Fullscreen on and off switches the window; vsync off raises the frame rate above the monitor's (debug panel stats).
- [ ] Quit, start again: the settings are kept (`user://settings.cfg`); loading a save does not change them.

## M13b Feedback ([ADR 0120](../decisions/0120-weapon-feel.md))

### Hit reactions and guard recoil ([ADR 0127](../decisions/0127-hit-reactions-and-guard-recoil.md))

Tests measure the survival targets (a still player at 10 m: pistol guard 6.75 s, rifle 5.37 s, SMG 3.85 s; at 4 m 2.35 / 1.98 / 2.88 s); these checks are how it feels.

- [ ] Taking a guard's shot: the view kicks up slightly (sideways too when shot from the side) and is back within about a third of a second; the crosshair opens for a moment. With camera motion 0 % the camera stays still and the crosshair jumps instead.
- [ ] Shooting a pistol guard right after its shot visibly delays its next one (about 0.3 s); keeping an SMG on a rifle guard cuts its bursts short.
- [ ] A leg or arm hit makes a guard lean back away from the shot for half a second and slow down (a chasing guard stumbles); a torso or head hit does not. Does the lean read at 10 m? (Its ground shadow does not lean.)
- [ ] Standing in the open at 10 m from a pistol guard you have several seconds to reach cover; rifle and SMG guards are clearly more dangerous at that range, all of them deadly within 4-5 m.
- [ ] Guards' bursts (rifle, SMG) climb a little: later rounds of a burst miss high more often than the first, but they keep firing short bursts (3-4 rounds).

### Weapon motion and sound ([ADR 0128](../decisions/0128-weapon-motion-and-shot-sounds.md))

Every value is on the range's tuning panel (the gun's `motion` and `shot_sound` rows); tune by feel and Save.

- [ ] Kick: the pistol snaps back and is settled before the next tap; the shotgun and sniper rifle kick hard and slower; the SMG and rifle shudder while held, never climbing off screen. Does the kick match the camera recoil?
- [ ] Sway: a quick mouse turn makes the gun lag a little behind and settle; not floaty, not seasick. The sniper lags most.
- [ ] Bob: none standing still or in the air; a gentle bob walking, stronger sprinting, smaller crouch-walking; it fades out (no snap) when you stop.
- [ ] Reload (R): the gun dips out of view and comes back as the HUD's "reloading" ends, for every gun (pistol 1.6 s, SMG 1.8 s, rifle 2.2 s, shotgun 2.4 s, sniper 2.5 s).
- [ ] Draw: pressing a belt key raises the gun from below; switching guns raises the new one; holstering (or the same key) lowers it before it disappears. Firing at once on a draw still works (the shot is not delayed).
- [ ] Camera shake on firing: slight on the pistol, SMG and rifle, clearly stronger on the shotgun and sniper; the crosshair stays on target (shots go where it points). Settings, camera motion 0 %: no shake and no recoil climb; nothing moves the view but the mouse.
- [ ] Sounds: with eyes closed, tell the pistol, SMG, assault rifle, shotgun (pump after the bang) and sniper rifle (deep boom, bolt) apart; repeated shots do not sound like one copied sample (pitch and volume vary). Silenced pistol, SMG, rifle and sniper: a muffled thud with the click, no bang.
- [ ] Echo: shooting in the hub or the shooting range gives a short, dense tail; in the warehouse yard or on the roof a longer, sparser one; step through the hall's dock door while firing and hear it change. A guard firing in the yard echoes outdoors even if you are inside.
- [ ] Is the one real gunshot recording in the packs (Titan Handgun) enough, or should a gun sound pack be added (the user decides)?

### Shot feedback ([ADR 0126](../decisions/0126-shot-feedback.md))

Tuning: `ui/hud/hit_marker.tres` (marker times, colours, sizes, tick sounds), `items/weapons/fx/shot_fx.tres` (puffs per material, holes, tracers); each weapon's `tracer_every` is on the range's tuning panel.

- [ ] Hit markers at the range: a body hit flashes four small white ticks round the crosshair, a headshot yellow ones a little longer, a kill a red X held a moment; a soft tick with each, the kill's stronger. Subtle enough, or too small at your resolution? No numbers anywhere.
- [ ] Spray the SMG or assault rifle into a dummy, at the hip and through a scope: the hit markers stay centred on the crosshair as it climbs with the recoil, never left behind where the aim was at the hit.
- [ ] Baton: a hit shows pale blue ticks; the knockout a pale blue X. Shotgun: eight pellets on a dummy tick once, not eight times.
- [ ] No marker when a guard shoots a dummy or you, when a barrel you shot blows up a dummy, or when you hurt yourself.
- [ ] Impacts: concrete walls puff grey dust and keep a dark hole; metal (the metal crates, a metal ledge, doors) throws orange sparks; wooden crates and barricades splinters; lamps and bottles pale shards. A room with a wood or carpet floor still gives dust on its walls, splinters only on a wood floor.
- [ ] Holes stay about 30 s and fade; a long spray keeps at most about 200 in the world. No holes on dummies, guards, crates you can push (they would float), or doors; the spray wall still keeps all its own marks.
- [ ] Bodies: a small dark-red puff, no decals, no pools. Is it too much or too little for the tone?
- [ ] Tracers: holding the assault rifle or SMG shows a short bright streak every third round flying to the hit; the pistol, shotgun and sniper show none. A guard's every shot shows one: can you tell where fire comes from in the warehouse yard at night? Too bright or too slow?
- [ ] No hitch on the first shot after loading a level; a long spray at the range keeps the frame rate (debug panel).

## M13 Interaction frame ([ADR 0129](../decisions/0129-interaction-frame.md))

- [ ] Look at a pickup on a table within reach (inventory bay): four thin white corner brackets hug it and a small boxed name ("Lockpick (3)", the prompt's name with the count) sits just above the small frame (the "E: pick up ..." line under the crosshair is gone since M13c). Step back out of reach or look away: the frame goes at once.
- [ ] Walk and turn while looking at a crate: the frame follows it smoothly with no lag or jitter. Carry it: no frame while it is held; put it down: the frame returns.
- [ ] A door up close: the brackets sit near the screen corners around what you see of the door, the "Door" tag inside the top-left corner, never cut off at the screen edge. A computer, a switch, a datapad and a training dummy are framed with their prompt names.
- [ ] Knock out a guard and look at the body: the frame fits the lying figure (not the standing height) with "Guard"; the "?" icon over a guard never stretches a frame.
- [ ] The brackets read on bright (a lit wall) and dark (an unlit corner) backgrounds; at 1080 p the lines are one pixel thin, at 4K still crisp. Too subtle or too strong? Is the tag's size right?
- [ ] Scoped (sniper RMB): no frame; knocked out or dead: no frame.

## M13c gear in the network lab and the security wing ([ADR 0130](../decisions/0130-device-overhaul.md) step 3)

The hub showroom is gone; the gear now stands in rooms 5 and 8 ([hub-and-gallery.md](../levels/hub-and-gallery.md#8-network-lab)).

- [ ] Network lab, bay A (west wall, open): RTR-01, SW-SECURITY and SW-CLOSET in their slots, blank panels below; up close (0.5 m) the blanks show dark seams and no bright lines; the cables rise from the bay's top to the ceiling. Can you read the switches' vertical port labels, and from how far (the shots found about 0.3 m at 648 p)?
- [ ] Bay B (east wall, locked): the glass door shows the lights; the frame reads "Locked · key or lockpick". Pick it with a lockpick (LMB), close it (E); it stays unlocked. In a fresh run, get the key from the closet shelf (open the closet from the console first): "Key added to the keychain", the Inventory's keychain lists "Bay B key", E opens the door. The file server inside opens its desktop with E like a desktop.
- [ ] Desk gear: the office switch on PC 2's desk, the edge router on the mail PC's desk; the four desktops (PC 1, PC 2, console, mail PC) stand on their desks, no shelf, nothing floating or sinking. Are the desk boxes noticeable enough, or too small to find?
- [ ] Annex, bay C (far wall, beside the exploit table): RTR-03, SW-CCTV, SW-WIFI, RTR-04, SW-ALARM, SW-SIRENS. The firewall station's devices (jack, alarm controller, panic button, sirens) stay on the west wall; does the station still read well with its router in the bay across the room?
- [ ] Security wing: one open bay on the hall's north wall (SW-OPS, RTR-05, SW-SECURITY, the four area switches, the rack alarm controller with its ARMED display); its sign to the right; shoot SW-SECURITY in the bay (one round) or cut breaker B: the security devices drop off as before. The booth computer stands on a desk; the booth's east wall keeps only the radio base station.
- [ ] Deck in hand, RMB (AR cables): runs from the bays' units rise to the ceiling above the bay (not from the bay's top) and across; runs from desk gear rise from the desk. Do the many runs from one bay read, or is it a tangle?
- [ ] Walk round each bay: 1 m free in front, the locked bay's door swings out without hitting anything; you can reach every unit with the crosshair (the frame names it).

## M13c the deck's Map nodes ([ADR 0130](../decisions/0130-device-overhaul.md))

Plug the deck into the network lab's jack and hack RTR-01.

- [ ] Each box has its kind's colour strip on its left edge and its icon in the same colour; at the fitted zoom, can you tell switches, routers, cameras and alarm gear apart by the strip alone?
- [ ] The status square at each box's right matches the device's light in the room: green up, amber blinking when its switch is down, red when disabled or broken, dark when unpowered. Cut a switch's power: do the squares behind it blink, and is the blink calm enough not to distract on a big map?
- [ ] A selected, disabled (red tint) or out-of-reach (grey) box keeps its strip and icon colours; is the grey "offline" box with an amber square clear enough as "cut off from you"?

## M13c frame status and keys ([ADR 0130](../decisions/0130-device-overhaul.md) step 1b, [ADR 0129](../decisions/0129-interaction-frame.md) amendment)

- [ ] No "E: ..." line under the crosshair anywhere (pickups, doors, crates, computers). Can you still tell what E will do from the frame and its name alone?
- [ ] Network lab: within 2 m of a switch, a camera or a computer the frame shows with a green "Online" square and word under the name; break or unpower the switch it hangs on: the devices behind it read "Cut off" with a blinking amber square (in step with their LEDs); switch one off from the deck: red "Disabled"; shoot one: red "Broken"; cut the power: grey "No power". Each changes while you look, without looking away.
- [ ] A lamp within reach (a wall lamp, the perception lab): green "Powered"; trip its breaker: grey "No power". Beyond 2 m nothing is framed (walk back from a switch: the frame goes at 2 m).
- [ ] A guard within 2 m: awake, the name only; knocked out, a blue-white "Unconscious"; killed, a dim red "Dead". The dead-body frame still fits the lying figure.
- [ ] Locked doors: the leaf's frame reads "Locked · keycard", "Locked · code", "Locked · lockpick" or "Locked · key or lockpick" (amber). E on it without what opens it shows a short message above the belt ("Locked: needs a keycard" ...); the keypad box still opens its screen with E.
- [ ] E on a crate too heavy to lift: "Too heavy"; E while carrying with no room to put down: "No room to put down"; E on a dead computer: "No power" or "Broken". Are the messages noticed, and do they stay long enough?
- [ ] Are the tag's status words readable on bright walls and in dark corners (the "No power" grey and the "Dead" red especially)? Too much text on a crowded screen?
- [ ] Keys: no level places a key yet (step 3). Debug: give the player a key (`Keychain.add()` from a script, or a key pickup `items/key/key.tscn` with `key_id` / `key_name` state and a `found_text`) and pick it up: "Key added to the keychain: <name>", nothing in the grid or belt, Q drops nothing. The Inventory tab (Tab) lists it at the far right under "KEYCHAIN · 1 KEY" with where it was found, dim. A mechanical lock whose data names that key opens with E; without the key E says "Locked: needs a key or a lockpick" and LMB with a lockpick still picks it.

## M13c door controllers ([ADR 0130](../decisions/0130-device-overhaul.md) step 1a)

- [ ] Security wing and warehouse: every keypad, card reader, status box and control box is the new model (10 x 20 cm, violet strip and door icon, the lock light top right) on both faces of its wall; nothing floats, sinks into the wall or overlaps a sign. The lock light is the only light on the door (none on the leaf).
- [ ] Look at either box of a networked door (security wing D4 and vault, warehouse front gate, security, bridge and vault doors): the frame names the door's controller (DOOR-VAULT ...), says Online, and the door's lock line ("Locked · keycard"). Cut its switch or breaker: Cut off (blinking amber) on the frame and on both box lights.
- [ ] E on a card reader without the card: "Locked: needs a keycard"; on a keypad: the code screen as before; on a roller door's control box: it opens.
- [ ] The deck plugs into either box of a door (LMB with the deck) and its Map shows the controller as a violet "Door controller" node; Open from the Map or the booth's Security app opens the door. The door exploit (from the Map) works on a door controller.
- [ ] Breaker A in the security wing: D4 (fail-safe) unlocks and its lights go dark; breaker B: the vault door (fail-secure) stays locked, lights dark.
- [ ] Mechanical doors (D2, the warehouse's pin-lock doors) show no light and no status line: they are not devices.

## M13c device scenes in the new look ([ADR 0130](../decisions/0130-device-overhaul.md) step 2)

- [ ] Security wing, network lab, warehouse: every camera, turret, siren, radio base station, panic button, alarm panel, wall jack, laser pair, access point and wall computer shows its new model in the old spot, flat on its wall or floor, nothing floating or sunk. The computers stand on a wall shelf: does that read as a standing terminal, or do they want desks (step 3)?
- [ ] One light per device: the access point's ring, a siren's or a switch's LED, the camera's lamp follow the device (green, amber blinking cut off, red disabled or broken, dark unpowered) in step with the frame's status word and the Map's square. Wall jacks, panic buttons and lasers show no light at all: is their state clear enough from the frame?
- [ ] Ports: on a jack, an alarm panel, a computer, the socket a cable takes is labelled with the far end's network name and its light is lit; unpower the far end: the light goes dark, the label stays. Are long names (cut or shrunk to fit) still recognisable?
- [ ] Name plates show the device's network name, and the frame names a device the same way ("SW-OFFICE", not "Switch a"), also on computers and panic buttons.
- [ ] Ring a siren (alarm or debug): the beacon's cover glows red-orange, lights the wall around it and its reflector turns; silenced, it goes dark and still. Is the light too strong in small rooms?
- [ ] Baton a high siren (3 m and more): from right under it the swing hits the wall; step back to about 1 m. Acceptable, or should high sirens be shot?
- [ ] The rack scenes (switch, router, server, alarm controller) in a bay: E on the rack server opens its OS screen like a desktop; the deck plugs into rack gear like into the old boxes.
- [ ] The locked bay (`objects/devices/linking_bay_locked.tscn`, step 3 places them): the glass door blocks E and the deck on the units while the lights show through; pick its lock: it swings open; E closes and opens it again. Does the leaf swing the right way and fast enough (0.5 s)?

## M13c warehouse office bay ([ADR 0130](../decisions/0130-device-overhaul.md) step 3, [mission-warehouse.md](../levels/mission-warehouse.md#office-bay-m13c))

- [ ] Second office: from its door the bay (BAY-OFFICE, east wall) reads as the network's home; its lights show through the glass; the frame on the door says "Locked · key or lockpick". Nothing in the room is in the way (1 m clear in front of the bay, the desks along the south wall).
- [ ] The key on the security room desk (beside the vault keycard): noticed when you search the room? "Key added to the keychain: Office bay key"; with it, E on the bay opens the door. Without it, picking works (4 pins, one spool) and G7 in the corridor does not hear the picking or a broken pick.
- [ ] Open bay: the units read top to bottom (RTR-01, five switches, MAIL-01) by their plates; the port labels are legible leaning in (0.3-0.5 m); E on MAIL-01 opens its OS screen (no account: a login only); shooting SW-YARD silences the yard as the booth switch did, shooting SW-SECURITY cuts the area switches apart. Is one bay for every switch too easy a way to silence the compound (it used to take the store and the booth)?
- [ ] Desks: both office PCs stand on their desks (no shelf), the sticky note, the camera exploit, the deck and SW-OFFICE stay readable and pickable around them; E on each PC opens it; SW-OFFICE's port labels name the jack and both PCs.
- [ ] Deck on the office jack: the Map shows SW-OFFICE, both PCs, the jack and RTR-01 as before; hacking RTR-01 shows Security with MAIL-01 under SW-SECURITY.
- [ ] Gate booth: no switch on its east wall any more; the yard's alarm controller is still there and works.

## M14b grenade effects ([ADR 0131](../decisions/0131-grenades-mines-and-effects.md#as-built-m14b-the-four-effects), [explosives.md](../game/explosives.md#the-effects-as-built-m14b))

Until M14a's grenades and the range are in, use the debug panel's Spawn tab (Gas, EMP, Jam at the crosshair).

- [ ] Frag: does the blast read as a grenade (smaller and sharper than a barrel)? Guards at 2-3 m die, at 4-5 m stagger on badly hurt, at 6 m barely notice: does the edge feel right, or should the falloff hold up to 6 m?
- [ ] Gas: the cloud reads as gas from outside (soft green puffs, no hard sphere edges) and from inside (green tint, the room still readable enough to walk out). About 3 s inside knocks you out ("Knocked out" overlay); stepping out after 1-2 s keeps you awake. Behind a door frame or a wall you are safe. Does it drift too much or too little (0.1 m/s), and is 12 s too long in a corridor?
- [ ] EMP: lights within 6 m go out at once and come back after 20 s by themselves; a camera's lamp goes dark and it stops tracking; a turret stops; a fail-safe door (security wing D4) unlocks and a vault stays locked; the frame on a device says "No power". Your energy bar halves. A deck plugged in nearby is unplugged. Is 20 s long enough to slip past a camera?
- [ ] Jamming: wireless cameras near the field (network lab Wi-Fi corner, warehouse AP-YARD) blink amber and the frame says "Jammed"; the Map still draws them with "jammed"; a camera that sees you then raises no alarm. A deck on a jack keeps working inside the field; a deck on the Wi-Fi drops. Guards inside get no radio dispatch. With no sound and only a tiny blinking beacon, can you tell where the field is and when it ends?

## M14a grenades, mines and Demolition ([ADR 0131](../decisions/0131-grenades-mines-and-effects.md), [explosives.md](../game/explosives.md))

Give yourself grenades from the debug panel (Give item: frag, gas, EMP, jamming grenade). Stuck or thrown, each releases its own effect (M14b, above).

- [ ] Each grenade in hand: the round frag, the canisters with green, blue and cyan caps; held low right, not in the way; the weapon corner says "x3" and counts down per throw; the last one thrown leaves empty hands.
- [ ] Close to a wall, a door, a crate, the floor (crouch and look down) or a ceiling: the ghost shows where it would stick, its base on the surface. Does the 1.2 m reach feel right? Is the ghost visible enough (60 % opaque)?
- [ ] Stuck on a sliding door, a hinged leaf or a crate you then carry or push: the mine rides along. Break the crate: the mine drops.
- [ ] Throws: level, 12 m Untrained (to the first touch-down; it then rolls up to about 4 m: too far?); looking up lobs higher and shorter. Is the fixed 20 degree arc readable without a preview? Off a wall and off a guard it bounces back; never sticks to a person. The bounces clink (impact noise: guards hear them).
- [ ] Mines: arm 2 s after sticking (a short beep), then blink red about once a second. Walk at a mine: it goes off about 2.5 m away (from your body); crouch-walk: about 1 m. Behind a crate or around a corner it does not see you. Does 2.5 m feel fair?
- [ ] The frame on an armed mine reads "Frag grenade · Armed" in blinking red.
- [ ] Disarm: Demolition Trained (Stats tab), crouch 1 to 2 m from a mine, E: it is back in the inventory. Untrained, or standing, or too close: a beep and it goes off half a second later. Is the 1 to 2 m window findable on a floor mine (your crosshair must be on it within 2 m of your eyes)?
- [ ] Demolition Advanced: armed mines within 8 m glow red, also in the dark (switch the lights off) and in smoke; walls still hide them.
- [ ] Demolition Master: after a throw, "Fuse 2.1 s" counts down under the crosshair until it goes off.
- [ ] Shoot a stuck or thrown grenade: it goes off; a blast sets off grenades and mines nearby (chains).
- [ ] Quicksave with a grenade in flight and a mine arming; quickload: the grenade carries on and goes off on time, the mine arms on time.

## M14 explosives walk-through (M14c: the range and the warehouse; [ADR 0131](../decisions/0131-grenades-mines-and-effects.md), [explosives.md](../game/explosives.md))

Shooting range (hub doorway 4), then the warehouse. No debug panel needed.

- [ ] Find the grenade lane from the counter gap: past the blast lane, behind the spray wall. The table's sign is readable from its front and does not hide the lane. E on each pickup takes 5 (frag, gas, EMP, jamming); "Restock grenades" puts back everything taken or knocked off the table.
- [ ] Stand on the throwing line, look level at the target square and throw a frag (Untrained): it lands on the square and rolls on about 3-4 m before it goes off. Is the roll too long for a 12 m lane? The 2 m and 4 m dummies drop or nearly; the 6 m one shrugs it off (a light wound): does the frag feel weak at 4.5-6 m?
- [ ] Exact distances: stick a frag on the target, walk back to the line, shoot it: the dummies take what the sign promises. "Reset dummies" on the table stands them up.
- [ ] "Skill tier" with a grenade in hand switches Demolition (Trained: 14 m throws land past the target; Advanced: mines glow; Master: the fuse readout).
- [ ] Gas on the target knocks out the 2 m dummy only (2.5 m cloud); an EMP or a jammer on the target does nothing visible (no electronics within 15 m).
- [ ] Walk from the grenade lane to the east wall (lane 6, by the counter): "Mine corridor · EMP and jamming room" over the opening. In the corridor, stick a frag on the wall, the floor and the door; walk back in: it goes off about 2.5 m away; crouch-walk: about 1 m. Opening the door with a mine on it carries the mine into the wall.
- [ ] Disarm a corridor mine Untrained (it beeps and goes off), then Trained (switch the tier at the grenade table first): crouched 1 to 2 m away, E takes it back.
- [ ] EMP and jamming room: the turret does not shoot you (guards only), the camera watches the door. An EMP thrown under the camera stops the camera alone ("No power" on its frame); one mid-room puts the lamp out and stops the turret and the access point (the camera stands right at its 6 m edge). A jammer anywhere in the room: the camera blinks amber, "Jammed". Everything comes back after 20 s.
- [ ] Warehouse: a frag on the security room's gun table by the shotgun shells, a frag on the dock's metal crate by roller door 2, gas in the locker room's north open locker, EMP on the basement store shelf by the lockpicks, the jammer on the manager's desk between the datapads. Each is easy to see and to pick up. Does each spot suggest a use nearby (the jammer for AP-YARD's cameras, the EMP for the vault turret, the gas for the break room)?

## UI plumbing refactor ([ADR 0133](../decisions/0133-ui-plumbing-focus-notices-screens.md))

- [ ] Network lab: plug the deck in, open a computer's remote desktop, press Esc (back to the map), then Esc again: the HUD comes back and you can move and look at once; the mouse is captured again. Repeat closing the deck with the ✕ while the desktop is open.
- [ ] Lockpick a door, open the debug panel (`) over it: the mouse is free; close the panel: the pick moves with the mouse again; leave with E: you can walk at once.
- [ ] Notices still show above the belt: "No room in inventory", "Too heavy", "Energy depleted" (F-key with no energy), a deck notice after lowering the deck ("Wi-Fi crack stopped").
- [ ] The shooting range tuning desk still opens its panel (E) and it closes when you walk away.
