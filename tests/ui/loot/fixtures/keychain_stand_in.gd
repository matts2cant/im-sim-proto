extends Keychain
## Test stand-in for the M14d keychain contract (ADR 0142) until the systems side lands: entries
## carry a `kind` (&"key" / &"card"), remove(key_id) -> Dictionary takes one off, and add() takes the
## kind. LootRules.move_key() uses exactly these two calls.


func add(key_id: StringName, key_name: String, found: String = "", kind: StringName = &"key") -> bool:
	if not super(key_id, key_name, found):
		return false
	_keys[-1]["kind"] = kind
	return true


func remove(key_id: StringName) -> Dictionary:
	for i in _keys.size():
		if _keys[i]["id"] == String(key_id):
			var entry: Dictionary = _keys[i]
			_keys.remove_at(i)
			changed.emit()
			return entry.duplicate()
	return {}
