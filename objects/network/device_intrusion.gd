class_name DeviceIntrusion
extends RefCounted
## Pure (ADR 0115, 0116): the intrusion state every Device keeps (Device.intrusion), saved with it:
## the exploit ids it is patched against (a detected run patches its product on its subnet), the
## access exploit runs gave users without an account (Device.has_access() and is_admin() read it
## beside DeviceAccounts), and its log (DeviceLog: logins, failed logins, exploit runs, remote
## actions with the source address).

## Exploit ids it is patched against.
var patched: PackedStringArray = PackedStringArray()
var device_log: DeviceLog = DeviceLog.new()

# User key (NetworkSource.user_key()) -> the access an exploit run gave (Exploit.Access).
var _exploit_access: Dictionary[String, int] = {}


## True when it is patched against `exploit`.
func is_patched(exploit: Exploit) -> bool:
	return exploit != null and patched.has(String(exploit.id))


## Patches it against `exploit` (once).
func patch(exploit: Exploit) -> void:
	if exploit != null and not is_patched(exploit):
		patched.append(String(exploit.id))


## The access an exploit gave the user `key` (Exploit.Access), or -1 when none.
func exploit_access(key: String) -> int:
	return int(_exploit_access.get(key, -1))


## An exploit run gave user `key` `access` (the higher one is kept).
func grant_exploit(key: String, access: Exploit.Access) -> void:
	if key.is_empty():
		return
	_exploit_access[key] = maxi(int(access), exploit_access(key))


func to_dict() -> Dictionary:
	var access := {}
	for key: String in _exploit_access:
		access[key] = _exploit_access[key]
	return {"patched": Array(patched), "log": device_log.to_array(), "exploit_access": access}


func from_dict(data: Dictionary) -> void:
	if data.has("patched"):
		patched = PackedStringArray(data["patched"] as Array)
	if data.has("log"):
		device_log.from_array(data["log"] as Array)
	if data.has("exploit_access"):
		_exploit_access.clear()
		var access := data["exploit_access"] as Dictionary
		for key: Variant in access:
			_exploit_access[str(key)] = int(access[key])
