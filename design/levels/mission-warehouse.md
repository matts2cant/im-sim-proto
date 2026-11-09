# Mission: warehouse

Milestone: M9. Decisions: [ADR 0086](../decisions/0086-warehouse-mission.md).

## Goal

Break into a logistics company's warehouse at night. Read the shipment manifest in the manager's office, then reach the boat at the riverside. Two optional objectives. Every system in the game is used for a real purpose, and every main route works ghost, pacifist or loud.

## Flow

- Separate scene `levels/mission/warehouse.tscn`, loaded by walking through the hub's mission doorway (west wall, north doorway). After extraction the summary offers a way back to the hub. Nothing the player carries in the hub comes along.
- **Fixed starting kit**: baton, the loud pistol (10 in the magazine, 10 spare rounds), 1 medkit. The three augmentations (Cloak, Speed Enhancement, Combat Strength) are available, Energy at 50%. Skills at their defaults (Untrained). The mission is balanced for this kit; equipment is found along the way.
- **Start**: at a van on the north road. A short briefing (text overlay, dismissed by a key) names the objectives. Objectives are listed in the personal log; there are no on-screen waypoint markers.
- **Objectives**
  - Main: read the shipment manifest, a datapad read in place ([ADR 0060](../decisions/0060-datapads-read-in-place-personal-log.md)), in the manager's office on the upper floor of the office block.
  - Optional A: take the prototype from the vault next to the manager's office (turret; keycard or terminal).
  - Optional B: sabotage the outgoing shipment on the loading dock (blow it up or set it on fire).
- **Extraction**: a boat on the riverside behind the back gate (the back gate opens from inside). Extraction needs the main objective.
- **Summary** at extraction: time, alarms raised, kills, knockouts, optional objectives done, badges. Then "Restart mission" or "Return to hub". No route-used stat ([backlog](../backlog.md)).

| Badge | Earned when |
|---|---|
| Ghost | No guard ever reached Alerted, no alarm rang, and no body was found. Suspicious is fine. |
| Pacifist | No death caused by the player, directly or indirectly (explosions, fire, a turret the player retargeted). Knockouts are fine. |

- **Saving**: one shared quicksave slot that records the level; loading it loads that level. The knocked-out and death losing screens work as everywhere ([../game/saving.md](../game/saving.md)).
- **Reinforcements**: 30 s after the first alarm, two guards enter through the front gate (once per mission).
- **Weapon drops**: a character with a weapon (not only guards) drops it as a pickup beside the body when knocked out or killed.

## Level

Night. Compound about 70 x 50 m (x west-east, z north-south), four layers: tunnel, ground, catwalks and offices at about 4.5 m, roof at about 9 m. This sketch is a starting point: the layout agent refines it against [metrics.md](metrics.md), may change anything it finds necessary, and checks with many screenshots.

```text
                    ROAD (start: van)
 +--[GATE: booth G1, camera]-------------------------+ [WATER TOWER: sniper perch, outside fence]
 | YARD: container stacks (2 high), forklift, crates, floodlights (breaker A)  |
 |   G2 patrol           dumpster (side-door code note)          G3 patrol     |
 |  +-----------------------------------------------------+   DRAIN CULVERT  |
 |  | LOADING DOCK: roller doors, the shipment (Opt. B)   |   (outside the   |
 |  | HALL 40x25 m, 9 m high: tall shelving, catwalks at  |    fence)        |
 |  |   4.5 m, skylights; G4 catwalk rifle guard          |      | tunnel    |
 |  |   OFFICE BLOCK (corner, 2 storeys):                 |   BASEMENT:      |
 |  |   ground: security room (terminal, monitors,        |   boiler room,   |
 |  |     breaker B, operator G5), lockers, break room G6 |   hatch to hall  |
 |  |   upper: manager office (manifest) + VAULT          |   floor, duct up |
 |  |     (turret, G7 outside its door)                   |                  |
 |  +-----------------------------------------------------+                  |
 |  BACK WALL: weakened section + gas cylinders     FIRE ESCAPE to upper office|
 +---[BACK GATE: lock]---------------------------------------------------------+
                    RIVERSIDE (extraction: boat)
```

