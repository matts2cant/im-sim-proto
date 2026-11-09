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
| [0052](0052-inventory-pauses-the-game.md) | Inventory pauses the game | Accepted |
| [0053](0053-ghosted-upright-carry-safe-release.md) | Ghosted, upright carry with safe release | Accepted |
| [0054](0054-player-and-physics-props.md) | Player and physics props: no solver contact, scripted push and weight | Accepted |
| [0055](0055-wake-props-when-support-goes.md) | Wake props when their support goes | Accepted |
| [0056](0056-generic-character-components.md) | Generic character components: movement noise, falls, impacts, knockback, state tags | Accepted |
| [0057](0057-forces-item-use-and-heat-as-generic-systems.md) | Forces, item use and heat as generic systems | Accepted |
| [0058](0058-step-climbing.md) | Step climbing as a generic character component | Accepted |
| [0059](0059-belt-selects-lmb-uses.md) | Belt selects, LMB uses; mouse wheel and H | Accepted |
| [0060](0060-datapads-read-in-place-personal-log.md) | Datapads are read in place into a personal log | Accepted |
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
| [0075](0075-alarms-as-network-devices.md) | Alarms as network devices | Accepted |
| [0076](0076-computer-skill-multitool-removed.md) | Computer skill replaces Electronics; the multitool is removed | Accepted |
| [0077](0077-devices-cables-and-remote-commands.md) | Devices, cables and remote commands (M8 alarm devices) | Accepted |
| [0078](0078-doors-locks-and-door-navigation.md) | Doors, locks as components, and doors on the navmesh | Accepted |
| [0079](0079-security-cameras-and-turret.md) | Security cameras and the turret: device vision, a detection meter, target presets as data | Accepted |
| [0080](0080-credentials-terminal.md) | The credentials terminal (M8 placeholder): login from known credentials, commands from receptrons | Accepted (screen amended by 0083) |
| [0082](0082-walkable-downed-bodies.md) | Downed bodies do not block characters (layer 8 `downed`) | Accepted |
| [0083](0083-security-terminal-redesign.md) | Security terminal redesign: Camera and Network tabs, device status from components, Esc only | Accepted |
| [0084](0084-parallel-fixed-fps-test-runner.md) | Test runner: parallel shards, simulated time (`--fixed-fps`), output to files, import only when needed | Accepted (amends 0011) |
| [0085](0085-weapons-and-attachments.md) | Shotgun, sniper rifle, assault rifle and weapon attachments (pellets, full-auto, scope, silencer as modifiers) | Accepted |
| [0086](0086-warehouse-mission.md) | Warehouse mission: separate level, fixed kit, objectives, badges, reinforcements, weapon drops | Accepted |
| [0087](0087-mission-systems.md) | Mission systems: a Mission node with data, objectives and tallies from events, death attribution by cause chain, level exits | Accepted |
| [0088](0088-weapon-drops-and-bursts.md) | Weapon drops from a holder's own loadout; AI bursts with automatic weapons; the rifle guard | Accepted |
| [0089](0089-warehouse-layout.md) | Warehouse layout: generated area scenes, see-through palisade Fence and Stairs kit parts, floodlights, breaker B in the basement | Accepted |
