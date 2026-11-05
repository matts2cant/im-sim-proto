# 23. Aiming: softened Deus Ex 1 reticle

Status: Accepted

Date: 2026-11-05

## Context

Pure twitch aiming ignores skill; fully random hits feel unfair.

## Decision

Use a settling reticle (about 0.8 s untrained to about 0.2 s Master) that shows the exact spread cone; shots always land inside it. Movement, firing and arm damage widen it.

## Alternatives considered

- Pure aim-based shooting.
- Hidden random spread.

## Consequences

- Pistols skill scales accuracy and settle.
- See [weapons and aiming](../game/weapons-and-aiming.md).
