# Attributes and tags

Milestone: M2.

## Purpose

A shared model for state and stats. Tags describe what something is or is currently doing; attributes hold numbers; modifiers change numbers. Skills, augmentations, damage effects and later progression are all modifiers, so the same framework carries them.

## Player-facing behaviour

Indirect: a burning crate, a slowed player with a damaged leg, a skill tier that speeds up lockpicking are all tag/attribute/modifier changes.

## Rules

### Tags (`core/attributes/`)

- Hierarchical StringNames (`material.metal`, `state.burning`, `actor.guard`). In use since M3: `material.wood|metal|glass|cardboard`, `object.crate|box|barrel|explosive|bottle|barricade|brazier`, `state.burning`, `state.charred`, `actor.player` ([objects-and-fire.md](objects-and-fire.md)).
- `TagContainer` (RefCounted): `add(tag)`, `remove(tag)` (exactly that tag, not its descendants), `has(query)`: true if `query` or any descendant is held (`has(&"material")` while `material.metal` is held; `material` does not match `materials`). Also `has_exact`, `has_all`, `has_any`, `tags()`. Signal `changed(tag, added)`, only on real changes. `to_dict()` / `from_dict()`.
- `TagContainer.matches(tag, query)` is the one hierarchy rule; receptron stimulus types use it too.
- `Tags` component (Node): `initial_tags` exported for the inspector, added in `_ready`; `container` holds the live tags. Saveable (`save_state` / `load_state`, group `saveable`).

### Attributes

- `Modifier` (Resource): `attribute`, `op` (`ADD` | `MULTIPLY` | `OVERRIDE`), `magnitude`, `priority` (OVERRIDE only), `source` (StringName, for removal).
- `AttributeSet` (RefCounted): named base values (`set_base`, `base`), `add_modifier` (one instance is applied at most once), `remove_modifier`, `remove_by_source(source)`, `value(name)`. Signal `changed(name, old, new)`, emitted only when the value actually changes. `to_dict()` / `from_dict()` (bases and modifiers in order).
- Attributes without a base value start from 0.
- `Attributes` component (Node): `base_values: Dictionary[StringName, float]` exported, applied in `_ready`; `attribute_set` holds the live set. Saveable.
- Attributes in use since M3: `health` on objects (Breakable lowers its base value), `carry_mass_limit` on the player (base 20 kg; Combat Strength adds a modifier in M6).

### Evaluation

**value = the winning OVERRIDE if any, else (base + sum of ADD) x product of MULTIPLY.**

- Override conflicts ([ADR 0040](../decisions/0040-override-modifier-conflict-rule.md)): the highest `priority` wins; on a tie the most recently added wins. Removing the winner reveals the next one.
- ADD and MULTIPLY ignore `priority`; their order does not matter.

```mermaid
flowchart TD
    B["Base value (0 if unset)"] --> O{"Any OVERRIDE modifier?"}
    O -->|yes| P["Highest priority; tie: most recently added"]
    P --> R["Current = its magnitude"]
    O -->|no| A["base + sum of ADD magnitudes"]
    A --> M["x product of MULTIPLY magnitudes"]
    M --> R2["Current value"]
    R --> S["changed(name, old, new) if it differs"]
    R2 --> S
```

- Modifiers carry a `source` so they can be removed when the source ends (augmentation toggled off, effect expired).
- `ApplyModifierEffect` adds a copy of its modifier per firing (stacking); with `replace_same_source` it first removes modifiers of the same source.
- Pure logic (containers, evaluation) is RefCounted/Resource and unit-tested without the scene tree.

## Interactions

- Effects apply tags and modifiers: [stimulus-response.md](stimulus-response.md)
- Skills and augmentations: [abilities.md](abilities.md)
- Body-part health and resistances: [damage.md](damage.md)
- Stats tab: [debug-panel.md](debug-panel.md)
- Saving: [saving.md](saving.md)
- Progression is parked: [../backlog.md](../backlog.md)

## Open questions

- Modifier expiry (timed modifiers): add when a system needs it (M4 damage effects or M6 augmentations); today the source removes its modifiers.
- Clamping (health >= 0, max values): left to the owning component (M4 `Health`).
