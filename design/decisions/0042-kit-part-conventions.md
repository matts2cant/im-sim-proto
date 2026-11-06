# 42. Kit part conventions

Status: Accepted

Date: 2026-11-06

## Context

The graybox kit ([ADR 0037](0037-graybox-kit.md)) must let an agent place a part with one instance, a transform and one to three properties, let the user edit parts in the inspector, and catch metric mistakes ([metrics](../levels/metrics.md)) where they are made. Details per part: [kit](../levels/kit.md).

## Decision

- **One node per part**: the part's root is the CSG root (`CSGCombiner3D` via `KitPart`), with `use_collision` and the `surface` metadata (StringName) footsteps read; `Sign` is a `Label3D`. Materials follow the surface automatically.
- **Anchor points**: parts that stand on the ground have their origin at ground level on their front edge and extend towards -Z (Ledge: bottom of the lip; Ramp: low edge; Gap: near edge of the near platform). Floors and rooms anchor at the centre of their walkable surface. The transform is where the player meets the part.
- **Connection points**: parts that chain expose them in code. `VentSegment.exit_transform()` is the next segment's transform relative to this one (straight: (0, -drop, -length); corners: (∓0.6, 0, -0.6) turned ±90°); housings end exactly at the entry and exit planes. A `Gap` chains by placing the next one at the far platform's near edge with `near_platform` off.
- **Rebuild on set**: every exported property has a setter that regenerates the part's CSG children. Generated children are internal nodes without an owner: never saved, never duplicated, hidden in the editor, and they exist right after `instantiate()` (no tree needed), so tests and tools can inspect them immediately.
- **Warnings, not errors**: `@tool` scripts never error on partial state. Values outside the legal range are clamped for the geometry and reported by `_get_configuration_warnings()`; the stored value is kept so the warning stays until fixed. Metric grey zones (between ledge bands, between gap difficulties, doors that force crouch) warn without clamping. Read-only hints (`Ledge.band`, `Gap.difficulty_label`) are editor-only properties.

## Alternatives considered

- **Owned generated children saved in the scene**: visible and editable, but every rebuild changes the `.tscn`, and duplicating a part duplicates its geometry twice.
- **Build on `_ready` / deferred rebuild**: fewer rebuilds, but children would not exist on an uninstanced or out-of-tree node, and tests would need the tree.
- **Hard errors for metric violations**: stops the editor on half-typed values; warnings keep editing fluid while still visible in the scene tree.

## Consequences

- Each property change rebuilds a handful of nodes; cheap for kit-sized parts.
- Tests reach generated nodes by name (`Ledge/Block`, `Room/<opening node_name>`); renaming them is an interface change.
- New parts follow the same pattern: extend `KitPart`, override `_build()` and `_surface_name()`, document origin and connection points in [kit](../levels/kit.md).
