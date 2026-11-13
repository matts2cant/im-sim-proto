class_name ProximityTrigger
extends Node3D
## Component (ADR 0131): turns its entity into a proximity mine. Tuning in `config`
## (ProximityTriggerConfig, `proximity_trigger.tres`, ADR 0138). Arming starts when a sibling Sticky
## sticks the entity (or arm() is called) and takes `arm_time` s; armed, a small red light blinks
## about once a second, and every `check_ticks` physics ticks it looks for characters (bodies on
## `character_mask`: players and guards, its owner included; never props or noises) that its tag
## filter accepts (`required_tags` / `ignored_tags`; by default every character): one within
## `radius` m of its centre (the gap to the character's collision shape), or within `crouched_radius`
## when the character is crouched (its `stance.crouch` tag), and in its line of sight (a ray to the
## shape's centre that nothing on `sight_mask` blocks) sets off the entity's Explosive
## (`Explosive.explode()`). Cheap: one sphere query (a second, smaller one only when a crouched
## character is near), then one ray per candidate.
## The interaction frame shows "Armed" (frame_word(), StatusWord.FRAME_GROUP). A highlight seen
## through darkness and smoke, not walls (set_highlighted(): MineSense, the Demolition skill) marks it.
## EventLog `mine.armed`, `mine.triggered {object, by}`. Saveable (arming, time left, armed).

signal armed

const GROUP: StringName = &"proximity_trigger"
const ARMED_BEEP_HZ: float = 2400.0
## Its word on the interaction frame while armed (blinking red).
const ARMED_WORD: StatusWord = preload("res://objects/devices/status_words/frame/armed.tres")
const DEFAULT_CONFIG: ProximityTriggerConfig = preload("res://items/grenades/proximity_trigger.tres")

@export var config: ProximityTriggerConfig = DEFAULT_CONFIG
## Where the blinking light sits (local to this node: the top of the entity).
@export var light_offset: Vector3 = Vector3(0, 0.05, 0)
@export var entity_path: NodePath = ^".."

var entity: Node3D
var is_arming: bool = false
var arming_left: float = 0.0
var is_armed: bool = false

var _tick: int = 0
var _blink_time: float = 0.0
var _light: MeshInstance3D
var _glow: OmniLight3D
var _highlight: MeshInstance3D
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(StatusWord.FRAME_GROUP)
	add_to_group(&"saveable")
	entity = get_node(entity_path) as Node3D
	if config == null:
		config = DEFAULT_CONFIG
	arming_left = config.arm_time
	_build_visuals()
	var sticky := Sticky.of(entity)
	if sticky != null:
		sticky.stuck.connect(arm)
	_show_light()


static func of(node: Node) -> ProximityTrigger:
	if node == null:
		return null
	for child in node.get_children():
		if child is ProximityTrigger:
			return child as ProximityTrigger
	return null


## Starts arming (once).
func arm() -> void:
	if is_armed or is_arming:
		return
	is_arming = true
	arming_left = config.arm_time


func _physics_process(delta: float) -> void:
	if is_arming:
		arming_left -= delta
		if arming_left <= 0.0:
			_become_armed()
	if not is_armed:
		return
	_blink_time += delta
	_show_light()
	_tick += 1
	if _tick % maxi(config.check_ticks, 1) != 0:
		return
	var who := _intruder()
	if who != null:
		_trigger(who)


## The frame's status word: "Armed" while armed.
func frame_word() -> StatusWord:
	return ARMED_WORD if is_armed else null


## Characters (bodies on `character_mask`) whose collision shapes come within `reach` m of its centre.
func characters_within(reach: float) -> Array[Node]:
	var found: Array[Node] = []
	for hit in _query(reach):
		var collider := hit["collider"] as Node
		if collider != null and not found.has(collider):
			found.append(collider)
	return found


## Shows or hides the highlight (MineSense: the Demolition skill marks armed mines nearby).
func set_highlighted(on: bool) -> void:
	_highlight.visible = on and is_armed


func is_highlighted() -> bool:
	return _highlight.visible


## The blinking light is lit now (tests, screenshots).
func is_light_on() -> bool:
	return _light.visible


func save_state() -> Dictionary:
	return {"arming": is_arming, "arming_left": arming_left, "armed": is_armed}


func load_state(data: Dictionary) -> void:
	is_arming = bool(data.get("arming", is_arming))
	arming_left = float(data.get("arming_left", arming_left))
	is_armed = bool(data.get("armed", is_armed))
	_show_light()


