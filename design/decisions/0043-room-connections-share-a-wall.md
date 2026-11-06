# 43. Room connections share one overlapped wall

Status: Accepted

Date: 2026-11-06

## Context

The movement course corridor (`Room`, 3 m high) joins the hub (5 m) and the hall (8 m) with its end walls placed exactly on theirs. The Room's floor and ceiling slabs spanned the full outer footprint, over the wall tops, so the corridor ceiling ended flush with the hub's and the hall's wall faces (and under the hub's door lintel). Two different materials on one plane z-fought: a dark, striped slab above both corridor doorways (M2 playtest).

## Decision

- **Connecting rooms overlap the shared wall**: both rooms use the same `wall_thickness`; the neighbour's interior starts at the outer face of this room's wall, so the two walls occupy the same volume; the two openings have the same width, height and position along the wall.
- **Walls own the rim**: a Room's walls run the full outer height (floor slab bottom to ceiling slab top, corners included); floor and ceiling slabs cover only the interior. Whatever a neighbour overlaps is wall, so only wall material meets wall material and the overlap is invisible (world-aligned grid shader).
- **Regression guard**: `KitGeometry.coplanar_material_overlaps()` lists faces of different CSG roots that lie on the same plane, face the same way, overlap and have different materials. The hub suite runs it over the hub and the movement course; the Room suite runs it over a tall room joined to a low corridor.

## Alternatives considered

- **Back-to-back walls** (interiors two wall thicknesses apart): no overlap at all, but the doorway becomes twice as deep, the corridor's length and its threshold strips change, and every existing connection moves.
- **Omit the wall on the shared side** (a per-wall flag): exact, but one more property to remember, and forgetting it gives the same glitch.
- **Flag any coplanar overlap**: catches same-material overlaps too, which the shared-wall convention produces on purpose and which render identically.

## Consequences

- Room collision bounds and every interior surface are unchanged; only hidden faces moved (wall bottoms and tops now show wall material under the floor and above the ceiling).
- The guard ignores same-material overlaps; a coplanar overlap of two different materials anywhere in the hub now fails a test. `kit_showcase.tscn` still has such overlaps with its ground slab (vents, a room's door threshold) and is not guarded.
