# 76. Computer skill replaces Electronics; the multitool is removed

Status: Accepted (amends [ADR 0020](0020-skills-augmentations.md) and [ADR 0061](0061-abilities-model.md))

Date: 2026-11-08

## Context

The Electronics skill scaled `bypass_time_mult` for the multitool, a consumable that bypassed keypads and electronic locks (ADR 0017's placeholder). Network hacking ([ADR 0074](0074-network-hacking.md)) replaces bypassing with the deck, and keypads become network devices. Nothing is left for a multitool or for Electronics to do.

## Decision

- **Computer skill** (Untrained / Trained / Advanced / Master) replaces Electronics. It affects only the deck's tools:
  - crack time ×1 / 0.75 / 0.5 / 0.3;
  - trace gain ×1 / 0.8 / 0.6 / 0.4;
  - strongest password the Icebreaker cracks: Weak / Medium / Strong / Strong.
- Like every skill these are attributes with modifiers; the deck reads its user's attributes ([ADR 0061](0061-abilities-model.md)). Admin access allows every admin action: nothing is skill-gated beyond the Icebreaker's strength limit.
- **The multitool is removed altogether.** M8 drops the item, its pickups and `bypass_time_mult`; M8 swaps Electronics for Computer in the skill table (no consumer until M12).
- **Keypads** accept only their code until M12; then they are also hackable ("read its code").

## Alternatives considered

- **Keep the multitool as a quick bypass**: a consumable that skips the network makes the network optional and the deck pointless.
- **Keep the Electronics name**: it suggests wiring and bypasses; the skill is about computers.
- **Skill-gated admin actions**: an account already gates them; a second gate adds nothing readable.

## Consequences

- [abilities](../game/abilities.md), [inventory](../game/inventory.md), [security](../game/security.md), the hub's loadout table and the inventory bay ([hub-and-gallery](../levels/hub-and-gallery.md)) and the warehouse's side-door route ([mission-warehouse](../levels/mission-warehouse.md)) change.
- Tests and playtest checks that use the multitool as an example item are rewritten in M8.
