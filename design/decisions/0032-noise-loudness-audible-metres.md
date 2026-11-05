# 32. Noise loudness unit: audible distance in metres

Status: Accepted

Date: 2026-11-06

## Context

Footsteps, landings and later impacts, gunshots and shouts all produce noise. Designers, tests and the debug panel need one unit that is easy to reason about and that the M2 noise propagation ([ADR 0027](0027-sound-propagation.md)) can use directly.

## Decision

Noise loudness is the distance in metres at which the noise is still audible. A footstep of loudness 6 is heard up to 6 m of path distance away. Multipliers (surface, augmentations) scale this distance.

## Alternatives considered

- Decibels: realistic, but needs a falloff model to answer "who hears it" and is hard to tune by eye.
- Abstract 0..1 intensity: says nothing about range without a second table.

## Consequences

- A `noise` stimulus's intensity is its audible distance; propagation compares it with the navmesh path length to each listener.
- Debug overlays can draw the loudness as a radius directly.
- Values: [movement](../game/movement.md).
