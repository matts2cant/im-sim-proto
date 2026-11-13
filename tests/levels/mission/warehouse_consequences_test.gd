extends GdUnitTestSuite
## Warehouse M12c consequences (design/levels/mission-warehouse.md "Consequences (M12c)", ADR
## 0115; the mail routes went with ADR 0130):
## both alarm controllers supervise the devices that report to them (a whole area switch dropping is
## a network fault there, one switch with one device is trouble notes only); the vault door stays
## locked on power loss (fail-secure, with its plate) while the bridge door unlocks (fail-safe). The
## populated level (no mission) is loaded once; each test restores power and the controllers.

const Helpers := preload("res://tests/levels/mission/warehouse_helpers.gd")
const SECURITY := "Population/Security/"
const CONTROLLERS: Array[String] = ["Devices/AlarmController", "Devices/AlarmControllerYard"]
const BUILDING: StringName = &"warehouse_building"

var _level: Node3D


func before() -> void:
	_level = await Helpers.load_for_queries(self, true, false)


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Powered.set_circuit(get_tree(), BUILDING, true)
	for path: String in ["Network/Rtr01", "Devices/VaultSwitch", "Devices/RoofSwitch"]:
		Powered.of(_entity(path)).on = true
	Lockable.of(_entity("Doors/BridgeDoor")).lock()
	for path: String in CONTROLLERS:
		var controller := AlarmController.of(_entity(path))
		controller.stop("reset")
		controller.supervision.notes.clear()
		controller.supervision.reset()
	await _checks(1)
	StimulusSystem.clear()


func _entity(path: String) -> Node3D:
	return _level.get_node(SECURITY + path) as Node3D


# Waits for `count` supervision checks of the shipped controllers (and two frames).
func _checks(count: int) -> void:
	var interval := AlarmController.of(_entity(CONTROLLERS[0])).config.supervision_interval
	for i in int(ceil(interval * 60.0)) * count + 2:
		await get_tree().physics_frame


func _faults() -> Array[EventLogEntry]:
	return EventLog.find(&"alarm.network_fault")


func test_the_vault_switch_dropping_is_a_network_fault_at_the_switch() -> void:
	Powered.of(_entity("Devices/VaultSwitch")).on = false
	await _checks(3)
	var faults := _faults()
	# Both controllers supervise the vault's devices: each raises one fault, at SW-VAULT.
	assert_int(faults.size()).is_equal(2)
	for entry in faults:
		assert_str(str(entry.data["at"])).is_equal("SW-VAULT")
	var controller := AlarmController.of(_entity(CONTROLLERS[0]))
	assert_bool(controller.is_fault()).is_true()
	assert_vector(controller.point).is_equal_approx(_entity("Devices/VaultSwitch").global_position, Vector3.ONE * 0.01)


func test_the_roof_switch_and_its_camera_are_trouble_notes_only() -> void:
	Powered.of(_entity("Devices/RoofSwitch")).on = false
	await _checks(3)
	assert_array(_faults()).is_empty()
	for path: String in CONTROLLERS:
		var controller := AlarmController.of(_entity(path))
		assert_bool(controller.is_ringing()).override_failure_message(path).is_false()
		var lines := controller.trouble_lines()
		assert_int(lines.size()).override_failure_message(path).is_equal(2)
		assert_str(" ".join(lines)).contains("SW-ROOF").contains("CAM-ROOF")


func test_power_loss_keeps_the_vault_locked_and_unlocks_the_bridge_door() -> void:
	var vault := _entity("Doors/VaultDoor")
	assert_bool(ActorState.has(vault, ElectronicLock.FAIL_SECURE)).is_true()
	assert_str((vault.get_node("PanelMesh/FailSecureLabel") as Label3D).text).is_equal("FAIL-SECURE")
	assert_bool(ActorState.has(_entity("Doors/BridgeDoor"), ElectronicLock.FAIL_SAFE)).is_true()
	Powered.set_circuit(get_tree(), BUILDING, false)
	await _checks(3)
	assert_bool(Lockable.of(vault).locked).is_true()
	assert_bool(Lockable.of(_entity("Doors/BridgeDoor")).locked).is_false()
	# The yard's controller, still up, sees the building drop: a fault at the main switch (the
	# building's controller, cut off behind its own switch, rings nothing it can reach).
	var yard := _faults().filter(func(entry: EventLogEntry) -> bool: return entry.target == "AlarmControllerYard")
	assert_int(yard.size()).is_equal(1)
	assert_str(str(yard[0].data["at"])).is_equal("SW-SECURITY")
