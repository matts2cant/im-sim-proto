# 61. Abilities: skills, energy and augmentations as attribute modifiers

Status: Accepted (details [ADR 0020](0020-skills-augmentations.md))

Date: 2026-11-06

## Context

M6 adds skills (Pistols, Low-Tech, Medicine, Electronics, Lockpicking; four tiers), bioelectric energy and augmentations (Cloak, Run Silent, Speed Enhancement, Regeneration, Combat Strength) without leveling: values are set in the debug panel. Guards (M7) and later progression must reuse the same model, and the systemic principle (AGENTS.md) forbids "is player" or "has skill X" checks in consumers. Several consumers read tuning straight from a config (AimConfig.settle_time, the pistol's reload_time, MovementNoise loudness, PlayerConfig jump and mantle heights), so nothing could change them per character.

## Decision

- **Consumers read attributes with their own tuning as the base.** `AttributeSet.evaluate(attribute, base)` applies an attribute's modifiers to a base the caller supplies (the stored base is ignored); `Attributes.read(entity, attribute, base)` does it for an entity and returns `base` when it has no Attributes. With no modifiers every consumer behaves exactly as before. Attributes read this way (base in brackets):
  - weapons, per `WeaponData.attribute_class` (`pistol`, `melee`): `<class>_damage_mult` (1), `<class>_cycle_mult` (1, on cycle_time), `<class>_reload_mult` (1, on reload_time), `<class>_spread_mult` (1, on every cone floor and on look and shot bloom), `<class>_settle_time` (AimConfig.settle_time);
  - healing items: `ItemData.use_scale_attribute` (medkit: `medical_heal_mult`, 1);
  - movement: `move_speed_mult` (existing), `jump_apex_height` (PlayerConfig 1.0 m), `mantle_max_height` (PlayerConfig 1.9 m), `footstep_noise_mult` and `landing_noise_mult` (1, in MovementNoise; a noise scaled to 0 is not made at all);
  - carrying: `carry_mass_limit` (existing, 20 kg);
  - tools (consumers in M8): `bypass_time_mult`, `lockpick_time_mult` (1).
- **One mechanism for "what an entity puts out depends on it": `Stimulus.scale_attribute`.** An emitter names an attribute of the stimulus's source; `StimulusSystem` multiplies the intensity by `Attributes.read(source, attribute, 1)` once, on emit (also in the `would_affect` dry run), and logs `scale_attribute` and `scale`. The weapon holder sets it on its damage rays and contacts (not on `force.impact`), the inventory on a consumable's use stimuli, and `EmitStimulusEffect` has a `scale_attribute` export. Medicine therefore scales the healer's outgoing `heal`, so a medic healing someone else later uses the medic's skill.
- **Skills** (`actors/common/abilities/`): `SkillTable` (`skill_table.tres`) holds `SkillData` with `SkillEffect`s (attribute, op, one magnitude per tier). The `Skills` component keeps tiers and re-derives each skill's modifiers (source `skill.<id>`) on every change, like BodyParts does for injuries, so skills, augmentations and injuries stack. Tier values that change nothing add no modifier. Numbers:

  | Skill | Attribute | Untrained / Trained / Advanced / Master |
  |---|---|---|
  | Pistols | `pistol_spread_mult` | ×1.0 / 0.8 / 0.6 / 0.4 |
  | | `pistol_settle_time` | ×1 / 0.75 / 0.5 / 0.25 (0.8 / 0.6 / 0.4 / 0.2 s) |
  | | `pistol_reload_mult` | ×1.0 / 0.85 / 0.7 / 0.5 |
  | | `pistol_damage_mult` | ×1.0 / 1.1 / 1.2 / 1.3 |
  | Low-Tech | `melee_damage_mult` | ×1.0 / 1.25 / 1.5 / 2.0 (baton stun 20 / 25 / 30 / 40) |
  | | `melee_cycle_mult` | ×1.0 / 0.9 / 0.8 / 0.7 |
  | Medicine | `medical_heal_mult` | ×1 / 1.5 / 2 / 3 (medkit 30 / 45 / 60 / 90) |
  | Electronics | `bypass_time_mult` | ×1.0 / 0.75 / 0.5 / 0.25 |
  | Lockpicking | `lockpick_time_mult` | ×1.0 / 0.75 / 0.5 / 0.25 |

- **Energy**: attributes `energy` (the base is the charge) and `energy_max` (its value is the capacity; 100 / 100 on the player), so the charge is saved with the attributes. The `Energy` component is a thin API over them (spend, set, refill). A biocell is a consumable whose use stimulus `energy` 25 reaches the `energy` receptron (`actors/common/abilities/receptrons/energy.tres`), which runs the new generic **`ChangeAttributeEffect`** (adds perceived × `per_intensity` to an attribute's base, clamped to `min_value` and an optional `max_attribute`; `can_apply` is false when nothing would change, so a biocell at full energy is refused with "Energy full" by the ADR 0057 dry run).
- **Augmentations**: `AugmentationData` resources (`augmentations/<id>.tres`) describe what an augmentation does while on, as data: `modifiers` (copied with source `aug.<id>`), `tags`, `pulse_stimuli` sent to the entity itself every `pulse_interval` when they would do something, `drain_per_second`, `slot` (toggle key `aug_<slot>`) or `passive`. The `Augmentations` component holds installed and active ids, re-derives modifiers and tags on every change, drains the sibling Energy every physics tick and switches every toggle off at 0 ("Energy depleted"); switching one on at 0 is refused with the same message. Logged: `augmentation.activated` / `deactivated` {reason: toggled, depleted, uninstalled} / `refused` {reason} / `installed`. All five are installed on the player by default (Stats tab to uninstall).

  | Augmentation | Key | Drain | While on |
  |---|---|---|---|
  | Cloak | F1 | 4 /s (25 s from full) | tag `state.cloaked` |
  | Run Silent | F2 | 1.5 /s | `footstep_noise_mult` ×0, `landing_noise_mult` ×0 |
  | Speed Enhancement | F3 | 2 /s | `move_speed_mult` ×1.5 (sprint 9 m/s), `jump_apex_height` ×1.6 (1.6 m), `mantle_max_height` +0.6 (2.5 m), `landing_noise_mult` ×1.5 |
  | Regeneration | F4 | 5 /s | `heal` 2 on itself every 0.5 s (4 HP/s, split like a medkit) while something is hurt; it keeps running (and draining) when nothing is |
  | Combat Strength | passive | none | `carry_mass_limit` +50 (70 kg), `melee_damage_mult` ×1.5 |

- **Cloak** only adds `state.cloaked`. Guard sight reads it in M7 (guards do not see a cloaked entity; cameras and turrets still do). First-person feedback reads the same tag: the WeaponHolder draws its view model at 30 % opacity and the HUD shows a faint blue tint.
- **Crouched aim** (added in M6 on request): `AimConfig.crouch_settle_factor` 0.6 multiplies the settle time while the shooter has `stance.crouch` (still or moving): 0.8 → 0.48 s untrained, 0.2 → 0.12 s at Pistols Master.
- **Saving**: `Skills` (tiers) and `Augmentations` (installed, active) are `saveable`; their modifiers and tags are re-derived on load, so the load order with Attributes and Tags does not matter. Energy needs nothing of its own (the attributes hold it).
- **UI**: the HUD shows an energy bar beside the body silhouette and a chip per augmentation that is on; the debug panel's **Stats** tab (registered by the player for itself, but it works on any entity with the components) edits tiers, installed, on/off and energy live. Keys F1-F4 (`aug_1`-`aug_4`); `aug_5` (F6) is bound but no augmentation uses slot 5.

## Alternatives considered

- **Swap AimConfig resources per tier** (the M4 plan, `aim_untrained.tres`): one config per tier per weapon, no stacking with injuries or augmentations, and nothing for reload or damage.
- **Consumers ask the Skills component for a tier**: a "has skill X" check in every consumer; guards and props could not get the same effect from an augmentation or an item.
- **Store config values as attribute bases on each entity**: duplicates the config in every scene and drifts from it; `evaluate()` with the config as the base keeps one source.
- **Scale damage and healing in each emitter**: three copies of the same rule; `scale_attribute` keeps it in the stimulus system, data-driven and logged.
- **An `EnergyRestoreEffect`**: specific to energy; `ChangeAttributeEffect` is the "change attribute" effect the framework already listed and works for any attribute.

## Consequences

- Any actor with Attributes, Tags, Energy and the components gets skills and augmentations with no code; guards in M7 can be given Pistols tiers or Combat Strength in their scene.
- With Combat Strength installed by default, the player carries the 25 kg and 60 kg crates and the baton stuns for 30 (two frontal hits on a dummy instead of three) until it is uninstalled in the Stats tab. Tests of the M3/M4 numbers uninstall it.
- With Speed Enhancement a sprint jump clears about 7.3 m and a 2.3 m ledge can be mantled: levels must not rely on those being impossible except where intended ([metrics](../levels/metrics.md)).
- Progression later only has to call `Skills.set_tier()` and `Augmentations.set_installed()`.
