class_name Augmentations
extends Node
## Component: the entity's augmentations (AugmentationData). Installed ones can be switched on; a
## passive one is on while installed. While on, an augmentation's modifiers and tags sit on the
## entity (re-derived on every change, source `aug.<id>`, so they stack with skills and injuries)
## and its pulse stimuli go to the entity. Every physics tick the toggles that are on drain the
## sibling Energy; at 0 they all switch off with "Energy depleted", and switching one on with no
## energy fails with the same message. Logged: `augmentation.activated`, `augmentation.deactivated`
## {reason}, `augmentation.refused`, `augmentation.installed`. Any entity with Attributes, Tags and
## Energy can have them (ADR 0061). Saveable (installed and active ids).

signal changed
## Short feedback for its own page ("Energy depleted"); the same text goes to the entity's
## Notices.
signal message(text: String)

const DEPLETED := "Energy depleted"
## Timer slack so float error never costs a whole tick.
const TIMER_SLACK: float = 0.0001

@export var catalog: Array[AugmentationData] = []
## Installed at start; empty installs none.
@export var installed_at_start: Array[StringName] = []

var _installed: Dictionary[StringName, bool] = {}
var _active: Dictionary[StringName, bool] = {}
# Seconds until each active augmentation's next pulse.
var _pulse_left: Dictionary[StringName, float] = {}
var _energy: Energy


static func of(entity: Node) -> Augmentations:
	if not is_instance_valid(entity):
		return null
	return entity.get_node_or_null(^"Augmentations") as Augmentations


func _ready() -> void:
	add_to_group(&"saveable")
	_energy = Energy.of(get_parent())
	for id in installed_at_start:
		if find(id) != null:
			_installed[id] = true
	_apply_all()


func entity() -> Node:
	return get_parent()


# Feedback: its page's `message` and the entity's Notices.
func _say(text: String) -> void:
	message.emit(text)
	Notices.send(get_parent(), text)


func find(id: StringName) -> AugmentationData:
	for data in catalog:
		if data != null and data.id == id:
			return data
	return null


## The toggle bound to `slot` (aug_<slot>), or null.
func in_slot(slot: int) -> AugmentationData:
	for data in catalog:
		if data != null and not data.passive and data.slot == slot:
			return data
	return null


func is_installed(id: StringName) -> bool:
	return _installed.get(id, false)


## On: an active toggle, or an installed passive augmentation.
func is_active(id: StringName) -> bool:
	var data := find(id)
	if data == null or not is_installed(id):
		return false
	return data.passive or _active.get(id, false)


## Ids of the augmentations that are on, in catalogue order.
func active_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for data in catalog:
		if data != null and is_active(data.id):
			ids.append(data.id)
	return ids


## Energy per second the toggles that are on drain together.
func drain_rate() -> float:
	var total := 0.0
	for data in catalog:
		if data != null and not data.passive and is_active(data.id):
			total += data.drain_per_second
	return total


## Installs or removes `id`; removing switches it off.
func set_installed(id: StringName, installed: bool) -> void:
	if find(id) == null or is_installed(id) == installed:
		return
	if not installed and _active.get(id, false):
		deactivate(id, &"uninstalled")
	_installed[id] = installed
	_apply(id)
	EventLog.record(EventKinds.AUGMENTATION_INSTALLED, _who(), "", {"id": String(id), "installed": installed})
	changed.emit()


## Switches a toggle on or off; returns whether it is on afterwards.
func toggle(id: StringName) -> bool:
	if is_active(id):
		var data := find(id)
		if data != null and not data.passive:
			deactivate(id, &"toggled")
		return is_active(id)
	return activate(id)


## Toggles the augmentation in `slot`; false when there is none.
func toggle_slot(slot: int) -> bool:
	var data := in_slot(slot)
	if data == null:
		return false
	toggle(data.id)
	return true


