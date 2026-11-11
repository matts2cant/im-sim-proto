extends GdUnitTestSuite
## Unit (ADR 0080, ADR 0114): LoginCredentials (the "user:password" format readables carry,
## matching), ComputerConfig's command table (labels, which commands a device is offered, in table
## order) and kinds (by tag), and the Mail and Files data (ComputerDocument, ComputerData): what
## reading one teaches, implicit clues teaching nothing, inboxes per account.

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
