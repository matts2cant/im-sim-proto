class_name DamageNumbersConfig
extends Resource
## Tuning for DamageNumbers: how the floating numbers look, move and stack.

## Seconds a number stays (rising and fading out).
@export var lifetime: float = 1.2
## Metres a number rises over its lifetime.
@export var rise: float = 0.5
@export var font_size: int = 40
@export var outline_size: int = 10
@export var pixel_size: float = 0.004
@export var outline_color: Color = Color(0, 0, 0, 0.9)
## Health damage, unless its type has a colour of its own in `type_colors` (exact type).
@export var damage_color: Color = Color.WHITE
@export var type_colors: Dictionary[StringName, Color] = {}
@export var stun_color: Color = Color(0.45, 0.7, 1.0)
@export var knockout_color: Color = Color(1.0, 0.85, 0.2)
## Numbers in quick succession alternate this far left and right of the part...
@export var side_offset: float = 0.35
## ...this high above it, plus `step_height` per step over `steps` steps.
@export var lift: float = 0.1
@export var step_height: float = 0.14
@export var steps: int = 3
## Anchor height above the entity's origin when it has no hitbox for the part.
@export var fallback_height: float = 1.2
