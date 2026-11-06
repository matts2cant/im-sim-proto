# 40. Override modifier conflict rule

Status: Accepted

Date: 2026-11-06

## Context

Several OVERRIDE modifiers can target one attribute at once (a stun forcing speed to 0 while an augmentation overrides it to a minimum). [attributes-and-tags.md](../game/attributes-and-tags.md) left "which wins?" open.

## Decision

- An attribute's value is the winning OVERRIDE's magnitude if any OVERRIDE exists; otherwise `(base + sum of ADD) x product of MULTIPLY`.
- Among OVERRIDEs the highest `priority` wins; on a tie the most recently added wins.
- `priority` is ignored for ADD and MULTIPLY.

## Alternatives considered

- **Most recent always wins**: order-dependent; a later weak effect would cancel a stun.
- **Lowest or highest magnitude wins**: right for some attributes (speed caps), wrong for others; the author knows which matters and sets the priority.
- **Overrides then still apply ADD/MULTIPLY**: makes "override" mean "replace base", which is a different op.

## Consequences

- Effects that must dominate (stun, death) use a high priority; ties stay predictable.
- Removing the winning override reveals the next one; saved modifier order (to_dict) preserves tie-breaking.
