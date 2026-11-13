# 136. Event kinds in one class, entries carry entities, attribution by tag

Status: Accepted

Date: 2026-11-13

## Context

The audit of 2026-11-13 (S1, S22, S25, Q21) found the EventLog, a 2000-entry debug ring buffer, used as the gameplay event bus with its contract held by strings: kinds were literals in emitters and copied constants in consumers (MissionTally, HitMarkerRules, NetworkFeedback, PickUpObjective), data keys were undocumented, and the player was recognised by node name (`player_names`, `shooter_names`, `entity.name == device_name`), so the Mission renamed the spawned player "Player" to fit. Reinforcements were sent by calling `GradedAwareness.search_at()` directly, past the radio and jamming rules every other dispatch obeys. Kinds shared the dotted namespace of tags (`actor.died`, `actor.guard`).

## Decision

- **Two roles of the EventLog**: `entry_added` is the stream of gameplay events; the ring buffer is history for the debug panel and scenario tests. Gameplay listens to `entry_added` and keeps what it needs; it never reads `entries()` or `find()`.
- **One class of kinds**: `EventKinds` (`events/event_kinds.gd`, a new top-level feature folder, since kinds are game content and `core/` is content-free) holds every kind as a `StringName` constant. Emitters record and consumers match the constants. The kinds `core/` records itself (`stimulus.*`, `receptron.fired`, `game.saved`, `game.loaded`, `level.reset`) are constants of the core classes, aliased by EventKinds. A test scans the code for `EventLog.record("...")` literals.
- **Documented contract**: the kinds gameplay reads carry a "Consumed" doc comment naming the reader, the entities (source, target, data key) and the data keys with their types. A contract test per kind drives the real emitter on a minimal entity and checks them (`tests/events/`).
- **Entries carry entities**: `EventLog.record()` takes entities (Nodes) or display names for source and target, and Node values in `data`. `EventLogEntry.make()` stores the display names (unchanged for the debug panel and existing assertions) and the entities by instance id; `entry.entity(role)` returns the live entity or null. No new references keep freed nodes alive or crash on them.
- **Attribution by tag**: "the player did it" means the entity has the mission's player tag (`MissionData.player_tag`, `actor.player`); a stimulus is the player's when its `stimulus.emitted` source entity has the tag or its cause is the player's (ADR 0087's cause chain, unchanged). A HUD's hit markers watch the HUD's own character by reference (any character with a HUD, and a namesake is not it). Objects remembered across a save (broken, lit) are keyed by node path, the identity `LevelSnapshot` uses. The spawned player keeps its scene's root name; nothing renames it.
- **Naming convention** (S25): kinds are `<subject>.<what happened>`, a past participle or an event noun; tags name states. The strings stay as they are (both dotted); a test checks that no kind appears as a tag in any scene or resource.
- **Reinforcements by radio** (S22): the Mission sends each arriving guard a CONTACT `MissionData.dispatch_type` (`alert.dispatch`) stimulus from the `ReinforcementSpawn` marker about the incident, the radio base station's dispatch. Their `heard_dispatch` receptron decides: they need a radio, and a jamming field over the marker or the guard loses it (`radio.jammed`).

## Alternatives considered

- **A prefix on every kind** (`ev.actor.died`): makes kinds look unlike tags, but rewrites about a thousand literals in tests and breaks every in-flight branch; the registry plus the no-collision test gives the same guarantee.
- **A separate gameplay signal bus** (a fourth autoload, or signals on each component): AGENTS.md allows exactly three autoloads, and the EventLog already reaches every consumer in order; the rule "listen, never scan" removes the dependency on the buffer.
- **Entity references stored as Objects in the entry**: freed nodes would turn into "previously freed" values that crash typed code; instance ids resolve to null instead.
- **Stable ids on every entity** (an exported id component): the node path is already the save system's identity and needs no data.

## Consequences

- A new kind is a constant in EventKinds; a new consumer documents the keys it reads on the constant and adds a contract test.
- Tests that build entries by hand use `EventLogEntry.make()` with entities (a tagged stand-in for the player) instead of names.
- Thrower (`items/grenades/thrower.gd`) still passes its two kinds as literals to its own `_log` helper (the file was another agent's during this change); the constants exist.
- ADR 0087's attribution text ("source is the player") now means the player-tagged entity, and its reinforcements now arrive by radio.
