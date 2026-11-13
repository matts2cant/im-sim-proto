# Conventions

## Naming and layout

- snake_case for files and folders; `class_name` in PascalCase.
- Test files: `<subject>_test.gd`, mirroring the source tree (`tests/core/stimulus/stimulus_system_test.gd`).
- Folders by feature, not by file type ([architecture.md](architecture.md)).

## Typing

- Statically typed GDScript everywhere.
- The `untyped_declaration` warning is set to error in project settings (addons excluded).
- `:=` inference is allowed.

## Design rules

- Composition over inheritance: behaviour in small component nodes attached to entities.
- Tuning data in `.tres` Resources (text, diffable).
- Pure logic in RefCounted/Resource classes; nodes are thin adapters.
- Exactly three autoloads: `StimulusSystem`, `EventLog`, `DebugPanel`.
- Signals for local events; stimuli for world events.
- Every stateful system is saveable (group `saveable`: `LevelSnapshot.GROUP`, never the literal; `save_state()` / `load_state()`).

## Entities and components ([ADR 0141](../decisions/0141-lookup-conventions-interfaces-device-keys.md))

- **Finding a component**: `X.of(entity)`, a static that scans the entity's direct children by class (`if child is X`), null-safe. The one exception is the two core components every scene names the same: `Tags.of()` and `Attributes.of()` look up `Tags.NODE_NAME` / `Attributes.NODE_NAME` (hot paths). Never `get_node("Tags")`, `$Attributes` on another entity, or a character helper (`ActorState` reads tags through `Tags.of()`); `Tags.above(node)` is the nearest ancestor with Tags.
- **A component's entity**: `Entities.of_component(self, entity_path)` (`@export var entity_path: NodePath = ^".."`), or `Entities.of_component(self)` for a component that is always a direct child; resolved once in `_ready` into an `entity` (or typed `body`) field. Not `get_parent()` or `get_node(entity_path)`.
- **What a collider stands for**: `Entities.of_collider(collider)`: a collider under a node in `Entities.PARTS_GROUP` (a character's `Hitboxes`) is its character, anything else itself. Ray and shape queries resolve hits through it.
- **Reading attributes**: `Attributes.value_of(entity, attribute)` for a value the entity stores (health, energy, carry limit; 0 without Attributes), `Attributes.read(entity, attribute, base)` for a tuning value whose base is in a config and that modifiers change. A component holding its own `Attributes` reference may call `value()` on it.
- **Component interfaces are group + method.** The class that calls the interface owns `GROUP` and the method name constants and documents the signatures (`HeatEffect`, `EmpEffect`, `DeviceStatus`, `ToolUse`, `DeviceNetwork.ADDRESS_GROUP`, `StatusWord.FRAME_GROUP`). An implementing component joins the group in `_init()` (it then counts out of the tree and when built in code) and implements the methods; callers iterate `Entities.members(entity, GROUP, METHOD)`. No bare `has_method()` probing and no duck typing on a user or a resource: ask a component (`Eyes.view_of()`) or take a `Callable`. A level's data may still name a method to call (`CallButton.method`, like a signal connection).
- **Groups are indexes someone reads.** Do not add a group nothing reads; a group kept only as an index for tests and the debug panel says so in its class header (`GasCloud.GROUP`).

## UI plumbing ([ADR 0133](../decisions/0133-ui-plumbing-focus-notices-screens.md))

- **Overlay focus.** A screen that keeps the world running takes `OverlayFocus.acquire(self, user, mouse_mode, hide_hud)` when it opens and `OverlayFocus.release(self)` when it closes (also from `_exit_tree`). Never save and restore `input_enabled`, the HUD's visibility or the mouse mode yourself. The player's gate is `Player.accepts_input()`; other systems ask `OverlayFocus.is_held(entity)`.
- **Notices.** A short player-facing message goes through `Notices.send(entity, text)`. Do not add `message` / `notice` signals for the HUD, and never emit a signal another class owns.
- **Screens.** A world object or item that needs a screen calls `Screens.open(user, MY_CLASS.SCREEN, self, options)` (and `Screens.has()`, `is_open()`, `close()`); it never names or instances a UI class. The screen extends `UserScreen` and answers to that id.
- **Registries, not enums.** A screen with interchangeable views (computer apps, deck tools) keeps a registry keyed by id; adding a view is one registration line, never a new `match` arm.
- **Looks in `.tres`.** Panel and button styles are type variations in a theme file (`ui/window/window_theme.tres`, `ui/tab_interface/tab_theme.tres`, `ui/mission/mission_theme.tres`); builders set `theme` and `theme_type_variation` (`TabStyle.themed()`). Only a box coloured from data may be built in code.
- **Feedback lines** that clear themselves are `TimedLabel`s.
- **Test-only queries** (find a button by text, read a menu) live in test helpers (`tests/ui/deck/deck_ui.gd`), not on the screen.

## Formatting and lint

- gdtoolkit 4.x: `gdformat` and `gdlint`, run by `tools/lint.sh` and the git pre-commit hook. Addons are excluded.
- LF line endings everywhere (`.gitattributes` enforces). Never write CRLF.
- Docs are in English.

## Git

- One feature branch per milestone (`m0-skeleton`, `m1-player`, ...), merged to `master` with `--no-ff` after tests and lint pass. Small fixes may go directly on master.

See [testing.md](testing.md) for test conventions and [../decisions/0030-code-conventions.md](../decisions/0030-code-conventions.md).