### Ways in

| Into | Ways |
|---|---|
| The compound | Front gate; over the fence from a container stacked against it; the drain culvert under the fence; the back gate (lockpick) |
| The building | Loading dock roller doors (guarded, loud); side door with a keypad (code on a note in the dumpster); roof (container stack, low annex roof, main roof; drop through a skylight onto the catwalks, or crawl a roof vent into the ducts); air ducts (1.0 m crawl: roof to above the hall catwalks and the office upper-floor ceiling; basement to security room); underground (culvert, tunnel, basement, floor hatch or service stairs); back wall breach (explosive, loud); fire escape to the upper office (mechanical lock) |

Sightlines: the water tower overlooks the yard and the skylights (sniper perch).

### Guards

About 8, mixed baton / pistol / rifle ([../game/perception-and-ai.md](../game/perception-and-ai.md)).

| Id | Post |
|---|---|
| G1 | Gate post |
| G2, G3 | Yard patrols |
| G4 | Catwalk rifle guard |
| G5 | Security operator |
| G6 | Break room |
| G7 | Vault, outside its door |
| G8 | Off-duty (asleep or idle) |

### Devices

Cameras (gate, yard, hall), the vault turret, a security terminal, an alarm controller with sirens and a panic button, a radio base station, breakers A (yard floodlights) and B (building), and at least one network switch whose breaking cuts the alarm network ([../game/security.md](../game/security.md), [ADR 0075](../decisions/0075-alarms-as-network-devices.md)).

### Systems used for a purpose

Light and breakers, floor noise, physics props to stack and throw, fire and explosives, carrying and hiding bodies, every door and lock type, keypad codes from notes, cameras, turret, terminal, alarm network, radio base station, augmentations, the new weapons including long sniper sightlines and the silencer. Two showcase moments: cutting the alarm network by breaking a switch; the sniper perch.

### Equipment to find

| Item | Where |
|---|---|
| Silencer | Break-room locker |
| Sniper rifle | Water tower perch |
| Shotgun | Security room |
| Assault rifle | The rifle guard (weapon drop) |
| Lockpicks | Basement |
| Two keycards | Vault, security room |
| Biocells x2, ammo, a second medkit | Along the routes |

Every main route works without any of them; each find opens an option.

## Targets

- Every main route is doable ghost, pacifist and loud, and covered by scenario tests.
- Ghost run 10-15 min, loud about 5 min.
- A careful first-time player gets spotted at least once but can recover.
- No route needs a precise jump or tight timing.
- Hiding spots read below 0.1 light; patrols leave crossing gaps of at least 4 s.
- Tests measure these (time to detect, run times); the numbers above are first guesses.

## Systems (M9 wave 1)

How the level uses the mission systems ([ADR 0087](../decisions/0087-mission-systems.md), [ADR 0088](../decisions/0088-weapon-drops-and-bursts.md)). Everything lives in `levels/mission/mission_kit/` (scenes, scripts, data) and `ui/mission/` (screens); the level only places nodes:

| Node in `warehouse.tscn` | What | Notes |
|---|---|---|
| `PlayerSpawn` | Marker3D | The player starts here facing the marker's -Z (the van on the north road). The level does **not** place a Player: the Mission spawns `actors/player/player.tscn` there (a placed player tagged `actor.player` would be used instead). |
| `ReinforcementSpawn` | Marker3D | Outside the front gate; the two reinforcements appear here, 1.5 m apart along the marker's X, facing its -Z. Keep 1 m of free navmesh on both sides. |
| `Extraction` | instance of `mission_kit/extraction_zone.tscn` | Invisible box standing on the node's origin, `size` 4 x 3 x 4 m by default (set it to the boat's jetty). Ends the mission once the main objective is done; before that it shows "Read the manifest first". |
| `Mission` | instance of `mission_kit/mission.tscn` | `data` = `mission_kit/warehouse_mission.tres`. One per level. |

