class_name CharacterAnimator
extends Node
## Component of any character carrying a rigid-part model (ADR 0103): it animates the model's parts
## (nodes driven by the clips of the model's AnimationPlayer) from the character's properties only:
## the body's horizontal ground speed, its tags (ActorState: `state.dead`, `state.unconscious`,
## `stance.sprint`) and its WeaponHolder (the drawn weapon's WeaponData.grip, the `fired` signal for
## shots and swings). CharacterAnimModel picks the clips; this adapter samples them into four
## layers, each cross-fading on a change (CharacterAnimLayer):
## base (idle / walk / sprint, full body, rate scaled to the ground speed), hold (the grip's pose on
## its arm parts, so the legs keep walking; the arms follow the aim's pitch), action (a shot or a
## swing over the hold pose), down (the down clip, full body, held on its last frame, the model lifted
## so the lying figure rests on the floor).
## Visual only: the gameplay aim (the eye, shots, the flashlight's beam) never reads the model. The
## drawn weapon's view hangs from a mount on the hand part (WeaponView.hang_from()), so it
## follows the arm. Polls every physics tick and shows the state at once (no fade) on its first tick
## and after a quickload (QuickSave.LOADED_GROUP), so a loaded downed body is already lying.
## The model's own AnimationPlayer is switched off; nothing is saved (the pose follows the state).

## Fade into a shot or a swing (seconds): quick, so the recoil reads.
const ACTION_FADE: float = 0.05

@export var config: CharacterAnimConfig
## The model: a scene whose AnimationPlayer's clips drive its part nodes.
@export var model_path: NodePath = ^"../Model"
## The character's WeaponHolder (optional: a character without one never holds anything).
@export var holder_path: NodePath = ^"../Aim/WeaponHolder"
## Node whose pitch the arms follow while holding (the eye; optional).
@export var aim_path: NodePath = ^"../Aim"

var entity: Node3D
var model: Node3D
var holder: WeaponHolder
var state: CharacterAnimModel
var base := CharacterAnimLayer.new()
var hold := CharacterAnimLayer.new()
var action := CharacterAnimLayer.new()
var down := CharacterAnimLayer.new()
## Where the drawn weapon's view hangs (a child of the hand part), or null.
var hand_mount: Node3D

var _aim: Node3D
var _animations: Dictionary[StringName, Animation] = {}
var _parts: Dictionary[StringName, Node3D] = {}
var _rest: Dictionary[StringName, Transform3D] = {}
# clip -> {part: Vector2i(rotation track, position track)}, -1 for none.
var _tracks: Dictionary[StringName, Dictionary] = {}
# down clip -> metres the model rises at its last frame so the lowest part touches the floor.
var _lift: Dictionary[StringName, float] = {}
var _model_rest: Transform3D
var _model_scale: float = 1.0
var _pitch_axis: Vector3 = Vector3.RIGHT
var _snap: bool = true
var _mount_grip: int = CharacterAnimModel.NO_GRIP


func _ready() -> void:
	entity = get_parent() as Node3D
	model = get_node_or_null(model_path) as Node3D
	if config == null or entity == null or model == null:
		push_warning("CharacterAnimator %s: needs a config, a Node3D parent and a model" % get_path())
		set_physics_process(false)
		return
	state = CharacterAnimModel.new(config)
	_index_model()
	_model_rest = model.transform
	_pitch_axis = (model.basis.inverse() * Vector3.RIGHT).normalized()
	_aim = get_node_or_null(aim_path) as Node3D
	# Measured before the weapon hangs from the hand: only the model's own meshes count.
	for clip: StringName in [config.dead_clip, config.unconscious_clip]:
		if not _lift.has(clip):
			_lift[clip] = _measure_lift(clip)
	holder = get_node_or_null(holder_path) as WeaponHolder
	if holder != null and _parts.has(config.hand_part):
		hand_mount = Node3D.new()
		hand_mount.name = "HandMount"
		_parts[config.hand_part].add_child(hand_mount)
		_place_mount(WeaponData.Grip.ONE_HAND)
		holder.view_pivot().hang_from(hand_mount)
		holder.fired.connect(_on_fired)
	add_to_group(QuickSave.LOADED_GROUP)


func _physics_process(delta: float) -> void:
	(
		state
		. update(
			delta,
			_ground_speed(),
			ActorState.has(entity, ActorState.SPRINTING),
			ActorState.is_dead(entity),
			ActorState.has(entity, ActorState.UNCONSCIOUS),
			_held_grip(),
		)
	)
	if _snap:
		_snap_layers()
		_snap = false
	else:
		_play_layers()
		for layer in _layers():
			layer.step(delta)
	_place_mount(state.grip)
	_pose()


