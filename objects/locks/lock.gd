class_name Lock
extends Node3D
## Base of the lock components (ADR 0078): one way to unlock the entity's Lockable. Its sounds and
## noises come from where it sits; a Door places it on its hardware (ADR 0098). A subclass overrides
## the hooks it needs; the entity (a Door) asks every Lock on it:
## - mount() / hardware(): where its hardware goes and what it looks like (ADR 0098): a fitting on the
##   door leaf (a keyhole), its own box on the wall beside the frame (keypad, card reader), or only a
##   light on any wall box (an electronic lock: its own status box when there is no other);
## - use_prompt() / use_locked(): what E does to the locked entity (enter a code, swipe a card);
## - locked_reason(): why it stays shut ("keycard", "lockpick"), for "Locked: ..." prompts;
## - grants_passage() / passage_layers(): characters it lets through while locked (navigation);
## - accepts_tool() / tool_hold() / tool_release() / tool_progress(): a held tool worked on it
##   (ToolUse; the hold-to-pick placeholder until M10's minigame).
## Any lock can have a free side (ADR 0090): from that side of the entity (its +Z: FRONT, -Z: BACK)
## it opens without the key, like an exit handle or a push bar (opens_freely_for(); the Door opens
## without unlocking it, Lockable.grants_passage() lets characters there through).

## Where a lock's hardware goes (ADR 0098): LEAF on the door leaf, on both faces (moves with it);
## WALL its own box on the wall beside the frame, on both faces; INDICATOR only the lock light on
## the wall boxes (its own box, hardware(), when the entity has no other).
enum Mount { LEAF, WALL, INDICATOR }

## Free sides of the entity: none, FRONT (its +Z side), BACK (its -Z side).
const NO_SIDE := 0
const FRONT := 1
const BACK := 2

@export var entity_path: NodePath = ^".."
## The side of the entity from which it opens without this lock (NONE: no free side).
@export_enum("None", "Front", "Back") var free_side: int = NO_SIDE

var entity: Node


func _ready() -> void:
	entity = get_node_or_null(entity_path)


## The Lock components of `node`, in child order.
static func locks_of(node: Node) -> Array[Lock]:
	var result: Array[Lock] = []
	if node == null:
		return result
	for child in node.get_children():
		if child is Lock:
			result.append(child as Lock)
	return result


## Where its hardware goes (Mount).
func mount() -> int:
	return Mount.INDICATOR


## The scene of its hardware (a wall box: StaticBody3D with a `Shape` CollisionShape3D box, origin on
## the back face, +Z out, a `Light` mesh; a leaf fitting: a Node3D on the leaf's face, +Z out), or null.
func hardware() -> PackedScene:
	return null


func lockable() -> Lockable:
	return Lockable.of(entity)


func is_locked() -> bool:
	var target := lockable()
	return target != null and target.locked


## Unlocks the entity for `user` (who wants it open); false when it was not locked.
func unlock_for(user: Node, how: StringName) -> bool:
	var target := lockable()
	return target != null and target.unlock(user, how, true)


## Opens the locked entity for `user` without unlocking it (a card swipe: it is locked again once
## closed). False when it was not locked.
func grant_for(user: Node, how: StringName) -> bool:
	var target := lockable()
	return target != null and target.grant(user, how)


## Prompt for E on the locked entity when this lock can be dealt with that way ("E: enter code"),
## else "".
func use_prompt(_user: Node) -> String:
	return ""


## E on the locked entity: true when this lock handled it.
func use_locked(_user: Node) -> bool:
	return false


## A word or two on what opens it, for "Locked: ..." ("keycard"); "" to say nothing.
func locked_reason(_user: Node) -> String:
	return ""


## True when `actor` may pass while it is locked (a keycard it carries).
func grants_passage(_actor: Node) -> bool:
	return false


## True when `user` stands on this lock's free side of the entity (it opens from there without a
## key). False without a free side or when either is not a Node3D.
func opens_freely_for(user: Node) -> bool:
	var body := user as Node3D
	var anchor := entity as Node3D
	if free_side == NO_SIDE or body == null or anchor == null:
		return false
	if not body.is_inside_tree() or not anchor.is_inside_tree():
		return false
	var depth := anchor.global_basis.z.normalized().dot(body.global_position - anchor.global_position)
	return LockRules.on_free_side(free_side, depth)


## Navigation layers that may plan a path through it while locked (AccessLayers).
func passage_layers() -> int:
	return 0


## True when a held tool of kind `tool` works on it now.
func accepts_tool(_tool: StringName) -> bool:
	return false


## `user` keeps working it with the tool for `delta` s; true when that unlocked it.
func tool_hold(_user: Node, _delta: float) -> bool:
	return false


## `user` stopped working it (let go, looked away): progress is lost.
func tool_release(_user: Node) -> void:
	pass


## 0..1 progress of the tool work in progress, or -1 when nobody is working it.
func tool_progress() -> float:
	return -1.0


## Origin of this lock's noises.
func noise_origin() -> Vector3:
	return global_position if is_inside_tree() else Vector3.ZERO


## Emits a `noise` of `loudness` from the lock (PATH, like any noise) and plays a placeholder tone.
func make_noise(loudness: float, tone_hz: float) -> void:
	if not is_inside_tree():
		return
	if loudness > 0.0:
		var noise := Stimulus.make_noise(loudness, noise_origin(), entity if entity != null else self)
		StimulusSystem.emit(noise)
	var audio := AudioStreamPlayer3D.new()
	audio.stream = PlaceholderBeep.tone(tone_hz)
	audio.unit_size = 4.0
	audio.process_mode = Node.PROCESS_MODE_ALWAYS
	audio.finished.connect(audio.queue_free)
	add_child(audio)
	audio.play()
