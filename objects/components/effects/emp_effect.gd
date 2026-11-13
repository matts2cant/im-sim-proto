class_name EmpEffect
extends Effect
## An electromagnetic pulse (ADR 0131, M14b) reaching an entity: every EMP-reactive component of it
## (its direct children in group GROUP that implement `take_emp(seconds: float, cause: Stimulus)`:
## Powered and a Device without one lose power for that long, a DeckSession unplugs) gets the
## stimulus's intensity as seconds (not the perceived intensity: an EMP stimulus is uniform, the
## whole radius is out for as long). A new EMP-reactive component joins the group; this effect never
## names it.
## Being electronic is having such a component: each one calls listen() on its entity in _ready,
## which adds the shared receptron() (`disrupted_by_emp`: this effect, then the half energy drain
## of ChangeAttributeEffect) to the entity's StimulusReceiver, creating one at the entity when it
## has none. No scene lists it.

const GROUP: StringName = &"emp_reactive"
const METHOD: StringName = &"take_emp"
## The stimulus type an EMP sends (EmpPulse).
const TYPE: StringName = &"emp"
## The shared receptron (loaded on first use: it holds this effect, a preload would be cyclic).
const RECEPTRON_PATH: String = "res://objects/components/receptrons/disrupted_by_emp.tres"
const RECEIVER_NAME: String = "StimulusReceiver"

static var _receptron: Receptron


func apply(ctx: EffectContext) -> void:
	for child in Entities.members(ctx.entity, GROUP, METHOD):
		child.call(METHOD, ctx.stimulus.intensity, ctx.stimulus)


## Makes `entity` react to EMPs: receptron() on its StimulusReceiver (a new one at the entity when it
## has none; added deferred then, as the entity may be setting up its children). Idempotent.
static func listen(entity: Node) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	var receiver := receiver_of(entity)
	if receiver == null:
		_add_receiver.call_deferred(entity)
		return
	add_receptron(receiver)


## The entity's StimulusReceiver (the first child that is one), or null.
static func receiver_of(entity: Node) -> StimulusReceiver:
	for child in entity.get_children():
		if child is StimulusReceiver:
			return child as StimulusReceiver
	return null


## The shared `disrupted_by_emp` receptron.
static func receptron() -> Receptron:
	if _receptron == null:
		_receptron = load(RECEPTRON_PATH) as Receptron
	return _receptron


## Appends receptron() to `receiver` unless it is there (a copy of the list: instances of one scene
## may share the exported array).
static func add_receptron(receiver: StimulusReceiver) -> void:
	var shared := receptron()
	if receiver.receptrons.has(shared):
		return
	var list := receiver.receptrons.duplicate()
	list.append(shared)
	receiver.receptrons = list


static func _add_receiver(entity: Node) -> void:
	if not is_instance_valid(entity) or entity.is_queued_for_deletion():
		return
	var receiver := receiver_of(entity)
	if receiver == null:
		receiver = StimulusReceiver.new()
		receiver.name = RECEIVER_NAME
		entity.add_child(receiver)
	add_receptron(receiver)
