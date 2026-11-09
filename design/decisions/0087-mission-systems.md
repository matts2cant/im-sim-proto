# 87. Mission systems: a Mission node with data, objectives and tallies from events, death attribution by cause chain, level exits

Status: Accepted

Date: 2026-11-09

## Context

M9 wave 1 builds the systems the warehouse mission needs ([ADR 0086](0086-warehouse-mission.md)) while another agent blocks out the level. The two meet through a small contract: marker and node names in the level scene, and reusable scenes the level places. Objectives and badges must follow the systemic rules: no rule may name a specific entity, and the Pacifist badge must see deaths the player caused indirectly (a barrel it shot, the fire that started, a turret it retargeted).

## Decision

- **Contract with a mission level**: `PlayerSpawn` (Marker3D, the player starts there facing its -Z), `ReinforcementSpawn` (Marker3D), `Extraction` (an instance of `levels/mission/mission_kit/extraction_zone.tscn`: an invisible 4 x 3 x 4 m box, `size` exported) and one `Mission` (`levels/mission/mission_kit/mission.tscn`) whose `data` is a `MissionData` `.tres` (`warehouse_mission.tres` for the warehouse). The level places no player: the Mission spawns `player.tscn` at `PlayerSpawn` (a placed one tagged `actor.player` is used and moved there instead).
- **Mission start** (when the level is ready): the fixed starting kit (`StartingItem` entries) goes into the player's inventory, energy is set to `energy_fraction` of the capacity, exactly the listed augmentations are installed; a fresh player has default skills. Each objective becomes a personal-log entry (`mission.<mission>.<objective>`) through the new `PersonalLog.add()` (no reading overlay). The briefing opens: a pause screen closed by E, Enter or Esc. It does not open after a quickload.
- **Objectives are data** (`MissionObjective` subclasses in the `.tres`): `ReadEntryObjective` (`PersonalLog.has(entry_id)`), `PickUpObjective` (an `item.picked_up` of the item id by the player), `SabotageObjective` (an entity tagged `tag` at the start is gone from the level or has `state.burning` / `state.charred`). They ask an `ObjectiveContext` (the Mission answers from components and tags) or read EventLog entries; `ObjectiveTracker` is pure. Main objectives gate extraction; a missing one's `extraction_hint` ("Read the manifest first") shows as a toast when the player enters the zone.
- **Tallies from the EventLog** (`MissionTally`, pure): kills and knockouts, alarms raised (`alarm.raised` that started a ring), Alerted guards (`actor.awareness` to `alerted`), bodies found. Ghost: no Alerted, no alarm, no body found. Pacifist: no kill.
- **Death attribution follows the stimulus cause chain**: a stimulus is the player's when its source is the player or its `cause_id` is one of the player's. Blasts already name the stimulus that set them off as their parent, fires name their ignition as the cause of every pulse, so a barrel the player shot and the fire it lit are the player's. Two additions close the turret case: `Device.send_command()` takes the operator (`by`, the terminal screen passes its player) and logs it with the command's stimulus id; a turret makes the last preset or enable command it obeyed the cause of its shots (`WeaponHolder.cause_id`, saved). `actor.died` names its killing stimulus (`by`); attributed means a kill. Noise is not tracked (it never harms). Known gaps: a thrown prop's impact (its source is the prop) and fall damage after a push.
- **Stimulus ids survive saves**: a quicksave records `StimulusSystem.last_id()`; a load reserves the ids up to it (`reserve_ids()`), so ids kept in saved state (a fire's ignition, the tallies' attributed ids, a turret's cause) never name a stimulus of the new session.
- **Extraction and summary**: the mission ends while an `ExtractionZone` holds the player (feet inside the box, able to act) and every main objective is done: `mission.completed` with the results and the summary screen (paused, mouse free; "Restart mission" reloads the level, "Return to hub" loads the hub, whose player starts at its spawn with nothing; Esc does nothing).
- **Reinforcements**: `reinforcement_delay` (30 s) of mission time after the first `alarm.raised`, the data's scenes (two pistol guards) are spawned once under `Mission/Reinforcements` at `ReinforcementSpawn`, spaced 1.5 m along its X, and search the first alarm's point (`GradedAwareness.search_at`, reason `alarm`). Saves keep them as spawned entities.
- **Level change**: `levels/kit/level_exit.tscn` (`LevelExit`) loads `scene_path` when an entity with `required_tag` (the player) that can act enters its box; the hub's `MissionExit` sits in the west wall's north doorway and points at `levels/mission/warehouse.tscn`. The quicksave already records its level: loading it from any level loads that level first.
- **Saved** (the Mission is saveable): time, objectives done, tallies (with the attributed ids), briefing seen, first alarm time and point, reinforcements sent, finished.

## Alternatives considered

- **Attribution at emit time** (stamping an "instigator" on every stimulus): reaches the same answer but changes every emitter; the cause chain already exists and the EventLog is the agreed source of truth for scenario checks.
- **Objectives as scripts per mission**: rejected; three generic kinds cover the warehouse and later missions add kinds, not code per objective.
- **Waypoint markers for objectives**: rejected in ADR 0086.
- **Giving the kit through pickups at the spawn**: the hub does this; for a mission the kit is fixed and must not be left behind by accident.

## Consequences

- A new mission is a level scene with the four contract nodes and a `MissionData` `.tres`; no code.
- Mission objectives appear in the personal log alongside datapads.
- The Pacifist badge depends on every harmful emitter keeping its cause chain; new emitters that act later (timers, AI) should carry a cause like the turret does.
- Weapon drops and guard bursts: [ADR 0088](0088-weapon-drops-and-bursts.md).
