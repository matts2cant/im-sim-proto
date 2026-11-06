# Level metrics

Hard numbers every level must respect. Source of truth for the values is `actors/player/player_config.tres`; update this page when tuning changes them. Back to [design/README.md](../README.md).

## Player body

| Metric | Value | Level rule |
|---|---|---|
| Capsule radius | 0.35 m | Corridors and vents ≥ 0.8 m wide (1.2 m recommended so the mouth is easy to line up) |
| Standing height | 1.8 m | Standing headroom ≥ 1.9 m |
| Crouched height | 0.95 m | Crawl spaces (vents) 1.0–1.2 m high; anything < 1.9 m forces crouch |
| Eye height | 1.65 m standing / 0.9 m crouched | Windows and peep holes at these heights |
| Max walkable slope | 45° | Use ramps ≤ 40° for stairs; there is no step-up: steps of 0.1–1.0 m are jumped onto, steps ≥ 1.0 m are mantled |

## Traversal

| Metric | Value | Level rule |
|---|---|---|
| Gravity | 19.6 m/s² (player only, ×2.0, [ADR 0036](../decisions/0036-player-gravity-scale.md)) | Launch speed 6.26 m/s, flat airtime 0.64 s |
| Jump apex | 1.0 m | Obstacles to jump over ≤ 0.9 m; a ledge below 1.0 m is jumped onto, not mantled |
| Flat gap, walk jump | ~2.6 m (4 m/s × 0.64 s) | "Easy" gaps ≤ 2 m |
| Flat gap, sprint jump | ~3.8 m (6 m/s × 0.64 s) | "Hard" gaps 3–3.5 m (walk jump fails, sprint clears); ≥ 4.2 m is impassable without augmentations |
| Gap with mid-air ledge catch | same-level far ledge: no extension; far ledge 1.0–1.9 m above take-off: up to ~4.6 m | The catch needs the ledge top ≥ 1.0 m above the last ground (and above the feet), so a same-level ledge cannot be caught. Largest gap crossable with a sprint jump plus catch: 3.83 m + 0.8 m reach ≈ 4.6 m, only onto a ledge 1.0–1.9 m higher; onto a same-level ledge it stays ≈ 3.8 m (≈ 4.1 m counting the ~0.25 m capsule overhang at the lip). Do not rely on either; keep hard gaps at 3.5 m or less |
| Mantle height | 1.0–1.9 m above the last ground stood on (and above the feet); the maximum also applies to the feet | Ledges below 1.0 m are jumped onto; 2.0–2.2 m are a deliberate "no"; ≥ 2.3 m is safely out of reach |
| Mantle reach | 0.8 m horizontal from the capsule | Ledge lips must be within reach of a standable spot |
| Mantle clearance | standing clearance on top, or crouched clearance (ends crouched) | A vent mouth on a ledge needs ≥ 1.0 m height above the ledge |

## Noise (audible distance in metres, walking on concrete = 6)

| Surface multiplier | concrete 1.0 · carpet 0.5 · grass 0.7 · wood 1.2 · metal 1.6 |
|---|---|
| Footsteps | walk 6 · sprint 14 · crouch 2 (× surface) |
| Landing | 6 × clamp(impact speed / 5, 1, 4) × surface, from 3 m/s impact (on concrete: 1 m jump 6.3 m/s → 7.5, 2 m drop 8.9 m/s → 10.6, 5 m drop 14.0 m/s → 16.8) |

Floors declare their surface with node metadata `surface` on the CSG root that has collision ([ADR 0033](../decisions/README.md)).
