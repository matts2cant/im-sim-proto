# Level metrics

Hard numbers every level must respect. Source of truth for the values is `actors/player/player_config.tres`; update this page when tuning changes them. The [graybox kit](kit.md) parts enforce these rules (clamp and warn), so prefer them to free CSG. Back to [design/README.md](../README.md).

## Player body

| Metric | Value | Level rule |
|---|---|---|
| Capsule radius | 0.35 m | Corridors and vents ≥ 0.8 m wide (1.2 m recommended so the mouth is easy to line up) |
| Standing height | 1.8 m | Standing headroom ≥ 1.9 m |
| Crouched height | 0.95 m | Crawl spaces (vents) 1.0–1.2 m high (kit `VentSegment` default 1.1 m); anything < 1.9 m forces crouch |
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

## Objects (M3)

| Object | Size | Level use |
|---|---|---|
| Small wooden crate | 0.6 m cube, 10 kg | Jump onto (< 1.0 m); carryable; two stacked (1.2 m) are mantled |
| Large wooden crate | 1.2 m cube, 60 kg | Mantled (1.0-1.9 m); too heavy to carry |
| Metal crate | 0.8 m cube, 25 kg | Jump onto; too heavy to carry |
| Cardboard box | 0.5 m cube, 2 kg | Carryable, throws far (12 m/s) |
| Explosive barrel | Ø0.6 x 0.9 m, 30 kg | Keep 4 m from things that should survive; 2 m from another barrel chains |
| Wooden barricade | 1.3 x 2.2 x 0.12 m, origin on the floor | Fills a 1.2 x 2.2 m doorway (ends overlap the jambs) |
| Brazier | Ø0.6 x 0.9 m, origin on the floor | Permanent fire, reach 1.2 m from its centre |

Fire reaches 1.0-2.0 m from a burning object's centre and does not pass walls (layer 1); props do not shield it. Touching small crates catch in 3 s, crates 0.6 m apart in 19 s ([objects-and-fire.md](../game/objects-and-fire.md)). Carry: pick-up reach 2.0 m, limit 20 kg; held centre 0.45 m + half the object's size ahead of the eyes (small crate 0.75 m, cardboard 0.7 m) and 0.1 m + half its size lower. Putting down or throwing needs room: a 0.6 m crate needs a gap over 0.6 m (surface to surface) between the capsule and a wall.

## Noise (audible distance in metres, walking on concrete = 6)

| Surface multiplier | concrete 1.0 · carpet 0.5 · grass 0.7 · wood 1.2 · metal 1.6 |
|---|---|
| Footsteps | walk 6 · sprint 14 · crouch 2 (× surface) |
| Landing | 6 × clamp(impact speed / 5, 1, 4) × surface, from 3 m/s impact (on concrete: 1 m jump 6.3 m/s → 7.5, 2 m drop 8.9 m/s → 10.6, 5 m drop 14.0 m/s → 16.8) |
| Object impacts | clamp(speed × √mass × 0.8, 2, 30) × material (wood 1.0, metal 1.4, glass 1.6, cardboard 0.4), from 2.5 m/s; burning crackle 4; break 15; explosion 60 |

Floors declare their surface with node metadata `surface` on the CSG root that has collision ([ADR 0033](../decisions/README.md)); kit parts set it from their `surface` property.

## Navigation

Guards navigate a navmesh baked at level load for a standing human: radius 0.35 m, height 1.8 m, max slope 45°, max climb 5 cm ([ADR 0041](../decisions/0041-runtime-navmesh-bake.md)). Anything lower than 1.8 m (vents, crawl spaces) is off the navmesh, and so is anything reached only by a step of 10 cm or more, a jump or a mantle: give guards ramps where they must follow.
