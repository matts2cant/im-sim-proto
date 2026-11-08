extends GdUnitTestSuite
## Unit (ADR 0080): TerminalCredentials (the "user:password" format datapads carry, matching) and
## TerminalConfig's command table (labels, which commands a device is offered, in table order).

const CONFIG: TerminalConfig = preload("res://objects/terminal/terminal.tres")


func test_credentials_parse_at_the_first_colon() -> void:
	var credentials := TerminalCredentials.parse("jmercer:falcon:7")
	assert_str(credentials.user).is_equal("jmercer")
	assert_str(credentials.password).is_equal("falcon:7")
	assert_str(TerminalCredentials.format("jmercer", "falcon:7")).is_equal("jmercer:falcon:7")


func test_malformed_credentials_are_not_known() -> void:
	assert_object(TerminalCredentials.parse("")).is_null()
	assert_object(TerminalCredentials.parse("nocolon")).is_null()
	assert_object(TerminalCredentials.parse(":secret")).is_null()
	assert_object(TerminalCredentials.parse("  :secret")).is_null()


func test_user_names_ignore_case_and_spaces_passwords_do_not() -> void:
	var credentials := TerminalCredentials.new("JMercer", "Falcon7")
	assert_bool(credentials.matches(" jmercer ", "Falcon7")).is_true()
	assert_bool(credentials.matches("jmercer", "falcon7")).is_false()
	assert_bool(credentials.matches("jmercer", "Falcon7 ")).is_false()
	assert_bool(credentials.matches("someone", "Falcon7")).is_false()
	assert_bool(TerminalCredentials.new("", "").matches("", "")).is_false()


func test_labels_come_from_the_table_with_a_readable_fallback() -> void:
	assert_str(CONFIG.label_for(Device.OPEN)).is_equal("Open")
	assert_str(CONFIG.label_for(Device.PAN_LEFT)).is_equal("Pan left")
	assert_str(CONFIG.label_for(Device.TARGET_GUARDS)).is_equal("Target guards")
	assert_str(CONFIG.label_for(&"command.self_destruct")).is_equal("Self Destruct")


func test_offered_commands_follow_the_table_order_and_skip_device_traffic() -> void:
	var accepted: Array[StringName] = [Device.PAN_RIGHT, Device.INCIDENT, Device.DISABLE, Device.BROADCAST]
	assert_array(CONFIG.offered(accepted)).contains_exactly([Device.DISABLE, Device.PAN_RIGHT])
	assert_bool(CONFIG.commands().has(Device.INCIDENT)).is_false()
	assert_bool(CONFIG.commands().has(Device.BROADCAST)).is_false()


func test_every_command_type_on_device_has_a_label_except_device_traffic() -> void:
	# A new command constant needs a label (or a deliberate omission here).
	var omitted: Array[StringName] = [Device.INCIDENT, Device.BROADCAST]
	var constants := (load("res://objects/devices/device.gd") as GDScript).get_script_constant_map()
	for constant: String in constants:
		var value: Variant = constants[constant]
		if value is StringName and String(value).begins_with("command.") and not omitted.has(value):
			assert_bool(CONFIG.command_labels.has(value)).override_failure_message(String(value)).is_true()
