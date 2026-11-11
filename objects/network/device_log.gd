class_name DeviceLog
extends RefCounted
## Pure (ADR 0115, 0116): what a device records about who used it over the network: logins, failed
## logins, exploit runs and remote actions (commands it received, firewall edits), each with the
## source address. Every Device keeps one (Device.device_log), saved with it. The newest CAPACITY
## entries are kept. Nothing reads them in the game yet: the deck's Logs tool and the guards who
## read logs come with M16; tests and the debug panel's network overlay show them.

## A login with the right password (also a remote desktop opened with an account).
const LOGIN: StringName = &"login"
const FAILED_LOGIN: StringName = &"failed_login"
const EXPLOIT: StringName = &"exploit"
## A command received over the network, or a change made remotely (a firewall rule).
const REMOTE: StringName = &"remote"
const CAPACITY: int = 50

## Oldest first: {tick, kind, address, user, detail}.
var entries: Array[Dictionary] = []


## Records one entry: `kind` (LOGIN, FAILED_LOGIN, EXPLOIT, REMOTE), the source `address` ("" when
## none: a device on the implicit network), the account or user key, and a short `detail`.
func record(kind: StringName, address: String, user: String = "", detail: String = "") -> void:
	var entry := {"tick": Engine.get_physics_frames(), "kind": String(kind), "address": address}
	entry["user"] = user
	entry["detail"] = detail
	entries.append(entry)
	while entries.size() > CAPACITY:
		entries.remove_at(0)


## The entries of `kind`, oldest first.
func of_kind(kind: StringName) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry in entries:
		if entry["kind"] == String(kind):
			found.append(entry)
	return found


## The newest entry, or {} when empty.
func last() -> Dictionary:
	return entries.back() if not entries.is_empty() else {}


func size() -> int:
	return entries.size()


## One entry as a line: "exploit 10.0.10.40 Helix default service login".
static func line(entry: Dictionary) -> String:
	var parts := PackedStringArray([str(entry.get("kind", ""))])
	for key: String in ["address", "user", "detail"]:
		var value := str(entry.get(key, ""))
		if not value.is_empty():
			parts.append(value)
	return " ".join(parts)


func to_array() -> Array:
	return entries.duplicate(true)


func from_array(data: Array) -> void:
	entries.clear()
	for item: Variant in data:
		if item is Dictionary:
			entries.append((item as Dictionary).duplicate())
