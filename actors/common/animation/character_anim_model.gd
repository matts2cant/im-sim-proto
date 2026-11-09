class_name CharacterAnimModel
extends RefCounted
## Pure state choice of a CharacterAnimator (ADR 0103): from a character's properties (horizontal
## ground speed, the sprint stance, dead / unconscious, the drawn weapon's grip, shots and swings) it
## picks the clip of each layer. No nodes, no Animation resources: the adapter samples the clips.
## - Base (full body): idle below `moving_speed`; sprint with the sprint stance or at `sprint_speed`;
##   walk otherwise. Walk and sprint play at ground speed / the clip's own speed (clamped), so the
##   feet keep pace with the ground.
## - Off hand (the off-hand parts): the off-hand pose while the off-hand item is in use (a lit
##   flashlight, ADR 0105), under the hold layer (a two-handed hold overrides it).
## - Hold (upper body, the grip's parts): the grip's hold pose while a weapon is drawn.
## - Action (upper body): a shot plays the grip's shoot clip, a melee swing the melee clip, once,
##   over the hold pose (shooting overrides holding).
## - Down (full body): dead beats unconscious beats everything; the clip plays once and holds its
##   last frame; actions and holding stop.

enum Locomotion { IDLE, WALK, SPRINT }
enum Down { NONE, UNCONSCIOUS, DEAD }

## No weapon drawn.
const NO_GRIP: int = -1

var config: CharacterAnimConfig
## Seconds each clip lasts (the adapter fills it from the model's animations); unknown clips last 0.
var clip_lengths: Dictionary[StringName, float] = {}

var locomotion: Locomotion = Locomotion.IDLE
## Playback rate of the base clip.
var playback: float = 1.0
var down: Down = Down.NONE
## WeaponData.Grip of the drawn weapon, or NO_GRIP.
var grip: int = NO_GRIP
## The off hand holds an item in use (a lit flashlight); false while down.
var off_hand: bool = false
## The one-shot clip playing over the hold pose (a shot, a swing), or empty.
var action_clip: StringName = &""
## Seconds it still plays.
var action_left: float = 0.0
## Parts the action drives.
var action_parts: Array[StringName] = []


func _init(p_config: CharacterAnimConfig) -> void:
	config = p_config


## Every physics tick: the character's state now (`off_hand_busy`: its off-hand item is in use).
func update(
	delta: float,
	speed: float,
	sprinting: bool,
	dead: bool,
	unconscious: bool,
	held_grip: int,
	off_hand_busy: bool = false,
) -> void:
	down = Down.DEAD if dead else (Down.UNCONSCIOUS if unconscious else Down.NONE)
	grip = NO_GRIP if is_down() else held_grip
	off_hand = off_hand_busy and not is_down()
	action_left = maxf(action_left - delta, 0.0)
	if action_left <= 0.0 or is_down():
		_clear_action()
	locomotion = choose_locomotion(speed, sprinting)
	playback = locomotion_rate(locomotion, speed)


## A shot (`melee` false) or a swing of the drawn weapon: starts its clip over the hold pose. Returns
## the clip started, empty when nothing plays (down, or a shot with nothing drawn).
func fire(melee: bool) -> StringName:
	if is_down():
		return &""
	if melee:
		action_clip = config.melee_clip
		action_parts = config.melee_parts
	elif grip != NO_GRIP:
		action_clip = config.shoot_clip(grip)
		action_parts = config.shoot_parts(grip)
	else:
		return &""
	action_left = clip_lengths.get(action_clip, 0.0)
	return action_clip


func is_down() -> bool:
	return down != Down.NONE


## The full-body clip under the upper layers: the locomotion clip (the down clip plays in its own
## layer on top, so standing up blends back into it).
func base_clip() -> StringName:
	match locomotion:
		Locomotion.WALK:
			return config.walk_clip
		Locomotion.SPRINT:
			return config.sprint_clip
	return config.idle_clip


## The hold pose now, or empty (nothing drawn, or down).
func hold_clip() -> StringName:
	if grip == NO_GRIP:
		return &""
	return config.hold_clip(grip)


## The off-hand pose now, or empty (nothing in use, or down).
func off_hand_clip() -> StringName:
	return config.hold_off_hand_clip if off_hand else &""


func hold_parts() -> Array[StringName]:
	if grip == NO_GRIP:
		return []
	return config.hold_parts(grip)


## The down clip now (dead before unconscious), or empty.
func down_clip() -> StringName:
	match down:
		Down.DEAD:
			return config.dead_clip
		Down.UNCONSCIOUS:
			return config.unconscious_clip
	return &""


## The clip the upper body shows: the action while one plays, else the hold pose (or empty).
func upper_clip() -> StringName:
	if not action_clip.is_empty():
		return action_clip
	return hold_clip()


## The base clip a body at `speed` m/s plays.
func choose_locomotion(speed: float, sprinting: bool) -> Locomotion:
	if speed < config.moving_speed:
		return Locomotion.IDLE
	if sprinting or speed >= config.sprint_speed:
		return Locomotion.SPRINT
	return Locomotion.WALK


## Playback rate of `state` at `speed` m/s: speed over the clip's own speed, clamped; idle plays at 1.
func locomotion_rate(state: Locomotion, speed: float) -> float:
	var clip_speed := 0.0
	match state:
		Locomotion.WALK:
			clip_speed = config.walk_clip_speed
		Locomotion.SPRINT:
			clip_speed = config.sprint_clip_speed
	if clip_speed <= 0.0:
		return 1.0
	return clampf(speed / clip_speed, config.min_playback, config.max_playback)


func _clear_action() -> void:
	action_clip = &""
	action_left = 0.0
	action_parts = []
