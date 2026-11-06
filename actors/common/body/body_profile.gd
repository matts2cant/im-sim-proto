class_name BodyProfile
extends Resource
## Tuning for a character's body parts: health per part, damage multipliers per type and part, how
## area damage (explosions, fire) is shared out, what an injury does, knockout and fall damage.
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
## Share of a `damage.explosive` hit each part takes (sums to 1).
@export var explosive_weights: Dictionary[StringName, float] = {}
## Share of a `damage.fire` hit each part takes (sums to 1).
@export var fire_weights: Dictionary[StringName, float] = {}
## Part that takes any other damage that arrives without a hitbox (a blunt CONTACT).
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

@export_group("Fall")
## Landing faster than this (m/s, downwards) hurts the legs.
@export var fall_min_speed: float = 10.0
## Each leg takes (impact speed - fall_min_speed) x this.
@export var fall_damage_per_speed: float = 8.0


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


## Share of an area hit of `type` per part; empty when the type is not shared out (single part).
func area_weights(type: StringName) -> Dictionary[StringName, float]:
	if TagContainer.matches(type, &"damage.explosive"):
		return explosive_weights
	if TagContainer.matches(type, &"damage.fire"):
		return fire_weights
	return {}


## Damage each leg takes from landing at `impact_speed` (m/s downwards); 0 below the threshold.
func fall_damage_per_leg(impact_speed: float) -> float:
	return maxf(impact_speed - fall_min_speed, 0.0) * fall_damage_per_speed


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
