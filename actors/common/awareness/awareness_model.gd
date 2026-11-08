class_name AwarenessModel
extends RefCounted
## Pure graded awareness (ADR 0068): the suspicion meter, the states Unaware, Suspicious, Searching
## and Alerted, and what the character should be doing in each (`phase`, `pace`, `destination`).
## No scene tree: GradedAwareness feeds it sightings (PerceptionSensor), heard noises, harm and
## external alerts; AwarenessBehaviour carries out the phase and reports arrivals.
## - Unaware: routine (patrol or post). Meter >= suspicious threshold (0.2 while wary) on sight, or a
##   heard noise: Suspicious. Meter >= alert threshold: Alerted.
## - Suspicious: LOOK (stop, face the point) for look_time, MOVE there (investigate pace),
##   LOOK_AROUND for look_around_time, then Unaware and wary. A loud noise skips the look and runs.
##   New evidence (a glimpse, a noise) moves the point. Meter at the alert threshold: Alerted.
## - Alerted: CHASE the target's last known position at run pace; the position follows the target
##   while it is seen. Unseen for lose_time: Searching. Also entered on harm from a hostile and on
##   an external alert (alert(): alarms and radio plug in here).
## - Searching: visits search_points random points within search_radius of the last known position
##   (the first at run pace, then walking), looking around at each; seeing the target: Alerted;
##   all visited or search_duration over: Unaware and wary. Also entered by search_at() (an ally's
##   shout or radio call, a siren, being woken: ADR 0072, ADR 0077) and discover_body() (ADR 0071):
##   the first destination is the point itself (run pace), then the random points.
## - TEND (Searching): stand by a downed ally found unconscious, facing it, until end_tend() (the
##   BodyDiscovery woke it or gave up) or tend_timeout. Calls do not interrupt it; sight does.
## Combat (ADR 0070) plugs into Alerted.

signal state_changed(from: State, to: State, reason: String)

enum State { UNAWARE, SUSPICIOUS, SEARCHING, ALERTED }
## What the character should be doing.
enum Phase { ROUTINE, LOOK, MOVE, LOOK_AROUND, CHASE, TEND }
enum Pace { WALK, INVESTIGATE, RUN }

const STATE_NAMES: Array[String] = ["unaware", "suspicious", "searching", "alerted"]
const PHASE_NAMES: Array[String] = ["routine", "look", "move", "look_around", "chase", "tend"]
const PACE_NAMES: Array[String] = ["walk", "investigate", "run"]

var config: AwarenessConfig
var state: State = State.UNAWARE
var phase: Phase = Phase.ROUTINE
var pace: Pace = Pace.WALK
var meter: float = 0.0
## Seconds of wariness left (0: not wary).
var wary_time: float = 0.0
## Suspicious: the point under investigation. Alerted and Searching: the last known position.
var point: Vector3 = Vector3.ZERO
## Where to go in MOVE and CHASE (Suspicious: the point; Searching: the current search point).
var destination: Vector3 = Vector3.ZERO
## Seconds in the current phase.
var phase_time: float = 0.0
## Alerted: seconds since the target was last seen.
var unseen_time: float = 0.0
## Searching: seconds since the search began, and search points begun.
var search_time: float = 0.0
var search_index: int = 0
## Whether a hostile target was seen on the last step, and where.
var target_seen: bool = false
var target_position: Vector3 = Vector3.ZERO
## Searching: going to (MOVE) or standing by (TEND) a downed ally to wake it.
var tending: bool = false
## Why the last state change happened: sight, noise, harm, alert, nothing_found, lost, search_over,
## reset, body, and search_at()'s reasons (shout, radio, alarm, woken).
var reason: String = ""
var rng := RandomNumberGenerator.new()


func _init(p_config: AwarenessConfig, seed_value: int = 0) -> void:
	config = p_config
	rng.seed = seed_value


func is_wary() -> bool:
	return wary_time > 0.0


## Alerted or Searching: knows a threat is about (a baton from behind no longer knocks out at once).
func is_aware() -> bool:
	return state == State.ALERTED or state == State.SEARCHING


func suspicious_threshold() -> float:
	return config.wary_suspicious_threshold if is_wary() else config.suspicious_threshold


func state_name() -> String:
	return STATE_NAMES[state]


