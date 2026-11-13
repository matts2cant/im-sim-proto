extends Node3D
## Screenshot helper for reviews (not a test): the four grenade model scenes side by side (frag, gas,
## EMP, jamming) above the bare Kenney GLBs (grenade-a, grenade-b) for comparison. Saves the window
## to `out=` and quits.

const MODELS: Array[String] = [
	"res://items/grenades/models/frag_model.tscn",
	"res://items/grenades/models/gas_model.tscn",
	"res://items/grenades/models/emp_model.tscn",
	"res://items/grenades/models/jamming_model.tscn",
]
const RAW: Array[String] = [
	"res://assets/models/kenney_blaster_kit/grenade-a.glb",
	"res://assets/models/kenney_blaster_kit/grenade-b.glb",
]
const SHOT_SIZE := Vector2i(1152, 648)

var _out: String = "res://reports/screenshots/grenade_models.png"
var _time: float = 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.trim_prefix("out=")
	get_window().size = SHOT_SIZE
	for i in MODELS.size():
		var node := (load(MODELS[i]) as PackedScene).instantiate() as Node3D
		add_child(node)
		node.position = Vector3(0, 0.12, -0.27 + i * 0.18)
		node.rotation_degrees.y = 30.0
	for i in RAW.size():
		var raw := (load(RAW[i]) as PackedScene).instantiate() as Node3D
		add_child(raw)
		raw.scale = Vector3.ONE * 0.45
		raw.position = Vector3(0, -0.12, -0.09 + i * 0.18)
		raw.rotation_degrees.y = 30.0


func _process(delta: float) -> void:
	_time += delta
	if _time < 0.5:
		return
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(_out))
	print("Saved ", _out)
	get_tree().quit()
