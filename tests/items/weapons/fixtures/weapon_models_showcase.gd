extends Node3D
## Screenshot helper for reviews (not a test): the weapon model scenes side on, -Z (the muzzle) to the
## right, each with its muzzle marker as a small red cube, a silencer fitted where the weapon takes
## one. `-- raw=1` shows the bare Kenney GLBs
## instead. Saves the window to `out=` and quits.

const MODELS: Array[String] = [
	"res://items/weapons/pistol/pistol_model.tscn",
	"res://items/weapons/shotgun/shotgun_model.tscn",
	"res://items/weapons/sniper_rifle/sniper_rifle_model.tscn",
	"res://items/weapons/assault_rifle/assault_rifle_model.tscn",
]
const RAW: Array[String] = [
	"res://assets/models/kenney_blaster_kit/blaster-b.glb",
	"res://assets/models/kenney_blaster_kit/blaster-m.glb",
	"res://assets/models/kenney_blaster_kit/blaster-f.glb",
	"res://assets/models/kenney_blaster_kit/blaster-p.glb",
	"res://assets/models/kenney_blaster_kit/silencer-small.glb",
	"res://assets/models/kenney_blaster_kit/crate-small.glb",
]
const SILENCER: ItemData = preload("res://items/attachments/silencer/silencer.tres")
const SHOT_SIZE := Vector2i(1152, 648)

var _out: String = "res://reports/screenshots/weapon_models.png"
var _time: float = 0.0


func _ready() -> void:
	var raw := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.trim_prefix("out=")
		elif arg == "raw=1":
			raw = true
	get_window().size = SHOT_SIZE
	var paths := RAW if raw else MODELS
	for i in paths.size():
		var node := (load(paths[i]) as PackedScene).instantiate() as Node3D
		add_child(node)
		node.position = Vector3(0, 1.6 - i * 0.45, 0)
		var model := node as WeaponModel
		if model == null:
			continue
		var fitted: Array[AttachmentData] = []
		if model.mount_for(SILENCER.attachment.slot) != null:
			fitted.append(SILENCER.attachment)
		model.fit(fitted)
		var marker := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * 0.02
		var red := StandardMaterial3D.new()
		red.albedo_color = Color.RED
		red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cube.material = red
		marker.mesh = cube
		model.muzzle_point().add_child(marker)


func _process(delta: float) -> void:
	_time += delta
	if _time < 0.5:
		return
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(_out))
	print("Saved ", _out)
	get_tree().quit()
