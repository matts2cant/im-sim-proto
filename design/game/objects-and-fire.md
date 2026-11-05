# Objects and fire

Milestone: M3 (Physics and fire room).

## Purpose

Physics props that are throwable, breakable, flammable and explosive, giving the systemic playground.

## Player-facing behaviour

Pick up, carry and throw objects. Impacts make noise. Fire spreads to flammable neighbours. Explosive barrels blow up when shot or burned.

## Rules

- Components: `Flammable`, `Breakable`, `Health`, `StimulusReceiver` attached to objects.
- Fire spreads via `fire` stimuli to flammable neighbours; fire damage is `damage.fire`; explosions are `damage.explosive` ([damage.md](damage.md)).
- Impacts emit `noise` stimuli ([stimulus-response.md](stimulus-response.md)).
- Combat Strength lets the player lift heavy objects ([abilities.md](abilities.md)).
- Dropped inventory items become physics objects ([inventory.md](inventory.md)).
- Breakable doors and walls can be opened with explosives ([security.md](security.md)).
- Water and electricity are parked ([../backlog.md](../backlog.md)).

## Interactions

- The mission back-wall route uses a loud barrel: [../levels/mission-warehouse.md](../levels/mission-warehouse.md)
- Tags such as `state.burning` and `material.*`: [attributes-and-tags.md](attributes-and-tags.md)

## Open questions

- Burn duration, spread radius and delay, explosion radius and damage, carry weight limits: TBD in M3.
