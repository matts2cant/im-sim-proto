class_name SurfaceTable
extends Resource
## Floor surfaces: noise multiplier and footstep sound per surface name.
## A floor declares its surface with node metadata `surface` (StringName) on the collider
## the player stands on; for CSG that is the CSG root node with use_collision (ADR 0033).

const SURFACE_META: StringName = &"surface"

@export var default_surface: StringName
@export var multipliers: Dictionary[StringName, float] = {}
@export var sounds: Dictionary[StringName, AudioStream] = {}
## Base pitch scale per surface (default 1.0); the randomizer adds its small variance on top.
@export var pitches: Dictionary[StringName, float] = {}


## Surface name of a floor collider, or the default when it declares none.
func surface_of(collider: Object) -> StringName:
	if collider != null and collider.has_meta(SURFACE_META):
		return StringName(collider.get_meta(SURFACE_META))
	return default_surface


## Noise multiplier of a surface; unknown surfaces sound like the default surface.
func multiplier(surface: StringName) -> float:
	if multipliers.has(surface):
		return multipliers[surface]
	return multipliers.get(default_surface, 1.0)


## Base pitch scale of a surface's sounds; 1.0 unless the table sets one.
func pitch(surface: StringName) -> float:
	return pitches.get(surface, 1.0)


func sound(surface: StringName) -> AudioStream:
	if sounds.has(surface):
		return sounds[surface]
	return sounds.get(default_surface)
