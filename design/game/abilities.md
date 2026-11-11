# Abilities

Milestone: M6 (Inventory and abilities bay). Model: [ADR 0061](../decisions/0061-abilities-model.md).

## Purpose

A basic ability system without leveling. Values are edited in the debug panel's Stats tab (and, until M18, the Tab interface's Skills page TESTING buttons). Built on modifiers so progression can be added later ([../backlog.md](../backlog.md)).

## Model

- Skills and augmentations are components and data any actor with Attributes (and Tags) can have: `Skills`, `Energy`, `Augmentations` in `actors/common/abilities/`. Nothing checks "is player" or "has skill X": consumers (weapons, carry, movement, noise, healing) read **attributes** with their own tuning as the base (`Attributes.read(entity, attribute, base)`), so with no modifiers everything behaves as before.
- A skill tier change or an augmentation switching on or off replaces that source's modifiers (`skill.<id>`, `aug.<id>`), so skills, augmentations and injuries (`body_parts`) stack.
- What an entity puts out (weapon damage, a medkit's heal) is scaled by an attribute of the source through `Stimulus.scale_attribute`, applied by the StimulusSystem on emit. Medicine scales the healer's outgoing `heal`, so a medic healing someone else uses the medic's skill.
- Tuning: `actors/common/abilities/skill_table.tres` and `actors/common/abilities/augmentations/<id>.tres`.

## Skills

Four tiers: 0 Untrained, 1 Trained, 2 Advanced, 3 Master. The player starts Untrained in everything.

| Skill | Attribute | Untrained / Trained / Advanced / Master |
|---|---|---|
| Pistols | `pistol_spread_mult` (every cone floor and the look and shot bloom) | ×1.0 / 0.8 / 0.6 / 0.4 |
| | `pistol_settle_time` (base AimConfig 0.8 s) | 0.8 / 0.6 / 0.4 / 0.2 s |
| | `pistol_reload_mult` (base 1.6 s) | ×1.0 / 0.85 / 0.7 / 0.5 |
| | `pistol_damage_mult` | ×1.0 / 1.1 / 1.2 / 1.3 (torso 25 → 32.5 at Master) |
| Rifles ([ADR 0101](../decisions/0101-rifles-and-sniper-skills.md)) | `rifle_spread_mult` (assault rifle and shotgun: every cone floor, the look and shot bloom, the shotgun's 2.5 degree pellet cone) | ×1.0 / 0.8 / 0.6 / 0.4 (pellet cone 2.5 / 2.0 / 1.5 / 1.0 degrees) |
| | `rifle_reload_mult` (shotgun 2.4 s, assault rifle 2.2 s) | ×1.0 / 0.85 / 0.7 / 0.5 |
| | `rifle_damage_mult` | ×1.0 / 1.1 / 1.2 / 1.3 (assault rifle 14 → 18.2, pellet 12 → 15.6 at Master) |
| Sniper ([ADR 0101](../decisions/0101-rifles-and-sniper-skills.md)) | `sniper_spread_mult` (sniper rifle: hip and scoped floors, look and shot bloom) | ×1.0 / 0.8 / 0.6 / 0.4 (scoped floor 0.2 → 0.08 degrees) |
| | `sniper_settle_time` (scoped 0.3 s, hip 0.8 s) | ×1.0 / 0.8 / 0.6 / 0.4 |
| | `sniper_sway_mult` (0.15 degrees) | ×1.0 / 0.75 / 0.5 / 0.25 |
| | `sniper_reload_mult` (2.5 s) | ×1.0 / 0.85 / 0.7 / 0.5 |
| | `sniper_damage_mult` (90) | ×1.0 / 1.1 / 1.2 / 1.3 |
| Low-Tech | `melee_damage_mult` (baton stun and blunt) | ×1.0 / 1.25 / 1.5 / 2.0 |
| | `melee_cycle_mult` (swing interval 0.6 s) | ×1.0 / 0.9 / 0.8 / 0.7 |
| Medicine | `medical_heal_mult` (medkit 30) | 30 / 45 / 60 / 90 |
| Computer ([ADR 0113](../decisions/0113-network-layer-tracers-and-the-deck.md)) | `deck_crack_time_mult` (the deck's Icebreaker: base Weak 10 s, Medium 24 s, Strong 50 s, [hacking.md](hacking.md)) | ×1 / 0.75 / 0.5 / 0.3 |
| | `deck_trace_gain_mult` (every trace gain the user causes: tools, failed logins, scans) | ×1 / 0.8 / 0.6 / 0.4 |
| | `deck_max_strength` (strongest password the Icebreaker cracks; ADD, 0 Weak, 1 Medium, 2 Strong) | Weak / Medium / Strong / Strong |
| | `deck_assist` (ADD, the deck's assists) | none / + time estimates / + trace estimates / + hidden routes of a gateway |
| Lockpicking | `lockpick_window_low` / `lockpick_window_high` / `lockpick_drop_threshold` / `lockpick_drop_delay` / `lockpick_lift_tolerance` / `lockpick_set_dwell` / `lockpick_rake` / `lockpick_assist` (ADD, bases in `lockpick_tuning.tres`) | Sweet spot 40-55 / 37-58 / 34-61 / 31-64 %; drop below 15 / 12 / 9 / 6 %; 0.3 / 0.45 / 0.6 / 0.75 s per dropped pin; lift tolerance +0 / 0.012 / 0.024 / 0.036; set dwell 0.08 / 0.068 / 0.056 / 0.044 s; Master rakes rakeable locks (at most 5 pins, all standard: Simple and Standard) by fast left-right strokes with the tip down, a pin every 3 strokes, with tension from the drop line to the sweet spot's top; assists Untrained sound only (brass lock), Trained + tension gauge, Advanced + captions, Master + the clear lock (pins drawn) (M10: the final prototype's `skillParams`, read by the minigame from its picker; replaced M8's `lockpick_time_mult`: [lockpicking.md](lockpicking.md), [ADR 0107](../decisions/0107-lockpicking-minigame.md), [ADR 0109](../decisions/0109-lockpicking-side-view-and-mouse-pick.md)) |

Computer replaces Electronics ([ADR 0076](../decisions/0076-computer-skill-multitool-removed.md)): Electronics and its `bypass_time_mult` went in M8 with the multitool, and Computer took its place in the skill table (no effects, no consumer until M12's deck). It affects only the deck's tools (and the trace a wrong guess at a computer adds); admin access allows every admin action. The attributes carry the deck's `deck_` prefix, so the Inventory tab's details show the skill on the deck (M12a).

Measured, Untrained / Master ([ADR 0101](../decisions/0101-rifles-and-sniper-skills.md), `tests/items/weapons/long_gun_skills_test.gd`): assault rifle full-auto, a 30-round group at 15 m, mean distance from its centre 0.33 / 0.13 m; sniper rifle scoped and still, settled to 0.25 degrees in 1.40 / 0.28 s; shotgun pellets on a 0.5 m plate at 10 m 2 to 5 / all 8 of 8. Guards have no Skills: their rifle shots are unchanged.

Knockout check (dummy threshold 60, frontal): Untrained stun 20 → 3 hits; Trained 25 → 3; Advanced 30 → 2; Master 40 → 2. From behind on an unaware target ×10: always one hit. Combat Strength multiplies on top (×1.5).

## Energy

- Attributes `energy` (the base is the charge) and `energy_max` (capacity), 100 / 100 on the player; the `Energy` component spends and refills them.
- Biocell (consumable, [inventory.md](inventory.md)): LMB with it in hand sends `energy` 25 to the user; the `energy` receptron's `ChangeAttributeEffect` adds it, capped at `energy_max`. At full energy it is refused with "Energy full" and kept.
- At 0 every active augmentation switches off with the HUD message "Energy depleted"; switching one on at 0 fails with the same message.

## Augmentations

All usable at once in v0 (body-slot conflicts come with progression). All five are installed on the player by default and all start off; the Stats tab installs and uninstalls them. Every one is a toggle, as in Deus Ex (the data model still supports a passive augmentation, on while installed, for later use).

| Augmentation | Key | Type | Drain | Effect while on |
|---|---|---|---|---|
| Cloak | F1 | toggle | 4 /s (25 s from full) | Tag `state.cloaked`: guards do not see you (M7); cameras and turrets still do. First person: the weapon goes translucent and the screen gets a faint blue tint |
| Run Silent | F2 | toggle | 1.5 /s | Footstep and landing noise ×0 (no noise stimulus, no sound) |
| Speed Enhancement | F3 | toggle | 2 /s | Walk/sprint/crouch speed ×1.5 (sprint 9 m/s), jump apex 1.0 → 1.6 m, mantle up to 2.5 m above the last ground (from 1.9), landing noise ×1.5 |
| Regeneration | F4 | toggle | 5 /s | `heal` 2 on itself every 0.5 s (4 HP/s), split over the damaged parts like a medkit; it keeps running and draining when nothing is hurt, but sends nothing then |
| Combat Strength | F5 | toggle | 1 /s | Carry limit 20 → 70 kg (metal crate 25 kg and large crate 60 kg become liftable); melee damage ×1.5 (stacks with Low-Tech). When it switches off (F5, or energy runs out) while you hold something over 20 kg, the object is dropped in front of you with the HUD message "Too heavy" (`player.dropped` how `too_heavy`); lighter objects stay held |

Every switch is logged (`augmentation.activated`, `augmentation.deactivated` {reason}, `augmentation.refused` {reason}, `augmentation.installed`).

## Rules

- Skills and augmentations are implemented as modifiers ([attributes-and-tags.md](attributes-and-tags.md)).
- Augmentations are toggled with F1-F5 (`aug_1`-`aug_5`; Combat Strength was on F6 until save/load moved into the game menu, [ADR 0064](../decisions/0064-game-menu.md)) ([controls.md](controls.md)). HUD chips and the Stats tab name the key bound to the action ("F5 Combat Strength").
- The carry limit is checked every tick while carrying: any change that drops `carry_mass_limit` below the held mass (Combat Strength off, a future injury modifier) drops the object.
- Crouching (`stance.crouch`) settles the aim cone faster (×0.6 settle time), stacking with Pistols ([weapons-and-aiming.md](weapons-and-aiming.md)).
- Saving: `Skills` (tiers) and `Augmentations` (installed, active) are saveable; the energy is in the attributes; modifiers and tags are re-derived on load ([saving.md](saving.md)).
- No difficulty settings in v0.

## Tab interface pages (M11, [ADR 0111](../decisions/0111-character-tabs-and-per-part-medkit.md))

The Tab interface (the world keeps running behind it) has two pages for abilities; both update live while shown and work for any character with the components (`ui/tab_interface/tabs/`).

- **Augmentations** (`augmentations_tab.tscn`): the energy bar and charge ("41 / 100"), the total drain of what is on and the seconds left at that drain ("10 s left at 4 / s", "No drain"); one card per key slot F1-F5 (the key bound to `aug_<n>`): name, description, drain per second and a switch. The switch goes through `Augmentations.toggle_slot()`, the F-keys' path, so switching on at 0 energy is refused with "Energy depleted" (shown on the page). While on, the card turns blue and shows "N s alone" (the charge / its own drain). A slot whose augmentation is not installed is greyed: "Not installed.", "needs an augmentation canister", no switch. Installed passive augmentations (none ship) are listed below without a switch.
- **Skills** (`skills_tab.tscn`): each skill with three tier pips and its tier name; the selected skill shows its description and "What each tier gives", a table built from the skill data (`SkillData.tier_rows()`): one row per `SkillEffect`, its `label` and per-tier text from its Display group (the modifier itself, "x0.8" / "+1.2 %", or the value it gives a stated base, settle "0.6 s", medkit "45", or one text per tier, Lockpicking's assists), the current tier's column highlighted. The base values shown (`display_base`) repeat the consumers' tuning for reading only. TESTING controls − / + change the tier through `Skills.set_tier()` (the Stats tab's path, clamped Untrained..Master) until M18 replaces them with experience; the Experience box is a placeholder until then.

## Interactions

- [weapons-and-aiming.md](weapons-and-aiming.md), [security.md](security.md), [damage.md](damage.md), [movement.md](movement.md), [light-and-visibility.md](light-and-visibility.md), [perception-and-ai.md](perception-and-ai.md), [debug-panel.md](debug-panel.md), [saving.md](saving.md)
- Test station: room 7 abilities station ([../levels/hub-and-gallery.md](../levels/hub-and-gallery.md)).

## Open questions

- Cloak against guards is only a tag until M7 perception reads it.
