class_name CharacterAnimator
extends Node
## Component of any character carrying a rigid-part model (ADR 0103): it animates the model's parts
## (nodes driven by the clips of the model's AnimationPlayer) from the character's properties only:
## the body's horizontal ground speed, its tags (ActorState: `state.dead`, `state.unconscious`,
## `stance.sprint`) and its WeaponHolder (the drawn weapon's WeaponData.grip, the `fired` signal for
## shots and swings) and its off-hand item (a Flashlight: in use while lit). CharacterAnimModel picks
## the clips; this adapter samples them into five layers, each cross-fading on a change
## (CharacterAnimLayer): base (idle / walk / sprint, full body, rate scaled to the ground speed),
## off hand (the off-hand pose while the item is in use, turned by config.off_hand_turn_deg; the arm
## follows the aim's pitch), hold (the grip's pose on its arm parts, so the legs keep walking; the
## arms follow the aim's pitch), action (a shot or a swing over the hold pose), down (the down clip,
## full body, held on its last frame, the model lifted so the lying figure rests on the floor).
## A staggered character (its HitReaction, ADR 0127) leans: the whole model tips by
## HitReaction.lean() about its feet.
## Visual only: the gameplay aim (the eye, shots, the flashlight's beam direction) never reads the
## model. The drawn weapon's view hangs from a mount on the hand part (WeaponView.hang_from()), so
## it follows the arm; the off-hand item hangs from the off hand while in use and from the stowed
## mount (the belt) otherwise (Flashlight.hang_from(), ADR 0105). An idle clip that never moves
## (config.idle_clip `static`: the training dummy's mannequin) keeps the character still.
## Polls every physics tick and shows the state at once (no fade) on its first tick
## and after a quickload (QuickSave.LOADED_GROUP), so a loaded downed body is already lying.
## The model's own AnimationPlayer is switched off; nothing is saved (the pose follows the state).
## The animated parts cast no shadow unless `config.model_casts_shadows` (a moving shadow caster
## makes every shadowed light around it render its shadow map again each tick): the character's
## static shadow proxy (a "Pose" of shadow-only boxes, tipped by DownedPose) casts it instead.

## Fade into a shot or a swing (seconds): quick, so the recoil reads.
const ACTION_FADE: float = 0.05

@export var config: CharacterAnimConfig
## The model: a scene whose AnimationPlayer's clips drive its part nodes.
@export var model_path: NodePath = ^"../Model"
## The character's WeaponHolder (optional: a character without one never holds anything).
@export var holder_path: NodePath = ^"../Aim/WeaponHolder"
## Node whose pitch the arms follow while holding (the eye; optional).
@export var aim_path: NodePath = ^"../Aim"
## The character's off-hand item, a Flashlight (optional).
@export var off_hand_path: NodePath = ^"../Aim/Flashlight"

var entity: Node3D
var model: Node3D
var holder: WeaponHolder
var state: CharacterAnimModel
var base := CharacterAnimLayer.new()
var off_hand := CharacterAnimLayer.new()
var hold := CharacterAnimLayer.new()
var action := CharacterAnimLayer.new()
var down := CharacterAnimLayer.new()
## Where the drawn weapon's view hangs (a child of the hand part), or null.
var hand_mount: Node3D
## Where the off-hand item is held while in use (a child of the off-hand part), and where it hangs
## otherwise (a child of the stowed part), or null.
var off_hand_mount: Node3D
var stowed_mount: Node3D
## The off-hand item, or null.
var off_hand_item: Flashlight

var _aim: Node3D
var _reaction: HitReaction
var _animations: Dictionary[StringName, Animation] = {}
var _parts: Dictionary[StringName, Node3D] = {}
var _rest: Dictionary[StringName, Transform3D] = {}
# clip -> {part: Vector2i(rotation track, position track)}, -1 for none.
var _tracks: Dictionary[StringName, Dictionary] = {}
# down clip -> metres the model rises at its last frame so the lowest part touches the floor.
var _lift: Dictionary[StringName, float] = {}
var _model_rest: Transform3D
var _pitch_axis: Vector3 = Vector3.RIGHT
var _off_hand_turn := Quaternion.IDENTITY
var _snap: bool = true
var _mount_grip: int = CharacterAnimModel.NO_GRIP
# The held down pose is shown and nothing moves.
var _still: bool = false


func _ready() -> void:
	entity = Entities.of_component(self) as Node3D
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
	_reaction = HitReaction.of(entity)
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
	off_hand_item = get_node_or_null(off_hand_path) as Flashlight
	if off_hand_item != null and _parts.has(config.off_hand_part) and _parts.has(config.stowed_part):
		off_hand_mount = _add_mount(config.off_hand_part, "OffHandMount", config.off_hand_mount)
		stowed_mount = _add_mount(config.stowed_part, "StowedMount", config.stowed_mount)
		off_hand_item.hang_from(off_hand_mount, stowed_mount)
	var turn := config.off_hand_turn_deg * (PI / 180.0)
	_off_hand_turn = (
		Quaternion(Vector3.BACK, turn.z) * Quaternion(Vector3.UP, turn.y) * Quaternion(Vector3.RIGHT, turn.x)
	)
	if not config.model_casts_shadows:
		for geometry: GeometryInstance3D in model.find_children("*", "GeometryInstance3D", true, false):
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_to_group(QuickSave.LOADED_GROUP)


