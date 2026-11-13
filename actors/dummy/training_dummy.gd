class_name TrainingDummy
extends StaticBody3D
## Training dummy: a static humanoid target composed of the shared components: BodyParts (dummy
## profile), Hitboxes, Awareness (exported, unaware by default), DownedPose (dead or knocked out it
## tips over backwards and characters walk through it, ADR 0082), DamageNumbers (a floating number
## per hit), a
## CharacterAnimator (the down clip from the same tags, ADR 0103) and the `restore` receptron. Facing
## -Z. Collision layers 3 (actors) and 7 (static actors: props bounce off it, ADR 0070); weapons hit
## its hitboxes. This script is only its reset hook: `use` (E) or reset() sends it a `restore`
## CONTACT (RestoreEffect: health, consciousness and pose back, numbers cleared, `actor.reset`).

@onready var body: BodyParts = $BodyParts
@onready var hitboxes: Hitboxes = $Hitboxes


func _ready() -> void:
	var usable := Usable.of(self)
	if usable != null:
		usable.used.connect(reset)


## Full health, conscious, upright, numbers cleared, through its `restore` receptron, right away.
func reset(by: Node = null) -> void:
	var source: Node = by if by != null else self
	StimulusSystem.emit_now(Stimulus.make_contact(RestoreEffect.STIMULUS, 1.0, self, source))
