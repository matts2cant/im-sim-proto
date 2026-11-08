class_name AccessLayers
extends RefCounted
## Navigation layers for doors and access (ADR 0078). Everyone walks on layer 1 (`WALK`, every
## region's default). A locked doorway's NavigationLink3D is on `LOCKED` plus the layer of every
## access id one of its locks lets through (a keycard lock's `access_id`); a character's
## NavigationAgent3D is on `WALK` plus the layers of the `access.<id>` tags it carries (DoorOpener).
## Noise paths use every layer: sound passes a locked door (its SoundAttenuator adds the metres).

const WALK: int = 1
const LOCKED: int = 1 << 1
## Noise path queries cross every link and region (StimulusSystem).
const ALL: int = 0xFFFFFFFF
const ACCESS_TAG_PREFIX := "access."
const FIRST_ACCESS_BIT: int = 2
const ACCESS_BITS: int = 30


## The navigation layer of access id `access_id` (layers 3-32, by a stable hash of the id; two ids
## may share a layer, which only lets a character plan a path it then cannot open).
static func access_layer(access_id: StringName) -> int:
	if String(access_id).is_empty():
		return 0
	return 1 << (FIRST_ACCESS_BIT + absi(String(access_id).hash()) % ACCESS_BITS)


## The tag that gives a character access `access_id` (`access.storage`).
static func access_tag(access_id: StringName) -> StringName:
	return StringName(ACCESS_TAG_PREFIX + String(access_id))


## Navigation layers of a character with `tags`: WALK plus one layer per `access.<id>` tag.
static func agent_layers(tags: TagContainer) -> int:
	var layers := WALK
	if tags == null:
		return layers
	for tag in tags.tags():
		var text := String(tag)
		if text.begins_with(ACCESS_TAG_PREFIX):
			layers |= access_layer(StringName(text.substr(ACCESS_TAG_PREFIX.length())))
	return layers
