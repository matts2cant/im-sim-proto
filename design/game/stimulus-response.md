# Stimulus and response

Milestone: M2 (`StimulusSystem` autoload added in M2); M3 added LINE_OF_SIGHT propagation and `cause_id`. Used by M3 onwards.

## Purpose

The systemic core, modelled on the Dark Engine "Act/React" approach (Thief, System Shock 2). Anything that happens in the world is a stimulus; anything that can react holds receptrons. Emergent chains come from effects that emit further stimuli.

## Player-facing behaviour

The player never sees the framework directly. They see consequences: a shot barrel explodes, nearby crates burn, a guard hears the noise and investigates. Footsteps and landings already emit `noise` stimuli (M2).

## Rules

### Stimulus (`core/stimulus/stimulus.gd`)

| Field | Meaning |
|---|---|
| `type` | StringName, hierarchical: `noise`, `fire`, `damage.ballistic`, `damage.blunt`, `damage.stun`, `damage.fire`, `damage.explosive`, `force.blast`, `force.impact`, `heal`, ... |
| `intensity` | float; for noise the loudness in audible metres ([ADR 0032](../decisions/0032-noise-loudness-audible-metres.md)) |
| `origin`, `source` | world position; the causing node (may be null) |
| `shape` | `RADIUS` (sphere of `radius`), `CONTACT` (`target` node), `RAY` (`direction` x `length`, first collider on `collision_mask`, ignoring `exclude`) |
| `propagation` | RADIUS only: `STRAIGHT` (straight line), `PATH` (navmesh path, used by noise) or `LINE_OF_SIGHT` (straight line, blocked by world geometry; used by fire and explosions) |
| `id`, `depth` | set by the system on emit: unique id; chain depth (0 outside processing, parent + 1 for effect emits) |
| `cause_id` | id of the stimulus that caused this one, across chains; 0 = none. `emit()` fills it with the parent's id when left at 0; components that re-emit on their own tick set it themselves (a burning crate's pulses carry the id of the stimulus that ignited it, [ADR 0046](../decisions/0046-heat-accumulation-fire-model.md)) |
| `source_label` | the source's name, remembered on emit, so the log still names a source freed before processing (a breaking crate's noise) |

Constructors: `Stimulus.make_radius()`, `make_noise(loudness, origin, source)` (intensity = radius = loudness, PATH), `make_contact()`, `make_ray()`.

Forces and healing are stimuli too ([ADR 0057](../decisions/0057-forces-item-use-and-heat-as-generic-systems.md)):

| Type | Shape | Intensity | Emitted by | Reacted to by |
|---|---|---|---|---|
| `force.blast` | RADIUS, LINE_OF_SIGHT | impulse in N s at the centre, linear falloff to 0 at the radius; direction = origin to the receiving entity | `Explosive` (`ExplosiveConfig.impulse` / `impulse_radius`) | every `PhysicsObject` (`pushed_by_force` receptron, `ApplyImpulseEffect`, lift 0.3) |
| `force.impact` | RAY | impulse in N s along `stimulus.direction`, at the hit `position` | ranged weapons (`WeaponData.impact_impulse`) | every `PhysicsObject` (same receptron) |
| `heal` | CONTACT on the user | health restored, split over damaged parts | consumable items (`ItemData.use_stimuli`) | characters (`heal` receptron, `HealEffect`, `include_self`) |

### Falloff ([ADR 0038](../decisions/0038-linear-falloff-noise-metres.md))

- RADIUS: `perceived = intensity x (1 - distance / radius)`, delivered only while `distance <= radius`.
- Noise is emitted with `intensity = radius = loudness`, so `perceived = loudness - distance`: the metres of margin left. A guard with `min_intensity 2` hears a noise only from 2 m inside its audible range.
- CONTACT and RAY: `perceived = intensity`.

### Propagation and delivery

