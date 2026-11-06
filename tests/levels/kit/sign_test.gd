extends GdUnitTestSuite
## Sign kit part: consistent text style per size.

const SCENE: PackedScene = preload("res://levels/kit/sign.tscn")


func test_default_style_is_medium_white_with_black_outline() -> void:
	var sign := auto_free(SCENE.instantiate()) as Sign

	assert_int(sign.size).is_equal(Sign.Size.MEDIUM)
	assert_int(sign.font_size).is_equal(64)
	assert_int(sign.outline_size).is_equal(16)
	assert_that(sign.modulate).is_equal(Color.WHITE)
	assert_that(sign.outline_modulate).is_equal(Color.BLACK)
	assert_int(sign.billboard).is_equal(BaseMaterial3D.BILLBOARD_DISABLED)


func test_size_sets_font_and_outline() -> void:
	var sign := auto_free(SCENE.instantiate()) as Sign
	var expected: Dictionary[Sign.Size, Vector2i] = {
		Sign.Size.SMALL: Vector2i(48, 12),
		Sign.Size.MEDIUM: Vector2i(64, 16),
		Sign.Size.LARGE: Vector2i(96, 20),
		Sign.Size.XLARGE: Vector2i(128, 24),
	}
	for size: Sign.Size in expected:
		sign.size = size

		assert_int(sign.font_size).is_equal(expected[size].x)
		assert_int(sign.outline_size).is_equal(expected[size].y)


func test_billboard_is_optional() -> void:
	var sign := auto_free(SCENE.instantiate()) as Sign
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.size = Sign.Size.LARGE

	assert_int(sign.billboard).is_equal(BaseMaterial3D.BILLBOARD_ENABLED)
	assert_int(sign.font_size).is_equal(96)
