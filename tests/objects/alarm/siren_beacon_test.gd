extends GdUnitTestSuite
## The siren's beacon (ADR 0130 step 2, objects/alarm/siren.tscn): while the siren sounds its glow
## shows (an emissive cover and a small light) and the core turns; silent, the glow is hidden and
## nothing turns. BeaconGlow is generic: any node shown by its owner.

const SIREN := preload("res://objects/alarm/siren.tscn")
const ORIGIN := Vector3(-680, 2, 680)

var _siren: Node3D
var _behaviour: Siren
var _glow: BeaconGlow


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_siren = auto_free(SIREN.instantiate()) as Node3D
	_siren.position = ORIGIN
	add_child(_siren)
	_behaviour = _siren.get_node("SirenBehaviour") as Siren
	_glow = _siren.get_node("Model/Beacon/Glow") as BeaconGlow


func after_test() -> void:
	StimulusSystem.clear()


func test_the_beacon_is_dark_and_still_while_silent() -> void:
	await get_tree().process_frame

	assert_bool(_glow.is_visible_in_tree()).is_false()
	assert_bool(_glow.turning()).is_false()
	assert_bool((_glow.get_node("Light") as Light3D).is_visible_in_tree()).is_false()


func test_the_beacon_lights_and_turns_while_the_siren_sounds() -> void:
	await get_tree().process_frame
	var core := _siren.get_node("Model/Beacon/Reflector") as Node3D
	var before := core.rotation.y

	_behaviour.ring(5.0)
	for i in 4:
		await get_tree().process_frame

	assert_bool(_glow.is_visible_in_tree()).is_true()
	assert_bool((_glow.get_node("Light") as Light3D).is_visible_in_tree()).is_true()
	var cover := (_glow.get_node("LitCover") as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
	assert_bool(cover.emission_enabled).is_true()
	assert_bool(_glow.turning()).is_true()
	assert_float(absf(core.rotation.y - before)).is_greater(0.0)

	_behaviour.silence()
	await get_tree().process_frame
	assert_bool(_glow.is_visible_in_tree()).is_false()
	assert_bool(_glow.turning()).is_false()