- **RADIUS / STRAIGHT**: every registered receiver within `radius` of `origin` (straight line, through walls).
- **RADIUS / PATH** ([ADR 0039](../decisions/0039-path-propagation-sound-attenuators.md)): distance = |origin to its nearest navmesh point| + navmesh path length (`NavigationServer3D.map_get_path` on the receiver's world map, usually the default 3D map) + |path end to receiver|, plus `extra_metres` of every enabled `SoundAttenuator` the straight segments of that polyline cross (each attenuator counted once).
  - No navmesh on the map, or no path found: straight-line distance (attenuators on that line still count); the reception is logged with `propagation: "straight_fallback"`.
  - Receivers further than `radius` in a straight line are skipped before any path query (a path is never shorter).
- **RADIUS / LINE_OF_SIGHT** (M3): straight-line distance, delivered only when a ray from `origin` to the receiver hits nothing on collision layer 1 (world, [ADR 0045](../decisions/0045-collision-layers.md)); the source's and the receiver entity's own bodies are excluded (a barricade on the world layer receives fire aimed at its centre; a brazier emits from inside itself). Physics objects (layer 4) never block. Logged with `propagation: "line_of_sight"`.
- **SoundAttenuator** (`core/stimulus/sound_attenuator.gd`): an `Area3D` in group `sound_attenuator` with `extra_metres` and `enabled`. Only the volumes of its `CollisionShape3D` children matter (box and sphere exact, other shapes by bounding box); no physics monitoring. M8 closed doors toggle `enabled`.
- **CONTACT**: the receivers of `target`, or of its nearest ancestor that has receivers (a hitbox delivers to its entity).
- **RAY**: `intersect_ray` from `origin` along `direction` for `length` on `collision_mask` (default all layers; weapons use `PhysicsLayers.WEAPON_MASK`: world, objects, hitboxes), excluding the source body and the `exclude` RIDs (a shooter's own hitboxes); the receivers of the first collider (same ancestor rule). M4, [ADR 0047](../decisions/0047-hitboxes-layer-5-part-aware-ray.md).
- **Delivery data** (M4): receivers pass it to their effects (`EffectContext.data`). CONTACT: `distance` 0 and `collider` (the target node). RAY: `distance`, `collider` (the node hit, e.g. a hitbox), `position` and `normal`. RADIUS: `distance`, `propagation`. `ctx.collider()` returns the collider; body-part damage reads the hitbox's `body_part` from it.
- Receivers are only delivered to when one of their receptrons matches the type (and, for own stimuli, opts in): no log noise, no path queries for deaf receivers.

### StimulusReceiver, Receptron, Effect

- **StimulusReceiver** (`Node3D` component): `receptrons: Array[Receptron]`; distances are measured to the receiver node, so put it where the entity perceives from (a guard's head). Exported paths, resolved once in `_ready`: `entity_path` (default `..`), `tags_path` (`../Tags`), `attributes_path` (`../Attributes`); the last two are optional. Registers with `StimulusSystem` in `_ready` (and on re-entry), unregisters on exit.
- **Self-exclusion**: a stimulus whose `source` is the receiver's entity (or inside it) only reaches receptrons with `include_self = true`.
- **Receptron** (Resource): `stimulus_type` (exact or ancestor: `damage` matches `damage.fire`; empty matches nothing), `min_intensity` / `max_intensity` (inclusive, on the perceived intensity; `max <= 0` = no max), `required_tags` (all), `blocked_tags` (none), `include_self`, `effects`. Every matching receptron runs its effects in order.
- **Effect** (Resource, `apply(ctx: EffectContext)`; `can_apply(ctx) -> bool`, default true, says whether apply() would change anything, asked by the dry run below): `AddTagEffect`, `RemoveTagEffect`, `ApplyModifierEffect` (adds a copy of its `Modifier` to the entity's `Attributes`; `replace_same_source` stops stacking), `EmitStimulusEffect` (type, intensity, shape, radius, propagation, ray direction/length; origin = receiver position, source = entity, CONTACT target = the source of the stimulus reacted to), `PlayCueEffect` (one-shot `AudioStreamPlayer3D` at the receiver, freed when finished), `LogEventEffect` (records an EventLog entry of its `kind` with the stimulus id, type, perceived intensity and shape; a stand-in reaction before a system exists), `ApplyImpulseEffect` (pushes a `RigidBody3D` entity with the perceived intensity as an impulse in N s; RADIUS away from the origin tilted up by `radial_lift`, RAY and CONTACT along `stimulus.direction`, at the RAY hit `position` when there is one; [ADR 0057](../decisions/0057-forces-item-use-and-heat-as-generic-systems.md)). Object effects live with the objects: `HeatEffect`, `DamageEffect` ([objects-and-fire.md](objects-and-fire.md)); characters use `BodyDamageEffect` ([damage.md](damage.md)) and `HealEffect` (`heal` -> `BodyParts.heal`, can_apply only when alive and hurt). New effect = small subclass.
- **EffectContext**: `receiver`, `entity`, `stimulus`, `perceived`, `data` (delivery data, above), plus `tags()` / `attributes()` (null without the component) and `collider()`.

### StimulusSystem (autoload, `core/stimulus/stimulus_system.gd`)

- `emit(stimulus, parent = null)`: assigns `id` and `depth` (depth of `parent` or of the stimulus being delivered, + 1; else 0) and queues. Beyond `MAX_DEPTH` (16) it is dropped and logged.
- `_physics_process`: takes the whole queue and delivers it FIFO. Stimuli emitted meanwhile (by effects) form the next tick's queue: no recursion.
- `emit_now(stimulus)` ([ADR 0057](../decisions/0057-forces-item-use-and-heat-as-generic-systems.md)): outside stimulus processing it delivers at once (a deliberate act from input or UI: using an item, also while the inventory screen pauses the game); called from an effect during processing it queues like `emit()`. What its effects emit is queued as its children.
- `would_affect(stimulus)`: dry run of a CONTACT stimulus: true when delivering it now would run an effect whose `can_apply()` is true (same type, intensity, tag and self rules as delivery; nothing run or logged). Other shapes: true. Used to refuse a consumable that would do nothing.
- `clear()` drops the queue (level change, quickload). The queue is transient and not saved; tags and attributes are.
- `stimulus_processed(stimulus, paths)` signal after each delivery, with the PATH polylines and ray segments: for debug overlays only.
- There is no `process_now()`: tests drive physics frames. Note that awaiting `physics_frame` resumes before that frame's processing, so a stimulus emitted from a test is observable after two awaits.

### EventLog kinds

| Kind | Source / target | Data |
|---|---|---|
| `stimulus.emitted` | source name / contact target | `id, type, intensity, origin, depth, source, shape, cause_id` (logged when the stimulus is processed, i.e. enters the world) |
| `stimulus.received` | source name / entity name | `id, type, perceived, distance`, plus `propagation` (`straight`, `path`, `straight_fallback`, `line_of_sight`) for RADIUS; `collider` (name) for CONTACT and RAY, `position` and `normal` for RAY |
| `receptron.fired` | source name / entity name | `id, receptron` (resource_name, else index), `effects` (class names) |
| `stimulus.dropped` | source name | `id, type, depth` |

Per receiver the reception is logged, then its receptron firings, then the next receiver.

Object and player kinds (M3, [objects-and-fire.md](objects-and-fire.md)): `object.ignited {object, by, heat}`, `object.burnt_out`, `object.exploded {object, by}`, `object.damaged {object, type, amount, health}`, `object.broken {object, reason, by, debris, contents}`, `object.impact {object, other, speed, loudness}`, `player.picked_up`, `player.dropped {object, how}`, `player.threw {object, speed}`, `player.pickup_refused {object, mass, limit}`, `debug.spawned {object, scene}`.

Damage and weapon kinds (M4, [damage.md](damage.md), [weapons-and-aiming.md](weapons-and-aiming.md)): `actor.damaged {actor, part, type, amount, health, by}`, `actor.stunned {actor, amount, stun, behind, aware, by}`, `actor.knocked_out {actor, stun, by}`, `actor.died {actor, by}`, `actor.healed {actor, amount, requested}`, `actor.reset`, `item.use_refused {object, reason}`, `weapon.equipped`, `weapon.holstered`, `weapon.fired {weapon, magazine, spread, hit}`, `weapon.swung {weapon, hit}`, `weapon.dry_fire`, `weapon.reload_started`, `weapon.reloaded`, `weapon.refused {weapon, reason}`, `level.reset {scene}`. `by` is the id of the damaging stimulus. (`player.hurt` from M3 is gone: the `body_damage` receptron replaced it.)

Inventory kinds (M5, [inventory.md](inventory.md)): `item.picked_up {item, count, left}`, `item.pickup_refused {item, count, reason}`, `item.dropped {item, count}`, `item.used {item, action}`, `item.use_refused {item, reason}` (was `{object, reason}` for the M4 world medkit), `debug.gave_item {item, count}`.

Tracing a fire: `object.ignited.by` is the id of the stimulus that lit it; that stimulus's `stimulus.emitted` entry names its source (the burning neighbour) and its `cause_id`, which equals the neighbour's own `object.ignited.by`; repeat until a stimulus with `cause_id` 0.

## One tick

```mermaid
sequenceDiagram
    participant F as FireSource / game code
    participant SS as StimulusSystem
    participant C as Crate StimulusReceiver
    participant L as Listener StimulusReceiver
    participant EL as EventLog
    F->>SS: emit(fire) (queued, depth 0)
    Note over SS: tick t: _physics_process takes the queue
    SS->>EL: stimulus.emitted fire
    SS->>C: receive(fire, perceived)
    C->>EL: stimulus.received
    C->>C: receptron matches type, intensity, tags
    C->>EL: receptron.fired
    C->>C: AddTagEffect state.burning
    C->>SS: EmitStimulusEffect: emit(noise) (queued for t+1, depth 1)
    Note over SS: tick t+1
    SS->>EL: stimulus.emitted noise
    SS->>SS: navmesh path + attenuators -> distance
    SS->>L: receive(noise, loudness - distance)
    L->>EL: stimulus.received, receptron.fired
```

## Class diagram

```mermaid
classDiagram
    class Stimulus {
        StringName type
        float intensity
        Vector3 origin
        Node source
        Shape shape
        float radius
        Propagation propagation
        int depth
        int id
        int cause_id
        perceived_at(distance) float
    }
    class StimulusReceiver {
        Array~Receptron~ receptrons
        Node entity
        Tags tags
        Attributes attributes
        receive(stimulus, perceived, data)
    }
    class Receptron {
        StringName stimulus_type
        float min_intensity
        float max_intensity
        Array required_tags
        Array blocked_tags
        bool include_self
        Array~Effect~ effects
        matches(type, perceived, tags) bool
    }
    class Effect {
        apply(ctx)
    }
    class StimulusSystem {
        emit(stimulus, parent)
        clear()
        signal stimulus_processed
    }
    class SoundAttenuator {
        float extra_metres
        bool enabled
        crosses(points) bool
    }
    StimulusSystem --> Stimulus : queues
    StimulusSystem --> StimulusReceiver : delivers to
    StimulusSystem --> SoundAttenuator : path attenuation
    StimulusReceiver o-- Receptron
    Receptron o-- Effect
    Effect <|-- AddTagEffect
    Effect <|-- RemoveTagEffect
    Effect <|-- ApplyModifierEffect
    Effect <|-- EmitStimulusEffect
    Effect <|-- PlayCueEffect
    EmitStimulusEffect ..> StimulusSystem : emit chains
```

## Stimulus chain example

```mermaid
flowchart LR
    A["Pistol shot"] -->|"damage.ballistic"| B["Barrel receptron"]
    B -->|"effect: emit"| C["damage.explosive + noise"]
    C --> D["Crate 2 receptron"]
    C --> G["Guard 1 receiver"]
    D -->|"effect: add tag state.burning"| E["Crate 2 burning"]
    E -->|"emit fire (next tick)"| F["Neighbour crates"]
    G -->|"awareness: Suspicious"| H["Guard 1 investigates"]
```

## Interactions

- Tags and attributes: [attributes-and-tags.md](attributes-and-tags.md)
- Noise sources and surfaces: [movement.md](movement.md)
- Fire and explosions: [objects-and-fire.md](objects-and-fire.md)
- Damage types: [damage.md](damage.md)
- Hearing and reactions: [perception-and-ai.md](perception-and-ai.md)
- Door attenuation: [security.md](security.md)
- Live log and Overlays tab: [debug-panel.md](debug-panel.md)
- Architecture: [../tech/architecture.md](../tech/architecture.md)

## Open questions

- Chain depth only follows effect emits (or an explicit `parent`). Components that re-emit on their own tick (a burning crate's periodic `fire`) start a new chain at depth 0 and link back through `cause_id` (decided in M3, [ADR 0046](../decisions/0046-heat-accumulation-fire-model.md)).
- A receiver whose nearest navmesh point is unreachable from the noise gets the partial path plus a straight tail through the wall (never shorter than the straight line). Revisit if sealed rooms hear too much.
