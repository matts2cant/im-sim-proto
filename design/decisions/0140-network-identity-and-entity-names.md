# 140. Network identity from a component, names from one helper

Status: Accepted

Date: 2026-11-13

## Context

The audit of 2026-11-13 found network identity held by node names (S2): firewall rules matched `entity.name == value`, and accounts, exploit grants, traces and Wi-Fi keys were keyed by the user's node name (`NetworkSource.user_key()`). Two characters with the same node name shared every access; renaming a node lost it. About ten components kept a private `_name()` ("entity name, else own name"), and display names lived in three wrappers (`NetworkSource.display_name()`, `Computer.display_name()`, `Interactor.display_name_of()`) (Q20); shipped content fell back to node names for player-facing names (S16). `DeckSession` (541 lines) mixed plugging and Wi-Fi, map discovery and scans, accounts and remote desktops (Q17).

## Decision

- **Users are keyed by a `NetworkIdentity`** (`objects/network/network_identity.gd`, a component with an exported `id`, saveable). `NetworkIdentity.key_of(user)` is the key every network store uses: `DeviceAccounts` (access), `DeviceIntrusion` (exploit grants), `Tracer` / `TraceModel` (traces), `AccessPoint` (who knows the key). Reads never create one: a user without an identity has nothing. Writes (a login, a crack, an exploit, a trace gain, a learned key) call `NetworkIdentity.ensure(user)`, which adds the identity scene (`network_identity.tscn`) as a child with a random id the first time any character acts on a network: the player, a guard, a test stand-in alike, with no scene edits. Because it is a scene, a level snapshot records it as a spawned node and recreates it on load with its saved id. A level may place one with a fixed `id`.
- **Logs keep names**: EventLog entries, device logs ("exploit 10.0.0.9 Player Turret exploit") and signals' log data name users by node name (`EntityNames.log_name()`); names are for reading, never for matching.
- **Firewall rules name devices by address** (`Device.address`), never by node name. The deck's Firewall tool offers only devices with an address; a device without one cannot be named in a rule (subnets and "you" still can). Shipped rules already used addresses (warehouse `security.tscn`); the network lab and security wing have no level rules (their tests' rules now use addresses).
- **`EntityNames`** (`objects/components/entity_names.gd`, static): `log_name(node, fallback)` (the node name; the component's own when the entity is gone), `device_log_name(device)`, `display_name(node)` (a device or a panel of one by its network name, else `display_name` metadata, else the node name in words without a trailing number), `device_name(device)` (`display_name` metadata, else the entity's node name in words) and `has_display_name()`. It replaces every private `_name()`, `NetworkSource.display_name()` and `Computer.display_name()`; `Interactor.display_name_of()` delegates to it.
- **Shipped content names itself**: every device, door, readable and pickup in the hub and the warehouse has a `display_name` (or, for a readable, a title and a source; for a pickup, an item name). A level test instantiates both levels out of the tree and lists any offender (`tests/levels/shipped_names_test.gd`). The names added are the ones the player saw before, except the security wing's doors ("D 1 keypad" became "D1 keypad").
- **`DeckSession` is a coordinator over two parts**: `DeckLink` (`items/deck/deck_link.gd`: the connection's state `port`, `source`, `stack`, `unplug_reason`; `source_for()` what plugging into a device or joining its Wi-Fi would give; `check()` why the connection must drop; the Wi-Fi range helpers) and `DeckDiscovery` (`items/deck/deck_discovery.gd`: reach, seen devices, scans, the map). `DeckSession` keeps its public API (the fields are read-only properties over the parts, the static helpers delegate), logging, signals, screens, accounts, commands and remote desktops.
- **Carried items through `Inventory`** (after ADR 0139): exploit items, the deck's "still carried" check and the Wi-Fi tool's read `Inventory.of(user)`, so any character with an Inventory can use an exploit item (tested); only `DeckSession.held_deck()` reads the player's hand (`PlayerInventory`), and another character plugs a deck by passing its stack to `plug()`.
- **Old saves migrate**: components write `user_keys: "identity"` beside their users. A save without it (keyed by node name) has each key resolved to the character of that name in the loaded level (a `CharacterBody3D` first), given an identity, once; a name nobody has is dropped. Saved firewall rules that named an address-less device by node name (only possible through the Firewall tool) match nothing after loading.

## Alternatives considered

- **Node paths as user keys** (the identity `LevelSnapshot` uses, ADR 0136): unique per level, but a path changes when a character is renamed or reparented (a body carried or moved), which is what S2 forbids.
- **The identity in the character scenes** (player and guard): every character scene would need it and instanced characters would share an exported id unless each instance overrides it; creating it on first network use gives every character one, generated, without editing the scenes.
- **Keeping both name and address matching in rules**: a renamed device would silently change which rules match it.

## Consequences

- A new store of per-user network state keys by `NetworkIdentity.key_of()` on reads and `ensure()` on writes, writes `FORMAT_KEY`, and migrates with `loaded_key()`.
- Tests that need a key call `NetworkIdentity.ensure(user)` (or `key_of()` after a grant); device-log lines name users by `EntityNames.log_name()`.
- The deck's discovery still remembers devices by node path (`seen`, Icebreaker progress keys) and a device's Journal code id falls back to its node name when it has no `credentials_id`: both are level identities (ADR 0136), out of this change.
