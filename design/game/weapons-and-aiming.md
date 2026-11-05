# Weapons and aiming

Milestone: M4 (Shooting range).

## Purpose

One lethal and one non-lethal weapon, with a softened Deus Ex 1 aiming model.

## Player-facing behaviour

- **Silenced pistol** (lethal), **stun baton** (non-lethal).
- The reticle shows the exact spread cone; shots always land inside it.
- The reticle settles over about 0.8 s untrained down to about 0.2 s at Master. Untrained aim is reliable at short range.
- Mouse look adds small bloom. Movement, firing and arm damage widen the cone.
- Baton deals `damage.stun`: one hit from behind on an unaware guard is a knockout; otherwise several hits (Low-Tech scales).

## Rules

- Skills: Pistols (accuracy, settle, reload), Low-Tech (baton damage/speed, knockout threshold): [abilities.md](abilities.md).
- Damage types and parts: [damage.md](damage.md).
- Shots emit stimuli ([stimulus-response.md](stimulus-response.md)).
- Shot guards and lights: [perception-and-ai.md](perception-and-ai.md), [light-and-visibility.md](light-and-visibility.md).
- Controls: LMB fire/use, R reload ([controls.md](controls.md)).

## Interactions

- Ammo and items: [inventory.md](inventory.md)
- Combat Strength strengthens melee: [abilities.md](abilities.md)

## Open questions

- Spread cone angles, bloom amounts, pistol noise level, magazine size, damage numbers, baton knockout threshold: TBD in M4.
