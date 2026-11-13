class_name TargetStatus
extends RefCounted
## The interaction frame's status line (ADR 0130), decided by components, never by what a thing is:
## - which things the frame shows besides what E acts on: anything with a Device, a Powered or
##   BodyParts (a character) under the crosshair within reach (qualifies(), shows());
## - the word and its colour: a Device on a network (cables either way, a wireless link or clients,
##   or an access point named) says Online / Cut off (blinks) / Jammed (blinks: a jamming field cuts
##   its wireless link, DeviceNetwork.is_jammed(), M14b) / Disabled (switched off by a command,
##   DeviceStatus.is_disabled()) / Broken / No power in the status light's colours; a powered thing
##   off any network says Powered / No power / Broken; a character says nothing while awake,
##   Unconscious or Dead; anything else nothing (a Device off any network without power wiring says
##   only Broken, or No power while an EMP's outage lasts). Before those, any component of the
##   thing in StatusWord.FRAME_GROUP may say its own word (component_word(): a mine's
##   ProximityTrigger says Armed, blinking red; ADR 0131).
## The words are StatusWords (ADR 0137: text, colour, blink; null: no status line), `.tres` data in
## objects/devices/status_words/frame/. The network rule is the one the status lights show, read from
## NetworkState (links_of(), is_networked(), on_network()) so the HUD does not depend on a light being
## attached; the network words take StatusLight.COLORS (tests hold them to it).
## The pure rules (qualifies, *_word, blink_alpha) take plain values; the readers take nodes.

const ONLINE: StatusWord = preload("res://objects/devices/status_words/frame/online.tres")
const CUT_OFF: StatusWord = preload("res://objects/devices/status_words/frame/cut_off.tres")
const JAMMED: StatusWord = preload("res://objects/devices/status_words/frame/jammed.tres")
const DISABLED: StatusWord = preload("res://objects/devices/status_words/frame/disabled.tres")
const BROKEN: StatusWord = preload("res://objects/devices/status_words/frame/broken.tres")
## Grey: the dark light's colour is unreadable on the tag's dark box.
const NO_POWER: StatusWord = preload("res://objects/devices/status_words/frame/no_power.tres")
const POWERED: StatusWord = preload("res://objects/devices/status_words/frame/powered.tres")
## The stun colour family (blue-white) and a dim red (the approved mockup's).
const UNCONSCIOUS: StatusWord = preload("res://objects/devices/status_words/frame/unconscious.tres")
const DEAD: StatusWord = preload("res://objects/devices/status_words/frame/dead.tres")
## The lock line ("Locked · keycard").
const LOCKED_COLOR := Color("ffd14d")
## Blinks like the status LED (status_light.gdshader): lit while fract(t * BLINK_RATE) >= 0.5, else
## at BLINK_DIM.
const BLINK_RATE: float = 1.25
const BLINK_DIM: float = 0.15


## True when the frame shows the thing under the crosshair: E acts on it, or it is a device, a
## powered thing or a character.
static func qualifies(interactable: bool, has_device: bool, has_powered: bool, is_character: bool) -> bool:
	return interactable or has_device or has_powered or is_character


## A network device's word: no power first, then broken, then switched off, then jammed, then
## whether it still has its network.
static func network_word(
	powered: bool, broken: bool, disabled: bool, has_network: bool, jammed: bool = false
) -> StatusWord:
	if not powered:
		return NO_POWER
	if broken:
		return BROKEN
	if disabled:
		return DISABLED
	if jammed:
		return JAMMED
	return ONLINE if has_network else CUT_OFF


## A powered thing off any network.
static func powered_word(powered: bool, broken: bool) -> StatusWord:
	if broken:
		return BROKEN
	return POWERED if powered else NO_POWER


## A character: nothing (null) while awake.
static func character_word(dead: bool, unconscious: bool) -> StatusWord:
	if dead:
		return DEAD
	return UNCONSCIOUS if unconscious else null


## The square's opacity at `seconds` while blinking: 1 in the lit half of each period, else BLINK_DIM.
static func blink_alpha(seconds: float) -> float:
	return 1.0 if fposmod(seconds * BLINK_RATE, 1.0) >= 0.5 else BLINK_DIM


## True when `entity` has a Device, a Powered or BodyParts (the frame shows it within reach).
static func shows(entity: Node) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	return qualifies(false, Device.of(entity) != null, Powered.of(entity) != null, is_character(entity))


## A character is what BodyParts makes one (it writes `state.dead` / `state.unconscious`).
static func is_character(entity: Node) -> bool:
	return BodyParts.of(entity) != null


## The word for `entity` now (null: none); `links`: its Device's NetworkState.links_of() (read once by
## the caller).
static func word_of(entity: Node, links: Array[Device]) -> StatusWord:
	if entity == null or not is_instance_valid(entity):
		return null
	var own := component_word(entity)
	if own != null:
		return own
	if is_character(entity):
		return character_word(ActorState.is_dead(entity), ActorState.has(entity, ActorState.UNCONSCIOUS))
	var device := Device.of(entity)
	var powered := Powered.of(entity)
	var broken := _is_broken(entity, device)
	if device != null and NetworkState.is_networked(device, links):
		var disabled := DeviceStatus.is_disabled(entity)
		var has_network := NetworkState.on_network(device, links)
		return network_word(device.is_powered(), broken, disabled, has_network, DeviceNetwork.is_jammed(device))
	if powered != null:
		return powered_word(powered.is_on() and not ActorState.has(entity, Device.UNPOWERED), broken)
	if device != null and not device.is_powered():
		# No power wiring but knocked out (an EMP): no power while it lasts.
		return powered_word(false, broken)
	return BROKEN if broken else null


## The first word one of `entity`'s components in StatusWord.FRAME_GROUP says (frame_word()), or null.
static func component_word(entity: Node) -> StatusWord:
	for child in entity.get_children():
		if child.is_in_group(StatusWord.FRAME_GROUP) and child.has_method(&"frame_word"):
			var word := child.call(&"frame_word") as StatusWord
			if word != null:
				return word
	return null


## The lock line for `entity` seen by `user` ("Locked · key or lockpick"), "" unless its Lockable
## (or the one its Usable works: a door controller's box shows its door's, Usable.lock_target()) is
## locked.
static func lock_line(entity: Node, user: Node) -> String:
	if entity == null or not is_instance_valid(entity):
		return ""
	var lockable := Lockable.of(entity)
	var usable := Usable.of(entity)
	if lockable == null and usable != null:
		lockable = usable.lock_target()
	if lockable == null or not lockable.locked:
		return ""
	return LockRules.locked_line(lockable.reasons(user))


## The name shown for a thing E does not act on: a network device's network name, else its usable's
## target name, else its display name (Interactor.display_name_of()).
static func name_of(entity: Node) -> String:
	var usable := Usable.of(entity)
	if usable != null and Device.of(entity) == null and not usable.target_name().is_empty():
		return usable.target_name()
	return Interactor.display_name_of(entity)


static func _is_broken(entity: Node, device: Device) -> bool:
	if device != null and device.broken:
		return true
	if ActorState.has(entity, Device.BROKEN):
		return true
	var breakable := Breakable.of(entity)
	return breakable != null and breakable.is_broken
