# 65. Light level model: Godot's attenuation, three body points, saturating sum

Status: Accepted

Date: 2026-11-06

## Context

[ADR 0013](0013-light-analytic.md) chose an analytic light level (lights x falloff x shadow rays to body points) over a render-based gem. M7 needs the numbers: which lights count, the falloff, the points, how they combine, how often, and a value guards can threshold (dark < 0.1, fully visible >= 0.5, owned by the guard work). Any entity may need it (player now, guards later: bodies they find, each other).

## Decision

- **Component `LightExposure`** (`actors/common/light/light_exposure.gd`) on any entity: joins group `light_exposure`, exposes `level` in [0, 1] and `LightExposure.of(entity)`. No player code; the player has one in `player.tscn`. Pure logic in `LightModel` (RefCounted), tuning in `LightExposureConfig` (`light_exposure.tres`).
- **Lights**: every visible `OmniLight3D` and `SpotLight3D` (not negative, energy > 0) whose range reaches the entity's centre (0.9 m above the feet) within range + 1 m. `DirectionalLight3D` is ignored: no level uses one indoors (only the kit showcase). The list of lights is cached per component and rescanned when a Light3D enters or leaves the tree (fire and explosion lights count: standing by a fire makes you visible).
- **Falloff**: Godot's own forward-renderer attenuation, so the number follows what is drawn: `energy x luminance(light_color) x (1 - (d / range)^4)^2 x d^-attenuation` (`omni_attenuation` / `spot_attenuation`, default 1), times Godot's spot cone factor `1 - ((1 - cos a) / (1 - cos spot_angle))^spot_angle_attenuation` (0 outside the cone). Surface angle (N·L) is ignored: a body has no single normal.
- **Shadows**: one ray per light and point against layers world (1) and objects (4) (`shadow_mask`), excluding the entity's own collision objects and the nearest collision object the light hangs from (its lamp). Rays are cast for every light that reaches, whether or not the Light3D casts shadows in the renderer: gameplay light never passes walls. Levels keep unshadowed lights out of range of other rooms.
- **Points** above the feet: 0.2, 1.0, 1.6 m standing; 0.2, 0.55, 0.85 m while the entity has `stance.crouch`. Weights 0.25 / 0.5 / 0.25.
- **Combine**: per point, `1 - exp(-gain x sum of contributions)` (gain 4): lights add up but saturate, so a second lamp helps less than the first and nothing exceeds 1. Level = `ambient + (1 - ambient) x weighted average of the points`, ambient 0.04. A weighted average (not the brightest point) makes partial cover count: feet hidden behind a crate lower the level a little, the chest out of the light lowers it a lot. The chest weighs most, as the calibration targets are chest values.
- **Rate**: 10 Hz (`update_interval` 0.1 s, every 6th physics tick); `update_now()` for tests and one-off reads.
- **Calibration** (perception lab, lane centres, standing / crouched): lit 0.93 / 0.88 (two 2.0-energy, 5 m lamps at 3.6 m), dim 0.31 / 0.21 (one 0.35-energy, 4 m lamp), dark 0.04 / 0.04; the hub spawn reads about 0.65. All keep clear of 0.1 and 0.5.
- **Seen darkness**: the hub's environment ambient (0.4) would make an unlit room look grey while it reads 0.04. A room that must look dark overrides the ambient with a `ReflectionProbe` in ambient-colour mode whose box reaches past the room's surfaces (fragments on the box faces get no blend: the box must enclose walls, floor and ceiling by more than `blend_distance`). The perception lab uses colour (0.5, 0.55, 0.65) x 0.12.
- **HUD**: `LightGauge` (gem + bar above the body silhouette), coloured dark / dim / lit; the debug Overlays tab shows the number and the lights in reach.

## Alternatives considered

- Render-based gem: rejected in ADR 0013 (not headless-testable).
- Inverse-square or linear falloff of our own: simpler, but would disagree with the rendered lights near the range edge.
- Max of the points: a body with only the head in light would read fully lit, so cover would not count.
- Linear sum clamped to 1: two lamps would saturate quickly and hide differences in bright rooms.
- Including the environment ambient in the level: the hub's ambient would make everything read "dim"; levels mark darkness with the probe instead.

## Consequences

- Any lit-or-not rule (guard sight, cameras later) reads one number from any entity.
- Light and visual stay in step as long as lights use the default distance fade and levels keep unshadowed lights out of neighbouring rooms.
- Cost: lights in reach x 3 shadow rays per entity at 10 Hz.
- See [light and visibility](../game/light-and-visibility.md).
