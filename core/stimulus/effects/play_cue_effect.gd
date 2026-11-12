class_name PlayCueEffect
extends Effect
## Plays a sound at the receiver's position through a one-shot AudioStreamPlayer3D that frees
## itself when done. VFX cues come with the systems that need them.

@export var stream: AudioStream
@export var volume_db: float = 0.0
@export var pitch_scale: float = 1.0


func apply(ctx: EffectContext) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.bus = GameSettings.EFFECTS_BUS
	player.name = "Cue"
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.finished.connect(player.queue_free)
	# Parented to the viewport, not the entity, so the sound outlives an entity that is freed.
	ctx.receiver.get_viewport().add_child(player)
	player.global_position = ctx.receiver.global_position
	player.play()
