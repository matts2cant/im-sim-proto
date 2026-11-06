# 37. Graybox kit of parametric parts and grid materials

Status: Accepted

Date: 2026-11-06

## Context

In M1, hand-placing CSG geometry in `.tscn` text cost ~35% of the agent's effort and let metric errors in (vent height, gap widths). The user also wants to keep editing levels in the editor with CSG Blockout.

## Decision

- Build levels from a kit of small `@tool` scenes with a few exported parameters (`Ledge` height, `Gap` width, `VentSegment` length/turn, `SurfaceFloor` surface, `Ramp` angle, `Doorway`, `Sign`). Each part enforces [level metrics](../levels/metrics.md) and sets its own `surface` metadata.
- Levels stay hand-authored `.tscn` files composed of kit instances plus free CSG where needed. Agents place parts; the user edits them in the inspector.
- Graybox look: CSG Blockout's world-aligned triplanar grid shader (1 m grid, 0.5 m subdivisions), copied with its MIT licence into `assets/materials/graybox/` so the game does not depend on an editor addon at runtime. One material per surface (concrete, carpet, wood, metal, grass) plus wall, ceiling, hazard and interactive.
- Built in M2 in parallel with the stimulus framework; the hub and movement course are converted as the first users.

## Alternatives considered

- **Build scripts generating levels**: fastest for agents and reviewable, but regeneration overwrites editor edits and creates two sources of truth.
- **Raw hand-authored CSG** (M1 approach): full editor freedom, but slow and error-prone for agents, large diffs.
- **Referencing the addon's materials in place**: no copy, but couples runtime visuals to an editor plugin.

## Consequences

- Upfront cost of one agent task; `@tool` scripts run in the editor and must be written defensively (no errors on partial state).
- Metric changes (e.g. gravity) are fixed once in the part, not in every level.
- The grid gives a visible scale reference for playtests and screenshot reviews.
