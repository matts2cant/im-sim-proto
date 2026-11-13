# Factions

Milestone: M15 ([ADR 0143](../decisions/0143-factions-territory-and-provocation.md)). Replaces the hardcoded sides (perception and lasers hostile to `actor.player`, turret presets by kind tag: audit finding S6). The territory rules take inspiration from the Hitman games (IO Interactive).

## Purpose

Who fights whom is never hardcoded. Characters and devices belong to factions; each level says how its factions relate; zones say where a faction is touchy. The same few rules give a warehouse break-in, a neutral district you should not wander in, allies who let you through, and NPCs fighting each other, and the relations can change with the story.

## Model

- **Factions** are resources (a name; characters use different Kenney character models per faction, no tints). Characters and devices carry a **faction tag** (`faction.<id>`).
- **Relations belong to the level**: each level holds a relations table (for each pair of factions: hostile, neutral or allied). The same factions can be allies in one level and enemies in a later one.
- A **"set relation" effect** changes a relation during a level (A↔B to hostile, neutral or allied): triggers use it now, dialogue and quests later (M17). The hub's factions room has buttons for it.

## Rules (for any character or device)

- **Hostile** factions are aggressive toward each other everywhere: perception treats a hostile as a threat (suspicion, alert, then combat if able); turrets fire; cameras and lasers report.
- **Neutral** factions ignore each other, except inside each other's zones and when provoked.
- **Allied** factions may enter each other's territory and restricted zones; they come to each other's help (provocation spreads to allies).

## Zones

A zone is a level volume with an **owner faction** and a **kind**:

- **Territory**: a neutral character the owners see inside it gets the escalation below.
- **Restricted**: owners treat a neutral character inside it as hostile at once.

Escalation in territory (Hitman-style): an owner who sees you warns you ("You're not supposed to be here. Leave."), follows or escorts you toward the way out, warns again; about **6 s** without leaving (or going deeper, or stepping into restricted space) makes them hostile to you. Leaving at any step calms them. A visible suspicion indicator over the owner shows the escalation. Only owners who see you react; others learn through the existing radio and alarm paths.

**Illegal actions**: inside their territory, owners also react to a neutral character seen with a drawn weapon, carrying a body, picking a lock or hacking a device (observable states as tags, e.g. `state.armed`, `state.carrying`, `state.tool_in_use`): a warning first in territory, hostile at once in restricted space.

**After a zone made them hostile**: they pursue while they see you and go back to neutral about **30 s** after losing you.

**Devices** follow the same rules: a faction's camera, laser or turret reports a neutral character in its owner's territory and reports or fires at one in a restricted zone; a hostile one anywhere. A hacked turret's target preset is an override of its faction's relations.

## Provocation

If X damages or stuns Y and Y's faction is neutral or allied to X, then Y, and every member of Y's faction or of a faction allied to it who sees it or hears the alarm, treats **X personally** as hostile for the rest of the level. The level's relations table does not change.

## Fight or flee

By capability, not faction: a character with a usable weapon fights its hostiles; one without (or out of ammo) moves away from hostiles, gunfire and explosions and alerts its allies. Kept simple: M16 replaces it.

## Feedback

- The crosshair caps and the interaction frame's brackets show the relation: **red** hostile, **white** neutral, **green** allied; the frame also names the faction ("Guard · Security").

## Explosives

Mines keep triggering on every character, the player included (their tag filter, ADR 0138, allows other rules later).

## Levels

- **Warehouse**: the player and the guards (Security), hostile as today.
- **Hub**: a new factions test room (a second floor reached by a staircase in the hub hall if the ground floor has no free footprint: measured before building) with three test factions (A, B, C), armed and unarmed members, a relations control panel (A↔B, B↔C, A↔C and each faction to the player, live), a turret and a camera owned by one faction, a territory zone and a restricted zone.

## Out of scope

Disguises (not planned), reputation scores, guards throwing grenades and full flee behaviour (M16), dialogue-driven relation changes (M17 uses the effect).
