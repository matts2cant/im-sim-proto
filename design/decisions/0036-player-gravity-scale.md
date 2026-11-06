# 36. Player gravity scale 2.0

Status: Accepted

Date: 2026-11-06

## Context

M1 playtest found the jump floaty with the engine default gravity of 9.8 m/s². The 1.0 m apex is fine; the problem is hang time (0.90 s on flat ground) and slow falls.

## Decision

- `PlayerConfig.gravity_scale` (2.0 in `player_config.tres`) multiplies the engine gravity for the player only, rising and falling: 19.6 m/s².
- `jump_apex_height` stays 1.0 m; the launch speed is derived from the scaled gravity: 6.26 m/s, flat airtime 0.64 s, flat jump about 2.5 m from walk and 3.8 m from sprint.
- Falls hit harder: a 2 m drop lands at 8.9 m/s and a 5 m drop at 14.0 m/s, which raises landing loudness (10.6 and 16.8 on concrete).

## Alternatives considered

- Project-wide gravity: rejected, physics objects in M3 (crates, bodies, thrown items) should keep real gravity.
- Fall-only multiplier (floaty rise, fast fall): kept simple for now; revisit if the symmetric jump still feels wrong.

## Consequences

- Gap rules in [metrics](../levels/metrics.md) change: easy gaps up to 2 m, hard gaps 3 to 3.5 m.
- See [movement](../game/movement.md).
