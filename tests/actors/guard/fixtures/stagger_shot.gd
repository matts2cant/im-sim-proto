extends Node
## Screenshot fixture (ADR 0127, review shots only): a pistol guard in the combat yard seen from its
## side. Saves the view just before a leg hit (reports/screenshots/guard_stagger_before.png), sends
## a 5-damage `damage.ballistic` RAY at its left leg hitbox from 3 m in front, saves the view while
## it staggers (guard_stagger.png) and quits. A real-time watchdog quits after 25 s whatever happens.
## Run: tools/run_windowed.sh 60 --path . res://tests/actors/guard/fixtures/stagger_shot.tscn

const HIT_TICK := 40
## Ticks after the hit is emitted: delivered on the second, then the lean eases in over 0.08 s.
const SHOT_AFTER := 9
const OUT := "res://reports/screenshots/"

@export var guard_path: NodePath = ^"../Guard"

var _tick: int = 0
var _capture: String = ""


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	get_tree().create_timer(25.0, true, false, true).timeout.connect(_quit)


func _physics_process(_delta: float) -> void:
	_tick += 1
	if _tick == HIT_TICK - 1:
		_capture = "guard_stagger_before.png"
	elif _tick == HIT_TICK:
		_hit()
	elif _tick == HIT_TICK + SHOT_AFTER:
		_capture = "guard_stagger.png"
	elif _tick > HIT_TICK + SHOT_AFTER + 30:
		_quit()


func _process(_delta: float) -> void:
	if _capture.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + _capture))
	_capture = ""


func _hit() -> void:
	var guard := get_node_or_null(guard_path)
	var boxes := Hitboxes.of(guard)
	if boxes == null:
		_quit()
		return
	var target := boxes.box(BodyDamageModel.LEG_L).global_position
	var origin := target + Vector3(0, 0, -3)
	var ray := Stimulus.make_ray(&"damage.ballistic", 5.0, origin, (target - origin).normalized(), 5.0)
	ray.collision_mask = PhysicsLayers.WEAPON_MASK
	StimulusSystem.emit(ray)


func _quit() -> void:
	get_tree().quit()
