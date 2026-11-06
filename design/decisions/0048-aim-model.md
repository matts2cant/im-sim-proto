# 48. Aim model

Status: Accepted

Date: 2026-11-06

## Context

[ADR 0023](0023-aiming.md) chose a softened Deus Ex 1 reticle that shows the exact spread cone, settles over about 0.8 s untrained (0.2 s Master) and widens with movement, firing and arm damage. M4 needs the numbers and a model the HUD, the weapons and M6 skills share, and tests need shots to be deterministic.

## Decision

- `AimModel` (pure, `items/weapons/aim_model.gd`), one per `WeaponHolder`, tuning in `AimConfig` (`aim_untrained.tres`).
- **Spread** (half-angle of the cone, degrees) relaxes exponentially toward the current **floor** with time constant `settle_time` (0.8 s); when the floor rises above the spread, the spread jumps to it at once.
- **Floor** = 1.5 standing still; x0.8 crouched and still; +3 walking (also crouch-walking, > 0.5 m/s); +6 sprinting; +6 airborne for more than 0.1 s; plus the `aim_spread_add` attribute (+3 per disabled arm). Capped at the max.
- **Bloom**: mouse look +0.02 per pixel moved, at most +2 per physics frame; +2.5 per shot. **Max** 10.
- **Shots** land uniformly inside the current cone: disk sampling (radius tan(spread) x sqrt(u), angle 2 pi v) from a `RandomNumberGenerator` the holder owns and tests seed.
- **Sway**: a slow figure-of-eight drift of the aim point (0.15 degrees x `aim_sway_mult`, x2 per disabled arm); cone and reticle are centred on it.
- **Reticle**: radius px = tan(spread) / tan(vertical fov / 2) x viewport height / 2, i.e. exactly the cone.
- M6 skills and augmentations change `settle_time` / the floors through the config or the `aim_spread_add` attribute; no code change.

## Alternatives considered

- **Linear settle** (fixed degrees per second): a big bloom takes proportionally long, a small one feels abrupt; exponential matches DX1's feel and has one tunable number.
- **Settling upwards too** (spread eases toward a higher floor): sprinting would briefly allow accurate shots.
- **Gaussian spread**: most shots near the centre, but then the reticle no longer shows where shots can land.
- **Airborne without grace**: a teleport or stepping off a kerb blooms the cone for a frame.

## Consequences

- The reticle never lies: every shot is inside the circle (integration-tested).
- Untrained aim is reliable at short range: 1.5 degrees is a 0.13 m radius at 5 m, inside a dummy's head.
- Shots are reproducible in tests; in play the generator is randomised per holder.
