class_name TargetStatus
extends RefCounted
## The interaction frame's status line (ADR 0130), decided by components, never by what a thing is:
## - which things the frame shows besides what E acts on: anything with a Device, a Powered or
##   BodyParts (a character) under the crosshair within reach (qualifies(), shows());
## - the word and its colour: a Device on a network (cables either way, a wireless link or clients,
##   or an access point named) says Online / Cut off (blinks) / Disabled (switched off by a command,
##   DeviceStatus.is_disabled()) / Broken / No power in the status light's colours; a powered thing
##   off any network says Powered / No power / Broken; a character says nothing while awake,
##   Unconscious or Dead; anything else nothing (a Device off any network without power wiring says
##   only Broken).
## The network rule is the one the status lights show, read from NetworkState (links_of(),
## is_networked(), on_network()) so the HUD does not depend on a light being attached; the colours
## are StatusLight.COLORS.
## The pure rules (qualifies, *_word, text, color, blink) take plain values; the readers take nodes.

enum Word { NONE, ONLINE, CUT_OFF, DISABLED, BROKEN, NO_POWER, POWERED, UNCONSCIOUS, DEAD }

const TEXTS: Dictionary[Word, String] = {
	Word.NONE: "",
	Word.ONLINE: "Online",
	Word.CUT_OFF: "Cut off",
	Word.DISABLED: "Disabled",
	Word.BROKEN: "Broken",
	Word.NO_POWER: "No power",
	Word.POWERED: "Powered",
	Word.UNCONSCIOUS: "Unconscious",
	Word.DEAD: "Dead",
}
## "No power": the dark light's colour is unreadable on the tag's dark box; a grey instead.
const NO_POWER_COLOR := Color("8a9296")
## The stun colour family (blue-white) and a dim red (the approved mockup's).
const UNCONSCIOUS_COLOR := Color("9fd8ff")
const DEAD_COLOR := Color("b0423b")
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


## A network device's word: no power first, then broken, then switched off, then whether it still
## has its network.
static func network_word(powered: bool, broken: bool, disabled: bool, has_network: bool) -> Word:
	if not powered:
		return Word.NO_POWER
	if broken:
		return Word.BROKEN
	if disabled:
		return Word.DISABLED
	return Word.ONLINE if has_network else Word.CUT_OFF


## A powered thing off any network.
static func powered_word(powered: bool, broken: bool) -> Word:
	if broken:
		return Word.BROKEN
	return Word.POWERED if powered else Word.NO_POWER


## A character: nothing while awake.
static func character_word(dead: bool, unconscious: bool) -> Word:
	if dead:
		return Word.DEAD
	return Word.UNCONSCIOUS if unconscious else Word.NONE


static func text(word: Word) -> String:
	return TEXTS[word]


## The word's colour (StatusLight.COLORS for the network states).
static func color(word: Word) -> Color:
	match word:
		Word.ONLINE, Word.POWERED:
			return StatusLight.COLORS[StatusLight.State.UP]
		Word.CUT_OFF:
			return StatusLight.COLORS[StatusLight.State.CUT_OFF]
		Word.DISABLED, Word.BROKEN:
			return StatusLight.COLORS[StatusLight.State.DISABLED]
		Word.UNCONSCIOUS:
			return UNCONSCIOUS_COLOR
		Word.DEAD:
			return DEAD_COLOR
	return NO_POWER_COLOR


static func blinks(word: Word) -> bool:
	return word == Word.CUT_OFF


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


## The word for `entity` now; `links`: its Device's NetworkState.links_of() (read once by the caller).
static func word_of(entity: Node, links: Array[Device]) -> Word:
	if entity == null or not is_instance_valid(entity):
		return Word.NONE
	if is_character(entity):
		return character_word(ActorState.is_dead(entity), ActorState.has(entity, ActorState.UNCONSCIOUS))
	var device := Device.of(entity)
	var powered := Powered.of(entity)
	var broken := _is_broken(entity, device)
	if device != null and NetworkState.is_networked(device, links):
		var disabled := DeviceStatus.is_disabled(entity)
		return network_word(device.is_powered(), broken, disabled, NetworkState.on_network(device, links))
	if powered != null:
		return powered_word(powered.on and not ActorState.has(entity, Device.UNPOWERED), broken)
	return Word.BROKEN if broken else Word.NONE


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
