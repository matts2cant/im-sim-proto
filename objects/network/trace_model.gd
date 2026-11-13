class_name TraceModel
extends RefCounted
## Pure logic of a Tracer (ADR 0113): a trace per user (0-100 %), gains already scaled, a drain that
## starts `drain_delay` s after a user's last gain, and lockouts per address that count down. add()
## reports when a gain fills the trace (the tracer then blocks the address); a trace already full
## while its address is locked out does not fill again.

const FULL: float = 100.0

var config: TracerConfig
# User key (NetworkIdentity.key_of()) -> trace (%).
var traces: Dictionary[String, float] = {}
# User key -> seconds since its last gain.
var idle: Dictionary[String, float] = {}
# Address -> lockout seconds left.
var lockouts: Dictionary[String, float] = {}


func _init(p_config: TracerConfig = null) -> void:
	config = p_config if p_config != null else TracerConfig.new()


## Adds `amount` % to `user`'s trace (its address `address`). True when this gain filled it and the
## address was not locked out yet (the caller reports the full trace and calls lock()).
func add(user: String, amount: float, address: String) -> bool:
	if amount <= 0.0 or user.is_empty():
		return false
	var before: float = traces.get(user, 0.0)
	var after := minf(FULL, before + amount)
	traces[user] = after
	idle[user] = 0.0
	return after >= FULL and before < FULL and not is_locked(address)


## Blocks `address` for the lockout duration.
func lock(address: String) -> void:
	if not address.is_empty():
		lockouts[address] = config.lockout


## Advances `delta` s: drains idle traces, counts lockouts down.
func step(delta: float) -> void:
	for user: String in traces.keys():
		var since: float = idle.get(user, 0.0) + delta
		idle[user] = since
		if since >= config.drain_delay:
			traces[user] = maxf(0.0, traces[user] - config.drain_per_second * delta)
	for address: String in lockouts.keys():
		var left: float = lockouts[address] - delta
		if left <= 0.0:
			lockouts.erase(address)
		else:
			lockouts[address] = left


func trace_of(user: String) -> float:
	return traces.get(user, 0.0)


func is_locked(address: String) -> bool:
	return not address.is_empty() and lockouts.has(address)


func lockout_left(address: String) -> float:
	return lockouts.get(address, 0.0)


## Renames every user key through `mapper` (String -> String; "" drops that user): a save's legacy
## keys (Tracer.load_state()).
func rekey(mapper: Callable) -> void:
	var old_traces := traces.duplicate()
	var old_idle := idle.duplicate()
	traces.clear()
	idle.clear()
	for user: String in old_traces:
		var key := str(mapper.call(user))
		if key.is_empty():
			continue
		traces[key] = old_traces[user]
		if old_idle.has(user):
			idle[key] = old_idle[user]


func to_dict() -> Dictionary:
	return {"traces": traces.duplicate(), "idle": idle.duplicate(), "lockouts": lockouts.duplicate()}


func from_dict(data: Dictionary) -> void:
	traces.clear()
	idle.clear()
	lockouts.clear()
	for key: Variant in data.get("traces", {}) as Dictionary:
		traces[str(key)] = float((data["traces"] as Dictionary)[key])
	for key: Variant in data.get("idle", {}) as Dictionary:
		idle[str(key)] = float((data["idle"] as Dictionary)[key])
	for key: Variant in data.get("lockouts", {}) as Dictionary:
		lockouts[str(key)] = float((data["lockouts"] as Dictionary)[key])
