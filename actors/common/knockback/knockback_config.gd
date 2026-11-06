class_name KnockbackConfig
extends Resource
## Tuning for a character's Knockback (shoves from `force.*` stimuli). Values live in the actor's
## `<actor>_knockback.tres`. Velocity change = impulse x impulse_scale / mass, capped.

## Body mass in kg (the player's matches PlayerConfig.body_mass).
@export var mass: float
## Gameplay gain over the physical impulse / mass: a real 80 kg body barely moves from a barrel's
## 60 N s at 2 m (0.75 m/s); characters are shoved harder so it reads.
@export var impulse_scale: float
## Cap on the carried horizontal shove speed (m/s).
@export var max_speed: float
## Cap on the upward speed a shove can give (m/s): v^2 / 2g is the most the feet rise (3 m/s:
## 0.23 m under the player's 2 g, 0.46 m under 1 g).
@export var max_up_speed: float
## The carried horizontal speed falls by this much per second on the ground and in the air.
@export var ground_damping: float
@export var air_damping: float
