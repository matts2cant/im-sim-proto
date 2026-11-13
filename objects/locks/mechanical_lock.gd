class_name MechanicalLock
extends Lock
## Lock component: a pin-tumbler lock (ADR 0078), a keyhole on the door leaf's handle on both faces
## (ADR 0098: it is picked by looking at the leaf). Its pins are data (`MechanicalLockData`). The pick
## hook is the Lock tool interface: a user holding a tool of kind `data.tool` (a lockpick) works it
## through ToolUse, which opens the user's lockpicking screen, the minigame (ADR 0107), through its
## Screens (SCREEN); a user without one cannot pick. The minigame builds its PinTumbler model from
## this lock (new_model()), reports its noises through pick_noise() (a `noise` from the lock, like
## any noise) and its success through complete_pick() (unlocks it for the user, who wants it open).
## Success consumes nothing.
## A practice lock (`data.practice`) re-locks `practice_relock_delay` s after it opened, with a new
## random layout of its tier's pins (PracticeRelock); its layout counter and seed are saved.
## Keys (ADR 0130): a lock whose `data.key_id` names a key opens with E when that key is on the
## user's Keychain (use_locked()); its reason is then "key or lockpick", else "lockpick".
## EventLog `lock.pick_started {entity}`, `lock.pick_cancelled {entity, reason}`, `lock.picked`,
## `lock.pick_broke`, `lock.relocked {entity, layout}`.

## A practice lock re-locked with layout number `layout`.
signal relocked(layout: int)

## The screen id the lock asks its picker's Screens for (the lockpicking minigame).
const SCREEN: StringName = &"lockpick"
const HARDWARE: PackedScene = preload("res://objects/locks/hardware/keyhole.tscn")
const DEFAULT_TUNING: LockpickTuning = preload("res://objects/locks/lockpicking/lockpick_tuning.tres")

@export var data: MechanicalLockData
## Minigame tuning (practice tiers, re-lock delay); the shared default when empty.
@export var tuning: LockpickTuning

var _relock: PracticeRelock = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	if tuning == null:
		tuning = DEFAULT_TUNING
	if is_practice():
		add_to_group(&"saveable")
		_rng.randomize()
		_relock = PracticeRelock.new(tuning.practice_relock_delay, _rng.randi_range(1, 99999))


func _physics_process(delta: float) -> void:
	if _relock == null or not _relock.advance(delta, _rng):
		return
	var target := lockable()
	if target != null:
		target.lock(null, &"practice")
	_log(EventKinds.LOCK_RELOCKED, null, {"layout": _relock.layout})
	relocked.emit(_relock.layout)


func mount() -> int:
	return Mount.LEAF


func hardware() -> PackedScene:
	return HARDWARE


func pin_count() -> int:
	return types().size()


func is_practice() -> bool:
	return data != null and data.practice


## The practice layout counter (1 first), 0 for a real lock.
func layout_number() -> int:
	return _relock.layout if _relock != null else 0


## A practice lock's tier name ("Standard"), "" for a real lock.
func tier_name() -> String:
	var tier := _practice_tier()
	return tier.display_name if tier != null else ""


## The pin types of the current layout (a practice lock: its tier's, shuffled by the model).
func types() -> Array[StringName]:
	var tier := _practice_tier()
	if tier != null:
		return tier.pins
	return data.pins if data != null else ([] as Array[StringName])


## A new minigame model of this lock's current layout for a picker with `params`.
func new_model(params: LockpickParams) -> PinTumbler:
	var model := PinTumbler.new(tuning if tuning != null else DEFAULT_TUNING, params)
	model.build(types(), _seed(), _tolerance(), _practice_tier() != null)
	return model


## A practice lock re-locked: `model` turns back and takes the new layout.
func relayout(model: PinTumbler) -> void:
	model.relock(types(), _seed(), _tolerance(), _practice_tier() != null)


## E with its key on the user's keychain unlocks it (EventLog `lock.unlocked`, how `key`) and the
## user wants it open; without it, it is picked (LMB with a lockpick).
func use_locked(user: Node) -> bool:
	if not _has_key(user):
		return false
	return unlock_for(user, &"key")


func locked_reason(_user: Node) -> String:
	return "lockpick" if String(_key_id()).is_empty() else "key or lockpick"


func accepts_tool(tool: StringName) -> bool:
	return data != null and tool == data.tool and is_locked()


## Working it with the tool opens the user's lockpicking minigame (Screens, SCREEN; the screen does
## the rest).
func tool_hold(user: Node, _delta: float) -> bool:
	if not is_locked():
		return false
	if not Screens.is_open(user, SCREEN):
		Screens.open(user, SCREEN, self)
	return false


## The minigame started (`user` picks it).
func pick_started(user: Node) -> void:
	_log(EventKinds.LOCK_PICK_STARTED, user, {})


## The minigame ended without opening it (`reason`: left, damage, out_of_reach, unlocked, no_picks).
func pick_cancelled(user: Node, reason: StringName) -> void:
	_log(EventKinds.LOCK_PICK_CANCELLED, user, {"reason": String(reason)})


## A pick broke on it.
func pick_broke(user: Node) -> void:
	_log(EventKinds.LOCK_PICK_BROKE, user, {})


## The minigame opened it: unlocks it for `user` (who wants it open). A practice lock starts its
## re-lock countdown. False when it was not locked.
func complete_pick(user: Node) -> bool:
	_log(EventKinds.LOCK_PICKED, user, {})
	if _relock != null:
		_relock.opened()
	return unlock_for(user, &"pick")


## A `noise` of `loudness` from the lock (the minigame's clicks, jams, snaps).
func pick_noise(loudness: float) -> void:
	if loudness <= 0.0 or not is_inside_tree():
		return
	StimulusSystem.emit(Stimulus.make_noise(loudness, noise_origin(), entity if entity != null else self))


func save_state() -> Dictionary:
	return _relock.save_state() if _relock != null else {}


func load_state(state: Dictionary) -> void:
	if _relock != null:
		_relock.load_state(state)


func _practice_tier() -> LockpickTier:
	if not is_practice():
		return null
	return (tuning if tuning != null else DEFAULT_TUNING).tier(data.practice_tier)


# The id of the key that opens it (`data.key_id`), &"" when no key exists.
func _key_id() -> StringName:
	return data.key_id if data != null else &""


# True when `user` carries its key (on a Keychain: ADR 0130). A lock without a key id has none.
func _has_key(user: Node) -> bool:
	var keychain := Keychain.of(user)
	return keychain != null and keychain.has_key(_key_id())


func _seed() -> int:
	if _relock != null:
		return _relock.pin_seed
	return data.pin_seed if data != null else 0


func _tolerance() -> float:
	var tier := _practice_tier()
	if tier != null:
		return tier.tolerance_mult
	return data.tolerance_mult if data != null else 1.0


func _log(kind: StringName, user: Node, extra: Dictionary) -> void:
	var target := String(entity.name) if entity != null else ""
	var data_out := {"entity": target}
	data_out.merge(extra)
	EventLog.record(kind, String(user.name) if is_instance_valid(user) else "", target, data_out)
