class_name SurfaceTable
extends Resource
## Floor surfaces: noise multiplier and footstep sound per surface name.
## The surface a character stands on is Surface.of() its floor collider (ADR 0138): the `surface`
## metadata of static geometry (for CSG the root node with use_collision, ADR 0033), else the
## `material.*` tag of the entity (a metal crate sounds like metal).

@export var default_surface: StringName
@export var multipliers: Dictionary[StringName, float] = {}
@export var sounds: Dictionary[StringName, AudioStream] = {}
## Base pitch scale per surface (default 1.0); the randomizer adds its small variance on top.
@export var pitches: Dictionary[StringName, float] = {}


## Surface name of a floor collider (Surface.of()), or the default when it has none.
func surface_of(collider: Object) -> StringName:
	var surface := Surface.of(collider)
	return default_surface if surface.is_empty() else surface


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