## Switches a toggle on; false (and logged) when it is not installed, passive, or there is no energy.
func activate(id: StringName) -> bool:
	var data := find(id)
	if data == null or data.passive or is_active(id):
		return is_active(id)
	var reason := ""
	if not is_installed(id):
		reason = "not_installed"
	elif _energy == null or _energy.is_empty():
		reason = "no_energy"
	if not reason.is_empty():
		EventLog.record(EventKinds.AUGMENTATION_REFUSED, _who(), "", {"id": String(id), "reason": reason})
		if reason == "no_energy":
			_say(DEPLETED)
		return false
	_active[id] = true
	_pulse_left[id] = data.pulse_interval
	_apply(id)
	EventLog.record(EventKinds.AUGMENTATION_ACTIVATED, _who(), "", {"id": String(id), "energy": _energy.current()})
	changed.emit()
	return true


func deactivate(id: StringName, reason: StringName = &"toggled") -> void:
	if not _active.get(id, false):
		return
	_active.erase(id)
	_pulse_left.erase(id)
	_apply(id)
	EventLog.record(EventKinds.AUGMENTATION_DEACTIVATED, _who(), "", {"id": String(id), "reason": String(reason)})
	changed.emit()


func deactivate_all(reason: StringName) -> void:
	for id: StringName in _active.keys():
		deactivate(id, reason)


func _physics_process(delta: float) -> void:
	if _active.is_empty():
		return
	if _energy != null:
		_energy.spend(drain_rate() * delta)
	if _energy == null or _energy.is_empty():
		deactivate_all(&"depleted")
		_say(DEPLETED)
		return
	for id: StringName in _active.keys():
		_pulse(find(id), delta)


# Counts down the pulse timer; on zero sends the pulse stimuli that would do something.
func _pulse(data: AugmentationData, delta: float) -> void:
	if data == null or data.pulse_stimuli.is_empty() or data.pulse_interval <= 0.0:
		return
	_pulse_left[data.id] = _pulse_left.get(data.id, data.pulse_interval) - delta
	if _pulse_left[data.id] > TIMER_SLACK:
		return
	_pulse_left[data.id] += data.pulse_interval
	var target := entity()
	for type: StringName in data.pulse_stimuli:
		var stimulus := Stimulus.make_contact(type, data.pulse_stimuli[type], target, target)
		if StimulusSystem.would_affect(stimulus):
			StimulusSystem.emit(stimulus)


func save_state() -> Dictionary:
	var installed: Array[String] = []
	var active: Array[String] = []
	for data in catalog:
		if data == null:
			continue
		if is_installed(data.id):
			installed.append(String(data.id))
		if _active.get(data.id, false):
			active.append(String(data.id))
	return {"installed": installed, "active": active}


## Restores installed and active ids and re-derives the modifiers and tags (no log entries).
func load_state(data: Dictionary) -> void:
	_installed.clear()
	_active.clear()
	_pulse_left.clear()
	for id: Variant in data.get("installed", []):
		if find(StringName(str(id))) != null:
			_installed[StringName(str(id))] = true
	for id: Variant in data.get("active", []):
		var aug := find(StringName(str(id)))
		if aug != null and not aug.passive and is_installed(aug.id):
			_active[aug.id] = true
			_pulse_left[aug.id] = aug.pulse_interval
	_apply_all()
	changed.emit()


func _apply_all() -> void:
	for data in catalog:
		if data != null:
			_apply(data.id)


# Replaces the augmentation's modifiers and tags on the entity with what its state says.
func _apply(id: StringName) -> void:
	var data := find(id)
	if data == null:
		return
	var on := is_active(id)
	var attributes := Attributes.of(entity())
	if attributes != null:
		attributes.attribute_set.remove_by_source(data.source())
		if on:
			for modifier in data.make_modifiers():
				attributes.attribute_set.add_modifier(modifier)
	for tag in data.tags:
		ActorState.set_tag(entity(), tag, on)


func _who() -> String:
	return String(entity().name)
