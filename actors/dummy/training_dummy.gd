class_name TrainingDummy
extends StaticBody3D
## Training dummy: a static humanoid target with BodyParts (dummy profile), Hitboxes, Awareness
## (exported, unaware by default) and a facing (-Z, marked by the visor). Every hit shows a floating
## number (part and amount); knocked out or dead it tips over backwards. `use` (E) or reset()
## restores health, consciousness and pose. Collision layers 3 (actors) and 7 (static actors: props
## bounce off it, ADR 0070); weapons hit its hitboxes.

const NUMBER_TIME: float = 1.2
const NUMBER_RISE: float = 0.5
const TIP_TIME: float = 0.5
const NUMBER_COLORS: Dictionary[StringName, Color] = {
	&"damage.stun": Color(0.45, 0.7, 1.0),
	&"knockout": Color(1.0, 0.85, 0.2),
}
## Lying on its back: tipped +90 degrees about X at the feet (it faces -Z, so it falls backwards
## onto +Z), lifted so the torso rests on the floor.
const LYING := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.15, 0))

## True while tipped over (dead or unconscious).
var is_down: bool = false

var _tween: Tween
var _stack: int = 0
var _fall: float = 0.0
var _standing_collision: Transform3D

@onready var body: BodyParts = $BodyParts
@onready var hitboxes: Hitboxes = $Hitboxes
@onready var pose: Node3D = $Pose
@onready var _collision: CollisionShape3D = $Collision
@onready var _numbers: Node3D = $Numbers


func _ready() -> void:
	_standing_collision = _collision.transform
	body.damaged.connect(_on_damaged)
	body.stunned.connect(_on_stunned)
	body.knocked_out.connect(_on_knocked_out)
	body.changed.connect(_update_pose)
	var usable := Usable.of(self)
	if usable != null:
		usable.used.connect(func(_user: Node) -> void: reset())


## Full health, conscious, upright, numbers cleared.
func reset() -> void:
	body.reset()
	for label in _numbers.get_children():
		label.queue_free()
	_stack = 0
	EventLog.record(&"actor.reset", String(name), "", {"actor": String(name)})


## The floating number labels currently shown (newest last).
func damage_numbers() -> Array[Label3D]:
	var labels: Array[Label3D] = []
	for child in _numbers.get_children():
		if child is Label3D and not child.is_queued_for_deletion():
			labels.append(child as Label3D)
	return labels


func _on_damaged(part: StringName, type: StringName, amount: float) -> void:
	_show_number(part, "%s %s" % [part, _amount_text(amount)], NUMBER_COLORS.get(type, Color.WHITE))


func _on_stunned(amount: float, _total: float) -> void:
	_show_number(BodyDamageModel.HEAD, "stun %s" % _amount_text(amount), NUMBER_COLORS[&"damage.stun"])


func _on_knocked_out() -> void:
	_show_number(BodyDamageModel.HEAD, "KO", NUMBER_COLORS[&"knockout"])


func _update_pose() -> void:
	var down := body.is_dead() or body.is_unconscious()
	if down == is_down:
		return
	is_down = down
	if _tween != null:
		_tween.kill()
		_tween = null
	if not down:
		_set_fall(0.0)
		return
	_tween = create_tween()
	_tween.tween_method(_set_fall, _fall, 1.0, TIP_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


# 0 = standing, 1 = lying: the figure, its hitboxes and its collision capsule all tip together.
func _set_fall(amount: float) -> void:
	_fall = amount
	var lying := Transform3D.IDENTITY.interpolate_with(LYING, amount)
	pose.transform = lying
	hitboxes.transform = lying
	_collision.transform = lying * _standing_collision


func _show_number(part: StringName, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.font_size = 40
	label.outline_size = 10
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	_numbers.add_child(label)
	var box := hitboxes.box(part)
	var anchor := box.global_position if box != null else global_position + Vector3.UP * 1.2
	# Numbers in quick succession alternate sides and heights instead of overlapping.
	var side := 0.35 if _stack % 2 == 0 else -0.35
	label.global_position = anchor + Vector3(side, 0.1 + 0.14 * (_stack % 3), 0)
	_stack += 1
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, ^"position:y", label.position.y + NUMBER_RISE, NUMBER_TIME)
	tween.tween_property(label, ^"modulate:a", 0.0, NUMBER_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


static func _amount_text(amount: float) -> String:
	return str(roundi(amount)) if is_equal_approx(amount, roundf(amount)) else "%.1f" % amount
