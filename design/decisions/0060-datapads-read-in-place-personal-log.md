# 60. Datapads are read in place into a personal log

Status: Accepted, amended by [ADR 0110](0110-tab-interface.md) (the log screen is the Tab interface's Journal tab; the reading overlay no longer pauses)

Date: 2026-11-06

## Context

Datapads were inventory items (`ItemData.UseAction.READ`): picked up with E, read from the inventory screen or a belt key, their `title` / `text` kept in the stack's state. The user asked for datapads that cannot be picked up, only read in place, with what they say added to a personal log the player can read later. M8 keypads will show a reminder when the player types a code they have read ([security.md](../game/security.md)), so the log also has to know which codes the player has learned.

## Decision

- **`Readable`** (`objects/components/readable.gd`, a `Usable` with verb "read") holds `entry_id` (stable, unique per readable), `title`, `text`, `codes: Dictionary[StringName, String]` (keypad code id -> code) and an optional `source` label. Anything with a Readable is read the same way: a datapad, a wall note, a terminal. The Interactor prompt is "E: read <title>" (`Usable.target_name()`, empty by default, lets a usable name its target). Using it passes a `LogEntry` to the user's `PersonalLog`; a user without one cannot read.
- **`PersonalLog`** (`actors/common/personal_log/`, any actor; the player has one) wraps the pure `LogBook`: entries oldest first, one per entry id (re-reading adds nothing); known codes derived from the entries, the last entry added wins a shared code id (newer information). `read()` emits `entry_read` every time (the reading overlay shows it) and `entry_added` plus EventLog `log.entry_added {entry_id, title, codes}` only for a new id (the HUD says "Added to log: <title>"). M8 asks `known_code(code_id)` ("" when unknown) and `code_source(code_id)` (the entry's title). Saveable (group `saveable`): the entry list; codes are rebuilt on load.
- **Datapad** (`objects/datapad/datapad.tscn`, moved from `items/`): a `PhysicsObject` prop (blasts and the player still push it, it makes impact noise) with a Readable instead of an ItemPickup; the `object.item` tag is dropped. It never enters an inventory. Because the Interactor resolves Usable before Carryable, E always reads it; it is not carried.
- **Reading overlay** (`ui/log/reading_overlay.tscn`) listens to the player's PersonalLog `entry_read`; it still pauses and closes with E or Esc, and the E that closes it is not a new press.
- **Log screen** (`ui/log/log_screen.tscn`, action `personal_log` = L): pauses like the inventory screen; L or Esc closes. Left: entry titles, newest first (the newest selected), then a Codes list ("Storage Door: 2817  (Storage access)"); right: the selected entry's title and text in a scrolling RichTextLabel (mouse wheel). It does not open while another pause screen is open, while dead or with the debug panel open; the inventory does not open over it. No stacking rules beyond that.
- **Removed**: `items/datapad/datapad.tres`, the catalogue / Give item entry, `ItemData.UseAction.READ` (`EQUIP_TOOL` becomes 3; the tool `.tres` files were updated), `PlayerInventory.read_requested`, the belt key's datapad exception from [ADR 0059](0059-belt-selects-lmb-uses.md) and the inventory menu's "Read".

## Alternatives considered

- **Keep datapads as items and also log them**: the user explicitly did not want them picked up; an item that only exists to be read clutters the grid.
- **Log in the inventory component / player script**: a log is useful for any actor (an NPC could "know" a code); a separate component keeps the player script thin.
- **Store known codes separately from entries**: two things to save and keep in sync; deriving them from the entries makes the save the entry list only.
- **Branch on the datapad scene in the Interactor**: the Readable component keeps the rule about a property ("readable"), not the datapad.

## Consequences

- A datapad cannot be taken to another place (no "deliver the datapad" objectives); the M9 mission's "take the datapad" becomes "read the datapad" ([mission-warehouse.md](../levels/mission-warehouse.md)).
- Each placed datapad needs a unique `entry_id` (`<level>.<room>.<name>`); an empty id warns and is never logged.
- M8 keypads only query `PersonalLog.known_code(code_id)` / `code_source(code_id)`; no keypad code lives on the datapad side.
- M6 quicksave saves the log through the `saveable` group like any component.