## QuickSave.LOADED_GROUP: the next tick shows the loaded state at once (a downed body lies still).
func on_quickloaded() -> void:
	_snap = true


## The parts the model's clips drive (node names), for tests.
func part(part_name: StringName) -> Node3D:
	return _parts.get(part_name, null)


func has_clip(clip: StringName) -> bool:
	return _animations.has(clip)


## How much of `clip` shows now in the layer that plays it (0..1), for tests and the debug panel.
func weight_of(clip: StringName) -> float:
	var weight := 0.0
	for layer in _layers():
		weight = maxf(weight, layer.weight_of(clip))
	return weight


## Metres the model is raised at the end of the down clip (its lying figure rests on the floor).
func lying_lift(clip: StringName) -> float:
	return _lift.get(clip, 0.0)


func _layers() -> Array[CharacterAnimLayer]:
	return [base, hold, action, down]


func _ground_speed() -> float:
	var body := entity as CharacterBody3D
	if body == null:
		return 0.0
	var velocity := body.get_real_velocity()
	return Vector2(velocity.x, velocity.z).length()


func _held_grip() -> int:
	if holder == null or not holder.is_armed():
		return CharacterAnimModel.NO_GRIP
	return holder.weapon().grip


func _on_fired(weapon: WeaponData) -> void:
	var clip := state.fire(weapon.is_melee())
	if clip.is_empty():
		return
	action.play(clip, state.action_parts, _length(clip), false, 1.0, ACTION_FADE, 0.0, true)


# The layers' wanted clips from the state choice, fading.
func _play_layers() -> void:
	var base_clip := state.base_clip()
	var start := 0.0
	var moving := state.locomotion != CharacterAnimModel.Locomotion.IDLE
	if moving and base.current.clip != config.idle_clip and base.current.clip != base_clip:
		# Walk <-> sprint: the new clip starts at the same share of its stride.
		start = base.current.progress() * _length(base_clip)
	base.play(base_clip, [], _length(base_clip), true, state.playback, config.fade_time, start)
	var hold_clip := state.hold_clip()
	hold.play(hold_clip, state.hold_parts(), _length(hold_clip), false, 1.0, config.fade_time)
	if state.action_clip.is_empty() and not action.current.clip.is_empty():
		action.play(&"", [], 0.0, false, 1.0, config.fade_time)
	var down_clip := state.down_clip()
	var fade := config.fade_time if not down_clip.is_empty() else config.wake_fade_time
	down.play(down_clip, [], _length(down_clip), false, 1.0, fade)


func _snap_layers() -> void:
	var base_clip := state.base_clip()
	base.snap(base_clip, [], _length(base_clip), true, 0.0)
	base.current.rate = state.playback
	var hold_clip := state.hold_clip()
	hold.snap(hold_clip, state.hold_parts(), _length(hold_clip), false, _length(hold_clip))
	action.snap(&"", [], 0.0, false, 0.0)
	var down_clip := state.down_clip()
	down.snap(down_clip, [], _length(down_clip), false, _length(down_clip))


func _length(clip: StringName) -> float:
	var animation: Animation = _animations.get(clip, null)
	return animation.length if animation != null else 0.0


# Every part: rest, then each layer over the one below (a fade blends the layer's two slots).
func _pose() -> void:
	var pitch := _aim_pitch() * hold.weight_of(state.hold_clip())
	for part_name: StringName in _parts:
		var rest := _rest[part_name]
		var rotation := rest.basis.get_rotation_quaternion()
		var position := rest.origin
		for layer: CharacterAnimLayer in [base, hold, action]:
			rotation = _layer_rotation(layer, part_name, rotation)
			position = _layer_position(layer, part_name, position)
		if pitch != 0.0 and hold.current.drives(part_name):
			rotation = Quaternion(_pitch_axis, pitch) * rotation
		rotation = _layer_rotation(down, part_name, rotation)
		position = _layer_position(down, part_name, position)
		var node := _parts[part_name]
		node.transform = Transform3D(Basis(rotation) * Basis.from_scale(rest.basis.get_scale()), position)
	var lift := 0.0
	for slot: CharacterAnimLayer.Slot in [down.current, down.previous]:
		if not slot.clip.is_empty():
			var weight := down.blend if slot == down.current else 1.0 - down.blend
			lift += _lift.get(slot.clip, 0.0) * weight * slot.progress()
	model.transform = Transform3D(_model_rest.basis, _model_rest.origin + Vector3.UP * lift)


# Pitch of the aim above the horizontal (radians), 0 without one.
func _aim_pitch() -> float:
	if _aim == null or not config.follow_aim_pitch or state.grip == CharacterAnimModel.NO_GRIP:
		return 0.0
	var forward := -_aim.global_basis.z.normalized()
	var up := entity.global_basis.y.normalized()
	return asin(clampf(forward.dot(up), -1.0, 1.0))


