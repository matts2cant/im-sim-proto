# 143. Factions per level, territory and restricted zones, provocation (M15)

Status: Accepted

Date: 2026-11-13

## Context

Sides were hardcoded as kind tags: perception and lasers hostile to `actor.player`, turret presets naming `actor.guard` (audit finding S6, deferred to M15). The roadmap's M15 asked for NPC groups allied, neutral or hostile to each other, a coloured crosshair and hostility in perception. The user and the chief engineer settled it in a design review (three rounds); the user proposed the territory model and asked for Hitman-style trespassing (IO Interactive).

## Decision

The full specification is [factions.md](../game/factions.md):
- faction resources and faction tags on characters and devices; **relations are per level** (hostile / neutral / allied per pair) and can change with a "set relation" effect;
- generic rules: hostile factions fight everywhere; neutral ones ignore each other outside zones; allied ones may enter each other's zones and help each other;
- **zones** (territory, restricted) owned by a faction: territory escalates Hitman-style (warn, follow, warn again, hostile after about 6 s), restricted is hostile at once; illegal actions seen in territory (drawn weapon, carrying a body, picking a lock, hacking) escalate too; zone hostility ends about 30 s after losing the target;
- **provocation**: damaging or stunning a neutral or allied character makes the attacker personally hostile to the victim's faction and its allies (witnesses) for the rest of the level;
- fight or flee by capability (armed fights, unarmed moves away and alerts allies), simple until M16;
- devices follow the same rules; a hacked turret's preset overrides its faction's relations;
- red / white / green on the crosshair caps and the frame brackets, the frame naming the faction; per-faction Kenney character models;
- the warehouse stays player versus Security; the hub gets a factions test room with three test factions and a relations control panel.

## Alternatives considered

- **Hostile tag lists per sensor (today)**: every new NPC type would need every config edited.
- **One global relations table**: the setting changes over the story; relations belong to the level.
- **Rules naming specific factions** ("guards and gang attack each other"): rejected by the user; only generic rules.
- **A reputation score**: provocation per individual is enough for now.
- **Disguises**: not planned.
- **Mines that spare allies**: kept hitting everyone; the mine's tag filter allows it later.

## Consequences

- Perception, turrets, lasers, cameras, combat and the HUD read relations instead of kind tags; the `actor.*` tags keep describing what an entity is.
- New: faction resources, the per-level relations table and its effect, zone volumes (kit part), illegal-action state tags, the territory escalation in awareness, per-faction character models, the hub factions room (possibly a second floor).
