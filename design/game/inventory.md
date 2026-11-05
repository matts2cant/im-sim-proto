# Inventory

Milestone: M5 (Inventory bay).

## Purpose

Deus Ex 1 style grid inventory.

## Player-facing behaviour

Open with I. Items occupy a footprint on the grid; a 10-slot belt (keys 1-0) references grid items. Dropped items become physics objects that can be thrown and make noise.

## Rules

- Grid is 6x5. Items have footprints (e.g. rifle 1x4, multitool 1x1). No rotation (parked: [../backlog.md](../backlog.md)).
- Consumables stack.
- The belt has 10 slots referencing grid items.
- Pick up with E, drop/throw with Q ([controls.md](controls.md)).
- Pure grid logic (placement, stacking) is unit-tested.
- Inventory is saveable ([saving.md](saving.md)).

## Interactions

- Dropped items are physics objects: [objects-and-fire.md](objects-and-fire.md)
- Medkits: [damage.md](damage.md); biocells: [abilities.md](abilities.md); multitools, lockpicks, keycards: [security.md](security.md); weapons: [weapons-and-aiming.md](weapons-and-aiming.md)

## Open questions

- Item list and footprints beyond the examples, stack limits: TBD in M5.