- **Data** (`warehouse_mission.tres`, a `MissionData`): briefing text; objectives: main `manifest` (`ReadEntryObjective`, entry id `warehouse.manifest`), optional `prototype` (`PickUpObjective`, item id `prototype`), optional `shipment` (`SabotageObjective`, tag `mission.shipment`); kit: baton, pistol (10 in the magazine), 10 pistol ammo, 1 medkit; energy 50%; augmentations Cloak, Speed Enhancement, Combat Strength; reinforcements: two `guard_pistol.tscn`, 30 s after the first alarm.
- **What wave 2 must match**: the manifest datapad's `Readable.entry_id` is `warehouse.manifest`; the prototype is an item with id `prototype` (a new `ItemData` in the catalogue, placed as a pickup in the vault); every part of the shipment carries the tag `mission.shipment` (add it to the props' `Tags.initial_tags`; any one of them broken, exploded or burning completes the objective).
- **Guards**: `guard_baton.tscn`, `guard_pistol.tscn`, and `guard_rifle.tscn` for the catwalk guard (G4; bursts of 3-5 rounds). Every guard drops its weapon as a pickup beside the body when knocked out or killed, so the assault rifle is found on G4.
- **Alarms**: any alarm controller's first ring starts the reinforcement timer; the reinforcements search where that alarm was raised.
- **Flow**: hub west north doorway (`MissionExit`, a `LevelExit`) -> warehouse (briefing, paused) -> extraction -> summary -> "Restart mission" or "Return to hub". The summary shows time, alarms raised, kills, knockouts, optional objectives done and the Ghost and Pacifist badges.
- **Test fixture**: `tests/levels/mission/mission_kit/fixtures/mission_fixture.tscn` is a small mission level with the same contract (see `mission_helpers.gd`); screens can be reviewed with `fixtures/mission_shots.tscn` (`-- shot=briefing|toast|summary|weapon_drop out=<png>`).

## Network (M11)

A sketch, not a layout ([../game/hacking.md](../game/hacking.md)). M9 places the hooks as M8 devices: a wireless access point spot covering the yard, an office wall jack, two office computers (credentials-placeholder terminals), the security console. Three subnets behind one gateway, FW-01, which runs the "Sentry" tracer watching Guest and Office:

```text
  [AP Guest] ~~ range reaches the yard (side door, dumpster)
      |
  Guest 10.0.1.0/24 ---+
                       |
  Office 10.0.2.0/24 --+-- FW-01 (Sentry tracer: Guest, Office) -- rules: Guest -> Office deny,
    office PC x2       |                                             Office -> Security deny,
    (mail with clues)  |                                             SEC-SERVER -> any allow
                       |
  Security 10.0.3.0/24 +   (unwatched by Sentry)
    SEC-SERVER (security room console; cameras, doors, turret trust it)
    3 cameras, security room door, vault turret, alarm controller, sirens, radio base station
```

- Entry: wireless from the yard (Guest), the office wall jack (Office), the office PCs bare-handed, the security console.
- Example routes: sniff a guard's login on the Guest wireless, use it on an office PC, read the mail with the security console's password hint; or break the Security switch to kill the cameras and sirens (the security room door is fail-secure, so it then needs another way in); or crack FW-01's admin account (Medium) and add a rule "you -> Security allow".
- Numbers (passwords, tracer tuning, software versions) are set in M11.

## Rules

- Success: extraction after reading the manifest (its entry is in the personal log, `PersonalLog.has(entry_id)`). Fail: death, then reload or restart.
- Route relevance: movement ([../game/movement.md](../game/movement.md)), physics and explosives ([../game/objects-and-fire.md](../game/objects-and-fire.md)), abilities ([../game/abilities.md](../game/abilities.md)).
- Scenario tests cover the routes ([../tech/testing.md](../tech/testing.md)).
- No difficulty settings.

## Milestone plan

1. Wave 1, in parallel: systems (level change, briefing and objectives, summary and badges, weapon drops, reinforcements) and the layout blockout.
2. Wave 2: population, exterior and interior in parallel (guards, devices, props, equipment).
3. Wave 3: route scenario tests and polish.

## Open questions

- Exact layout, patrol routes and device placement: settled by the layout and population agents within the targets above.
- Network layout and which guards use devices on patrol: M11.
