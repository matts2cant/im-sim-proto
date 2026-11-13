extends GdUnitTestSuite
## Integration (ADR 0140): network identity never comes from node names. Users are keyed by their
## NetworkIdentity: two characters with the same node name keep separate accounts, traces, exploit
## grants and Wi-Fi keys, and renaming one changes nothing; firewall rules name device addresses, so
## a renamed device keeps its rule. The identity is made on a user's first network act, saved
## through a level snapshot (as a spawned node), and saves keyed by node name (before ADR 0140)
## migrate to the character of that name.

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const ORIGIN := Vector3(520, 0, -560)
const LEVEL_PATH := "user://fixnet_identity_level.tscn"
## Node names no other suite uses (a legacy key is looked up by name in the whole tree).
const LEGACY_NAME := "IdentityLegacyUser"

var _root: Node3D
var _n: Dictionary[String, Node3D]


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_n = Net.lab(_root, ORIGIN)


func after_test() -> void:
	StimulusSystem.clear()


func _dev(entity_name: String) -> Device:
	return Device.of(_n[entity_name])


func _tracer() -> Tracer:
	return _n["Rtr01"].get_node("Tracer") as Tracer


# A user named "Hacker" under its own holder (two holders: two users with the same node name).
func _user(holder_name: String, offset: Vector3) -> Node3D:
	var holder := Node3D.new()
	holder.name = holder_name
	_root.add_child(holder)
	return Net.user(holder, ORIGIN + offset)


func test_two_users_with_the_same_node_name_keep_separate_access_and_traces() -> void:
	var first := _user("HolderA", Vector3(0, 0, 1))
	var second := _user("HolderB", Vector3(0, 0, 2))
	assert_str(String(first.name)).is_equal(String(second.name))
	var pc := DeviceAccounts.of(_n["OfficePc"])
	assert_bool(pc.try_login("kbrandt", "ferry19", first)).is_true()
	assert_bool(pc.has_access(first)).is_true()
	assert_bool(pc.has_access(second)).is_false()
	assert_bool(_dev("OfficePc").has_access(second)).is_false()
	# A wrong login adds trace for its own user only.
	DeviceAccounts.of(_n["Console"]).try_login("dmarsh", "nope", second)
	assert_float(_tracer().trace_of(second)).is_equal_approx(15.0, 0.001)
	assert_float(_tracer().trace_of(first)).is_equal(0.0)
	# An exploit grant and a Wi-Fi key are per user too.
	_dev("Camera").intrusion.grant_exploit(NetworkIdentity.ensure(first))
	assert_bool(_dev("Camera").is_admin(first)).is_true()
	assert_bool(_dev("Camera").has_access(second)).is_false()
	var wireless := Net.add_wireless(_n, _root, ORIGIN)
	var radio := AccessPoint.of(wireless["ApYard"])
	radio.grant_key(second)
	assert_bool(radio.knows_key(second)).is_true()
	assert_bool(radio.knows_key(first)).is_false()
	assert_str(NetworkIdentity.key_of(first)).is_not_equal(NetworkIdentity.key_of(second))
	# Logs still name users by node name.
	assert_str(str(EventLog.find(&"network.login")[0].data["by"])).is_equal("Hacker")


func test_renaming_a_user_changes_nothing() -> void:
	var user := _user("HolderA", Vector3(0, 0, 1))
	DeviceAccounts.of(_n["OfficePc"]).grant(user, "kbrandt")
	DeviceAccounts.of(_n["Console"]).try_login("dmarsh", "nope", user)
	user.name = "SomeoneElse"
	assert_bool(_dev("OfficePc").has_access(user)).is_true()
	assert_float(_tracer().trace_of(user)).is_equal_approx(15.0, 0.001)


func test_a_user_without_an_identity_has_nothing_and_reads_give_none() -> void:
	var user := _user("HolderA", Vector3(0, 0, 1))
	assert_str(NetworkIdentity.key_of(user)).is_empty()
	assert_bool(_dev("OfficePc").has_access(user)).is_false()
	assert_float(_tracer().trace_of(user)).is_equal(0.0)
	assert_object(NetworkIdentity.of(user)).is_null()
	# The first grant gives it one, from the identity scene (a save can recreate it).
	DeviceAccounts.of(_n["OfficePc"]).grant(user, "kbrandt")
	var identity := NetworkIdentity.of(user)
	assert_object(identity).is_not_null()
	assert_str(identity.scene_file_path).is_equal(NetworkIdentity.SCENE_PATH)
	assert_str(identity.id).is_not_empty()
	assert_bool(identity.is_in_group(&"saveable")).is_true()
	assert_str(NetworkIdentity.ensure(user)).is_equal(identity.id)


