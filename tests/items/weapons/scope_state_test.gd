extends GdUnitTestSuite
## Unit: ScopeState (ADR 0085). RMB toggles (press in, press again out), refused when scoping is not
## possible; the zoom moves over zoom_time; it scopes out by itself when scoping stops being
## possible (reload, arms, no scope) and drops at once on reset (weapon switched or put away).

var _scope: ScopeState


func before_test() -> void:
	_scope = ScopeState.new()
	_scope.zoom_time = 0.15


func test_toggle_in_and_out() -> void:
	assert_bool(_scope.toggle(true)).is_true()
	assert_bool(_scope.scoped).is_true()
	assert_bool(_scope.toggle(true)).is_true()
	assert_bool(_scope.scoped).is_false()


func test_toggle_in_is_refused_when_not_available_but_out_always_works() -> void:
	assert_bool(_scope.toggle(false)).is_false()
	assert_bool(_scope.scoped).is_false()
	_scope.toggle(true)
	assert_bool(_scope.toggle(false)).is_true()
	assert_bool(_scope.scoped).is_false()


func test_zoom_takes_zoom_time_in_and_out() -> void:
	_scope.toggle(true)
	_scope.step(0.05, true)
	assert_float(_scope.amount).is_equal_approx(1.0 / 3.0, 0.001)
	assert_float(_scope.fov(80.0, 15.0)).is_equal_approx(80.0 - 65.0 / 3.0, 0.01)
	_scope.step(0.1, true)
	assert_float(_scope.amount).is_equal(1.0)
	assert_float(_scope.fov(80.0, 15.0)).is_equal(15.0)
	_scope.toggle(true)
	_scope.step(0.075, true)
	assert_float(_scope.amount).is_equal_approx(0.5, 0.001)
	_scope.step(0.2, true)
	assert_float(_scope.fov(80.0, 15.0)).is_equal(80.0)


func test_scopes_out_by_itself_when_no_longer_available() -> void:
	_scope.toggle(true)
	_scope.step(0.2, true)

	assert_bool(_scope.step(1.0 / 60.0, false)).is_true()

	assert_bool(_scope.scoped).is_false()
	# It zooms back out over zoom_time, and only reports the scope-out once.
	assert_float(_scope.amount).is_between(0.8, 0.95)
	assert_bool(_scope.step(0.2, false)).is_false()
	assert_float(_scope.amount).is_equal(0.0)


func test_reset_drops_it_at_once() -> void:
	_scope.toggle(true)
	_scope.step(0.2, true)

	assert_bool(_scope.reset()).is_true()

	assert_bool(_scope.scoped).is_false()
	assert_float(_scope.amount).is_equal(0.0)
	assert_bool(_scope.reset()).is_false()


func test_zero_zoom_time_is_instant() -> void:
	_scope.zoom_time = 0.0
	_scope.toggle(true)
	_scope.step(1.0 / 60.0, true)
	assert_float(_scope.amount).is_equal(1.0)
