# 141. One lookup convention, component interfaces as group + method, device keys

Status: Accepted

Date: 2026-11-13

## Context

The last wave of the audit of 2026-11-13 found the plumbing between entities and components written several ways:

- Components found three ways (S14, Q23): `X.of()` by node name (`Attributes`, `Skills`, `Energy`, `Augmentations`), by a scan of the children (most), and no `Tags.of()` at all: tags were read through the character helper `ActorState.tags_of()` or a raw `get_node("Tags")`. Attributes were read three ways (Q24), a component found its entity three ways (`entity_path` with or without a cast, `get_parent()`, Q25).
- Four "entity of this collider" resolvers (S15): the Interactor's (a hitbox stands for its character), the laser's and the surface lookup's (the nearest ancestor with Tags), the StimulusSystem's (the nearest ancestor with receivers).
- Component interfaces in three styles (S17): group + method (`HeatEffect`, `EmpEffect`), method only (`DeviceStatus`, `ToolUse`, `DeviceNetwork.address_of()`), duck typing (the deck asked its user for `eye_transform()`, the map graph took "an object with `label_for()`").
- The deck remembered devices by entity node path (`seen`, Icebreaker and Wi-Fi crack progress) and a device's Journal code id fell back to its node name (ADR 0140 left both out).

## Decision

- **Lookups** (conventions.md "Entities and components"): every component is found with `X.of(entity)`, a scan of the entity's direct children by class. `Tags` and `Attributes`, the two core components read on hot paths, are found by their fixed node names (`Tags.NODE_NAME`, `Attributes.NODE_NAME`; every scene and fixture names them so): the one documented exception. `Tags.of()` and `Tags.above()` (the nearest ancestor with Tags) replace `ActorState.tags_of()` and raw `get_node()`. Attributes are read two ways by where the base lives: `Attributes.value_of(entity, attribute)` for a value the entity stores, `Attributes.read(entity, attribute, base)` for a config value its modifiers change.
- **`Entities`** (`core/entity/entities.gd`, static, content-free): `of_component(component, path)` resolves a component's entity (its `entity_path`, `..` by default) for every component; `of_collider(collider)` is the one "what does this collider stand for" rule: a collider whose parent is in `Entities.PARTS_GROUP` (a character's `Hitboxes`) stands for that parent's parent, any other collider for itself. The Interactor, Carrier, Thrower, lasers, shot feedback, `Surface.of()` and the StimulusSystem's delivery start from it (the laser and surface lookups then take `Tags.above()`, the StimulusSystem the nearest ancestor with receivers, as before). `members(entity, group, method)` lists an entity's components that implement an interface.
- **Component interfaces are group + method.** The class that calls the interface owns a `GROUP` constant and the method names; an implementing component joins the group in `_init()` (so a component built in code or not yet in the tree counts) and implements the methods; callers ask `Entities.members()`. Applied to `DeviceStatus` (`device_reporter`), `ToolUse` (`tool_target`), `DeviceNetwork.ADDRESS_GROUP` (`network_addressable`), alongside `HeatEffect`, `EmpEffect` and `StatusWord.FRAME_GROUP`. Duck typing on a user is gone: the deck's eye is `Eyes.view_of()`, the map graph takes a `Callable` for its labels. Data wiring stays a method name where a level names it (`CallButton.method`, like a signal connection) and `saveable` keeps its contract (`LevelSnapshot.GROUP`, used everywhere instead of the literal).
- **Device keys.** `Device.device_id` is a device's stable key: set in a level for a fixed one, else a random one made when the device enters the tree and saved with it (like `NetworkIdentity`). The deck's `seen` list and its Icebreaker and Wi-Fi crack tables key by it (`DeckDiscovery.key_of()`, `devices_by_key()`), and `DeviceAccounts.code_id()` falls back to it (after `credentials_id` and the computer's) instead of the node name. Levels do not carry state across (a level exit starts the next one fresh), so a deck's keys and the level's ids are always saved and loaded together.
- **Old saves migrate.** A deck key that is an entity node path (it starts with `/`) becomes its device's key as soon as the path resolves in the loaded level (`DeckDiscovery.migrated_key()` / `migrate_keys()`, as the lists and tables are read); an unresolved one stays and matches nothing. `DeviceAccounts.known_login()` also reads the legacy code id (the node name in snake_case) for a device keyed by its device id, so a crack filed by an old save is still known.

## Alternatives considered

- **Find every component by node name** (fast, one rule): breaks the moment a scene names a node differently, and `PlayerInventory` (an `Inventory` subclass) or a second component of a kind would need special names. Kept only for the two core components every scene already names.
- **One collider rule "nearest ancestor with Tags"**: a door controller's wall boxes are bodies without Tags under the controller entity, and the Interactor must reach their `DoorControl`; the parts group keeps the Interactor's behaviour exactly and generalises it.
- **Device addresses as deck keys**: most devices have no address (the lab and wing have none), and the same address may exist in two levels.
- **A deterministic key from the level scene and the level-relative path**: survives without saving, but breaks on a rename or reparent like the node paths it replaces.

## Consequences

- New components use `X.of()` by class scan and `Entities.of_component()`; a new interface follows the group + method pattern.
- A new store of per-device deck state keys by `DeckDiscovery.key_of()` and migrates with `migrate_keys()`.
- Tests that build a stand-in for an interface join its group (`tests/objects/devices/fixtures/*_stand_in.gd`).
