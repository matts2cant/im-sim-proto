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
- [ ] Weapons rack (ADR 0085, west of the door): from the door it reads as a table of guns against the wall beside the door, the sniper rifle and shotgun at the back, the assault rifle, three ammo boxes and the silencer crate in front; its four signs read from the booth and none runs into the corner or the doorway. E takes each item (prompt names the one you look at); the guns go on the belt.
- [ ] Shotgun feel: one shot on the 5 m dummy's torso drops it; at 10 m about half the pellets hit; the 20 m dummy takes several shots. 0.9 s between shots feels like a pump; the flash and bang feel heavier than the pistol; R reloads all six in 2.4 s.
- [ ] Sniper rifle from the hip: the reticle ring is huge (6 degrees) and shots wander. RMB: the view zooms in about 0.15 s to a black scope with a thin crosshair and a small red ring; the gun disappears. Hold still: the ring tightens in about 1.4 s; mouse look moves the crosshair about as far per mouse movement as at the hip (not twitchy). One shot at the 40 m dummy's torso kills it. RMB again zooms out. R, a belt key, H or being knocked out also zoom out; RMB while reloading does nothing. Nothing pauses.
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
- [ ] H holsters whatever is in hand: the pistol view goes, the belt highlight and the name above the belt disappear, the bottom-right name clears; H with empty hands does nothing. The wheel and H do nothing in the inventory screen, while reading or when dead.
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
- [ ] Datapad pedestal (ADR 0060): looking at each datapad the prompt reads "E: read Inventory bay" / "E: read Storage access", never the neighbour's. E opens the text (game paused), E or Esc closes it without also re-reading or picking anything up; "Added to log: Storage access" shows for about 2 s after closing. The datapad stays on the pedestal, the inventory is unchanged. Reading it again shows the text but no new "Added to log".
- [ ] Datapads are props: a blast or walking into the pedestal pushes them like other small objects; E never carries or picks them up.
- [ ] L opens the personal log (paused, mouse free); L or Esc closes it. Entries are listed newest first, the newest selected; clicking an entry shows its text on the right; long text scrolls with the mouse wheel. Under "Codes": "Storage Door: 2817  (Storage access)". L does nothing while the inventory or the text overlay is open, or when dead; I does nothing while the log is open.
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
- [ ] Ammo boxes (ADR 0101): on the shooting range rack, in the hub and in the inventory screen, shells are yellow, rifle rounds green, sniper rounds purple and pistol ammo red, the box in the world the same colour as its icon.
- [ ] Held weapons (ADR 0101): every weapon (pistol, silenced pistol, shotgun, sniper rifle with and without silencer, assault rifle, baton) sits lower in the bottom-right corner than before but stays readable; firing kicks it back and it returns; the baton's chop still crosses the view; the scope still hides the model and it reappears when you scope out or reload.
- [ ] Stats tab: Low-Tech Advanced: a frontal baton knockout takes 2 hits (Combat Strength off), swings come faster at Master. Medicine Master: a medkit heals 90 (watch several parts recover).
- [ ] Stats tab: unchecking "installed" switches an augmentation off and its F-key does nothing ("on" greyed); the energy slider and "Refill energy" change the HUD bar at once; F-key toggles show up in the tab while it is open.
- [ ] Esc game menu ([ADR 0064](../decisions/0064-game-menu.md)): Esc pauses the game, frees the mouse and shows Resume / Save / Load / Quit game in the log screen's style, Resume highlighted; Up/Down move, Enter presses; Esc or Resume closes it and the mouse is captured again (looking works at once, Space jumps, it does not re-press a button).
- [ ] With the inventory, log screen or reading overlay open, Esc closes only that screen; the next Esc opens the menu. I and L do nothing while the menu is open. With the debug panel open (`), Esc does not open the menu.
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

- [ ] Entry hall: the five lock-row doors read at a glance from the hub door, each with its sign; the west wall left of the table is bare (practice locks come in M10); the hub doorway shows no seam or flicker from either side.
- [ ] Table: E on the "Closet code" datapad shows it and adds it to the log (L); the two lockpicks go into the inventory.
- [ ] D1 keypad: "E: enter code" opens the entry screen (game paused) showing "Note: 5309, from 'Closet code'"; a wrong code beeps and says "Wrong code"; 5309 + Enter opens the door; Esc leaves halfway without opening the game menu. The keycard lies on the shelf inside.
- [ ] D2 pin lock: "Locked: lockpick"; LMB with a lockpick drawn starts the lockpicking minigame (see "M10 Lockpicking minigame"); once picked the door opens and the lockpick count does not change. The "Booth login" datapad is on the shelf.
- [ ] D3 keycard: "Locked: keycard" without the card, "E: open (keycard)" with it; the booth has the terminal, breaker B and the alarm controller with the radio base station, and you can turn round in it. From the booth door the two east-wall devices read apart: the dark red box under "Alarm controller", the dark blue box with the antenna under "Radio base station".
- [ ] D4 electronic: breaker A (hall north wall, "E: switch off D4 power") clunks and the door's control light goes dark; the door stays shut until E opens it; switching A back on locks nothing that is open.
- [ ] D5 breakable: pistol rounds and baton hits do nothing; shoot the barrel from the hub door: the blast blows the panel away for good, D4 next door stays shut, the hall lamps survive.
- [ ] Terminal: "E: use security terminal" shows "Known: rvoss from 'Booth login'" after reading the D2 datapad; Fill in, Log in. A wrong password says "Wrong password." with a low beep. The game keeps running behind the screen; Esc leaves every time, even while typing; E never leaves; walking away closes the screen; the hint says only "Esc: leave".
- [ ] Terminal Camera tab: Camera and Turret listed with their status; the Camera's live view follows its sweep (smooth, no stutter, the frame rate holds); Pan left turns the view; Disable shows "No signal"; the Turret's view looks along its head; switching to the Network tab and back resumes the view.
- [ ] Debug panel Overlays "Network" in the security wing: every device labelled (name, status) through walls, cables from the hall switch to each device in green; breaker B off turns every switch cable red and the switch reads "offline (unpowered)"; unticked, nothing is left in the world.
- [ ] Terminal Network tab: every device hangs on the switch's bus (terminal outlined in blue; ADR 0099 replaced the floor plan); cables do not hide each other; clicking a node opens its menu beside it (status and commands), clicking the background closes it; Test on a siren turns its status amber ("ringing") within a fraction of a second; opening the vault door shows "open · locked".
- [ ] Terminal Network map (M9h, [ADR 0099](../decisions/0099-network-map-layout-pan-zoom.md)): at the warehouse security console it opens fitted, both switches' groups readable without zooming (names and status lines), no cable crossing another; dragging (left or middle button, also starting on a node) moves the map smoothly and never loses it off the panel; the wheel zooms around the cursor (the point under it stays put), text stays sharp zoomed in; F and the Fit button show everything again; a click (no drag) on a node opens its menu beside it, never off the panel, and it follows the node while you drag; a drag never opens a menu; Esc still leaves at once, the game keeps running. Same in the gallery's security wing booth.
- [ ] Network map colours (M9h, [ADR 0099 amendment](../decisions/0099-network-map-layout-pan-zoom.md#amendment-node-colours-m9h); review shots: `warehouse_shots.tscn -- shots=terminal_network_states,terminal_network_states_menu`, `wing_shots.tscn -- shot=terminal_states`): at the warehouse console, Disable a camera: its node turns red (outline, red-tinted box, "disabled") within a fraction of a second, Enable turns it green again; cut breaker A: the whole yard group goes grey with dashed cables, a disabled yard device too; break a device: grey. Grey, red and green read apart at a glance, also in greyscale (a colour-blind filter or a desaturated screenshot); a selected node's white outline shows on all three. Same for the turret, the laser arrays and a disarmed alarm controller in the gallery's security wing booth; sirens, doors and switches are never red.
- [ ] Breaker B / switch: breaker B off (booth) or two pistol rounds (or two baton swings) in the switch (hall north wall): within a second every device on the terminal's Network tab is grey "offline" with dashed cables and no commands (never "broken"), the Camera tab shows "No signal", and the vault door's controls go dark; the camera still turns red on you but no siren rings; the panic button does nothing. A device shot to pieces with the switch on also just reads "offline".
- [ ] Camera corridor: from the corridor mouth the camera over the vault door sweeps ±40° with a pause at each end (green lamp). Walk in lit: it stops on you, amber, then red with a beep in about 1.3 s; both sirens sound and the HUD shows "ALARM". Crouched in either alcove you are in the dark (light gauge empty) and it never sees you, even when it points at you; time the sweep to move alcove to alcove. Cloaked (F1) it still sees you in the light. One pistol round breaks it; a shot siren loses its horn and stays silent.
- [ ] Guard: the baton guard by the vault door is lit and faces the door; crouch-walk up behind it from the second alcove and knock it out. Press the hall panic button instead: the sirens ring and the guard leaves its post searching around it (and runs to where the camera saw you when the camera raised the alarm).
- [ ] Vault: from the terminal, Disable the turret (its laser and head go idle), then Open the vault door: it slides open while still locked and locks again when closed. Enabled instead, the turret behind the opened door turns to you in the corridor and fires after its beep; Target guards makes it shoot the guard and ignore you; standing in its open field you are dead in about 4 s; three pistol rounds break it. With breaker B off the vault never opens. The loot table holds 5 biocells, 2 medkits and 40 rounds.
- [ ] Rewards: 2 biocells behind D4, a medkit behind D5.
- [ ] Baton on devices ([ADR 0104](../decisions/0104-devices-breakable-by-the-baton.md), [security.md](../game/security.md#breaking-devices)): with the baton (2), the hall switch breaks in two swings and the network goes offline as with a pistol; the panic button, a siren (3 m up over the hall: step about half a metre off the wall and look up), the corridor camera and a laser array emitter or receiver each break in one swing; the alarm controller and the radio base station in the booth in two. Each swing is quiet (no guard in the next room turns); the device goes dark, keeps its husk and reads "offline" on the terminal. The turret, disabled from the terminal or clubbed from behind, takes six swings; walking up to it from the front while it is on is deadly.
- [ ] Baton reach: the hall ceiling lamps (3.6 m) cannot be hit standing; a jump with a swing near the top of it breaks one. A keypad or card reader box beside a locked door takes swings and shots without any effect: the door stays locked and shut.
- [ ] Quicksave and quickload in the wing: open and broken doors, picked items, breaker positions, the terminal login and a disabled turret are restored.
- [ ] AI arena (room 6, alarm devices on their own): its panic button rings both sirens and every guard runs to the button (base station dispatch); shooting its switch silences the sirens within about 2.5 s.
- [ ] Debug panel "Raise alarm" / "Clear alarm" ring and stop the sirens in rooms 5 and 6; the HUD "ALARM" goes within about 1.5 s of the last siren pulse you can hear (about 34 m of walking distance).
- [ ] Doors anywhere: a door does not close on you standing in the doorway; no gap or flicker where the closed panel meets the jambs and the lintel or where the open panel hides in the wall; guards walk through unlocked doors and never through locked ones they have no access for.
- [ ] Laser hall ([ADR 0096](../decisions/0096-laser-tripwires.md), [ADR 0100](../decisions/0100-laser-arrays-alarm-time-downed-targets.md), behind D1): the beams read as thin red lines from the doorway, standing and crouched. Walking into the low beam (0.4 m) beeps and rings both sirens; a walking jump from about a step and a half before it clears it without a beep. Crouching under the high beam (1.3 m) never trips it; walking under it upright does. Standing in a beam gives one beep, not a beep per second. The two-beam array stops both a jump and a crouch; its two heads read as one emitter (a mast joins them), and walking through both beams gives one beep, not two.
- [ ] Throwing the box through a beam rings the alarm; the vault guard comes looking (base station). A knocked-out guard dropped into a beam trips it; an awake guard walking through does not.
- [ ] From the booth terminal's Network tab the three laser arrays (Laser Low, Laser High, Laser Pair: one node each) read enabled / clear (tripped right after a break); Disable turns all of an array's beams off (no line, no trip) and Enable brings them back. Breaker B off: every array goes dark and reads offline. One pistol round at any of an array's boxes (the pair's mast too) breaks it for good (all its beams go, the terminal says offline). Quicksave and load keep a disabled or broken array.
- [ ] Turret on guards (M9h, [ADR 0100](../decisions/0100-laser-arrays-alarm-time-downed-targets.md)): log in at the booth terminal, Target guards, open the vault: the turret kills the post guard, then turns back to rest; its beep stops and nothing loops (the sirens ring for 45 s, then stop). Knock a guard out in a turret's view while it targets guards: it never fires at the body.
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
- [ ] Warehouse doors and security (M9 wave 2, [mission-warehouse.md](../levels/mission-warehouse.md#doors-locks-and-keys-m9-wave-2), [ADR 0090](../decisions/0090-door-size-free-side-locks-warehouse-security.md); review shots: `warehouse_shots.tscn` with `-- shots=door_front_gate_road,door_roller_yard,terminal_network,view_camera_hall,... out=res://reports/screenshots/m9c`, names in `tests/levels/mission/fixtures/warehouse_security_shots.gd`):
  - [ ] The front gate slides along the outside of the fence in about 3 s and reads as a gate, not a wall; the roller doors rise into the wall in about 2.5 s and are clearly loud; nothing clips through posts or walls while they move.
  - [ ] Back gate: from the quay it says "Locked: lockpick" and is picked with the lockpicking minigame (4 pins); from inside it just opens ("E: open") and locks again once closed. Same for the tunnel gate (picked from the ditch), the annex roof door and the fire escape door (opened from inside).
  - [ ] Side door: the code note in the dumpster gives 2390 and the keypad shows the reminder. Manager office: 4471 from the night shift notes in the break room; from inside (after duct B) the door just opens.
  - [ ] Keycards: the security keycard on the locker room bench opens the security room; the vault keycard on the security room desk opens the vault. The console login is on the manager's desk next to the manifest.
  - [ ] Security console (Network tab): every device is listed with readable labels; it disables the turret, opens the vault, locks or opens the front gate. Cutting breaker B or shooting the switch in the basement store turns everything offline.
  - [ ] Cameras: the gate, yard, hall and office cameras spot you lit within a couple of seconds and every siren rings; the dark corners (dumpster corner, truck gap, behind the containers) stay unseen. With the switch broken, the cameras still turn red but nothing rings.
  - [ ] Sirens: when the alarm rings, guards in the yard, on the catwalks, in the offices and in the basement react; you can hear a siren from every guard post.
  - [ ] Office PCs (second office, picked door): the sticky note and the shift notes log in; they show only the office network.
- [ ] Warehouse polish (M9e, [mission-warehouse.md](../levels/mission-warehouse.md#design-review-m9e), [ADR 0092](../decisions/0092-warehouse-polish.md); review shots: `warehouse_shots.tscn` with `-- shots=gate_bars_road,back_gate_bars_out,yard_switch,yard_switch_window,panel_office_entrance,panel_bridge_door,panel_fire_escape_door,panel_catwalk_stairs_in,panel_catwalk_stairs_out,terminal_network,upper_corridor,office_front out=res://reports/screenshots/m9e/after`):
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
- [ ] Warehouse roof security (M9g, [mission-warehouse.md](../levels/mission-warehouse.md#roof-security-m9g), [ADR 0097](../decisions/0097-warehouse-roof-security.md); review shots: `warehouse_shots.tscn` with `-- shots=roof_beam_west,roof_beam_west_crouch,roof_beam_east,roof_beam_east_crouch,roof_camera_east,roof_camera_east_crouch,roof_camera_west,roof_camera_west_crouch,roof_west_arrival,view_camera_roof,terminal_network out=res://reports/screenshots/m9g_roof`, without `dark=1`: it cuts breaker A and the beams go off):
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

## M11 Hacking feel ([ADR 0074](../decisions/0074-network-hacking.md), tuning in [hacking.md](../game/hacking.md#tuning))

- [ ] No crack feels like dead waiting: Trained on a Medium password (18 s) and Advanced on a Strong one (25 s). Note any wait that drags.
- [ ] One crack against a default tracer leaves room to spare; two in a row without a pause trip it; a short pause (about 8 s) drains it.
- [ ] A sensitive tracer makes Trained brute force on Medium fail, so finding the password or an exploit feels worth it.
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

## M10 Lockpicking sounds ([ADR 0108](../decisions/0108-lockpick-sounds.md))

Audition scene: run `items/lockpick/audio/fixtures/lockpick_audio_audition.tscn` (F6), keys 1-0 or the buttons play the cues, the sliders drive the voices. Compare with the prototype (`design/prototypes/lockpicking_bench.html`, sound on).
- [ ] Each cue sounds like the prototype's: a crisp set click, a quieter muffled click, a tiny tick, a deep clunk, a low creak, a dull jam, a loud snap, two short blips for the drop, the open's clack and thump. Pressing a noisy cue several times varies it slightly without changing pitch or level.
- [ ] Relock: the creak, then three quick pin settles falling in pitch, at the level of the other cues.
- [ ] Mashing keys quickly: overlapping cues all ring out; none cuts another off.
- [ ] Scraping slider up: a hiss that rises in pitch as Tension goes up, with no clicks or zipper noise while sweeping; back to 0 fades out quickly.
- [ ] Strain slider: silent up to about 0.12, then a buzzing tone that rises in pitch and level towards 1; Stop all (Space) fades everything out at once, without a click.
- [ ] The voices follow the sliders without a noticeable lag.

## M10 Lockpicking minigame ([ADR 0107](../decisions/0107-lockpicking-minigame.md))

In the security wing (D2's pin lock) or any pin lock, with lockpicks; set the Lockpicking tier in the debug panel's Stats tab. Practice locks: until a later wave places them in the security wing's hall, instance `objects/locks/practice_lock/practice_lock.tscn` on a wall (set its tier in its MechanicalLock data). Review shots: `tests/ui/lockpick/fixtures/lockpick_shots.tscn` with `SHOT=untrained|trained|advanced|master|relock|room`.
- [ ] LMB with the pick on the lock: the camera turns smoothly to the lock in about a quarter second, the panel opens over the live view, the player does not move with W / S / A / D and keeps crouching if crouched; guards and the world keep running.
- [ ] Tension: W / S raise and lower it at a comfortable speed, Shift gives fine steps, it stays where left; the wrench flexes and the plug turns a hair with it.
- [ ] Lift: mouse up raises the pick, it stays where left; the tip lags behind on the binding pin and the pick bows with the force; the sensitivity feels right (tuning `lift_per_pixel`).
- [ ] A / D: the pick drops below the pins, then slides across, quickly (about 0.1 s); moving with the pick up never jams the next pin; several presses in a row land on the right pin.
- [ ] Feel of the pins matches the prototype: a crisp click and a hair of plug turn per set; the muffled click above the window; a deep clunk and a bigger turn on a spool, the plug pushing back (creak) while you ease tension and lift; serrated ticks; pins dropping one by one below the drop zone and all at 0 %; a jam on an overset, cleared by releasing tension; the strain rising before a snap at high tension.
- [ ] Assists: Untrained shows no gauge, captions or pins view; Trained adds the gauge (its green band widens with each tier); Advanced adds the captions; Master adds the pins view. A practice lock shows everything at any tier.
- [ ] Leaving: E and Esc leave (Esc never opens the game menu; E never also opens the door), so does getting hit; the progress is lost; holding LMB while leaving does not restart it.
- [ ] A broken pick uses up one lockpick ("SNAP" caption, the count on the belt drops); with none left the panel closes and the HUD says "Out of lockpicks".
- [ ] A picked door: the plug turns open, the panel closes and the door swings open; the pick count is unchanged.
- [ ] Practice lock: once open, about 3 s later the plug turns back, the relock sound plays, the pins drop and settle at new heights, the caption says "new pin layout" and the panel reads "Layout 2"; the new layout picks differently.
- [ ] Master on a Simple lock: holding LMB in the sweet spot rakes it open in about 2 s with clicks; letting go stops.
- [ ] A guard nearby hears a snapped pick (about 5 m) but not the clicks beyond about 1 m.
- [ ] Timing targets (a player who understands the mechanic): Simple about 5 s untrained; Standard about 15 s untrained, 7 s at Master; Secure about 30 s / 15 s; High-security about 60 s / 25 s.
