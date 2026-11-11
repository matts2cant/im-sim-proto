# Decision records

One ADR per design decision. Add a new ADR for any new design decision (next number, same format: Title, Status, Date, Context, Decision, Alternatives considered, Consequences).

| ADR | Title | Status |
|---|---|---|
| [0001](0001-engine-godot.md) | Engine: Godot 4 | Accepted |
| [0002](0002-language-gdscript.md) | Language: typed GDScript | Accepted |
| [0003](0003-systemic-framework.md) | Systemic framework: own Act/React stimulus framework | Accepted |
| [0004](0004-perspective-first-person.md) | Perspective: first person | Accepted |
| [0005](0005-level-gallery-and-mission.md) | Level structure: test gallery plus mission area | Accepted |
| [0006](0006-pillars.md) | Pillars for v0 | Accepted |
| [0007](0007-combat-weapons.md) | Combat: one lethal, one non-lethal weapon | Accepted |
| [0008](0008-progression-none.md) | Progression: none in v0 | Accepted |
| [0009](0009-debug-tooling.md) | Debug tooling from day one | Accepted |
| [0010](0010-fiction-graybox.md) | Fiction: abstract graybox | Accepted |
| [0011](0011-testing-strategy.md) | Testing: three layers with GdUnit4 | Accepted |
| [0012](0012-guard-awareness.md) | Guard awareness: graded states, communication, alarm | Accepted |
| [0013](0013-light-analytic.md) | Light visibility computed analytically | Accepted |
| [0014](0014-movement-scope.md) | Movement scope: jump, mantle, vents | Accepted |
| [0015](0015-inventory-grid.md) | Inventory: Deus Ex 1 grid | Accepted |
| [0016](0016-bodies.md) | Bodies: carry, discovery, waking by others | Accepted |
| [0017](0017-hacking-placeholder.md) | Hacking: multitools and credentials for now | Superseded by [0074](0074-network-hacking.md) |
| [0018](0018-damage-body-parts.md) | Damage: Deus Ex 1 body parts and damage types | Accepted |
| [0019](0019-version-control.md) | Version control: local git, branch per milestone | Accepted |
| [0020](0020-skills-augmentations.md) | Skills and augmentations list for v0 | Accepted (Electronics replaced by Computer, 0076) |
| [0021](0021-mission-design.md) | Mission area design | Accepted |
| [0022](0022-guard-feedback.md) | Guard feedback: MGS-style icons and text barks | Accepted |
| [0023](0023-aiming.md) | Aiming: softened Deus Ex 1 reticle | Accepted |
| [0024](0024-baton-knockout.md) | Baton knockout rules | Accepted |
| [0025](0025-saving.md) | Saving: saveable contract from M0, F5/F9 in M6 | Accepted (F5/F9 replaced by the game menu, 0064) |
| [0026](0026-audio.md) | Audio: starter pack plus Kenney CC0, placeholders, no auto-downloads | Accepted |
| [0027](0027-sound-propagation.md) | Sound propagation by navmesh path distance | Accepted |
| [0028](0028-input-physical-keys.md) | Input: physical-key bindings | Accepted |
| [0029](0029-docs-english-no-difficulty.md) | Docs in English; no difficulty settings | Accepted |
| [0030](0030-code-conventions.md) | Code conventions | Accepted |
| [0031](0031-agent-workflow.md) | Agent workflow: chief engineer and sub-agents | Accepted |
| [0032](0032-noise-loudness-audible-metres.md) | Noise loudness unit: audible distance in metres | Accepted |
| [0033](0033-floor-surface-metadata.md) | Floor surface via collider metadata | Accepted |
| [0034](0034-ramps-not-stair-stepping.md) | Ramps instead of automatic stair stepping | Superseded by [0058](0058-step-climbing.md) |
| [0035](0035-mantle-rules.md) | Mantle rules | Accepted |
| [0036](0036-player-gravity-scale.md) | Player gravity scale 2.0 | Accepted |
| [0037](0037-graybox-kit.md) | Graybox kit of parametric parts and grid materials | Accepted |
| [0038](0038-linear-falloff-noise-metres.md) | Unified linear falloff, noise intensity = audible metres | Accepted |
| [0039](0039-path-propagation-sound-attenuators.md) | Path propagation with SoundAttenuator areas | Accepted |
| [0040](0040-override-modifier-conflict-rule.md) | Override modifier conflict rule | Accepted |
| [0041](0041-runtime-navmesh-bake.md) | Runtime navmesh bake on level load | Accepted |
| [0042](0042-kit-part-conventions.md) | Kit part conventions | Accepted |
| [0043](0043-room-connections-share-a-wall.md) | Room connections share one overlapped wall | Accepted |
| [0044](0044-fire-scope-v0.md) | Fire scope in v0 | Accepted |
| [0045](0045-collision-layers.md) | Collision layers | Accepted |
| [0046](0046-heat-accumulation-fire-model.md) | Heat accumulation fire model, fresh chain per pulse with cause_id | Accepted |
| [0047](0047-hitboxes-layer-5-part-aware-ray.md) | Hitboxes on layer 5 and part-aware RAY delivery | Accepted |
| [0048](0048-aim-model.md) | Aim model | Accepted |
| [0049](0049-knockout-rules-awareness.md) | Knockout rules and Awareness interface | Accepted |
| [0050](0050-inventory-model-and-belt-references.md) | Inventory model and belt references | Accepted |
| [0051](0051-single-interactor-hud-prompts.md) | Single Interactor and HUD prompts | Accepted |
| [0052](0052-inventory-pauses-the-game.md) | Inventory pauses the game | Superseded by 0110 |
| [0053](0053-ghosted-upright-carry-safe-release.md) | Ghosted, upright carry with safe release | Accepted |
| [0054](0054-player-and-physics-props.md) | Player and physics props: no solver contact, scripted push and weight | Accepted |
| [0055](0055-wake-props-when-support-goes.md) | Wake props when their support goes | Accepted |
| [0056](0056-generic-character-components.md) | Generic character components: movement noise, falls, impacts, knockback, state tags | Accepted |
| [0057](0057-forces-item-use-and-heat-as-generic-systems.md) | Forces, item use and heat as generic systems | Accepted |
| [0058](0058-step-climbing.md) | Step climbing as a generic character component | Accepted |
| [0059](0059-belt-selects-lmb-uses.md) | Belt selects, LMB uses; mouse wheel and H | Accepted |
| [0060](0060-datapads-read-in-place-personal-log.md) | Datapads are read in place into a personal log | Accepted, amended by 0110 |
| [0061](0061-abilities-model.md) | Abilities: skills, energy and augmentations as attribute modifiers | Accepted (Electronics replaced by Computer, 0076) |
| [0063](0063-quicksave-quickload.md) | Quicksave and quickload: one JSON slot, level snapshot with removed and spawned nodes | Accepted (keys amended by 0064) |
| [0064](0064-game-menu.md) | Esc game menu: save, load and quit; F5 becomes Combat Strength | Accepted |
| [0065](0065-light-level-model.md) | Light level model: Godot's attenuation, three body points, saturating sum | Accepted |
| [0066](0066-power-circuits-shootable-lights.md) | Power circuits and shootable lights | Accepted |
| [0067](0067-vision-and-detection.md) | Vision and detection: cones, light, a suspicion meter | Accepted |
| [0068](0068-awareness-states-and-guard-behaviour.md) | Awareness states and guard behaviour | Accepted |
| [0069](0069-hostile-and-ally-tags.md) | Who perceives whom: hostile and ally tags | Accepted |
| [0070](0070-guard-combat-and-loadouts.md) | Guard combat: one weapon path for every actor, loadouts as data; static characters block props | Accepted |
| [0071](0071-bodies-discovery-waking-carrying.md) | Bodies: discovery, waking and carrying downed characters | Accepted |
| [0072](0072-shouts-radio-level-alarm.md) | Shouts, radio and the level alarm | Accepted (level alarm superseded by 0075) |
| [0073](0073-realistic-lockpicking.md) | Realistic pin-tumbler lockpicking minigame | Accepted |
| [0074](0074-network-hacking.md) | Network hacking: a realistic network, a deck and tracers | Accepted |
| [0075](0075-alarms-as-network-devices.md) | Alarms as network devices | Accepted, amended by 0100 |
| [0076](0076-computer-skill-multitool-removed.md) | Computer skill replaces Electronics; the multitool is removed | Accepted |
| [0077](0077-devices-cables-and-remote-commands.md) | Devices, cables and remote commands (M8 alarm devices) | Accepted |
| [0078](0078-doors-locks-and-door-navigation.md) | Doors, locks as components, and doors on the navmesh | Accepted, amended by 0098 |
| [0079](0079-security-cameras-and-turret.md) | Security cameras and the turret: device vision, a detection meter, target presets as data | Accepted |
| [0080](0080-credentials-terminal.md) | The credentials terminal (M8 placeholder): login from known credentials, commands from receptrons | Superseded by 0114 (computers replace the terminal) |
| [0082](0082-walkable-downed-bodies.md) | Downed bodies do not block characters (layer 8 `downed`) | Accepted |
| [0083](0083-security-terminal-redesign.md) | Security terminal redesign: Camera and Network tabs, device status from components, Esc only | Superseded by 0114 (the Camera tab became the Security app; the map moves to the deck) |
| [0084](0084-parallel-fixed-fps-test-runner.md) | Test runner: parallel shards, simulated time (`--fixed-fps`), output to files, import only when needed | Accepted (amends 0011) |
| [0085](0085-weapons-and-attachments.md) | Shotgun, sniper rifle, assault rifle and weapon attachments (pellets, full-auto, scope, silencer as modifiers) | Accepted |
| [0086](0086-warehouse-mission.md) | Warehouse mission: separate level, fixed kit, objectives, badges, reinforcements, weapon drops | Accepted |
| [0087](0087-mission-systems.md) | Mission systems: a Mission node with data, objectives and tallies from events, death attribution by cause chain, level exits | Accepted |
| [0088](0088-weapon-drops-and-bursts.md) | Weapon drops from a holder's own loadout; AI bursts with automatic weapons; the rifle guard | Accepted |
| [0089](0089-warehouse-layout.md) | Warehouse layout: generated area scenes, see-through palisade Fence and Stairs kit parts, floodlights, breaker B in the basement | Accepted |
| [0090](0090-door-size-free-side-locks-warehouse-security.md) | Door size as data (doorway, travel), a free side for any lock, the warehouse security population as a generated scene | Accepted, amended by 0098 |
| [0091](0091-warehouse-population.md) | Warehouse population: generated from the layout markers, crossing gaps measured by simulation, breach panel and gas cylinders, duct B hatch lip | Accepted |
| [0092](0092-warehouse-polish.md) | Warehouse polish: tighter patrols, two security switches, barred gates, side-wall door panels, free-side navigation links, door signs, label boxes in the network graph | Accepted, amended by 0098 |
| [0093](0093-warehouse-route-tests.md) | Warehouse route scenario tests (chained segments, condition waits), the annex's high window and the cache shed, one shared sensor scan per frame, deferred level changes | Route tests superseded by 0106 |
| [0094](0094-noise-reach-on-partial-paths.md) | Noise reach on partial navmesh paths (gaps only through open air, else searched backwards, else not heard); investigation arrival needs height too | Accepted |
| [0095](0095-darkness-and-flashlights.md) | Darkness and flashlights: a light floor for moving targets in the dark (a step at 0.5 m/s), flashlights as carried spot lights lit by awareness state or a patrol flag | Accepted, amended by 0105 |
| [0096](0096-laser-tripwires.md) | Laser tripwires: a beam device on the security network (shape query, carried ghosts, ignored tags unless downed), re-arm on a clear beam, low / high / pair heights, the security wing's laser hall | Accepted, amended by 0100 |
| [0097](0097-warehouse-roof-security.md) | Warehouse roof security: high beams at the two roof arrivals, a camera over duct B's lit forecourt (with a sweep window), on the yard network (breaker A, the booth switch) | Accepted |
| [0098](0098-door-lock-hardware-and-keycard-relock.md) | Door lock hardware: a handle and keyhole on the leaf, keypad / card reader / status boxes on the wall beside the frame (placed from the door's settings), E on what you look at; a keycard grants an opening and the door is locked again once closed | Accepted |
| [0099](0099-network-map-layout-pan-zoom.md) | Network map: devices grouped by hub (3+ cables) in combs, routes that never cross, lanes between groups; pan, zoom around the cursor and fit (button, F); amended: nodes grey when unreachable, red when disabled (`device_disabled()`) | Accepted |
| [0100](0100-laser-arrays-alarm-time-downed-targets.md) | Laser arrays (one device feeding 1 to 4 authored beams, one emitter body, one incident per crossing), the alarm rings 45 s, a downed hostile is no sighting (the turret beep loop) | Accepted |
| [0101](0101-rifles-and-sniper-skills.md) | Rifles and Sniper skills (`rifle_*`, `sniper_*` class attributes; pellet cone and sway scale with the class), ammo boxes in their weapon's colour, one screen-angle shift that lowers the player's view models | Accepted |
| [0102](0102-guard-speeds.md) | Guard speeds: patrol 1.5 m/s, run 4.0 m/s (a sprinting player outruns a running guard), sprint stance from 3.0 m/s; the warehouse west catwalk patrol waits 1 s at its west end | Accepted |
| [0103](0103-character-models-and-animation.md) | Character models and animation: Kenney blocky characters (guards `character-j`, dummies `character-d`, scale 0.66), one `CharacterAnimator` driven by speed, tags and the held weapon's grip (`WeaponData.grip`), upper-body hold and shot layers over walking legs, the weapon in the hand, hitboxes moved to the model, a static shadow proxy | Accepted, amended by 0105 |
| [0104](0104-devices-breakable-by-the-baton.md) | Security devices are electronics (blunt x4: the baton breaks a wall device in 1-2 hits), the turret armoured (blunt x2: 6 hits); door wall boxes stay part of the door; the swing is unchanged (reach 1.8 m from the eye) | Accepted |
| [0105](0105-character-model-playtest-fixes.md) | Character model playtest fixes: shaded external materials for the unlit GLBs, every weapon one-handed with a per-weapon hold turn (`WeaponData.hold_rotation_deg`, `hold_offset`; the baton upright), the flashlight a model in the off hand while lit (beam from its lens along the eye's direction) and at the belt while off, training dummies still (`static` idle clip), the head hit zone a 0.528 m box | Accepted |
| [0106](0106-drop-scripted-warehouse-route-tests.md) | Drop scripted warehouse route tests: passage tests, noise spot checks and systems in isolation instead; full routes are played by hand | Accepted |
| [0107](0107-lockpicking-minigame.md) | Lockpicking minigame: the prototype's pin-tumbler model (`PinTumbler`, tuning in a `.tres`), a screen on the picker in real time, the Lockpicking skill as attributes replacing `lockpick_time_mult`, an assist ladder (gauge, captions, pins view), pin changes that reset the lift, practice locks that re-lay their pins | Accepted, amended by 0109 |
| [0108](0108-lockpick-sounds.md) | Lockpicking sounds: one-shots baked to WAV by `tools/sfx_gen/lockpick_sfx.py`, a port of the prototype's WebAudio synth (three noise variants per noisy cue, a new `relock` cue); the scrape and strain synthesised live into an `AudioStreamGenerator` with the same formulas; non-positional on Master; cues and tuning in `sounds.tres` | Accepted |
| [0109](0109-lockpicking-side-view-and-mouse-pick.md) | Lockpicking rework (amends 0107): the final prototype's side cutaway with a rigid hook pick (brass, or clear for the Master assist and practice locks), wheel tension, the mouse moving the pick's aim with a bottom band for sliding between pins, sweet spot 40-3t .. 55+3t %, a set dwell, the aim bias after a set, overset only from the sweet spot (set and loose pins +0.15), physical raking by strokes on rakeable locks (at most 5 standard pins) | Accepted |
| [0110](0110-tab-interface.md) | The Tab interface: one host (`TabInterface`) loading `TabPage` scenes as data (Inventory, Health, Augmentations, Skills, Journal), over the running world with the player's input off; Tab / I / L / Esc / 1-5 / Q-E rules, one screen at a time, closes on death or knockout; only the game menu, briefing and summary pause (the keypad and datapad reading no longer do); the Inventory tab's data-driven details (`ItemDetails`), the Journal (objectives, codes with `Readable.code_labels`, notes) | Accepted |
| [0111](0111-character-tabs-and-per-part-medkit.md) | Character tabs of the Tab interface (Health, Augmentations, Skills) bound to any character's components; a medkit used on one part touches that part's hitbox so `HealEffect` heals only it (same amount, refusal and receptron); skill tier tables built from a Display group on `SkillEffect` | Accepted |
| [0112](0112-hacking-reconciled-with-the-built-game.md) | Hacking reconciled with the built game (amends 0074): overlays like the Tab interface; computers (Mail, Files, Security) replace the security terminal, the Security app lists only the devices the computer controls; the network map moves to the deck; subnets behind a gateway hidden until it is hacked, chained; remote desktops from the deck; the Journal as the one list; Computer skill assists; trace bars only in the screens; M12 split into M12a and M12b; NPC logins, the security operator and the Sniffer move to M16 | Accepted |
| [0114](0114-computers-halcyon-os.md) | Computers (Halcyon OS: Mail, Files, Security) replace the security terminal: `Computer`, `DeviceAccounts` logins with Fill in, Mail and Files as data read into the Journal (implicit clues as notes), the Security app grouped by kind (tags, icons as data) over the devices a computer controls, remote desktops inside the deck; the old map's row source kept as legacy for the deck | Accepted |
| [0113](0113-network-layer-tracers-and-the-deck.md) | Network layer and the deck (M12a): subnets and gateways as gates in the reach graph (a user passes a gateway once it has an account there: discovery is reach), trust lists, `DeviceAccounts` (the computers' contract), tracers (`TraceModel`, per user, lockouts per address), the deck item with a tethered `DeckSession` (wall jack, maintenance port, computer), `IcebreakerTool`, `DeckScreen` (Map moved to `ui/deck/`, Icebreaker, assists, trace bars), Computer skill attributes `deck_*`, `DeviceSwitch` for panic buttons and radio base stations | Accepted |
| [0115](0115-m12b-intrusion-and-m12c-consequences.md) | M12b intrusion: exploits (Journal section, versions on the Map, burned per subnet when detected), Firewall rules deciding which devices reach which, wireless (access points, Wi-Fi keys cracked by aiming the deck with line of sight, range by skill); logs recorded, the Logs tool in M16. M12c consequences: status LEDs, plates, the deck's AR cable view, feedback; mail needs a route to its server, loss-of-signal alarms (3 in 10 s), fail-secure vaults, a "Clean hands" badge (nothing broken) | Accepted |
| [0116](0116-exploits-firewall-tool-and-device-logs.md) | Exploits, the Firewall tool and device logs as built (M12b): software as data on any device, `Exploit` resources taught by mails, files and datapads into the Journal's Exploits section, `ExploitTool` runs (4 s, +10 % trace spread over the run) granting access without an account, burned on the subnet's product when a tracer saw the run; a user's traffic judged only by rules from "you" (else access to the router), the Firewall tool editing rules through `Router`; `DeviceLog` recording logins, failed logins, exploit runs and remote actions with the source address | Accepted |
| [0117](0117-wireless-access-points-and-the-decks-wifi.md) | Wireless as built (M12b): `AccessPoint` (range, Wi-Fi key, client address), `Device.wireless` radio links in the reach graph (never network gear, within the access point's range), the deck's Wi-Fi range by Computer skill (`deck_wireless_range`), aiming as a ranged tool target, `WirelessTool` (the key cracked while in range and in sight, pausing otherwise, progress on the deck), joining the subnet as a `WIRELESS` source, the Wi-Fi key screen and dashed light-blue links on the Map | Accepted |
| [0120](0120-weapon-feel.md) | Weapon feel (M13a, M13b): accuracy blending character skill and the player's aim (Master closest to Counter-Strike), recoil patterns on automatic weapons with the camera climbing and returning, skill scaling pattern size, noise and recovery, the submachine gun, the shooting range with live tuning, a settings menu in the Esc menu; then hit markers, impacts, tracers, aim punch and flinch, guards obeying recoil, weapon motion and per-weapon sounds | Accepted |
| [0121](0121-exploits-as-items-and-map-fixes.md) | M12b playtest: exploits become one-use inventory items by device kind (camera, turret, door, alarm, computer, router), used instantly from a device's menu on the Map for permanent admin access; the Exploits tool, the Journal section, software versions and burning removed; icons per device kind on the Map; the plugged subnet appears at once, far subnets show a visible scan | Accepted |
