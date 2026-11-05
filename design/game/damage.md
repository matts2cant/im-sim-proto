# Damage

Milestone: M4 (Shooting range).

## Purpose

Deus Ex 1 style per-body-part damage for the player and guards.

## Player-facing behaviour

A HUD body silhouette shows part health. Injuries change behaviour. Medkits heal.

## Rules

- Body parts: head, torso, left arm, right arm, left leg, right leg, with per-part hitboxes.
- Head or torso at 0 = death.
- One leg at 0 = slow; both legs = crawl.
- Arm at 0 = heavy aim sway / no two-handed items.
- Damage types: ballistic, blunt, stun, fire, explosive, with per-type resistances. They arrive as stimuli (`damage.ballistic`, `damage.blunt`, `damage.stun`, `damage.fire`, `damage.explosive`).
- Medkits heal distributed across damaged parts; the Medicine skill scales the amount ([abilities.md](abilities.md)).
- Regeneration augmentation heals body parts ([abilities.md](abilities.md)).
- `Health` component per part; pure damage rules are unit-tested.
- Stun damage and knockout: [weapons-and-aiming.md](weapons-and-aiming.md).

## Interactions

- [stimulus-response.md](stimulus-response.md), [attributes-and-tags.md](attributes-and-tags.md) (health and resistances as attributes), [movement.md](movement.md), [perception-and-ai.md](perception-and-ai.md), [objects-and-fire.md](objects-and-fire.md) (fire and explosive damage)

## Open questions

- Part health values, per-type resistance numbers, medkit distribution rule, how stun accumulates per part: TBD in M4.
