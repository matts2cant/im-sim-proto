class_name StimulusReceiver
extends Node3D
## Component: lets an entity react to stimuli. Place it where the entity perceives from (a guard's
## head); distances are measured to this node. Holds Receptrons; each one that matches a delivered
## stimulus runs its effects in order. Registers itself with StimulusSystem while in the tree.

## EventLog kinds this component records (aliased by EventKinds).
const RECEIVED_KIND: StringName = &"stimulus.received"
const FIRED_KIND: StringName = &"receptron.fired"

@export var receptrons: Array[Receptron] = []
## The entity this receiver belongs to: its own stimuli are ignored unless a receptron opts in.
@export var entity_path: NodePath = ^".."
## The entity's Tags component; optional.
@export var tags_path: NodePath = ^"../Tags"
## The entity's Attributes component; optional.
@export var attributes_path: NodePath = ^"../Attributes"

var entity: Node
var tags: Tags
var attributes: Attributes


func _ready() -> void:
	entity = get_node_or_null(entity_path)
	if entity == null:
		push_warning("StimulusReceiver %s: entity_path %s not found, using the receiver" % [get_path(), entity_path])
		entity = self
	tags = get_node_or_null(tags_path) as Tags
	attributes = get_node_or_null(attributes_path) as Attributes
	StimulusSystem.register(self)


# The first entry happens before the StimulusSystem autoload may be ready, so _ready registers;
# this only re-registers after the receiver was taken out of the tree and put back.
func _enter_tree() -> void:
	if is_node_ready():
		StimulusSystem.register(self)


func _exit_tree() -> void:
	StimulusSystem.unregister(self)


## True when `stimulus` came from this receiver's own entity (or a node inside it).
func is_own(stimulus: Stimulus) -> bool:
	var source := stimulus.source
	if not is_instance_valid(source) or not is_instance_valid(entity):
		return false
	return source == entity or entity.is_ancestor_of(source)


## True when some receptron reacts to this stimulus type; others are not delivered to at all.
func wants(stimulus: Stimulus) -> bool:
	var own := is_own(stimulus)
	for receptron in receptrons:
		if receptron != null and receptron.matches_type(stimulus.type) and (receptron.include_self or not own):
			return true
	return false


## True when receiving `stimulus` at `perceived` would run an effect that can apply
## (Effect.can_apply()); nothing is run or logged. Same matching as receive().
func would_react(stimulus: Stimulus, perceived: float, data: Dictionary = {}) -> bool:
	var own := is_own(stimulus)
	var container := tags.container if tags != null else null
	for receptron in receptrons:
		if receptron == null or (own and not receptron.include_self):
			continue
		if not receptron.matches(stimulus.type, perceived, container):
			continue
		var ctx := EffectContext.new(self, stimulus, perceived, data)
		for effect in receptron.effects:
			if effect != null and effect.can_apply(ctx):
				return true
	return false


## Called by StimulusSystem: logs the reception, then runs every matching receptron's effects.
## `data` (distance, propagation, the collider hit) is passed on to the effects; nodes in it are
## logged by name.
func receive(stimulus: Stimulus, perceived: float, data: Dictionary = {}) -> void:
	var entity_name := String(entity.name)
	var received := {"id": stimulus.id, "type": stimulus.type, "perceived": perceived}
	for key: Variant in data:
		if received.has(key):
			continue
		var value: Variant = data[key]
		if value is Object:
			received[key] = String((value as Node).name) if is_instance_valid(value) and value is Node else ""
		else:
			received[key] = value
	EventLog.record(RECEIVED_KIND, stimulus.source_name(), entity_name, received)
	var own := is_own(stimulus)
	var container := tags.container if tags != null else null
	for index in receptrons.size():
		var receptron := receptrons[index]
		if receptron == null or (own and not receptron.include_self):
			continue
		if not receptron.matches(stimulus.type, perceived, container):
			continue
		var label: Variant = receptron.resource_name if not receptron.resource_name.is_empty() else index
		var fired := {"id": stimulus.id, "receptron": label, "effects": receptron.effect_names()}
		EventLog.record(FIRED_KIND, stimulus.source_name(), entity_name, fired)
		var ctx := EffectContext.new(self, stimulus, perceived, data)
		for effect in receptron.effects:
			if effect != null:
				effect.apply(ctx)
