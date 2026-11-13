class_name DeviceStatus
extends RefCounted
## What a device shows on a security screen (ADR 0083, ADR 0137), collected without knowing what the
## device is. A component interface (conventions.md): each behaviour component on a device's entity
## that joins GROUP (in its _ready) may offer:
## - `device_status() -> Array[StatusWord]`: its state in words, in order (ENABLED, a camera's
##   "sweeping", RINGING, a door's "open", a lock's "locked", ...; StatusWord constants, an alert word
##   flagged `alert`). Never "broken" or "offline": a screen shows a device it cannot reach as offline
##   whatever the reason (unpowered, broken, a dead switch).
## - `device_commands() -> Array[StringName]`: the commands it handles that change something now, in
##   its order (a sweeping camera offers Stop sweep, not Resume sweep; a locked door Unlock, not
##   Lock; switched off, only Enable). Each component owns its command constants (Door.OPEN,
##   Lockable.LOCK, SecurityCamera.STOP_SWEEP, DeviceSwitch.ENABLE, ...): a new command needs no edit
##   outside its component (and a label in the screens' command tables, data).
## - `device_view() -> Node3D`: the node it sees from (its -Z is the view direction), or null while
##   it sees nothing (disabled). A device has a view when one of its components has the method.
## - `device_disabled() -> bool`: true while a command has switched it off (`command.disable`, or
##   `command.disarm`: a blind camera, a dark laser array, a turret or an alarm controller off).
##   Only components that can be switched off offer it: a device without one is never disabled.
##   Screens colour a disabled device apart (ADR 0099 amendment); it is still online.
## Entities' direct children in GROUP are asked, in tree order.
## The colour rule of the screens is tone() (each screen has its palette for the tones).

## A device's colour class on a security screen (tone()).
enum Tone { ONLINE, OFFLINE, DISABLED, ACCESS, ALERT }

## The group of the components that report to security screens (the methods below).
const GROUP: StringName = &"device_reporter"
const STATUS_METHOD: StringName = &"device_status"
const COMMANDS_METHOD: StringName = &"device_commands"
const VIEW_METHOD: StringName = &"device_view"
const DISABLED_METHOD: StringName = &"device_disabled"
## The words screens add themselves, and those several kinds of device say.
const ONLINE: StatusWord = preload("res://objects/devices/status_words/online.tres")
const OFFLINE: StatusWord = preload("res://objects/devices/status_words/offline.tres")
const ENABLED: StatusWord = preload("res://objects/devices/status_words/enabled.tres")
const DISABLED: StatusWord = preload("res://objects/devices/status_words/disabled.tres")
const IDLE: StatusWord = preload("res://objects/devices/status_words/idle.tres")
const RINGING: StatusWord = preload("res://objects/devices/status_words/ringing.tres")
const SILENT: StatusWord = preload("res://objects/devices/status_words/silent.tres")
## Between words on a screen ("online · enabled · sweeping").
const SEPARATOR: String = " · "


## The words a screen shows for a device: just OFFLINE when not `online`, else ONLINE then `parts`
## (duplicate texts and empty words dropped, "online" / "offline" never repeated).
static func summarize(online: bool, parts: Array[StatusWord]) -> Array[StatusWord]:
	if not online:
		return [OFFLINE] as Array[StatusWord]
	var words: Array[StatusWord] = [ONLINE]
	var seen := PackedStringArray([ONLINE.text, OFFLINE.text])
	for part in parts:
		if part == null or part.text.is_empty() or seen.has(part.text):
			continue
		seen.append(part.text)
		words.append(part)
	return words


## Every component's status words for `entity`, in tree order.
static func parts_of(entity: Node) -> Array[StatusWord]:
	var parts: Array[StatusWord] = []
	for child in Entities.members(entity, GROUP, STATUS_METHOD):
		for word: Variant in child.call(STATUS_METHOD) as Array:
			if word is StatusWord:
				parts.append(word as StatusWord)
	return parts


## summarize() of `entity`'s components (not asked when offline).
static func words_of(entity: Node, online: bool) -> Array[StatusWord]:
	var parts: Array[StatusWord] = []
	if online:
		parts = parts_of(entity)
	return summarize(online, parts)


## The texts of words_of() ("online", "enabled", "sweeping").
static func of(entity: Node, online: bool) -> PackedStringArray:
	return StatusWord.texts(words_of(entity, online))


## The words joined for display ("online · enabled · sweeping").
static func text(texts: PackedStringArray) -> String:
	return SEPARATOR.join(texts)


## A list row's short status: "offline", else the words after "online" ("online" when none).
static func short_text(texts: PackedStringArray) -> String:
	if texts.has(OFFLINE.text):
		return OFFLINE.text
	var rest := PackedStringArray()
	for word in texts:
		if word != ONLINE.text:
			rest.append(word)
	return text(rest) if not rest.is_empty() else ONLINE.text


## The colour rule of every security screen: a device whose words are `texts` (summarize()), that is
## `disabled` or not, that the viewer has `access` to or not, and that says an `alert` word or not:
## OFFLINE beats the rest (an unreachable device's state is unknown), then DISABLED, ACCESS, ALERT,
## else ONLINE.
static func tone(texts: PackedStringArray, disabled: bool = false, access: bool = false, alert: bool = false) -> Tone:
	if texts.has(OFFLINE.text):
		return Tone.OFFLINE
	if disabled:
		return Tone.DISABLED
	if access:
		return Tone.ACCESS
	return Tone.ALERT if alert else Tone.ONLINE


## True when a component of `entity` says it is switched off (`device_disabled()`).
static func is_disabled(entity: Node) -> bool:
	for child in Entities.members(entity, GROUP, DISABLED_METHOD):
		if bool(child.call(DISABLED_METHOD)):
			return true
	return false


## The commands of `commands` (a screen's table, those the device accepts) worth offering for
## `entity` now, in their order: those one of its components offers now (`device_commands()`); while
## a component is switched off, only what the switched-off components offer (Enable: nothing else
## works until then). A device whose components offer none (no `device_commands()`): all of them.
static func applicable(commands: Array[StringName], entity: Node) -> Array[StringName]:
	var found: Array[StringName] = []
	if entity == null or not is_instance_valid(entity):
		return found
	var declared := false
	var disabled := false
	var on: Array[StringName] = []
	var off: Array[StringName] = []
	for child in Entities.members(entity, GROUP):
		var switched_off := child.has_method(DISABLED_METHOD) and bool(child.call(DISABLED_METHOD))
		disabled = disabled or switched_off
		if not child.has_method(COMMANDS_METHOD):
			continue
		declared = true
		var list: Array[StringName] = off if switched_off else on
		for command: Variant in child.call(COMMANDS_METHOD) as Array:
			list.append(StringName(command))
	if not declared and not disabled:
		return commands.duplicate()
	var offered: Array[StringName] = off if disabled else on
	for command in commands:
		if offered.has(command):
			found.append(command)
	return found


## True when a component of `entity` offers a view.
static func has_view(entity: Node) -> bool:
	return _view_component(entity) != null


## The node `entity` sees from now, or null (no view, or it sees nothing).
static func view_of(entity: Node) -> Node3D:
	var component := _view_component(entity)
	return component.call(VIEW_METHOD) as Node3D if component != null else null


static func _view_component(entity: Node) -> Node:
	var found := Entities.members(entity, GROUP, VIEW_METHOD)
	return found[0] if not found.is_empty() else null