## One tick. `seen`: a hostile target is in sight, gaining `gain` suspicion per second, at `seen_at`.
func step(delta: float, seen: bool, gain: float, seen_at: Vector3) -> void:
	wary_time = maxf(wary_time - delta, 0.0)
	phase_time += delta
	target_seen = seen and gain > 0.0
	if target_seen:
		target_position = seen_at
		meter = minf(meter + gain * delta, 1.0)
	elif state != State.ALERTED:
		meter = maxf(meter - config.decay * delta, 0.0)
	match state:
		State.UNAWARE:
			_step_unaware()
		State.SUSPICIOUS:
			_step_suspicious()
		State.ALERTED:
			_step_alerted(delta)
		State.SEARCHING:
			_step_searching(delta)


## A noise was heard at `at`, `perceived` metres of margin (loudness - path distance).
func hear(at: Vector3, perceived: float) -> void:
	var loud := perceived >= config.loud_noise
	match state:
		State.UNAWARE:
			_suspect(at, "noise", loud)
		State.SUSPICIOUS:
			_evidence(at)
			if loud:
				destination = at
				_set_phase(Phase.MOVE, Pace.RUN)
		State.SEARCHING:
			point = at
			destination = at
			_set_phase(Phase.MOVE, Pace.RUN if loud else Pace.WALK)
		State.ALERTED:
			if not target_seen:
				point = at
				destination = at


## Hurt by a hostile at `at`.
func harm(at: Vector3) -> void:
	_alert(at, "harm")


## External alert (alarm, radio, a shout: the next wave) about a threat at `at`.
func alert(at: Vector3) -> void:
	_alert(at, "alert")


## A search for a threat at `at` that something else reported (`why`: shout, radio, alarm, woken):
## Searching there, the point itself first at run pace. Alerted characters keep chasing; one
## tending a downed ally keeps tending. Returns true when it started a search.
func search_at(at: Vector3, why: String) -> bool:
	if state == State.ALERTED or tending:
		return false
	_search_from(at, at, Pace.RUN, why)
	return true


## A downed ally was found at `at` (ADR 0071): wary for at least `body_wary_duration`, then, unless
## Alerted (a fight goes on), Searching around it, going first to `approach` (beside the body) at
## run pace. `tend`: the ally is unconscious; on arrival it stands by it (TEND) instead of looking
## around. Returns true when it started a search.
func discover_body(at: Vector3, approach: Vector3, tend: bool) -> bool:
	make_wary(config.body_wary_duration)
	if state == State.ALERTED:
		return false
	_search_from(at, approach, Pace.RUN, "body")
	tending = tend
	return true


## Ends a TEND (woken, or given up): looks around there, then searches on. Also cancels a tend that
## has not arrived yet.
func end_tend() -> void:
	tending = false
	if phase == Phase.TEND:
		_set_phase(Phase.LOOK_AROUND, Pace.WALK)


## Stays wary at least `seconds` more.
func make_wary(seconds: float) -> void:
	wary_time = maxf(wary_time, seconds)


## The behaviour reached the destination (or got as close as it can).
func arrived() -> void:
	if phase == Phase.MOVE and state == State.SEARCHING and tending:
		_set_phase(Phase.TEND, Pace.WALK)
	elif phase == Phase.MOVE and (state == State.SUSPICIOUS or state == State.SEARCHING):
		_set_phase(Phase.LOOK_AROUND, pace)


## Forgets everything (unconscious, dead): Unaware, meter 0, not wary.
func reset() -> void:
	meter = 0.0
	wary_time = 0.0
	unseen_time = 0.0
	search_time = 0.0
	search_index = 0
	target_seen = false
	tending = false
	_set_phase(Phase.ROUTINE, Pace.WALK)
	_change(State.UNAWARE, "reset")


func to_dict() -> Dictionary:
	return {
		"state": state,
		"phase": phase,
		"pace": pace,
		"meter": meter,
		"wary_time": wary_time,
		"point": point,
		"destination": destination,
		"phase_time": phase_time,
		"unseen_time": unseen_time,
		"search_time": search_time,
		"search_index": search_index,
		"target_position": target_position,
		"tending": tending,
		"rng_state": rng.state,
	}