func _become_armed() -> void:
	is_arming = false
	is_armed = true
	_blink_time = 0.0
	_show_light()
	_audio.play()
	EventLog.record(EventKinds.MINE_ARMED, String(entity.name), "", {"object": String(entity.name)})
	armed.emit()


# The first character the tag filter accepts, close enough for its stance and in sight, or null.
func _intruder() -> Node:
	var hits := _query(config.radius)
	if hits.is_empty():
		return null
	var close: Array[Node] = []
	var checked_close := false
	for hit in hits:
		var collider := hit["collider"] as CollisionObject3D
		if collider == null:
			continue
		var tags := ActorState.tags_of(collider)
		if not config.accepts(tags.container if tags != null else null):
			continue
		if ActorState.has(collider, ActorState.CROUCHING):
			if not checked_close:
				close = characters_within(config.crouched_radius)
				checked_close = true
			if not close.has(collider):
				continue
		if _sees(collider, int(hit["shape"])):
			return collider
	return null


func _query(reach: float) -> Array[Dictionary]:
	var sphere := SphereShape3D.new()
	sphere.radius = reach
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, global_position)
	params.collision_mask = config.character_mask
	params.collide_with_areas = false
	var body := entity as CollisionObject3D
	if body != null:
		params.exclude = [body.get_rid()]
	var hits: Array[Dictionary] = []
	hits.assign(get_world_3d().direct_space_state.intersect_shape(params, 16))
	return hits


# Nothing on `sight_mask` between its centre (a little along its +Y: off a floor or ceiling, up
# beside a wall, which its centre already clears) and the centre of the character's shape
# `shape_index`.
func _sees(character: CollisionObject3D, shape_index: int) -> bool:
	var to := character.global_position
	var owner_id := character.shape_find_owner(shape_index)
	var shape_node := character.shape_owner_get_owner(owner_id) as Node3D
	if shape_node != null:
		to = shape_node.global_position
	var from := global_position + global_basis.y.normalized() * 0.02
	var exclude: Array[RID] = []
	if entity is CollisionObject3D:
		exclude.append((entity as CollisionObject3D).get_rid())
	return PhysicsLayers.segment_clear(get_world_3d().direct_space_state, from, to, config.sight_mask, exclude)


func _trigger(who: Node) -> void:
	var data := {"object": String(entity.name), "by": String(who.name)}
	EventLog.record(EventKinds.MINE_TRIGGERED, String(who.name), String(entity.name), data)
	is_armed = false
	_show_light()
	var explosive := Explosive.of(entity)
	if explosive != null:
		explosive.explode()


func _show_light() -> void:
	if _light == null:
		return
	var period := config.blink_period
	var lit := is_armed and fposmod(_blink_time, period) < period * config.blink_lit_share
	_light.visible = lit
	_glow.visible = lit
	if not is_armed:
		_highlight.visible = false


func _build_visuals() -> void:
	_light = MeshInstance3D.new()
	_light.name = "BlinkLight"
	var bulb := SphereMesh.new()
	bulb.radius = 0.008
	bulb.height = 0.016
	var lit := StandardMaterial3D.new()
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.albedo_color = Color(1.0, 0.12, 0.08)
	bulb.material = lit
	_light.mesh = bulb
	_light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light.position = light_offset
	add_child(_light)
	_glow = OmniLight3D.new()
	_glow.name = "BlinkGlow"
	_glow.light_color = Color(1.0, 0.15, 0.1)
	_glow.light_energy = 0.6
	_glow.omni_range = 0.35
	_glow.shadow_enabled = false
	_glow.position = light_offset
	add_child(_glow)
	_highlight = MeshInstance3D.new()
	_highlight.name = "Highlight"
	var shell := SphereMesh.new()
	shell.radius = 0.12
	shell.height = 0.24
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(1.0, 0.2, 0.15, 0.4)
	# Unlit (seen in the dark), unfogged and drawn after every other transparent thing (over smoke);
	# solid geometry still hides it (no seeing mines through walls).
	overlay.disable_fog = true
	overlay.render_priority = Material.RENDER_PRIORITY_MAX
	shell.material = overlay
	_highlight.mesh = shell
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_highlight.visible = false
	add_child(_highlight)
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "ArmedBeep"
	_audio.bus = GameSettings.EFFECTS_BUS
	_audio.stream = PlaceholderBeep.tone(ARMED_BEEP_HZ, 0.08)
	_audio.volume_db = -10.0
	_audio.unit_size = 2.0
	add_child(_audio)