func _physics_process(delta: float) -> void:
	var speed := _ground_speed()
	var sprinting := ActorState.has(entity, ActorState.SPRINTING)
	var dead := ActorState.is_dead(entity)
	var unconscious := ActorState.has(entity, ActorState.UNCONSCIOUS)
	var off_hand_busy := off_hand_item != null and off_hand_item.lit
	state.update(delta, speed, sprinting, dead, unconscious, _held_grip(), off_hand_busy)
	if _snap:
		_snap_layers()
		_snap = false
		_still = false
	else:
		_play_layers()
		for layer in _layers():
			layer.step(delta)
	_place_mount(state.grip)
	# A body lying still in its held down pose needs no new pose until something changes.
	var settled := state.is_down() and down.blend >= 1.0 and down.current.progress() >= 1.0
	if settled and _still:
		return
	_pose()
	_still = settled


## QuickSave.LOADED_GROUP: the next tick shows the loaded state at once (a downed body lies still).
func on_quickloaded() -> void:
	_snap = true


## The parts the model's clips drive (node names), for tests.
func part(part_name: StringName) -> Node3D:
	return _parts.get(part_name, null)


## How much of `clip` shows now in the layer that plays it (0..1), for tests and the debug panel.
func weight_of(clip: StringName) -> float:
	var weight := 0.0
	for layer in _layers():
		weight = maxf(weight, layer.weight_of(clip))
	return weight


func _layers() -> Array[CharacterAnimLayer]:
	return [base, off_hand, hold, action, down]


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
	var off_clip := state.off_hand_clip()
	off_hand.play(off_clip, config.off_hand_parts, _length(off_clip), false, 1.0, config.fade_time)
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
	var off_clip := state.off_hand_clip()
	off_hand.snap(off_clip, config.off_hand_parts, _length(off_clip), false, _length(off_clip))
	var hold_clip := state.hold_clip()
	hold.snap(hold_clip, state.hold_parts(), _length(hold_clip), false, _length(hold_clip))
	action.snap(&"", [], 0.0, false, 0.0)
	var down_clip := state.down_clip()
	down.snap(down_clip, [], _length(down_clip), false, _length(down_clip))


func _length(clip: StringName) -> float:
	var animation: Animation = _animations.get(clip, null)
	return animation.length if animation != null else 0.0


# Every part: rest, then each layer over the one below (a fade blends the layer's two slots). The
# off-hand parts take the off-hand turn; the held and off-hand parts follow the aim's pitch.
func _pose() -> void:
	var aim_pitch := _aim_pitch()
	var hold_weight := hold.weight_of(state.hold_clip())
	var off_weight := off_hand.weight_of(config.hold_off_hand_clip)
	for part_name: StringName in _parts:
		var rest := _rest[part_name]
		var rotation := rest.basis.get_rotation_quaternion()
		var position := rest.origin
		for layer: CharacterAnimLayer in [base, off_hand]:
			rotation = _layer_rotation(layer, part_name, rotation)
			position = _layer_position(layer, part_name, position)
		var off_hand_part := off_weight > 0.0 and part_name == config.off_hand_part
		if off_hand_part:
			rotation = Quaternion.IDENTITY.slerp(_off_hand_turn, off_weight) * rotation
		for layer: CharacterAnimLayer in [hold, action]:
			rotation = _layer_rotation(layer, part_name, rotation)
			position = _layer_position(layer, part_name, position)
		var pitch_weight := hold_weight if hold.current.drives(part_name) else 0.0
		if off_hand_part and not hold.current.drives(part_name):
			pitch_weight = off_weight
		if aim_pitch != 0.0 and pitch_weight > 0.0:
			rotation = Quaternion(_pitch_axis, aim_pitch * pitch_weight) * rotation
		rotation = _layer_rotation(down, part_name, rotation)
		position = _layer_position(down, part_name, position)
		var node := _parts[part_name]
		node.transform = Transform3D(Basis(rotation) * Basis.from_scale(rest.basis.get_scale()), position)
	var lift := 0.0
	for slot: CharacterAnimLayer.Slot in [down.current, down.previous]:
		if not slot.clip.is_empty():
			var weight := down.blend if slot == down.current else 1.0 - down.blend
			lift += _lift.get(slot.clip, 0.0) * weight * slot.progress()
	var lean := _reaction.lean() if _reaction != null else Basis.IDENTITY
	model.transform = Transform3D(lean * _model_rest.basis, _model_rest.origin + Vector3.UP * lift)


# Pitch of the aim above the horizontal (radians), 0 without one.
func _aim_pitch() -> float:
	if _aim == null or not config.follow_aim_pitch:
		return 0.0
	if state.grip == CharacterAnimModel.NO_GRIP and off_hand.is_idle():
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


# A mount node under `part_name` at `mount` (the part's frame).
func _add_mount(part_name: StringName, mount_name: String, mount: Transform3D) -> Node3D:
	var node := Node3D.new()
	node.name = mount_name
	node.transform = mount
	_parts[part_name].add_child(node)
	return node


# Puts the hand mount where `grip` holds the weapon (a two-handed weapon between the hands), the
# model's scale undone so the weapon shows at its size x config.held_scale.
func _place_mount(grip: int) -> void:
	if hand_mount == null or grip == _mount_grip or grip == CharacterAnimModel.NO_GRIP:
		return
	_mount_grip = grip
	var hand := hand_mount.get_parent() as Node3D
	var scale := (entity.global_basis.inverse() * hand.global_basis).get_scale()
	var mount := config.mount(grip)
	var unscale := Vector3(1.0 / scale.x, 1.0 / scale.y, 1.0 / scale.z) * config.held_scale
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
