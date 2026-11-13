class_name MissionData
extends Resource
## A mission's data (ADR 0087), the `.tres` its Mission node uses: briefing, objectives, the fixed
## starting kit, the player's energy and augmentations at the start, reinforcements.

## Unique per mission: personal-log entry ids (`mission.<id>.<objective>`) and the EventLog use it.
@export var id: StringName = &""
@export var title: String = ""
## The briefing's text above the objective list.
@export_multiline var briefing: String = ""
## In order: the briefing and the summary list them this way.
@export var objectives: Array[MissionObjective] = []
## Shown at the extraction while a main objective without its own hint is missing.
@export var extraction_hint: String = "Finish the main objective first"
## Tag of the entities that are the mission's player (spawned at PlayerSpawn when none is placed).
@export var player_tag: StringName = ActorState.PLAYER

@export_group("Start")
## Given to the player at the start (nothing from elsewhere comes along).
@export var starting_items: Array[StartingItem] = []
## Energy at the start, as a share of the capacity.
@export_range(0.0, 1.0) var energy_fraction: float = 0.5
## Augmentations installed at the start (the others are removed); all start off.
@export var augmentations: Array[StringName] = []

@export_group("Reinforcements")
## Characters that enter at the level's ReinforcementSpawn once, `reinforcement_delay` seconds of
## mission time after the first alarm rings, and search where it was raised (told by a radio
## dispatch: `dispatch_type`).
@export var reinforcement_scenes: Array[PackedScene] = []
## The stimulus type that radios them to the incident: the radio base station's dispatch, so the
## `heard_dispatch` receptron (a radio, no jamming) decides whether they react.
@export var dispatch_type: StringName = &"alert.dispatch"
@export var reinforcement_delay: float = 30.0
## Sideways distance between two arrivals, centre to centre (m), along the marker's X.
@export var reinforcement_spacing: float = 1.5


## The personal-log entry id of `objective`.
func log_entry_id(objective: MissionObjective) -> StringName:
	return StringName("mission.%s.%s" % [id, objective.id])
