# 123. Recoil, the still cone per tier, damage falloff and the crosshair (M13a build)

Status: Accepted (builds the M13a part of [ADR 0120](0120-weapon-feel.md); extends [ADR 0048](0048-aim-model.md), [ADR 0061](0061-abilities-model.md), [ADR 0085](0085-weapons-and-attachments.md))

Date: 2026-11-12

## Context

ADR 0120 set the M13a targets: a pistol hit share on a torso at 10 m of about 55 / 75 / 90 / 100 % by Weapons tier, an assault rifle 10-shot spray with recoil pulled of about 30 / 50 / 70 / 85 %, Master's first still shot exact, recoil patterns that climb the camera, skill scaling recoil, a submachine gun that kills in 0.6-0.7 s at 5 m and is clearly worse than the rifle past 15 m, every tuning value a slider on the range. The user then asked for a Deus Ex crosshair instead of the aiming circle (2026-11-12).

## Decision

- **Still cone per tier**: a new class attribute `<class>_still_mult` scales only the still floor (`AimConfig.base_min_deg`); `<class>_spread_mult` keeps scaling the movement terms, the shot and look bloom and the pellet cone. Pistols 1 / 0.875 / 0.75 / 0, Rifles 1 / 0.4 / 0.2 / 0 (Master: cone 0 standing still), Sniper 1 / 0.8 / 0.6 / 0.4 (its old floors). Rifles' spread multiplier becomes 1 / 0.65 / 0.5 / 0.4.
- **Per-weapon cones**: the pistol gets `pistol_aim.tres` (still 2.0, bloom 0.8, settle 0.8); the assault rifle 1.0, bloom 1.4 up to a 5 degree cap, settle 0.5; the submachine gun 1.0, bloom 0.5 to 6, settle 0.3. Moving is moderate: walking +0.5 to +0.8, sprinting +3 to +4, airborne +5 to +6 (the shotgun's default cone too).
- **Recoil** is a `WeaponHolder` feature: `WeaponData.recoil` (a `RecoilConfig`: a per-shot `pattern` for automatic weapons, else an up-and-sideways kick, `noise_deg`, `recover_delay`, `recover_time`, `scope_blackout_time`) drives a pure `RecoilState` (the climb `offset`, a `heat` that indexes the pattern and decays with the return). Each shot leaves along the aim already climbed by the earlier shots. The configs hold the Untrained numbers (pattern and kick x`pattern_scale` 1.5, the full noise), so Untrained adds no modifier; the user's `<class>_recoil_size_mult` (1 / 0.89 / 0.78 / 0.67: Master x1 of the bare pattern), `_recoil_noise_mult` (1 / 0.75 / 0.5 / 0.25) and `_recoil_recover_mult` (1 / 0.85 / 0.7 / 0.55, on the return time) scale it, written by the skill table like every skill effect (ADR 0120: Untrained x1.5 size and x2 noise against Master x1 and x0.5).
- **Camera and bullets**: whoever owns the eye may turn it by a share of the climb (`RecoilState.view_share`, `view_recoil()`); the holder adds the rest to the shots (`unfollowed()`), so the bullets follow the whole pattern whatever the share. The player sets the share from the camera motion setting (`GameSettings.camera_motion()`, ADR 0124) and turns its Camera node by it on top of mouse look, so pulling the mouse down compensates and the climb returns by itself. The HUD crosshair moves by the part the camera does not follow.
- **Guards keep their aim until M13b**: holder exports `recoil_enabled` (off by default, on in `player.tscn`) and `weapon_aim` (the weapon's own cone; off on guards' rifle and SMG loadouts, so they aim with the guard cones: `guard_aim.tres`, and `guard_rifle_aim.tres` with the rifle's old numbers).
- **Damage falloff** (`WeaponData.falloff_start`, `falloff_end`, `falloff_min`): each projectile's damage scales with the distance to what it hits. Only the submachine gun uses it (full to 8 m, 0.25 x from 22 m). Without it the Pistols skill's Master scaling makes the SMG more accurate at 20 m than the Master rifle, whose bloom is set by its 85 % spray target; falloff makes "clearly worse past 15 m" hold at every tier.
- **Automatic fire keeps its rhythm**: a held trigger's next cycle is shortened by the time the last one ran out before the physics step ended (`WeaponState.try_fire(keep_rhythm)`), so a 0.07 s cycle fires every 0.07 s on average at 60 Hz (it fired every 0.083 s).
- **Crosshair** (user request): four arms around the centre dot, their inner ends on the cone radius (the circle's maths and offset), 11 px long at 1080 p (scaled with the height), 2 px with a dark outline; "T" caps on the arms when the aim is on something a weapon can damage (a hitbox, `BodyParts` or `Breakable`) within the held weapon's range. One colour hook (`Hud._target_color()`) for hostility once factions exist.
- **Tuning as data**: `RecoilConfig`, `AimConfig` and the falloff are `@export_range` values the range's tuning panel lists by reflection (ADR 0125); the pattern's points and loop index are the shape, not sliders. The per-tier multipliers stay in the skill table (`SkillEffect.tier_values`), where skills write attributes.

## Measured (tests)

| | Untrained | Trained | Advanced | Master |
|---|---|---|---|---|
| Pistol, torso at 10 m, a shot a second (`aim_tiers_test`) | 56 % | 80 % | 92 % | 100 % |
| Assault rifle, 10-shot spray pulled (`aim_tiers_test`) | 31 % | 49 % | 67 % | 87 % |
| SMG time to kill at 5 m, pulled (`smg_test`) | 0.60-0.73 s | | | |
| 20 m time to kill: SMG / rifle (`smg_test`) | no kill in a magazine / 1.3 s to none | | | 1.3 s / 0.43-1.33 s |

The assault rifle kills at 10 m in 0.43 s at Master pulling the recoil (`weapon_outcomes_test`): five hits at 18.2 damage, faster than ADR 0120's "about 0.6 s" (that number was measured Untrained without recoil); Untrained it now often takes over a second, by the 30 % target.

## Alternatives considered

- **Master's still cone through `spread_mult` 0**: also removes Master's bloom and movement penalty.
- **Recoil applied to `pitch` and the yaw directly**: the same feel, but the camera share could not differ from the bullets'.
- **A weapon-specific skill scale instead of falloff**: a special rule for one weapon; falloff is a general property any gun can use.
- **Guards with recoil now**: M13b retunes guards against the survival targets of ADR 0070.

## Consequences

- [weapons-and-aiming.md](../game/weapons-and-aiming.md), [abilities.md](../game/abilities.md) and [inventory.md](../game/inventory.md) describe the build; the old weapon outcome numbers moved (`weapon_outcomes_test`, `long_gun_skills_test`).
- Two warehouse guards carry the SMG (`guard_smg.tscn`); the shooting range's second rack holds it.
