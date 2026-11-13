extends GdUnitTestSuite
## Unit (ADR 0080, ADR 0114): LoginCredentials (the "user:password" format readables carry,
## matching), ComputerConfig's command table (labels, which commands a device is offered, in table
## order) and kinds (by tag), and the Mail and Files data (ComputerDocument, ComputerData): what
## reading one teaches, implicit clues teaching nothing, inboxes per account, mail readable on a
## computer with no network (ADR 0130).

const CONFIG: ComputerConfig = preload("res://objects/computer/computer.tres")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")


func test_a_device_kind_comes_from_its_tags_with_its_group_and_icon() -> void:
	var root := auto_free(Node3D.new()) as Node3D
	add_child(root)
	root.position = Vector3(0, -500, 0)
	var siren := Fixtures.entity(root, "Siren", Vector3.ZERO, [], [&"object.siren", &"object.device"])
	var lamp := Fixtures.entity(root, "Lamp", Vector3.ONE, [], [&"object.device"])
	var kind := CONFIG.kind_for(siren)
	assert_str(kind.name).is_equal("Siren")
	assert_str(kind.group).is_equal("Alarm")
	assert_bool(kind.icon.is_empty()).is_false()
	assert_object(CONFIG.kind_for(lamp)).is_null()
	# Every kind has a group of the list and an icon.
	for each in CONFIG.kinds:
		assert_bool(CONFIG.groups.has(each.group)).override_failure_message(each.name).is_true()
		assert_bool(each.icon.is_empty()).override_failure_message(each.name).is_false()
	assert_array(Array(CONFIG.groups)).contains_exactly(["Cameras and turrets", "Doors", "Alarm", "Laser arrays"])


func test_reading_a_document_teaches_its_codes_unless_it_is_an_implicit_clue() -> void:
	var mail := ComputerDocument.new()
	mail.id = &"test.mail"
	mail.title = "Login"
	mail.sender = "IT"
	mail.text = "Your login: kbrandt / ferry19"
	mail.codes = {&"office_pc": "kbrandt:ferry19"}
	mail.code_labels = {&"office_pc": "Office PC login"}
	var entry := mail.entry("Mail")
	assert_str(entry.source).is_equal("Mail")
	assert_str(entry.title).is_equal("Login")
	assert_str(entry.text).is_equal("From IT\n\nYour login: kbrandt / ferry19")
	assert_str(entry.codes[&"office_pc"]).is_equal("kbrandt:ferry19")
	assert_str(DocumentApp.learned_text(mail)).is_equal(
		"Learned: Office PC login kbrandt / ferry19 · added to the Journal."
	)
	mail.implicit_clue = true
	var note := mail.entry("Mail")
	assert_bool(note.codes.is_empty()).is_true()
	assert_bool(note.code_labels.is_empty()).is_true()
	assert_str(note.text).contains("ferry19")
	assert_str(DocumentApp.learned_text(mail)).is_equal(DocumentApp.CLUE)


func test_an_inbox_holds_its_accounts_mail_and_the_shared_mail() -> void:
	var data := ComputerData.new()
	for spec: Array in [["a", "kbrandt"], ["b", ""], ["c", "lpetrova"]]:
		var item := ComputerDocument.new()
		item.id = StringName(spec[0])
		item.account = spec[1]
		data.mail.append(item)
	var ids: Array[StringName] = []
	for item in data.mail_for(" KBrandt "):
		ids.append(item.id)
	assert_array(ids).contains_exactly([&"a", &"b"])


func test_a_computers_mail_is_readable_with_no_network() -> void:
	# ADR 0130: no mail servers or routes; the mail is on the computer itself.
	var root := auto_free(Node3D.new()) as Node3D
	add_child(root)
	root.position = Vector3(0, -500, 20)
	var entity := Fixtures.entity(root, "LonePc", Vector3.ZERO, [], [&"object.computer", &"object.device"])
	var device := Device.new()
	device.name = "Device"
	entity.add_child(device)
	var computer := Computer.new()
	computer.name = "Computer"
	computer.config = CONFIG
	computer.data = ComputerData.new()
	var item := ComputerDocument.new()
	item.id = &"test.lone_mail"
	item.title = "Hello"
	computer.data.mail.append(item)
	entity.add_child(computer)
	assert_array(device.reached()).is_empty()
	assert_array(computer.documents(Computer.MAIL, "anyone")).contains_exactly([item])


func test_credentials_parse_at_the_first_colon() -> void:
	var credentials := LoginCredentials.parse("jmercer:falcon:7")
	assert_str(credentials.user).is_equal("jmercer")
	assert_str(credentials.password).is_equal("falcon:7")
	assert_str(LoginCredentials.format("jmercer", "falcon:7")).is_equal("jmercer:falcon:7")


func test_malformed_credentials_are_not_known() -> void:
	assert_object(LoginCredentials.parse("")).is_null()
	assert_object(LoginCredentials.parse("nocolon")).is_null()
	assert_object(LoginCredentials.parse(":secret")).is_null()
	assert_object(LoginCredentials.parse("  :secret")).is_null()


func test_user_names_ignore_case_and_spaces_passwords_do_not() -> void:
	var credentials := LoginCredentials.new("JMercer", "Falcon7")
	assert_bool(credentials.matches(" jmercer ", "Falcon7")).is_true()
	assert_bool(credentials.matches("jmercer", "falcon7")).is_false()
	assert_bool(credentials.matches("jmercer", "Falcon7 ")).is_false()
	assert_bool(credentials.matches("someone", "Falcon7")).is_false()
	assert_bool(LoginCredentials.new("", "").matches("", "")).is_false()


func test_labels_come_from_the_table_with_a_readable_fallback() -> void:
	assert_str(CONFIG.label_for(Door.OPEN)).is_equal("Open")
	assert_str(CONFIG.label_for(SecurityCamera.PAN_LEFT)).is_equal("Pan left")
	assert_str(CONFIG.label_for(Turret.TARGET_GUARDS)).is_equal("Target guards")
	assert_str(CONFIG.label_for(&"command.self_destruct")).is_equal("Self Destruct")


func test_offered_commands_follow_the_table_order_and_skip_device_traffic() -> void:
	var accepted: Array[StringName] = [
		SecurityCamera.PAN_RIGHT, Device.INCIDENT, DeviceSwitch.DISABLE, RadioBaseStation.BROADCAST
	]
	assert_array(CONFIG.offered(accepted)).contains_exactly([DeviceSwitch.DISABLE, SecurityCamera.PAN_RIGHT])
	assert_bool(CONFIG.commands().has(Device.INCIDENT)).is_false()
	assert_bool(CONFIG.commands().has(RadioBaseStation.BROADCAST)).is_false()


func test_every_command_type_on_device_has_a_label_except_device_traffic() -> void:
	# A new command constant needs a label (or a deliberate omission here).
	var omitted: Array[StringName] = [Device.INCIDENT, RadioBaseStation.BROADCAST]
	var constants := (load("res://objects/devices/device.gd") as GDScript).get_script_constant_map()
	for constant: String in constants:
		var value: Variant = constants[constant]
		if value is StringName and String(value).begins_with("command.") and not omitted.has(value):
			assert_bool(CONFIG.command_labels.has(value)).override_failure_message(String(value)).is_true()
