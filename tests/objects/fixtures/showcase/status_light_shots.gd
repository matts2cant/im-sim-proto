extends Node
## Screenshot helper (not a test, M13 playtest fix): loads the level named by the LEVEL environment
## variable (default the hub), waits for the devices' status lights, then for each light (up to
## PER_KIND per device scene) looks at its LED from 1 m in front of the device at eye height
## (1.65 m above the floor below that spot) and saves a PNG into SHOT_DIR (default
## reports/screenshots/status_lights/) named after the level, the device's scene and its node name.
## Quits itself when done, with a real-time watchdog. Run (LEVEL=res://levels/mission/warehouse.tscn
## for the warehouse):
## tools/run_windowed.sh 150 --path . --resolution 1152x648 \
##   res://tests/objects/fixtures/showcase/status_light_shots.tscn

const SIZE := Vector2i(1152, 648)
const EYE_HEIGHT := 1.65
const STAND_OFF := 1.0
const PER_KIND := 3
## The second view of each light: from this far round to the device's left (degrees).
const SIDE_ANGLE := -55.0
const WATCHDOG_MS := 90000

var _camera: Camera3D
var _started_ms: int = 0


func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	DisplayServer.window_set_size(SIZE)
	var level_path := OS.get_environment("LEVEL")
	if level_path.is_empty():
		level_path = "res://levels/hub/hub.tscn"
	var level := (load(level_path) as PackedScene).instantiate() as Node3D
	add_child(level)
	_camera = Camera3D.new()
	_camera.near = 0.02
	add_child(_camera)
	_run.call_deferred(level, level_path.get_file().get_basename())


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _started_ms > WATCHDOG_MS:
		print("status_light_shots: watchdog")
		get_tree().quit(1)


func _run(level: Node3D, level_name: String) -> void:
	for i in 30:
		await get_tree().physics_frame
	var player := level.get_node_or_null("Player") as Node3D
	if player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	for layer in level.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var dir := OS.get_environment("SHOT_DIR")
	if dir.is_empty():
		dir = "res://reports/screenshots/status_lights"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var per_kind: Dictionary[String, int] = {}
	var lights := level.find_children("StatusLight", "Node3D", true, false)
	print("status_light_shots: %d lights" % lights.size())
	for node in lights:
		var light := node as StatusLight
		if light == null or light.led == null:
			continue
		var entity := light.get_parent() as Node3D
		var kind := entity.scene_file_path.get_file().get_basename()
		if kind.is_empty():
			kind = "inline"
		per_kind[kind] = per_kind.get(kind, 0) + 1
		if per_kind[kind] > PER_KIND:
			continue
		for view: String in ["front", "side"]:
			_pose(light, entity, deg_to_rad(SIDE_ANGLE if view == "side" else 0.0))
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			var file := "%s/%s_%s_%d_%s_%s.png" % [dir, level_name, kind, per_kind[kind], entity.name, view]
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(file))
			print("status_light_shots: %s led %s" % [file, light.led.global_position])
	get_tree().quit()


func _pose(light: StatusLight, entity: Node3D, angle: float) -> void:
	var target := light.led.global_position
	var front := entity.global_basis.z
	front.y = 0.0
	if front.length() < 0.1:
		front = Vector3.BACK
	front = front.normalized().rotated(Vector3.UP, angle)
	var eye := target + front * STAND_OFF
	var space := entity.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(eye + Vector3.UP * 0.2, eye + Vector3.DOWN * 4.0)
	var hit := space.intersect_ray(query)
	eye.y = (hit["position"] as Vector3).y + EYE_HEIGHT if not hit.is_empty() else target.y
	_camera.global_position = eye
	if eye.distance_to(target) > 0.01:
		_camera.look_at(target, Vector3.UP)
	_camera.make_current()
