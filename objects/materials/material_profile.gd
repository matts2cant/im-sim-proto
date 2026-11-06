class_name MaterialProfile
extends Resource
## What an object is made of: how loud its impacts are, what they sound like, how much each damage
## type hurts it and how it breaks. Shared by objects of one material (`objects/materials/*.tres`).

## The material tag objects of this material carry (`material.wood`).
@export var tag: StringName = &""
## Impact loudness multiplier (wood 1.0, metal 1.4, glass 1.6, cardboard 0.4).
@export var impact_loudness: float = 1.0
## Impact sounds by tier: light, medium, heavy (ImpactRules.tier()).
@export var impact_sounds: Array[AudioStream] = []
## Damage multiplier per stimulus type (`damage.fire`); the most specific entry wins (`damage.fire`
## before `damage`); types without an entry take full damage.
@export var damage_multipliers: Dictionary[StringName, float] = {}
## Breaks outright on an impact at least this fast (m/s); 0 = never (glass bottles).
@export var break_impact_speed: float = 0.0
@export var break_sound: AudioStream
@export var break_volume_db: float = 0.0
## Albedo of debris pieces.
@export var debris_color: Color = Color(0.5, 0.5, 0.5)


func damage_multiplier(type: StringName) -> float:
	var key := String(type)
	while not key.is_empty():
		if damage_multipliers.has(StringName(key)):
			return damage_multipliers[StringName(key)]
		var dot := key.rfind(".")
		key = key.substr(0, dot) if dot >= 0 else ""
	return 1.0


## Sound for an impact tier (0 light, 1 medium, 2 heavy); falls back to the nearest lower tier.
func impact_sound(tier: int) -> AudioStream:
	for index in range(mini(tier, impact_sounds.size() - 1), -1, -1):
		if impact_sounds[index] != null:
			return impact_sounds[index]
	return null
