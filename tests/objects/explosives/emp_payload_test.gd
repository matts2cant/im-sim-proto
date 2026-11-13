extends GdUnitTestSuite
## Integration (ADR 0131, M14b): the EMP payload on a grenade stand-in (explosive_fixtures) sends an
## `emp` pulse (6 m, 20 s): everything electronic inside (anything with a Powered or a Device: the
## `disrupted_by_emp` receptron their _ready adds) loses power for 20 s and comes back by itself,
## through the existing power rules (Device `state.unpowered`, a fail-safe door unlocks, a camera,
## turret and laser stop, lights go out); a character loses half its energy and its deck is
## unplugged; a prop without electronics and a device 8 m away are untouched. Game time runs 8x.
## Distances are from the grenade (0.1 m up) to the entity's origin.
##   plan (x east, z south): grenade (0,0);  Lamp device (3,1,0), Bare device (no Powered) (-3,1,0),
##   Crate (prop) (0,0.3,2), Far device (8,1,0);  shipped camera (0,2.6,-3), ceiling lamp (2,2.8,-2),
##   turret (-2,0,-3), laser (-4,1.3,1);  doors at (0,0,4) fail-safe, (4,0,4) fail-secure; hacker (1,0,-1)

const Grenades := preload("res://tests/objects/explosives/explosive_fixtures.gd")
const Net := preload("res://tests/objects/network/network_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const CAMERA: PackedScene = preload("res://objects/camera/security_camera.tscn")
const LAMP: PackedScene = preload("res://objects/light_fixture/ceiling_lamp.tscn")
const TURRET: PackedScene = preload("res://objects/turret/turret.tscn")
const LASER: PackedScene = preload("res://objects/laser/laser_array.tscn")
const DOOR: PackedScene = preload("res://objects/door/door.tscn")
const CONTROLLER: PackedScene = preload("res://objects/door/door_controller.tscn")
const ORIGIN := Vector3(380, 0, 660)
const TIME_FACTOR := 8.0

var _root: Node3D
var _saved_time: Vector2


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_saved_time = Grenades.speed_up(TIME_FACTOR)
	_root = auto_free(Node3D.new()) as Node3D
	_root.position = ORIGIN
	add_child(_root)
	Characters.floor_box(_root)


func after_test() -> void:
	Grenades.restore_time(_saved_time)
	StimulusSystem.clear()


func test_electronics_are_off_for_20_s_then_back_and_others_untouched() -> void:
	var lamp := Net.body_device(_root, "Lamp", Vector3(3, 1, 0), [], true)
	var bare := Net.body_device(_root, "Bare", Vector3(-3, 1, 0))
	var far := Net.body_device(_root, "Far", Vector3(8, 1, 0), [], true)
	var crate := Fixtures.entity(_root, "Crate", Vector3(0, 0.3, 2), [])
	await Grenades.seconds(get_tree(), 0.05)
	_explode()
	await Grenades.seconds(get_tree(), 10.0)
	assert_bool(Device.of(lamp).is_up()).is_false()
	assert_bool(Powered.of(lamp).is_on()).is_false()
	assert_bool(Device.of(bare).is_up()).is_false()
	assert_bool(ActorState.has(bare, Device.UNPOWERED)).is_true()
	assert_bool(Device.of(far).is_up()).is_true()
	# The frame says "No power" (it reads the device's power).
	for entity: Node in [lamp, bare]:
		var word := TargetStatus.word_of(entity, NetworkState.links_of(Device.of(entity)))
		assert_str(TargetStatus.text(word)).override_failure_message(entity.name).is_equal("No power")
	assert_array(_fired_on("Crate")).is_empty()
	assert_array(_fired_on("Far")).is_empty()
	assert_bool(is_instance_valid(crate)).is_true()
	# Saved now (10 s left), loaded onto fresh devices: they come back at the same time.
	var copy_lamp := Net.body_device(_root, "CopyLamp", Vector3(20, 1, 0), [], true)
	var copy_bare := Net.body_device(_root, "CopyBare", Vector3(20, 1, 3))
	await Grenades.seconds(get_tree(), 0.05)
	Powered.of(copy_lamp).load_state(Powered.of(lamp).save_state())
	Device.of(copy_bare).load_state(Device.of(bare).save_state())
	assert_bool(Device.of(copy_lamp).is_up()).is_false()
	assert_bool(Device.of(copy_bare).is_up()).is_false()
	await Grenades.seconds(get_tree(), 15.0)
	for entity: Node3D in [lamp, bare, copy_lamp, copy_bare]:
		assert_bool(Device.of(entity).is_up()).override_failure_message(entity.name).is_true()
	assert_bool(ActorState.has(bare, Device.UNPOWERED)).is_false()
	# No damage to anything.
	assert_array(EventLog.find(&"object.damaged")).is_empty()


func test_cameras_turrets_lasers_and_lights_stop() -> void:
	var camera := _place(CAMERA, "Camera", Vector3(0, 2.6, -3))
	var lamp := _place(LAMP, "CeilingLamp", Vector3(2, 2.8, -2))
	var turret := _place(TURRET, "Turret", Vector3(-2, 0, -3))
	var laser := _place(LASER, "Laser", Vector3(-4, 1.3, 1))
	await Grenades.seconds(get_tree(), 0.1)
	assert_bool(SecurityCamera.of(camera).is_watching()).is_true()
	var light := lamp.find_children("*", "Light3D", true, false)[0] as Light3D
	assert_bool(light.visible).is_true()
	_explode()
	await Grenades.seconds(get_tree(), 0.1)
	assert_bool(SecurityCamera.of(camera).is_watching()).is_false()
	assert_bool(Turret.of(turret).is_active()).is_false()
	assert_bool(LaserArray.of(laser).is_watching()).is_false()
	assert_bool(light.visible).is_false()


func test_a_fail_safe_door_unlocks_and_a_fail_secure_one_stays_locked() -> void:
	var safe := _door("Safe", Vector3(0, 0, 4), &"door.fail_safe")
	var secure := _door("Secure", Vector3(4, 0, 4), &"door.fail_secure")
	await Grenades.seconds(get_tree(), 0.1)
	assert_bool(safe.is_locked()).is_true()
	_explode()
	await Grenades.seconds(get_tree(), 0.2)
	assert_bool(safe.is_locked()).is_false()
	assert_bool(secure.is_locked()).is_true()
	assert_bool(ActorState.has(safe.hardware.controller.entity, Device.UNPOWERED)).is_true()


func test_drains_half_the_energy_and_unplugs_the_deck() -> void:
	var user := Net.user(_root, Vector3(1, 0, -1))
	var energy := Energy.new()
	energy.name = "Energy"
	var values := (user.get_node("Attributes") as Attributes).attribute_set
	values.set_base(Energy.ENERGY_MAX, 100.0)
	values.set_base(Energy.ENERGY, 80.0)
	user.add_child(energy)
	var stack := Net.carry(user)
	var kiosk := Net.body_device(_root, "Kiosk", Vector3(1.5, 1, -1.5))
	await Grenades.seconds(get_tree(), 0.05)
	var session := DeckSession.of(user)
	assert_bool(session.plug(Device.of(kiosk), stack)).is_true()
	_explode()
	await Grenades.seconds(get_tree(), 0.1)
	assert_float(energy.current()).is_equal_approx(40.0, 0.01)
	assert_bool(session.is_plugged()).is_false()
	assert_str(String(session.unplug_reason)).is_equal("emp")


func _explode() -> void:
	var grenade := Grenades.grenade(_root, "EmpGrenade", Vector3(0, 0.1, 0), Grenades.EMP)
	Grenades.explosive_of(grenade).explode()


func _place(scene: PackedScene, entity_name: String, at: Vector3) -> Node3D:
	var entity := scene.instantiate() as Node3D
	entity.name = entity_name
	entity.position = at
	_root.add_child(entity)
	return entity


# A locked electronic door with the shipped controller (no Powered: the Device's own outage).
func _door(door_name: String, at: Vector3, tag: StringName) -> Door:
	var entity := DOOR.instantiate() as StaticBody3D
	entity.name = door_name
	entity.position = at
	var tag_node := entity.get_node("Tags") as Tags
	var all_tags := tag_node.initial_tags.duplicate()
	all_tags.append(tag)
	tag_node.initial_tags = all_tags
	(entity.get_node("Lockable") as Lockable).locked = true
	var lock := ElectronicLock.new()
	lock.name = "ElectronicLock"
	entity.add_child(lock)
	entity.get_node("Hardware").add_child(CONTROLLER.instantiate())
	_root.add_child(entity)
	return Door.of(entity)


func _fired_on(entity_name: String) -> Array[EventLogEntry]:
	return EventLog.find(&"receptron.fired").filter(func(e: EventLogEntry) -> bool: return e.target == entity_name)