## Restores a to_dict() snapshot (no state_changed).
func from_dict(data: Dictionary) -> void:
	state = int(data.get("state", state)) as State
	phase = int(data.get("phase", phase)) as Phase
	pace = int(data.get("pace", pace)) as Pace
	meter = float(data.get("meter", meter))
	wary_time = float(data.get("wary_time", wary_time))
	point = data.get("point", point)
	destination = data.get("destination", destination)
	phase_time = float(data.get("phase_time", phase_time))
	unseen_time = float(data.get("unseen_time", unseen_time))
	search_time = float(data.get("search_time", search_time))
	search_index = int(data.get("search_index", search_index))
	target_position = data.get("target_position", target_position)
	tending = bool(data.get("tending", tending))
	rng.state = int(data.get("rng_state", rng.state))


func _step_unaware() -> void:
	if not target_seen:
		return
	if meter >= config.alert_threshold:
		_alert(target_position, "sight")
	elif meter >= suspicious_threshold():
		_suspect(target_position, "sight", false)


func _step_suspicious() -> void:
	if target_seen:
		if meter >= config.alert_threshold:
			_alert(target_position, "sight")
			return
		_evidence(target_position)
	match phase:
		Phase.LOOK:
			if phase_time >= config.look_time:
				destination = point
				_set_phase(Phase.MOVE, Pace.INVESTIGATE)
		Phase.LOOK_AROUND:
			if phase_time >= config.look_around_time:
				_calm("nothing_found")


func _step_alerted(delta: float) -> void:
	meter = 1.0
	if target_seen:
		point = target_position
		destination = point
		unseen_time = 0.0
		return
	unseen_time += delta
	if unseen_time >= config.lose_time:
		_search()


func _step_searching(delta: float) -> void:
	if target_seen:
		_alert(target_position, "sight")
		return
	search_time += delta
	if search_time >= config.search_duration:
		_calm("search_over")
	elif phase == Phase.TEND:
		if phase_time >= config.tend_timeout:
			end_tend()
	elif phase == Phase.LOOK_AROUND and phase_time >= config.search_look_time:
		_next_search_point()


# Suspicious: new evidence at `at` moves the point. Moving: the destination follows. Looking around:
# far evidence sends the character there; near evidence keeps it looking.
func _evidence(at: Vector3) -> void:
	var far := at.distance_to(point) > config.repoint_distance
	point = at
	match phase:
		Phase.MOVE:
			destination = at
		Phase.LOOK_AROUND:
			if far:
				destination = at
				_set_phase(Phase.MOVE, Pace.INVESTIGATE)
			else:
				phase_time = 0.0


func _suspect(at: Vector3, why: String, loud: bool) -> void:
	point = at
	destination = at
	if loud:
		_set_phase(Phase.MOVE, Pace.RUN)
	else:
		_set_phase(Phase.LOOK, Pace.INVESTIGATE)
	_change(State.SUSPICIOUS, why)


func _alert(at: Vector3, why: String) -> void:
	point = at
	destination = at
	meter = 1.0
	unseen_time = 0.0
	tending = false
	if state != State.ALERTED:
		_set_phase(Phase.CHASE, Pace.RUN)
	_change(State.ALERTED, why)


func _search() -> void:
	search_time = 0.0
	search_index = 0
	tending = false
	_pick_search_point()
	_change(State.SEARCHING, "lost")


# Searching around `at`, going first to `first` (counts as the first search point).
func _search_from(at: Vector3, first: Vector3, first_pace: Pace, why: String) -> void:
	point = at
	destination = first
	search_time = 0.0
	search_index = 1
	tending = false
	_set_phase(Phase.MOVE, first_pace)
	_change(State.SEARCHING, why)


func _next_search_point() -> void:
	if search_index >= config.search_points:
		_calm("search_over")
		return
	_pick_search_point()


func _pick_search_point() -> void:
	var angle := rng.randf() * TAU
	var radius := config.search_radius * sqrt(rng.randf())
	destination = point + Vector3(cos(angle), 0.0, sin(angle)) * radius
	_set_phase(Phase.MOVE, Pace.RUN if search_index == 0 else Pace.WALK)
	search_index += 1


func _calm(why: String) -> void:
	tending = false
	make_wary(config.wary_duration)
	_set_phase(Phase.ROUTINE, Pace.WALK)
	_change(State.UNAWARE, why)


func _set_phase(value: Phase, value_pace: Pace) -> void:
	phase = value
	pace = value_pace
	phase_time = 0.0


func _change(to: State, why: String) -> void:
	if to == state:
		return
	var from := state
	state = to
	reason = why
	state_changed.emit(from, to, why)
