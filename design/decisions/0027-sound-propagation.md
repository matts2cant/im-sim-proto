# 27. Sound propagation by navmesh path distance

Status: Accepted

Date: 2026-11-05

## Context

Sound should respect walls and doors.

## Decision

Noise travels by NavigationServer3D path distance, attenuated by distance and by closed doors on the path.

## Alternatives considered

- Straight-line distance: ignores walls.
- Room/portal graph: more authoring work.

## Consequences

- Depends on a valid navmesh.
- See [stimulus and response](../game/stimulus-response.md).
