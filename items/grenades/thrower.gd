class_name Thrower
extends Node
## Component of any character with a WeaponHolder (ADR 0131): what the holder's THROWN weapons
## (grenades) become when its trigger fires them (the ThrowRelease delivery calls release()). The
## weapon's entity (WeaponData.thrown_scene) is spawned beside the user:
## - when the eye looks at a surface within `config.stick_reach` m (walls, floors, ceilings, doors,
##   props: anything solid but a character, which blocks the look but takes nothing), it is stuck
##   there (its Sticky; a ProximityTrigger then arms it as a mine): upright beside a wall, on its
##   base on a floor or ceiling (ThrowRules.stick_transform());
## - otherwise it is thrown in a fixed arc (ThrowRules.launch_velocity(): `config.lift_deg` above the
##   view, at the speed that lands the user's `throw_distance` attribute, base `config.base_distance`,
##   away on flat ground when looking level), its Fuse lit; it ignores the thrower's body for
##   `config.ignore_thrower_time` s.
## With `show_ghost` (the player) a translucent copy of the drawn weapon's model (its view scene)
## shows where and how it would stick while one is drawn. The fuse of the last throw is kept for the
## HUD (fuse_left()). Nothing here reads input.

const THROW_DISTANCE: StringName = &"throw_distance"
## What the stick look meets: surfaces, and the characters that block it without taking anything.
const LOOK_MASK: int = (
	PhysicsLayers.WORLD
	| PhysicsLayers.OBJECTS
	| PhysicsLayers.CHARACTER_LAYERS
	| PhysicsLayers.STATIC_ACTORS
	| PhysicsLayers.DOWNED
)
## Layers whose bodies are characters (a weapon never sticks to a person).
const CHARACTER_MASK: int = PhysicsLayers.CHARACTER_LAYERS | PhysicsLayers.STATIC_ACTORS | PhysicsLayers.DOWNED
const SPIN: float = 6.0

@export var config: ThrowConfig
@export var holder_path: NodePath
## Shows the ghost of the drawn weapon where it would stick (the player's view).
@export var show_ghost: bool = false

var holder: WeaponHolder
## The fuse of the last weapon thrown (the HUD's fuse readout), or null.
var last_fuse: Fuse = null

var _ghost: Node3D = null
var _ghost_data: WeaponData = null
var _offsets: Dictionary[String, Vector2] = {}
# Thrown bodies still ignoring the thrower: [WeakRef, seconds left].
var _ignoring: Array[Array] = []


func _ready() -> void:
	holder = get_node(holder_path) as WeaponHolder


static func of(node: Node) -> Thrower:
	if node == null or not is_instance_valid(node):
		return null
	for child in node.get_children():
		if child is Thrower:
			return child as Thrower
	return null


## The user throwing (the holder's).
func user() -> CollisionObject3D:
	return holder.user if holder != null else null


## Throw distance (m) on flat ground now: `config.base_distance` through the user's `throw_distance`.
func throw_distance() -> float:
	return Attributes.read(user(), THROW_DISTANCE, config.base_distance)


## Where `data`'s entity would stick now: {"pose": Transform3D, "on": Node3D followed}, or {} (it
## would be thrown).
func stick_spot(data: WeaponData) -> Dictionary:
	if data == null or not data.is_thrown() or holder == null or holder.eye == null:
		return {}
	var offsets := _stick_offsets(data.thrown_scene)
	if offsets.x < 0.0:
		return {}
	var eye := holder.eye.global_transform
	var forward := -eye.basis.z.normalized()
	var exclude: Array[RID] = []
	var who := user()
	if is_instance_valid(who):
		exclude.append(who.get_rid())
		exclude.append_array(Hitboxes.rids_of(who))
	var query := PhysicsRayQueryParameters3D.create(
		eye.origin, eye.origin + forward * config.stick_reach, LOOK_MASK, exclude
	)
	var hit := holder.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var collider := hit["collider"] as Node3D
	if collider == null or _is_character(collider):
		return {}
	var pose := ThrowRules.stick_transform(
		hit["position"] as Vector3, hit["normal"] as Vector3, forward, offsets.x, offsets.y
	)
	return {"pose": pose, "on": _shape_node(collider, int(hit["shape"]))}


## Sticks or throws `data`'s entity (the trigger fired it). Returns "stuck" or "thrown" ("" when the
## weapon has no entity).
func release(data: WeaponData) -> String:
	if data == null or data.thrown_scene.is_empty():
		return ""
	var spot := stick_spot(data)
	var body := (load(data.thrown_scene) as PackedScene).instantiate() as RigidBody3D
	var who := user()
	who.get_parent().add_child(body, true)
	var sticky := Sticky.of(body)
	if not spot.is_empty() and sticky != null:
		var pose: Transform3D = spot["pose"]
		body.global_transform = pose
		sticky.stick(spot["on"] as Node3D, pose)
		_log(&"thrower.stuck", body)
		return "stuck"
	_launch(body)
	_log(&"thrower.thrown", body)
	return "thrown"