func _layer_rotation(layer: CharacterAnimLayer, part_name: StringName, below: Quaternion) -> Quaternion:
	if layer.is_idle():
		return below
	var current := _slot_rotation(layer.current, part_name, below)
	if layer.blend >= 1.0:
		return current
	return _slot_rotation(layer.previous, part_name, below).slerp(current, layer.blend)


func _layer_position(layer: CharacterAnimLayer, part_name: StringName, below: Vector3) -> Vector3:
	if layer.is_idle():
		return below
	var current := _slot_position(layer.current, part_name, below)
	if layer.blend >= 1.0:
		return current
	return _slot_position(layer.previous, part_name, below).lerp(current, layer.blend)


func _slot_rotation(slot: CharacterAnimLayer.Slot, part_name: StringName, below: Quaternion) -> Quaternion:
	if not slot.drives(part_name):
		return below
	var track := _track(slot.clip, part_name)
	if track.x < 0:
		return _rest[part_name].basis.get_rotation_quaternion()
	return _animations[slot.clip].rotation_track_interpolate(track.x, slot.time)


func _slot_position(slot: CharacterAnimLayer.Slot, part_name: StringName, below: Vector3) -> Vector3:
	if not slot.drives(part_name):
		return below
	var track := _track(slot.clip, part_name)
	if track.y < 0:
		return _rest[part_name].origin
	return _animations[slot.clip].position_track_interpolate(track.y, slot.time)


func _track(clip: StringName, part_name: StringName) -> Vector2i:
	var tracks: Dictionary = _tracks.get(clip, {})
	return tracks.get(part_name, Vector2i(-1, -1))


# The model's clips, the part nodes their tracks drive (by name) and each part's rest transform.
func _index_model() -> void:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_warning("CharacterAnimator %s: the model has no AnimationPlayer" % get_path())
		return
	var player := players[0] as AnimationPlayer
	player.stop()
	player.active = false
	var root := player.get_node_or_null(player.root_node)
	for clip in player.get_animation_list():
		var animation := player.get_animation(clip)
		_animations[clip] = animation
		var tracks: Dictionary[StringName, Vector2i] = {}
		for i in animation.get_track_count():
			var path := animation.track_get_path(i)
			var node := root.get_node_or_null(NodePath(path.get_concatenated_names())) as Node3D
			if node == null:
				continue
			var key := StringName(node.name)
			if not _parts.has(key):
				_parts[key] = node
				_rest[key] = node.transform
			var entry: Vector2i = tracks.get(key, Vector2i(-1, -1))
			match animation.track_get_type(i):
				Animation.TYPE_ROTATION_3D:
					entry.x = i
				Animation.TYPE_POSITION_3D:
					entry.y = i
			tracks[key] = entry
		_tracks[clip] = tracks
		state.clip_lengths[clip] = animation.length


# Puts the hand mount where `grip` holds the weapon (a two-handed weapon between the hands), the
# model's scale undone so the weapon keeps its size.
func _place_mount(grip: int) -> void:
	if hand_mount == null or grip == _mount_grip or grip == CharacterAnimModel.NO_GRIP:
		return
	_mount_grip = grip
	var hand := hand_mount.get_parent() as Node3D
	var scale := (entity.global_basis.inverse() * hand.global_basis).get_scale()
	var mount := config.mount(grip)
	var unscale := Vector3(1.0 / scale.x, 1.0 / scale.y, 1.0 / scale.z)
	hand_mount.transform = Transform3D(mount.basis * Basis.from_scale(unscale), mount.origin)


# Height the down clip's last frame needs to rest its lowest part on the floor (metres, in the
# character's frame): the pose is applied for a moment and the meshes' boxes measured.
func _measure_lift(clip: StringName) -> float:
	if not _animations.has(clip) or not is_inside_tree():
		return 0.0
	var probe := CharacterAnimLayer.new()
	probe.snap(clip, [], _length(clip), false, _length(clip))
	for part_name: StringName in _parts:
		var rest := _rest[part_name]
		var rotation := _layer_rotation(probe, part_name, rest.basis.get_rotation_quaternion())
		var position := _layer_position(probe, part_name, rest.origin)
		_parts[part_name].transform = Transform3D(Basis(rotation) * Basis.from_scale(rest.basis.get_scale()), position)
	var to_entity := entity.global_transform.affine_inverse()
	var lowest := INF
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box := (to_entity * mesh.global_transform) * mesh.get_aabb()
		lowest = minf(lowest, box.position.y)
	for part_name: StringName in _parts:
		_parts[part_name].transform = _rest[part_name]
	return -lowest if lowest < INF else 0.0
