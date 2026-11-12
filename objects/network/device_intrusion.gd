class_name DeviceIntrusion
extends RefCounted
## Pure (ADR 0115, 0121): the intrusion state every Device keeps (Device.intrusion), saved with it:
## the users an exploit item gave admin access without an account (Device.has_access() and
## is_admin() read it beside DeviceAccounts; ExploitItems.use()), and its log (DeviceLog: logins,
## failed logins, exploits used, remote actions with the source address).

var device_log: DeviceLog = DeviceLog.new()

# User keys (NetworkSource.user_key()) an exploit item gave admin access.
var _exploit_admins: Dictionary[String, bool] = {}


## True when an exploit item gave user `key` admin access here.
func has_exploit(key: String) -> bool:
	return _exploit_admins.has(key)


## An exploit item gave user `key` admin access here (permanent, like an admin account).
func grant_exploit(key: String) -> void:
	if not key.is_empty():
		_exploit_admins[key] = true


func to_dict() -> Dictionary:
	return {"log": device_log.to_array(), "exploit_admins": _exploit_admins.keys()}


func from_dict(data: Dictionary) -> void:
	if data.has("log"):
		device_log.from_array(data["log"] as Array)
	if data.has("exploit_admins"):
		_exploit_admins.clear()
		for key: Variant in data["exploit_admins"] as Array:
			_exploit_admins[str(key)] = true
