class_name Icebreaker
extends RefCounted
## Pure: the deck's Icebreaker (ADR 0113), a deterministic brute force of one account's password.
## Progress is a fraction (0-1) that grows by delta / crack time, where crack time = the strength's
## base time (DeckConfig) x the user's `deck_crack_time_mult`; the password's letters lock in one by
## one (floor(progress x length)). It cracks only passwords no stronger than the user's
## `deck_max_strength` (Weak 0, Medium 1, Strong 2). The skill attributes (Computer skill: crack time
## x1 / 0.75 / 0.5 / 0.3, trace gain x1 / 0.8 / 0.6 / 0.4, strongest Weak / Medium / Strong /
## Strong, assists 0-3) are read from the user each tick, so a skill change takes effect at once.
## A job remembers a hash of the password it started on: progress saved on the deck is resumed only
## while the password is unchanged.

const CRACK_TIME_ATTRIBUTE: StringName = &"deck_crack_time_mult"
const MAX_STRENGTH_ATTRIBUTE: StringName = &"deck_max_strength"
const ASSIST_ATTRIBUTE: StringName = &"deck_assist"
## Assist levels (cumulative): Trained time estimates, Advanced + trace estimates, Master + routes.
const ASSIST_TIMES: int = 1
const ASSIST_TRACE: int = 2
const ASSIST_ROUTES: int = 3

## "<device key>|<user>": where its progress is kept on the deck.
var key: String = ""
## The account's user name and the device's display name (screens).
var user: String = ""
var host: String = ""
var password: String = ""
var strength: int = DeviceAccount.Strength.WEAK
## Base time (s) of its strength.
var base_time: float = 10.0
## 0..1.
var progress: float = 0.0
var running: bool = false


static func make(
	p_key: String, p_user: String, p_host: String, p_password: String, p_strength: int, p_base_time: float
) -> Icebreaker:
	var job := Icebreaker.new()
	job.key = p_key
	job.user = p_user
	job.host = p_host
	job.password = p_password
	job.strength = p_strength
	job.base_time = p_base_time
	return job


## The user's crack time multiplier (1 without the skill).
static func crack_mult(entity: Node) -> float:
	return maxf(0.01, Attributes.read(entity, CRACK_TIME_ATTRIBUTE, 1.0))


## The user's trace gain multiplier (1 without the skill).
static func trace_mult(entity: Node) -> float:
	return Attributes.read(entity, Tracer.TRACE_GAIN_ATTRIBUTE, 1.0)


## The strongest password strength the user cracks (DeviceAccount.Strength).
static func max_strength(entity: Node) -> int:
	return roundi(Attributes.read(entity, MAX_STRENGTH_ATTRIBUTE, 0.0))


## The user's assist level (0-3).
static func assist(entity: Node) -> int:
	return clampi(roundi(Attributes.read(entity, ASSIST_ATTRIBUTE, 0.0)), 0, ASSIST_ROUTES)


static func can_crack(p_strength: int, p_max_strength: int) -> bool:
	return p_strength <= p_max_strength


## Seconds a whole crack takes with `mult` (crack_mult()).
static func crack_time(p_base_time: float, mult: float) -> float:
	return p_base_time * mult


## A stable hash of `text` (a password), the same in every session.
static func password_hash(text: String) -> int:
	return hash(text)


## Advances `delta` s at crack time multiplier `mult`; true when this tick finished it.
func advance(delta: float, mult: float) -> bool:
	if is_done():
		return false
	progress = minf(1.0, progress + delta / maxf(0.001, crack_time(base_time, mult)))
	return is_done()


func is_done() -> bool:
	return progress >= 1.0


## How many letters have locked in.
func locked_letters() -> int:
	return password.length() if is_done() else floori(progress * password.length())


## Seconds left at `mult`.
func time_left(mult: float) -> float:
	return maxf(0.0, (1.0 - progress) * crack_time(base_time, mult))


## The trace (%) finishing would add to one tracer gaining `gain_per_second`, for a user with
## `mult` (crack time) and `gain_mult` (trace gain).
func trace_to_finish(gain_per_second: float, mult: float, gain_mult: float) -> float:
	return time_left(mult) * gain_per_second * gain_mult
