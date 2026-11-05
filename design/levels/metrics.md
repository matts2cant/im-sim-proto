# Level metrics

Hard numbers every level must respect. Source of truth for the values is `actors/player/player_config.tres`; update this page when tuning changes them. Back to [design/README.md](../README.md).

## Player body

| Metric | Value | Level rule |
|---|---|---|
| Capsule radius | 0.35 m | Corridors and vents ≥ 0.8 m wide (1.2 m recommended so the mouth is easy to line up) |
| Standing height | 1.8 m | Standing headroom ≥ 1.9 m |
| Crouched height | 0.95 m | Crawl spaces (vents) 1.0–1.2 m high; anything < 1.9 m forces crouch |
| Eye height | 1.65 m standing / 0.9 m crouched | Windows and peep holes at these heights |
| Max walkable slope | 45° | Use ramps ≤ 40° for stairs; there is no step-up, steps ≥ 0.3 m are mantled |

## Traversal

| Metric | Value | Level rule |
|---|---|---|
| Jump apex | 1.0 m | Obstacles to jump over ≤ 0.9 m |
| Flat gap, walk jump | ~3.6 m | "Easy" gaps ≤ 3 m |
| Flat gap, sprint jump | ~5.4 m | "Hard" gaps 4–5 m; ≥ 6 m is impassable without augmentations (ledge catch may extend this, see [movement.md](../game/movement.md)) |
| Mantle height | 0.3–1.9 m above the feet **and** above the last ground stood on | Ledges 2.0–2.2 m are a deliberate "no"; ≥ 2.3 m is safely out of reach |
| Mantle reach | 0.8 m horizontal from the capsule | Ledge lips must be within reach of a standable spot |
| Mantle clearance | standing clearance on top, or crouched clearance (ends crouched) | A vent mouth on a ledge needs ≥ 1.0 m height above the ledge |

## Noise (audible distance in metres, walking on concrete = 6)

| Surface multiplier | concrete 1.0 · carpet 0.5 · grass 0.7 · wood 1.2 · metal 1.6 |
|---|---|
| Footsteps | walk 6 · sprint 14 · crouch 2 (× surface) |
| Landing | 6 × clamp(impact speed / 5, 1, 4) × surface, from 3 m/s impact |

Floors declare their surface with node metadata `surface` on the CSG root that has collision ([ADR 0033](../decisions/README.md)).