func test_a_renamed_device_keeps_its_firewall_rule() -> void:
	Net.add_siren(_root, _n, ORIGIN)
	var router := Router.of(_n["Rtr01"])
	var alarm := _dev("Alarm")
	var siren := _dev("Siren")
	var rule := RouterRule.make(RouterRule.Match.DEVICE, alarm.address, RouterRule.Match.DEVICE, siren.address, false)
	router.rules = [rule]
	assert_bool(alarm.reaches(siren)).is_false()
	# Renamed (cables are scene paths the editor keeps up to date, so the rule is judged directly).
	_n["Alarm"].name = "RenamedAlarm"
	_n["Siren"].name = "RenamedSiren"
	assert_bool(rule.matches(NetworkSource.of_device(alarm), siren)).is_true()
	assert_bool(router.passes(NetworkSource.of_device(alarm), siren)).is_false()
	# A rule naming a node name matches nothing.
	var by_name := RouterRule.make(RouterRule.Match.DEVICE, "RenamedAlarm", RouterRule.Match.ANY, "", false)
	assert_bool(by_name.matches(NetworkSource.of_device(alarm), siren)).is_false()


func test_a_level_snapshot_keeps_the_identity() -> void:
	var level := _saved_level().instantiate()
	_root.add_child(level)
	var key := NetworkIdentity.ensure(level.get_node("User"))
	var snapshot := LevelSnapshot.capture(level)
	assert_str(str((snapshot["spawned"] as Dictionary).get("User/NetworkIdentity", ""))).is_equal(
		NetworkIdentity.SCENE_PATH
	)
	level.free()
	var again := _saved_level().instantiate()
	_root.add_child(again)
	LevelSnapshot.apply(again, snapshot)
	assert_str(NetworkIdentity.key_of(again.get_node("User"))).is_equal(key)


func test_saves_keyed_by_node_name_migrate_to_that_character() -> void:
	var user := _user("HolderA", Vector3(0, 0, 1))
	user.name = LEGACY_NAME
	var wireless := Net.add_wireless(_n, _root, ORIGIN)
	var radio := AccessPoint.of(wireless["ApYard"])
	DeviceAccounts.of(_n["OfficePc"]).load_state({"access": {LEGACY_NAME: ["kbrandt"], "Nobody404": ["kbrandt"]}})
	_tracer().load_state({"traces": {LEGACY_NAME: 40.0}, "idle": {LEGACY_NAME: 0.0}, "lockouts": {}})
	_dev("Camera").load_state({"exploit_admins": [LEGACY_NAME], "log": []})
	radio.load_state({"known": [LEGACY_NAME]})
	assert_bool(DeviceAccounts.of(_n["OfficePc"]).has_access(user, "kbrandt")).is_true()
	assert_float(_tracer().trace_of(user)).is_equal_approx(40.0, 0.001)
	assert_bool(_dev("Camera").is_admin(user)).is_true()
	assert_bool(radio.knows_key(user)).is_true()
	# One identity for all of them; a name nobody has is dropped.
	assert_int(user.find_children("*", "NetworkIdentity", false, false).size()).is_equal(1)
	assert_int(DeviceAccounts.of(_n["OfficePc"]).save_state()["access"].size()).is_equal(1)
	# A save in the new format is keyed by identity and loads as is.
	var saved := DeviceAccounts.of(_n["OfficePc"]).save_state()
	assert_str(str(saved[NetworkIdentity.FORMAT_KEY])).is_equal(NetworkIdentity.FORMAT)
	DeviceAccounts.of(_n["OfficePc"]).load_state(saved)
	assert_bool(DeviceAccounts.of(_n["OfficePc"]).has_access(user, "kbrandt")).is_true()


func test_an_identity_saves_its_id_and_a_fixed_id_stays() -> void:
	var identity := (load(NetworkIdentity.SCENE_PATH) as PackedScene).instantiate() as NetworkIdentity
	identity.id = "guard-7"
	_root.add_child(identity)
	assert_str(identity.id).is_equal("guard-7")
	var other := (load(NetworkIdentity.SCENE_PATH) as PackedScene).instantiate() as NetworkIdentity
	_root.add_child(other)
	assert_str(other.id).is_not_empty()
	assert_str(other.id).is_not_equal(identity.id)
	other.load_state(identity.save_state())
	assert_str(other.id).is_equal("guard-7")


# A tiny level saved under user:// (LevelSnapshot needs a scene file): a root and a "User".
func _saved_level() -> PackedScene:
	if not ResourceLoader.exists(LEVEL_PATH):
		var root := Node3D.new()
		root.name = "IdentityLevel"
		var user := Node3D.new()
		user.name = "User"
		root.add_child(user)
		user.owner = root
		var packed := PackedScene.new()
		packed.pack(root)
		ResourceSaver.save(packed, LEVEL_PATH)
		root.free()
	return load(LEVEL_PATH) as PackedScene
