class_name BodyProfile
extends Resource
## Tuning for a character's body parts: health per part, damage multipliers per type and part, how
## damage without a hitbox is shared out per type, what an injury does, and knockout. Fall damage
## (how fast a landing hurts) is the `fall_damage` receptron's, not the profile's (ADR 0056).
## Values live in the actor's `<actor>_body.tres`; the script only declares them (design/game/damage.md).

@export_group("Health")
@export var head_health: float = 60.0
@export var torso_health: float = 100.0
## Each arm.
@export var arm_health: float = 60.0
## Each leg.
@export var leg_health: float = 70.0

@export_group("Resistances")
## Multiplier per damage type for the whole body (`damage.ballistic`); the most specific entry wins,
## types without an entry take x1.
@export var type_multipliers: Dictionary[StringName, float] = {}
## Extra multipliers per type for one part (headshots: `damage.ballistic` x2 on the head).
@export var head_multipliers: Dictionary[StringName, float] = {}
@export var torso_multipliers: Dictionary[StringName, float] = {}
@export var arm_multipliers: Dictionary[StringName, float] = {}
@export var leg_multipliers: Dictionary[StringName, float] = {}

@export_group("Area damage")
## How a hit that arrives without a hitbox is shared out, per damage type: type -> {part: share}
## (shares sum to 1). The most specific entry wins (`damage.fire` covers `damage.fire.napalm`):
## explosive 40% torso / 12% each other part, fire even, blunt all torso, fall both legs.
@export var area_weights_by_type: Dictionary[StringName, Dictionary] = {}
## Part that takes damage of a type without an entry (a ballistic hit with no hitbox).
@export var default_part: StringName = &"torso"

@export_group("Injuries")
## One disabled leg: `move_speed_mult` x this.
@export var leg_speed_mult: float = 0.6
## Both legs disabled: forced crawl (crouched) at this speed in m/s.
@export var crawl_speed: float = 1.0
## Each disabled arm: `aim_spread_add` + this many degrees.
@export var arm_spread_add: float = 3.0
## Each disabled arm: `aim_sway_mult` x this.
@export var arm_sway_mult: float = 2.0

@export_group("Knockout")
## Stun points (from `damage.stun`) that knock the character out.
@export var knockout_threshold: float = 60.0
## A hit from inside this arc behind the character (degrees, centred on its back) is "from behind".
@export var behind_arc_deg: float = 120.0
## Stun from behind on an unaware character is multiplied by this.
@export var sneak_multiplier: float = 10.0


func max_health(part: StringName) -> float:
	match part:
		BodyDamageModel.HEAD:
			return head_health
		BodyDamageModel.TORSO:
			return torso_health
		BodyDamageModel.ARM_L, BodyDamageModel.ARM_R:
			return arm_health
		BodyDamageModel.LEG_L, BodyDamageModel.LEG_R:
			return leg_health
	return 0.0


## Whole-body multiplier for `type` times the part's own multiplier for it.
func multiplier(part: StringName, type: StringName) -> float:
	return lookup(type_multipliers, type) * lookup(_part_multipliers(part), type)


## Share of a hit of `type` without a hitbox per part (the entry for the type or its nearest
## ancestor); empty when there is none (all to `default_part`).
func area_weights(type: StringName) -> Dictionary[StringName, float]:
	var weights: Dictionary[StringName, float] = {}
	var key := String(type)
	while not key.is_empty():
		if area_weights_by_type.has(StringName(key)):
			var entry: Dictionary = area_weights_by_type[StringName(key)]
			for part: Variant in entry:
				weights[StringName(str(part))] = float(entry[part])
			return weights
		var dot := key.rfind(".")
		key = key.substr(0, dot) if dot > 0 else ""
	return weights


## The entry for `type` or its nearest ancestor (`damage.fire`, then `damage`); 1.0 when none.
static func lookup(table: Dictionary[StringName, float], type: StringName) -> float:
	var key := String(type)
	while not key.is_empty():
		if table.has(StringName(key)):
			return table[StringName(key)]
		var dot := key.rfind(".")
		key = key.substr(0, dot) if dot > 0 else ""
	return 1.0


func _part_multipliers(part: StringName) -> Dictionary[StringName, float]:
	match part:
		BodyDamageModel.HEAD:
			return head_multipliers
		BodyDamageModel.TORSO:
			return torso_multipliers
		BodyDamageModel.ARM_L, BodyDamageModel.ARM_R:
			return arm_multipliers
		BodyDamageModel.LEG_L, BodyDamageModel.LEG_R:
			return leg_multipliers
	return {}
