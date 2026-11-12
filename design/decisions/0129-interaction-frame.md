# 129. The interaction frame: corner brackets and a name tag on what E acts on (M13)

Status: Accepted

Date: 2026-11-12

## Context

The user asked for Deus Ex's (2000) highlight: when the crosshair is on something usable within reach, four thin white corner brackets frame its outline on screen and a small boxed name sits inside the frame's top-left corner. The prompt line under the crosshair ("E: pick up Lockpick") stays. The rule must be systemic: anything that becomes interactable is framed with no extra code, and the HUD must not know what the thing is.

## Decision

- **What is framed is what the Interactor targets** (ADR 0051): `Interactor.target` with a kind of PICK_UP, USE, CARRY or TOO_HEAVY (`TargetFrameRules.frames()`). Not while carrying (PUT_DOWN / NO_ROOM), not while the player cannot act (`ActorState.can_act`), not while scoped (the scope view replaces the crosshair, ADR 0085). The Interactor already decides by components (ItemPickup, Usable, Carryable), so the frame inherits that.
- **The name is the prompt's name**: the Interactor now keeps `target_name` beside `prompt` (the item's name with the stack's count above 1, `Interactor.counted_name()`; `Usable.target_name()`; else `display_name_of()`). A usable that writes its whole prompt ("Locked: keycard") is still named ("Door").
- **The outline is the target's visible geometry**: its GeometryInstance3D descendants (itself included) except text and sprites (labels and icons over a character, a dummy's readout), particles (fire), shadow-only proxies (a character's static shadow pose), nodes placed on their own (`top_level`: the deck's AR lines) and the operand shapes inside a CSG tree; collision and hit shapes are not geometry. Hidden parts are skipped at each refresh (a flashlight's beam when off). The parts are collected when the target changes.
- **Projection**: each part's box (its own AABB in its own frame) is clipped to the camera's view (`Camera3D.get_frustum()`, each face cut by every plane, Sutherland-Hodgman) and the remaining points are projected; the frame is the rectangle around all of them, padded 6 px and clamped 16 px inside the screen (px at 1080 p, scaled with the canvas height). Nothing left in view (behind the camera): hidden. Clipping at the view's sides frames what is seen of a big thing up close (a door), and per-part boxes frame a lying body tightly.
- **Look**: four L brackets, 1 px wide at 1080 p (scaled with the window, never under one physical pixel), arms 15 % of the frame's shorter side within 8-24 px at 1080 p (never past half the side), white with a faint dark outline. The name tag is a Label with the `HudTargetTag` type variation in `ui/hud/hud_theme.tres` (dark translucent box, thin light border), inside the frame's top-left corner when the frame is at least twice its height, else just above the frame (below it at the top edge).
- **Where**: `TargetFrameRules` (pure, RefCounted) and `TargetFrame` (`ui/hud/target_frame.tscn`, a HUD control the Hud refreshes every frame; `refresh(player)` is public for tests). Visual only, not saved; the game keeps running and there is nothing to leave.

## Alternatives considered

- **One merged AABB of the target, cached on target change and projected each frame** (the brief's first plan): a box in the target's frame does not follow parts that move inside it (a body tipping over as it is knocked out), and the merged box of a lying guard framed about 100 px of floor above it at 1080 p. Per-part boxes cost a few dozen projections per frame (a guard has eight visible parts), nothing measurable.
- **Clipping at the near plane only**: corners of a door up close that are off the top of the screen project far out sideways, so the frame ran well past the door's visible edge onto the floor.
- **Projecting the collision shapes**: they are often larger or simpler than the look (a door's doorway box, a guard's capsule standing while the body lies) and hitboxes stand for characters.
- **The window theme (`ui/window/window_theme.tres`)**: it holds the overlay screens' styles; a small HUD theme keeps the HUD's styles apart and out of the screens' merges.

## Consequences

- Anything with an ItemPickup, an available Usable or a Carryable that the player can offer is framed, with its name, without code: a new usable prop only needs visible meshes.
- A thing whose look is only text or sprites is not framed (none exists). A thing with no visible geometry gets no frame, but its prompt still shows.
- `Interactor.target_name` is available to any other HUD element that needs the target's name.