## Seconds left on the fuse of the last throw, or -1 when it is gone or out.
func fuse_left() -> float:
	if last_fuse == null or not is_instance_valid(last_fuse) or not last_fuse.is_lit:
		return -1.0
	return last_fuse.left


func ghost_visible() -> bool:
	return _ghost != null and _ghost.visible


func _physics_process(delta: float) -> void:
	_step_ignoring(delta)
	if not show_ghost:
		return
	var data := holder.weapon() if holder != null else null
	var spot := {}
	if data != null and data.is_thrown() and ActorState.can_use_arms(user()):
		spot = stick_spot(data)
	if spot.is_empty():
		if _ghost != null:
			_ghost.visible = false
		return
	_show_ghost(data, spot["pose"] as Transform3D)


func _launch(body: RigidBody3D) -> void:
	var eye := holder.eye.global_transform
	var forward := -eye.basis.z.normalized()
	var who := user()
	body.global_transform = Transform3D(eye.basis, eye.origin + forward * config.spawn_forward)
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity")) * body.gravity_scale
	var eye_height := eye.origin.y - who.global_position.y
	body.linear_velocity = ThrowRules.launch_velocity(
		forward, throw_distance(), eye_height, config.lift_deg, config.spawn_forward, gravity
	)
	body.angular_velocity = eye.basis.x * SPIN
	body.add_collision_exception_with(who)
	_ignoring.append([weakref(body), config.ignore_thrower_time])
	var fuse := Fuse.of(body)
	if fuse != null:
		fuse.light()
		last_fuse = fuse


func _step_ignoring(delta: float) -> void:
	for i in range(_ignoring.size() - 1, -1, -1):
		var entry := _ignoring[i]
		entry[1] = float(entry[1]) - delta
		var body := (entry[0] as WeakRef).get_ref() as RigidBody3D
		if body == null or float(entry[1]) <= 0.0:
			if body != null and is_instance_valid(user()):
				body.remove_collision_exception_with(user())
			_ignoring.remove_at(i)


# A body of a character (or one of its parts) never takes a stuck weapon.
func _is_character(collider: Node) -> bool:
	var body := collider as CollisionObject3D
	if body != null and (body.collision_layer & CHARACTER_MASK) != 0:
		return true
	return BodyParts.of(Interactor.entity_of(collider)) != null


# The node to follow: the collision shape hit (a sliding door's panel moves its shape, not its
# body), else the collider (a CSG root).
static func _shape_node(collider: Node3D, shape_index: int) -> Node3D:
	var body := collider as CollisionObject3D
	if body == null or shape_index < 0:
		return collider
	var owner_id := body.shape_find_owner(shape_index)
	var shape := body.shape_owner_get_owner(owner_id) as Node3D
	return shape if shape != null else collider


# The scene's Sticky offsets (read once per scene): x surface_offset, y side_offset; x is -1 when it
# cannot stick.
func _stick_offsets(scene_path: String) -> Vector2:
	if _offsets.has(scene_path):
		return _offsets[scene_path]
	var offsets := Vector2(-1.0, -1.0)
	var packed := load(scene_path) as PackedScene if not scene_path.is_empty() else null
	if packed != null:
		var node := packed.instantiate()
		var sticky := Sticky.of(node)
		if sticky != null:
			offsets = Vector2(sticky.surface_offset, sticky.side_offset)
		node.free()
	_offsets[scene_path] = offsets
	return offsets


func _show_ghost(data: WeaponData, pose: Transform3D) -> void:
	if _ghost_data != data:
		if _ghost != null:
			_ghost.free()
		_ghost = null
		_ghost_data = data
		if data.view_scene != null:
			_ghost = data.view_scene.instantiate() as Node3D
			_ghost.name = "Ghost"
			add_child(_ghost)
			for node in _ghost.find_children("*", "GeometryInstance3D", true, false):
				var geometry := node as GeometryInstance3D
				geometry.transparency = 1.0 - config.ghost_alpha
				geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _ghost == null:
		return
	_ghost.global_transform = pose
	_ghost.visible = true


func _log(kind: StringName, body: Node) -> void:
	var who := user()
	var who_name := String(who.name) if is_instance_valid(who) else ""
	EventLog.record(kind, who_name, String(body.name), {"object": String(body.name)})
