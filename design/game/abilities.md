# Abilities

Milestone: M6 (Inventory and abilities bay). Model: [ADR 0061](../decisions/0061-abilities-model.md).

## Purpose

A basic ability system without leveling. Values are edited in the debug panel's Stats tab. Built on modifiers so progression can be added later ([../backlog.md](../backlog.md)).

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
| Low-Tech | `melee_damage_mult` (baton stun and blunt) | ×1.0 / 1.25 / 1.5 / 2.0 |
| | `melee_cycle_mult` (swing interval 0.6 s) | ×1.0 / 0.9 / 0.8 / 0.7 |
| Medicine | `medical_heal_mult` (medkit 30) | 30 / 45 / 60 / 90 |
| Electronics | `bypass_time_mult` | ×1.0 / 0.75 / 0.5 / 0.25 (attribute only; the multitool consumer is M8) |
| Lockpicking | `lockpick_time_mult` | ×1.0 / 0.75 / 0.5 / 0.25 (attribute only; the lockpick consumer is M8) |

Knockout check (dummy threshold 60, frontal): Untrained stun 20 → 3 hits; Trained 25 → 3; Advanced 30 → 2; Master 40 → 2. From behind on an unaware target ×10: always one hit. Combat Strength multiplies on top (×1.5).

## Energy

- Attributes `energy` (the base is the charge) and `energy_max` (capacity), 100 / 100 on the player; the `Energy` component spends and refills them.
- Biocell (consumable, [inventory.md](inventory.md)): LMB with it in hand sends `energy` 25 to the user; the `energy` receptron's `ChangeAttributeEffect` adds it, capped at `energy_max`. At full energy it is refused with "Energy full" and kept.
- At 0 every active augmentation switches off with the HUD message "Energy depleted"; switching one on at 0 fails with the same message.

## Augmentations

All usable at once in v0 (body-slot conflicts come with progression). All five are installed on the player by default; the Stats tab installs and uninstalls them.

| Augmentation | Key | Type | Drain | Effect while on |
|---|---|---|---|---|
| Cloak | F1 | toggle | 4 /s (25 s from full) | Tag `state.cloaked`: guards do not see you (M7); cameras and turrets still do. First person: the weapon goes translucent and the screen gets a faint blue tint |
| Run Silent | F2 | toggle | 1.5 /s | Footstep and landing noise ×0 (no noise stimulus, no sound) |
| Speed Enhancement | F3 | toggle | 2 /s | Walk/sprint/crouch speed ×1.5 (sprint 9 m/s), jump apex 1.0 → 1.6 m, mantle up to 2.5 m above the last ground (from 1.9), landing noise ×1.5 |
| Regeneration | F4 | toggle | 5 /s | `heal` 2 on itself every 0.5 s (4 HP/s), split over the damaged parts like a medkit; it keeps running and draining when nothing is hurt, but sends nothing then |
| Combat Strength | — | passive while installed | none | Carry limit 20 → 70 kg (metal crate 25 kg and large crate 60 kg become liftable); melee damage ×1.5 (stacks with Low-Tech) |

Every switch is logged (`augmentation.activated`, `augmentation.deactivated` {reason}, `augmentation.refused` {reason}, `augmentation.installed`).

## Rules

- Skills and augmentations are implemented as modifiers ([attributes-and-tags.md](attributes-and-tags.md)).
- Augmentations are toggled with F1-F4 ([controls.md](controls.md)); F6 (`aug_5`) is bound but unused.
- Crouching (`stance.crouch`) settles the aim cone faster (×0.6 settle time), stacking with Pistols ([weapons-and-aiming.md](weapons-and-aiming.md)).
- Saving: `Skills` (tiers) and `Augmentations` (installed, active) are saveable; the energy is in the attributes ([saving.md](saving.md)).
- No difficulty settings in v0.

## Interactions

- [weapons-and-aiming.md](weapons-and-aiming.md), [security.md](security.md), [damage.md](damage.md), [movement.md](movement.md), [light-and-visibility.md](light-and-visibility.md), [perception-and-ai.md](perception-and-ai.md), [debug-panel.md](debug-panel.md), [saving.md](saving.md)
- Test station: room 7 abilities station ([../levels/hub-and-gallery.md](../levels/hub-and-gallery.md)).

## Open questions

- Should Combat Strength stay installed by default? It makes the "Too heavy" crates liftable and the baton two-hit from the front until uninstalled.
- Cloak against guards is only a tag until M7 perception reads it.
