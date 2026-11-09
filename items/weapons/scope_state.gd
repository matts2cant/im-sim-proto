class_name ScopeState
extends RefCounted
## Pure scope state of a WeaponHolder (ADR 0085): scoped or not (a toggle), and how far the view has
## zoomed (`amount`, 0 at the hip ... 1 fully scoped) moving at 1 / `zoom_time` per second. The holder
## says each step whether scoping is possible (a weapon with a scope, the user can use its arms, not
## reloading); when it is not, the scope comes off by itself. Switching or putting the weapon away
## drops it at once (reset()).

## True between a toggle in and a toggle out (or an automatic scope-out).
var scoped: bool = false
## Zoom progress: 0 = hip view, 1 = fully zoomed.
var amount: float = 0.0
## Seconds a full zoom in or out takes.
var zoom_time: float = 0.15


## RMB: scopes in when `available`, else (or when already scoped) scopes out. Returns true when the
## state changed.
func toggle(available: bool) -> bool:
	if scoped:
		scoped = false
		return true
	if not available:
		return false
	scoped = true
	return true


## Advances the zoom `delta` seconds; scopes out when scoping is no longer `available` (the weapon
## lost its scope, the user cannot use its arms, a reload started). Returns true when that happened.
func step(delta: float, available: bool) -> bool:
	var dropped := scoped and not available
	if dropped:
		scoped = false
	var target := 1.0 if scoped else 0.0
	var rate := INF if zoom_time <= 0.0 else delta / zoom_time
	amount = move_toward(amount, target, rate)
	return dropped


## Off at once (weapon switched or put away). Returns true when it was scoped.
func reset() -> bool:
	var was := scoped
	scoped = false
	amount = 0.0
	return was


## Field of view now: `hip_fov` blended to `scope_fov` by the zoom amount.
func fov(hip_fov: float, scope_fov: float) -> float:
	return lerpf(hip_fov, scope_fov, amount)


## The camera's field of view with `weapon` drawn (hip_fov without a weapon or a scope); whoever
## owns the camera applies it, mouse sensitivity follows the ratio.
func view_fov(weapon: WeaponData, hip_fov: float) -> float:
	if weapon == null or not weapon.has_scope():
		return hip_fov
	return fov(hip_fov, weapon.scope_fov)
