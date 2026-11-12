class_name Breakable
extends Node3D
## Component: takes damage from `damage.*` stimuli (the `damage` receptron -> DamageEffect ->
## take_damage()) scaled by the material's multiplier per type, out of the entity's Attributes
## `health`. At 0 it emits `depleted`; unless `break_on_depleted` is off (an Explosive handles it)
## it breaks: `noise` (PATH), break sound, debris, `contents` spawned in place, entity freed (unless
## `free_entity` is off: a door keeps its frame).
## Place it at the object's centre (noise origin, debris and contents spawn point).

signal depleted(cause: Stimulus)
signal broken

const HEALTH: StringName = &"health"

@export var material: MaterialProfile
@export var settings: BreakSettings
## Spawned where the object was when it breaks (an item in a crate).
@export var contents: Array[PackedScene] = []
## Off when another component (Explosive) reacts to health 0 instead.
@export var break_on_depleted: bool = true
## Off when the entity stays after breaking and reacts to `broken` itself (a door loses its panel
## but keeps its frame, navigation link and saved state).
@export var free_entity: bool = true
## Debris size reference: the object's largest dimension in metres.
@export var size: float = 0.6
@export var entity_path: NodePath = ^".."

var entity: Node3D
var attributes: Attributes
var is_broken: bool = false


func _ready() -> void:
	entity = get_node(entity_path) as Node3D
	attributes = entity.get_node_or_null(^"Attributes") as Attributes


static func of(node: Node) -> Breakable:
	for child in node.get_children():
		if child is Breakable:
			return child as Breakable
	return null


func health() -> float:
	return attributes.value(HEALTH) if attributes != null else 0.0


## Applies `amount` of `type` damage times the material multiplier; returns the damage dealt.
func take_damage(type: StringName, amount: float, cause: Stimulus = null) -> float:
	if is_broken or attributes == null or entity.is_queued_for_deletion():
		return 0.0
	var dealt := amount * (material.damage_multiplier(type) if material != null else 1.0)
	if dealt <= 0.0:
		return 0.0
	var values := attributes.attribute_set
	values.set_base(HEALTH, values.base(HEALTH) - dealt)
	var data := {"object": String(entity.name), "type": type, "amount": dealt, "health": health()}
	# The damaging stimulus (mission tallies attribute what broke an object that stays, a device).
	data["by"] = cause.id if cause != null else 0
	EventLog.record(&"object.damaged", cause.source_name() if cause != null else "", String(entity.name), data)
	if health() <= 0.0:
		depleted.emit(cause)
		if break_on_depleted:
			break_apart(&"destroyed", cause)
	return dealt


## Breaks now: noise, sound, debris, contents, then the entity is freed. `reason` is logged
## (`destroyed`, `burnt_out`, `impact`).
func break_apart(reason: StringName, cause: Stimulus = null) -> void:
	if is_broken or entity.is_queued_for_deletion():
		return
	is_broken = true
	var origin := global_position
	StimulusSystem.emit(Stimulus.make_noise(settings.noise_loudness, origin, entity), cause)
	_play_sound(origin)
	var parent := entity.get_parent()
	var debris := _spawn_debris(parent, origin)
	var spawned := _spawn_contents(parent, origin)
	var data := {
		"object": String(entity.name),
		"reason": reason,
		"by": cause.id if cause != null else 0,
		"debris": debris,
		"contents": spawned,
	}
	EventLog.record(&"object.broken", String(entity.name), "", data)
	broken.emit()
	# Props wake what rested on them when they leave the tree; other bodies (the barricade) here.
	if entity is CollisionObject3D and not entity is PhysicsObject:
		SupportWake.wake_touching(entity as CollisionObject3D)
	if free_entity:
		entity.queue_free()


func _spawn_debris(parent: Node, origin: Vector3) -> int:
	var count := randi_range(settings.debris_min, settings.debris_max)
	var piece_size := size * settings.debris_size_fraction
	var color := material.debris_color if material != null else Color.GRAY
	for i in count:
		var piece := Debris.new()
		piece.setup(piece_size, color, settings.debris_lifetime, settings.debris_mass)
		var offset := (
			Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)) * size * settings.debris_scatter
		)
		piece.position = origin + offset
		parent.add_child(piece)
		var outward := offset.normalized() if not offset.is_zero_approx() else Vector3.UP
		piece.linear_velocity = (outward + Vector3.UP * settings.debris_lift).normalized() * settings.debris_speed
	return count


func _spawn_contents(parent: Node, origin: Vector3) -> Array[String]:
	var names: Array[String] = []
	for i in contents.size():
		var scene := contents[i]
		if scene == null:
			continue
		var node := scene.instantiate()
		parent.add_child(node, true)
		if node is Node3D:
			(node as Node3D).global_position = origin + content_offset(i, contents.size(), size)
		names.append(String(node.name))
	return names


## Where content item `index` of `count` appears relative to the centre: one item at the centre,
## several spread on a horizontal circle a quarter of the object's size wide, so items never
## spawn inside each other (overlapping bodies fly apart and bottles shatter).
static func content_offset(index: int, count: int, object_size: float) -> Vector3:
	if count <= 1:
		return Vector3.ZERO
	var angle := TAU * index / count
	return Vector3(cos(angle), 0.0, sin(angle)) * object_size * 0.25


func _play_sound(origin: Vector3) -> void:
	if material == null or material.break_sound == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.bus = GameSettings.EFFECTS_BUS
	player.name = "BreakSound"
	player.stream = material.break_sound
	player.volume_db = material.break_volume_db
	player.unit_size = 6.0
	player.finished.connect(player.queue_free)
	# Parented to the viewport so the sound outlives the entity.
	get_viewport().add_child(player)
	player.global_position = origin
	player.play()
