@tool
class_name Acoustics
extends RefCounted
## Echo tails by place (ADR 0128). An acoustic zone is an Area3D on the `acoustics` physics layer
## (PhysicsLayers.ACOUSTICS) with Godot's reverb bus settings on (`reverb_bus_enabled`,
## `reverb_bus_name`, `reverb_bus_amount`): an AudioStreamPlayer3D whose `area_mask` has the layer
## and that plays inside it sends that share of its sound to the zone's reverb bus (the engine does
## the send; the dry sound stays on the player's own bus). Indoors is a zone (every kit Room makes
## one over its interior, Room.indoor_acoustics); anywhere else is outdoors, the default: a sound
## player there plays on the outdoor bus, whose reverb keeps the dry sound and adds a longer, sparse
## tail. Both buses send to Effects (default_bus_layout.tres), so the effects volume applies.

## Short, dense tail (small predelay, little feedback); fed by indoor zones' sends.
const INDOOR_BUS: StringName = &"ReverbIndoor"
## Dry sound plus a longer, sparser tail (late predelay with feedback: separate echoes).
const OUTDOOR_BUS: StringName = &"ReverbOutdoor"
## Share of a sound made inside an indoor zone sent to INDOOR_BUS.
const INDOOR_SEND: float = 0.45
## Name of the zone a kit part generates.
const ZONE_NAME: String = "AcousticZone"


## An indoor acoustic zone: a box `size` centred at `centre` (in its parent's frame), sending
## `amount` to `bus`. Static, never monitoring: only sound players and zone_at() look for it.
static func make_zone(
	size: Vector3, centre: Vector3, bus: StringName = INDOOR_BUS, amount: float = INDOOR_SEND
) -> Area3D:
	var zone := Area3D.new()
	zone.name = ZONE_NAME
	zone.monitoring = false
	zone.monitorable = false
	zone.collision_layer = PhysicsLayers.ACOUSTICS
	zone.collision_mask = 0
	zone.reverb_bus_enabled = true
	zone.reverb_bus_name = bus
	zone.reverb_bus_amount = amount
	zone.position = centre
	var shape := CollisionShape3D.new()
	shape.name = "Volume"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	zone.add_child(shape)
	return zone


## The acoustic zone at `position` (the first one using a reverb bus, as the audio engine picks
## it), or null outdoors.
static func zone_at(world: World3D, position: Vector3) -> Area3D:
	if world == null:
		return null
	var query := PhysicsPointQueryParameters3D.new()
	query.position = position
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = PhysicsLayers.ACOUSTICS
	for hit in world.direct_space_state.intersect_point(query):
		var zone := hit["collider"] as Area3D
		if zone != null and zone.reverb_bus_enabled:
			return zone
	return null


## The reverb a sound made at `position` gets: its zone's reverb bus indoors, OUTDOOR_BUS outdoors.
static func reverb_bus_at(world: World3D, position: Vector3) -> StringName:
	var zone := zone_at(world, position)
	return zone.reverb_bus_name if zone != null else OUTDOOR_BUS


## The bus a sound player at `position` plays on: `dry_bus` indoors (its zone adds the tail through
## the player's `area_mask`), OUTDOOR_BUS outdoors.
static func player_bus_at(world: World3D, position: Vector3, dry_bus: StringName) -> StringName:
	return dry_bus if zone_at(world, position) != null else OUTDOOR_BUS
