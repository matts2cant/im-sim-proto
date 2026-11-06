# 51. Single Interactor and HUD prompts

Status: Accepted

Date: 2026-11-06

## Context

Until M4, E was decided in two places: the player looked for a `Usable` and otherwise `PlayerCarry` ran its own look ray to pick up a physics object. M5 adds item pickups, and the player needs to know before pressing E what will happen (pick up, carry, use, too heavy). M8 adds doors, keypads and terminals that will also answer to E.

## Decision

- One `Interactor` component on the player resolves the target once per physics tick: one ray from the eyes, 2.0 m (`interact_reach`), on layers 1, 4 and 5 (world, objects, hitboxes), excluding the player and its own hitboxes. A hitbox stands for its character.
- Resolution by components on the hit entity, in this order: `ItemPickup` (pick up), `Usable` (use, with its verb), `Carryable` (carry, or "Too heavy" above the carry limit). While carrying, E puts down.
- The result is a kind, a target and a prompt string (`Interactor.prompt_for`, pure): "E: pick up Multitool (3)", "E: reset Training dummy", "E: carry Small crate", "Too heavy", "E: put down Small crate". The HUD shows the prompt under the reticle; E calls `perform()`, which re-resolves and does exactly what the prompt said.
- Failures give feedback through the HUD message line ("No room in inventory") and the EventLog.

## Alternatives considered

- **Each component raycasts for itself** (M3/M4 style): the prompt and the action can disagree, and priority is implicit in call order.
- **Area3D proximity instead of a ray**: picks things behind you or behind cover; DX1 is crosshair-based.
- **Prompt text on each component**: duplicates the wording rules; a pure function is easier to test and keep consistent.

## Consequences

- New interactables (doors, keypads in M8) add a component and one branch in the resolver.
- The interaction mask no longer includes layer 3 (actor bodies): characters are reached through their hitboxes.
- `PlayerCarry.try_pick_up()` remains for its own tests; the game path is `try_pick_up_body()` from the Interactor.
