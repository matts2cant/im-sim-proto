# 86. Warehouse mission: separate night level, fixed kit, objectives, badges, reinforcements, weapon drops

Status: Accepted

Date: 2026-11-09

## Context

M9 builds the one mission of v0. It should use every system for a real purpose, support many routes, and run ghost, pacifist or loud. Design agreed with the user. Layout and numbers: [mission-warehouse.md](../levels/mission-warehouse.md).

## Decision

- **Separate scene**: `levels/mission/warehouse.tscn`, loaded by walking through the hub's west wall north doorway. After extraction the player can return to the hub or restart.
- **Fixed kit**: nothing from the hub comes along. Baton, the loud pistol (10 in the magazine, 10 spare rounds), 1 medkit; the three augmentations available, Energy 50%, skills Untrained. The mission is balanced for this kit; found equipment (silencer, sniper rifle, shotgun, lockpicks, keycards, biocells, ammo, medkit) opens options but no main route needs it.
- **Objectives**: main (read the manifest datapad, upper-floor manager's office), optional A (vault prototype), optional B (sabotage the shipment). Listed in the personal log, introduced by a text briefing at the van dismissed by a key. No waypoint markers. Extraction (a boat behind the back gate) needs the main objective.
- **Summary screen**: time, alarms, kills, knockouts, optional objectives done, badges; then "Restart mission" or "Return to hub". Ghost: no guard ever reached Alerted, no alarm rang, no body was found (Suspicious is fine). Pacifist: no death caused by the player, directly or indirectly (explosions, fire, a retargeted turret); knockouts are fine.
- **Saving**: one shared quicksave slot recording the level; loading it loads that level. Losing screens are unchanged.
- **Reinforcements**: 30 s after the first alarm, two guards enter through the front gate, once per mission.
- **Weapon drops**: any character with a weapon drops it as a pickup beside the body when knocked out or killed (a property of the weapon holder, not of guards).
- **Level targets**: about 70 x 50 m night compound with four layers, about 8 guards, many entry routes. Ghost run 10-15 min, loud about 5 min; no precise jumps or tight timing; hiding spots below 0.1 light; patrol crossing gaps of at least 4 s. Every main route is covered by scenario tests.
- **M12 hooks**: a wireless access point spot over the yard, an office wall jack, two office computers and the security console are placed now as M8 devices.

## Alternatives considered

- **Mission inside the hub scene**: rejected; the hub's lighting and fixed footprint leave no room for a 70 x 50 m night level with four layers.
- **Carrying the hub inventory into the mission**: rejected; the player could bring anything from the test rooms and no route could be balanced.
- **Waypoint markers**: rejected; they fight the immersive-sim style. The personal log and the briefing carry the objectives.
- **Route tracking in the summary**: dropped from M9 (backlog); it needs per-route markers and adds little over the badges.

## Consequences

- Level change and a mission state (objectives, badges, reinforcement timer) are new framework needs; they follow the systemic rules (components, stimuli and tags, no identity branches).
- Pacifist needs causality tracking of deaths through explosions, fire and retargeted turrets: the damage source chain must reach the player.
- Wave plan: systems and layout blockout first, then population, then route tests and polish.
