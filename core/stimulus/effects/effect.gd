class_name Effect
extends Resource
## Base class of receptron effects. A new effect type is a small subclass overriding apply().


func apply(_ctx: EffectContext) -> void:
	pass


## The script's class_name, for EventLog entries.
func effect_name() -> String:
	var script := get_script() as Script
	while script != null:
		var global_name := script.get_global_name()
		if not global_name.is_empty():
			return String(global_name)
		script = script.get_base_script()
	return "Effect"
