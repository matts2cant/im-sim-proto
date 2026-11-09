# 101. Rifles and Sniper skills, ammo boxes in their weapon's colour, lower view models

Status: Accepted (extends [ADR 0061](0061-abilities-model.md) and [ADR 0085](0085-weapons-and-attachments.md))

Date: 2026-11-09

## Context

M9h playtest feedback: no skill scaled the shotgun, sniper rifle or assault rifle (their `WeaponData.attribute_class` was empty), so only the pistol got better with training. The ammo boxes did not match their weapons (pistol ammo tan, shells red, sniper rounds grey), and the first-person view models took too much of the lower-right quarter of the screen. The user asked for two skills built like Pistols, through attributes and never a skill check, with Pistols' four tiers and scaling (spread x1.0 / 0.8 / 0.6 / 0.4, reload x1.0 / 0.85 / 0.7 / 0.5, damage x1.0 / 1.1 / 1.2 / 1.3); Sniper also steadies the scope, Rifles also narrows the shotgun's pellet cone. Guards hold the assault rifle (the rifle guard, ADR 0088) and must not change by accident.

## Decision

### Skills

- **Rifles** (`rifles`): the assault rifle and the shotgun get `attribute_class` `rifle`; **Sniper** (`sniper`): the sniper rifle gets `sniper`. Both are `SkillData` entries in `skill_table.tres` (after Pistols), so the debug panel's Stats tab (one tier picker per table entry) and the Skills save (`{"tiers": {id: tier}}`) pick them up with no code. The player starts Untrained in both (`Skills.initial_tiers` is empty; the mission kit only sets inventory, energy and augmentations).

  | Skill | Attribute | Untrained / Trained / Advanced / Master |
  |---|---|---|
  | Rifles | `rifle_spread_mult` (cone floors, look and shot bloom, and the shotgun's pellet cone) | x1.0 / 0.8 / 0.6 / 0.4 |
  | | `rifle_reload_mult` (shotgun 2.4 s, assault rifle 2.2 s) | x1.0 / 0.85 / 0.7 / 0.5 |
  | | `rifle_damage_mult` | x1.0 / 1.1 / 1.2 / 1.3 |
  | Sniper | `sniper_spread_mult` (hip and scoped floors, look and shot bloom) | x1.0 / 0.8 / 0.6 / 0.4 |
  | | `sniper_reload_mult` (2.5 s) | x1.0 / 0.85 / 0.7 / 0.5 |
  | | `sniper_damage_mult` (90) | x1.0 / 1.1 / 1.2 / 1.3 |
  | | `sniper_settle_time` (scoped 0.3 s, hip 0.8 s) | x1.0 / 0.8 / 0.6 / 0.4 |
  | | `sniper_sway_mult` (0.15 degrees) | x1.0 / 0.75 / 0.5 / 0.25 |

- **Sniper's scope numbers.** Settle x0.8 / 0.6 / 0.4, gentler than Pistols' x0.75 / 0.5 / 0.25: together with the spread factor (the scoped floor drops to 0.08 degrees and the hip floor it settles from to 2.4) Master already settles from the hip to 0.25 degrees in 0.28 s instead of 1.40 s (measured), and a 90-damage one-shot weapon should keep a short wait before a precise shot. Sway x0.75 / 0.5 / 0.25: Untrained sway (0.15 degrees, 0.26 m at 100 m, about half a torso; about 6 px on the 15-degree scope view) visibly moves the crosshair; at Master (0.04 degrees, 0.07 m at 100 m, head-sized) the scope is steady but still alive.
- **Rifles leave settle and sway alone**: the brief lists spread, reload and damage only, and the assault rifle's own cone (settle 0.5 s) already recovers quickly between bursts.
- **New holder rules, for any class** (they read attributes, never the skill): the pellet cone is `pellet_spread_deg` x `<class>_spread_mult` (shotgun 2.5 degrees, 1.0 at Rifles Master), and the aim sway is `aim_sway_mult` (injuries) x `<class>_sway_mult`. A class modifier only reaches its class: `pistol_spread_mult` does not narrow the shotgun.
- **Guards** have no `Skills` component, so `rifle_*` attributes read their base on them: the rifle guard's damage (14, scale 1.0), cone and sway are unchanged (asserted in `guard_rifle_test.gd`).
- **Saves**: a skill missing from a save loads Untrained (`Skills.load_state` clears and reads what is listed), so saves from before this change load with Rifles and Sniper Untrained; no migration.

Measured (`tests/items/weapons/long_gun_skills_test.gd`, the player in `skill_range.tscn`, distances centre to centre from the feet, eye 1.65 m):

| Outcome | Untrained | Master |
|---|---|---|
| Assault rifle, 30-round full-auto group on a wall at 15 m, mean distance of the hits from their centre | 0.33 m | 0.13 m |
| Sniper rifle scoped and still, from a settled hip cone: to 0.25 degrees / to its floor | 1.40 s / 2.13 s | 0.28 s / 0.75 s |
| Shotgun pellets (of 8) on a 0.5 x 0.5 m plate at 10 m, 8 seeds | 2 to 5 (mean 3.9) | 8 every shot |

### Ammo box colours

Each ammo box is its weapon's colour, set as the box material's `albedo_color` in its world scene and the same `ItemData.colour` (the inventory and belt icons draw it): shotgun shells yellow `Color(0.85, 0.68, 0.12)`, rifle rounds green `Color(0.22, 0.55, 0.22)`, sniper rounds purple `Color(0.5, 0.25, 0.65)`, pistol ammo red `Color(0.72, 0.16, 0.14)`. No new models. `tests/items/ammo_colour_test.gd` checks the hue of each and that the box and the icon agree.

### Lower view models

`WeaponHolder.view_shift_deg` (`Vector2`, degrees: x right, y down) moves every weapon's grip pivot (`WeaponData.view_offset`) on screen by the same angle: sideways and down by its depth x tan(angle) (`WeaponView.rest_position()`), so a pistol at 0.5 m and a sniper rifle at 0.85 m move alike. Recoil and the baton's chop run from the shifted rest pose; the scope still hides the model. One rule, not per-weapon offsets: the weapons keep their own `view_offset`s, which still set where each sits relative to the others. The player's holder sets (3, 9): about 50 px lower on a 648 px view (the pistol's top from y 408 to 460, the assault rifle's stock from 405 to 540) and slightly right. Guards keep zero, so the gun a guard holds does not move. The muzzle (flash, shot noise origin) moves with the model.

## Consequences

- Every long gun now improves with training; the Stats tab has seven skills.
- A future weapon joins a skill by naming its class; a future skill for a class only adds a table entry.
- The view shift is a holder setting: a later options screen (field of view, view model position) can drive it.

## Alternatives considered

- **One Rifles skill for all three long guns**: rejected by the user (sniper is its own role).
- **Lowering each weapon's `view_offset`**: per-weapon edits that would also move the guards' held weapons (the rifle guard holds the player's `assault_rifle.tres`) and would need retuning per weapon; a screen-angle rule moves all alike.
- **A shift in metres**: moves near weapons (the pistol at 0.5 m) more on screen than far ones (the sniper at 0.85 m).
