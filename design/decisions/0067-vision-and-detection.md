# 67. Vision and detection: cones, light, a suspicion meter

Status: Accepted

Date: 2026-11-06

## Context

Guards (M7) must see the player gradually, so light, distance, stance, Cloak and cover all matter and the player can read and play against it (ADR 0012). Binary "in cone and in line of sight" is unreadable and gives no room for shadows. The light system is built in parallel (its component: a child of a lit entity in group `light_exposure` with a public `level` in [0, 1]).

## Decision

- **`PerceptionSensor`** (`actors/common/perception/`), a component of any character, tuned by a **`PerceptionConfig`** `.tres` (the guard's: `actors/guard/guard_perception.tres`); the numbers live in the pure **`VisionRules`**. Once per tick GradedAwareness calls `look(wary)`; it returns the hostile target seen best (highest gain), or nothing.
- **Who is a target** is data, by tags only (ADR 0069): an entity whose `Tags` (group `tags`, new) have one of `hostile_tags` and none of `hidden_tags` (`state.cloaked`). Never a class or a name: a static capsule tagged `actor.player` is seen like the player.
- **Line of sight**: rays from the eyes (`eye_height` 1.6 m above the feet) to the target's head, chest and feet (0.9, 0.6 and 0.1 of the height of its first collision shape; a crouched capsule is shorter, so cover hides more of it). Blocked by world (layer 1) and props (layer 4); seen if any ray is clear.
- **Zones** (horizontal angle from the facing, horizontal distance from the eyes): focus ±30°, 20 m, factor 1; peripheral ±60°, 10 m, factor 0.4; nothing else (no sight behind).
- **Gain** (suspicion per second while seen) = 1.25 × light × distance × zone × stance × wary:
  - light = clamp((L − 0.1) / 0.4, 0, 1), L the target's light level (full at 0.5, none at 0.1). Within 2 m (centre to centre) light is at least 0.5: nobody is invisible at arm's length.
  - distance = 1 up to 5 m, linear down to 0.25 at 20 m.
  - stance = 0.7 with `stance.crouch`; wary = 1.5 while wary (ADR 0068).
- The meter, its decay (0.25/s) and its thresholds (Suspicious 0.3, 0.2 while wary; Alerted 1.0) belong to the awareness model (ADR 0068).
- **Light lookup** is one function, `PerceptionSensor.light_level_of()`: the `level` of the entity's child in group `light_exposure`, else 1.0 (fully lit). The merge with the light branch swaps it for the light system's accessor.
- Worked numbers (tests): lit at 4 m in focus → 1.25/s, Alerted in 0.8 s; lit at 12 m → 1.23 s; dim (L 0.25) at 4 m → 2.1 s; crouched dim at 8 m → 3.6 s; dark (0.05) at 6 m → never; peripheral 45° at 6 m → 2.1 s; behind → never; dark at 1.5 m in focus → 1.6 s.

## Alternatives considered

- **Binary sight** (in cone + line of sight = alerted): no shadows, no stance, no reading time for the player.
- **One ray to the target's centre**: a target half behind a crate would vanish; three points match "any part shows".
- **3D angles and distances**: a guard on a balcony would lose targets right below; horizontal keeps cones readable. Revisit with vertical limits if levels get tall.
- **The sensor running its own tick**: two components ordering against each other; GradedAwareness asking once per tick keeps one sighting per step.

## Consequences

- The light system only provides the `light_exposure` child; without one an entity counts as fully lit (no shadows until the light branch merges).
- Cloak is just a tag in `hidden_tags`; cameras and turrets (later) can use a config without it.
- `Tags` nodes join the group `tags`, so systems can find entities by tag without registries.
- Tests: `tests/actors/common/perception/vision_rules_test.gd`, `perception_sensor_test.gd`.
- See [perception and AI](../game/perception-and-ai.md).
