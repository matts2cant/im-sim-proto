extends GdUnitTestSuite
## Unit (ADR 0078, ADR 0137): ToolUse works the first component of a target that takes the held tool
## and says so every tick (`worked`), so the tool's own component reacts (the deck plugs into a Device)
## without the target knowing the tool's owner. A Device takes the deck only where it has a port.

const Devices := preload("res://tests/objects/devices/device_fixtures.gd")

var _worked: Array = []


func before_test() -> void:
	_worked.clear()


func test_worked_names_the_target_component_and_the_tool_each_tick() -> void:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var tool_use := ToolUse.new()
	root.add_child(tool_use)
	tool_use.worked.connect(func(target: Node, tool: StringName) -> void: _worked.append([target, tool]))
	# A lone device (no cables): a maintenance port, the deck's tool target.
	var entity := Devices.device(root, "Kiosk", Vector3(0, 0, 0))
	var device := Device.of(entity)
	assert_bool(device.accepts_tool(Device.DECK_TOOL)).is_true()
	assert_bool(device.accepts_tool(&"lockpick")).is_false()
	tool_use.step(entity, Device.DECK_TOOL, true, 0.1)
	tool_use.step(entity, Device.DECK_TOOL, true, 0.1)
	assert_int(_worked.size()).is_equal(2)
	assert_object(_worked[0][0]).is_same(device)
	assert_str(String(_worked[0][1])).is_equal(String(Device.DECK_TOOL))
	# Not holding, or a tool it does not take: nothing is worked.
	tool_use.step(entity, Device.DECK_TOOL, false, 0.1)
	tool_use.step(entity, &"lockpick", true, 0.1)
	assert_int(_worked.size()).is_equal(2)
	# Working it never finishes: the device itself does nothing with the deck.
	assert_bool(device.tool_hold(root, 0.1)).is_false()
