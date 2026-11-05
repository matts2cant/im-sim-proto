# 2. Language: typed GDScript

Status: Accepted

Date: 2026-11-05

## Context

Prototype iteration speed matters most. The project is GDScript-friendly and uses the standard (non-.NET) Godot build.

## Decision

Use statically typed GDScript.

## Alternatives considered

- C#: reconsidered later if needed.

## Consequences

- Fast iteration, no build step.
- Typing is enforced by project settings ([0030](0030-code-conventions.md)).
- C#-only addons (e.g. Forge) are not usable ([0003](0003-systemic-framework.md)).
