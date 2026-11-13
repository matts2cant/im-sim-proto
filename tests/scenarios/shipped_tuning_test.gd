extends GdUnitTestSuite
## Shared tuning configs (ADR 0138, audit S11/S13): numbers that were per-node exports or constants
## in code live in `.tres` configs that the shipped scenes reference, with the values they had.
## Scenes are instantiated out of the tree (no _ready) or read through their SceneState.

const BREAKER_PANEL: PackedScene = preload("res://objects/breaker_panel/breaker_panel.tscn")
const ACCESS_POINT: PackedScene = preload("res://objects/network/access_point.tscn")
const GUARD: PackedScene = preload("res://actors/guard/guard.tscn")
const PLAYER: PackedScene = preload("res://actors/player/player.tscn")
const AP_YARD_CONFIG: AccessPointConfig = preload("res://levels/mission/population/ap_yard_access_point.tres")
const GUARD_AWARENESS: AwarenessConfig = preload("res://actors/guard/guard_awareness.tres")
const GUARD_COMBAT: CombatConfig = preload("res://actors/guard/guard_combat.tres")
const BREAK_SETTINGS: BreakSettings = preload("res://objects/components/break_settings.tres")


func test_device_configs() -> void:
	var panel := auto_free(BREAKER_PANEL.instantiate()) as Node
	var breaker := panel.get_node("CircuitBreaker") as CircuitBreaker
	assert_object(breaker.config).is_same(CircuitBreaker.DEFAULT_CONFIG)
	assert_float(breaker.config.noise_loudness).is_equal(6.0)
	var ap := auto_free(ACCESS_POINT.instantiate()) as Node
	var radio := AccessPoint.of(ap)
	assert_object(radio.config).is_same(AccessPoint.DEFAULT_CONFIG)
	assert_float(radio.wireless_range()).is_equal(15.0)


func test_the_warehouse_yard_access_point_keeps_its_long_range() -> void:
	# The level uses it (warehouse_ap_yard_test measures its devices against the live range).
	assert_float(AP_YARD_CONFIG.wireless_range).is_equal(27.0)


func test_character_configs() -> void:
	for scene: PackedScene in [GUARD, PLAYER]:
		var character := auto_free(scene.instantiate()) as Node
		var fall := character.get_node("FallImpact") as FallImpact
		assert_object(fall.config).is_same(FallImpact.DEFAULT_CONFIG)
		assert_float(fall.config.min_speed).is_equal(3.0)
		var hearing := AlarmHearing.of(character)
		assert_object(hearing.config).is_same(AlarmHearing.DEFAULT_CONFIG)
		assert_float(hearing.config.hold).is_equal(1.5)
	var guard := auto_free(GUARD.instantiate()) as Node
	var opener := DoorOpener.of(guard)
	assert_object(opener.config).is_same(DoorOpener.DEFAULT_CONFIG)
	assert_array([opener.config.lookahead, opener.config.path_lift, opener.config.search_margin]).is_equal(
		[3.5, 0.5, 2.0]
	)


func test_former_constants() -> void:
	assert_float(GUARD_AWARENESS.look_around_period).is_equal(4.0)
	assert_float(GUARD_COMBAT.still_speed).is_equal(0.5)
	assert_float(BREAK_SETTINGS.sound_unit_size).is_equal(6.0)
