# Abilities

Milestone: M6 (Inventory and abilities bay).

## Purpose

A basic ability system without leveling. Values are edited in the debug panel's Stats tab. Built on modifiers so progression can be added later ([../backlog.md](../backlog.md)).

## Skills

Four tiers: Untrained, Trained, Advanced, Master.

| Skill | Affects |
|---|---|
| Pistols | accuracy, settle, reload |
| Low-Tech | baton damage/speed, knockout threshold |
| Electronics | multitool bypass time / multitools used |
| Lockpicking | pick time / lockpicks used |
| Medicine | heal per medkit |

## Augmentations

Powered by bioelectric energy, refilled by biocells. All usable at once in v0 (body-slot conflicts come with progression).

| Augmentation | Type | Effect |
|---|---|---|
| Cloak | toggle, drains | Invisible to guards, not to cameras/turrets |
| Run Silent | toggle, drains | Footstep noise x0 |
| Speed Enhancement | toggle, drains | Faster, higher jump/mantle, louder landings |
| Combat Strength | passive | Lift heavy objects, stronger melee |
| Regeneration | toggle, drains | Heals body parts |

## Rules

- Skills and augmentations are implemented as modifiers ([attributes-and-tags.md](attributes-and-tags.md)).
- Augmentations are triggered with F1-F4 and F6 ([controls.md](controls.md)).
- No difficulty settings in v0.

## Interactions

- [weapons-and-aiming.md](weapons-and-aiming.md), [security.md](security.md), [damage.md](damage.md), [movement.md](movement.md), [light-and-visibility.md](light-and-visibility.md), [perception-and-ai.md](perception-and-ai.md), [debug-panel.md](debug-panel.md), [saving.md](saving.md)

## Open questions

- Per-tier numbers, energy capacity, drain rates, biocell restore amount: TBD in M6.
