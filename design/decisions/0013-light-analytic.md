# 13. Light visibility computed analytically

Status: Accepted

Date: 2026-11-05

## Context

A render-based light gem cannot be tested headless.

## Decision

Compute player light level analytically: each relevant light's falloff times shadow rays to several body points.

## Alternatives considered

- Render-based light gem.

## Consequences

- Headless-testable.
- Results may differ slightly from what is rendered.
- See [light and visibility](../game/light-and-visibility.md).
