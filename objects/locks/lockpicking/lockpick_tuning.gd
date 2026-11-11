class_name LockpickTuning
extends Resource
## Tuning of the lockpicking minigame (ADR 0073, 0107, 0109). The numbers are the final prototype's
## (design/prototypes/lockpicking_bench.html) unless noted. Lift, tension and pin heights are 0..1
## fractions of the full range; times are seconds. The skill-dependent values (tension window, drop
## threshold and delay, lift tolerance bonus, set dwell, rake, assists) are attributes whose base is here and
## whose per-tier steps are the Lockpicking skill's modifiers (skill_table.tres).

@export_group("Skill bases (attributes)")
## `lockpick_window_low` base: the lowest tension of the sweet spot.
@export var window_low: float = 0.40
## `lockpick_window_high` base: the highest tension of the sweet spot.
@export var window_high: float = 0.55
## `lockpick_drop_threshold` base: below this tension set pins start to drop.
@export var drop_threshold: float = 0.15
## `lockpick_drop_delay` base: seconds per dropped pin below the threshold.
@export var drop_delay: float = 0.3
## `lockpick_lift_tolerance` base: added to `base_tolerance` around the shear line.
@export var lift_tolerance_bonus: float = 0.0
## `lockpick_set_dwell` base: seconds the binding pin must stay at its shear line to set.
@export var set_dwell: float = 0.08
## `lockpick_rake` base: rakes when the attribute is at least 0.5.
@export var rake: float = 0.0
## `lockpick_assist` base: 0 sound only, 1 + tension gauge, 2 + captions, 3 + clear lock.
@export var assist: float = 0.0

@export_group("Tension")
## Tension change per mouse wheel notch (up raises it).
@export var wheel_step: float = 0.03
## The same with Shift held (fine steps).
@export var wheel_fine_step: float = 0.01
## At or below this tension every pin drops at once.
@export var release_tension: float = 0.004

@export_group("Pins")
## Lift tolerance around the shear line before the skill bonus and the lock's multiplier.
@export var base_tolerance: float = 0.045
## A pin's shear-line lift is `pin_height_min` + random * `pin_height_range`.
@export var pin_height_min: float = 0.44
@export var pin_height_range: float = 0.30
## A spool's false set this far below its shear line.
@export var false_set_offset: float = 0.12
## A serrated pin's ticks this far below its shear line.
@export var serrated_offsets: Array[float] = [0.18, 0.09]
## Unlifted pins fall at this rate (lift per second).
@export var pin_fall_rate: float = 3.0
## A set or loose pin oversets when its key pin is pushed this far past the shear line beyond the
## tolerance (the binding pin: at the tolerance).
@export var set_overset: float = 0.15
## Above the window the tolerance shrinks: max(over_floor, 1 - over_slope * (t - hi) / (1 - hi)).
@export var over_floor: float = 0.35
@export var over_slope: float = 1.4

@export_group("Pick")
## Spring of the tip towards the lift target (per second, as a fraction of the gap).
@export var tip_ease: float = 18.0
## A binding pin rises at (force - required) * this per second.
@export var lift_rate: float = 7.0
## Force a binding pin needs: `lift_required_base` + `lift_required_tension` * tension^2 (+ bump).
@export var lift_required_base: float = 0.04
@export var lift_required_tension: float = 0.5
## Force above which the pick strains (on a heavily bound pin or an overset).
@export var strain_force: float = 0.3
## Strain gain per unit of force above `strain_force`, per second, on a binding pin.
@export var strain_rate: float = 3.0
## The same while prying an overset pin.
@export var strain_rate_overset: float = 2.5
## Extra strain factor per unit of tension above the window.
@export var strain_high_tension: float = 4.0
## Strain lost per second while not straining.
@export var strain_relief: float = 0.8
## A binding pin is hard to lift above `window_high` - this.
@export var hard_margin: float = 0.05
## The pick breaks at this strain.
@export var break_strain: float = 1.0

@export_group("False sets")
## Extra plug turn (degrees) on a spool's false set; it turns back as the spool is lifted.
@export var false_set_turn: float = 3.2
## A false-set spool stays stuck while tension is above its false-set tension minus this.
@export var stuck_spool_margin: float = 0.06
## The creak plays when the plug turns back by more than this (degrees)...
@export var creak_step: float = 0.25
## ... at most once per this many seconds.
@export var creak_interval: float = 0.22
## A serrated tick adds this much required force, decaying by `bump_decay` per second.
@export var tick_bump: float = 0.12
@export var bump_decay: float = 0.5
## Each serrated tick turns the plug this many degrees.
@export var tick_turn: float = 0.35

@export_group("Feedback")
## The tip rubs (scrape) when it moves faster than this (lift per second)...
@export var scrape_speed: float = 0.05
## ... with an amount of speed * this, up to 1.
@export var scrape_gain: float = 2.0
## Seconds between two scrape noises.
@export var scrape_noise_interval: float = 1.2
## Camera / panel nudge on events (decays by `nudge_decay` per second).
@export var nudge_decay: float = 4.0
@export var nudge_set: float = 0.45
@export var nudge_set_muted: float = 0.15
@export var nudge_overset: float = 0.6
@export var nudge_false_set: float = 0.7
@export var nudge_tick: float = 0.2
@export var nudge_snap: float = 1.0
## Seconds a caption stays up.
@export var caption_time: float = 1.6

@export_group("Plug")
## Plug turn (degrees) per unit of tension and per set pin.
@export var plug_tension_turn: float = 1.4
@export var plug_set_turn: float = 0.9
## The open plug turns from `plug_open_base` to `plug_open_base` + `plug_open_turn` degrees.
@export var plug_open_base: float = 6.0
@export var plug_open_turn: float = 84.0
## Open animation speed (fraction per second).
@export var open_rate: float = 1.8
## The opening sound and noise come this long after the last set.
@export var open_sound_delay: float = 0.12

@export_group("Rake")
## A sideways tip move in the bottom band faster than this (pin slots per second) is a rake stroke.
@export var rake_speed: float = 2.5
## Reversals of fast strokes that set one binding pin (a raking picker on a rakeable lock).
@export var rake_strokes: int = 3
## Seconds without a stroke before the raking rhythm is lost.
@export var rake_gap: float = 0.5
## Scrape amount of a stroke: speed / this, up to 1.
@export var rake_scrape_speed: float = 8.0
## Seconds between two rake noises (shared with the binding scrape's noise).
@export var rake_noise_interval: float = 0.6
## Seconds between two "why nothing catches" captions.
@export var rake_hint_interval: float = 1.5
## Panel nudge on a stroke.
@export var nudge_rake: float = 0.15
## A lock is rakeable when it has at most this many pins, all standard (Simple and Standard locks).
@export var rake_max_pins: int = 5

@export_group("Noise (loudness)")
@export var noise_click: float = 2.0
@export var noise_scrape: float = 2.0
@export var noise_tick: float = 2.0
@export var noise_jam: float = 3.0
@export var noise_clunk: float = 3.0
@export var noise_open: float = 4.0
@export var noise_snap: float = 6.0

@export_group("Controls and screen")
## Pixels of relative mouse motion up for the full lift (0 to 1).
@export var lift_pixels: float = 300.0
## Pixels of relative mouse motion sideways per pin slot.
@export var slot_pixels: float = 60.0
## Tip and aim at or under this lift (0..1): the bottom band, where the tip slides between pins and
## rakes.
@export var bottom_band: float = 0.10
## The tip's sideways spring in the bottom band, and back under its pin above it (per second).
@export var slide_ease: float = 14.0
@export var settle_ease: float = 20.0
## The tip's pin becomes the nearest slot once the tip is more than this (slots) from it.
@export var slot_hysteresis: float = 0.55
## The aim along the keyway goes this far (slots) past the front and back pins.
@export var aim_x_margin: float = 0.45
## The camera turns to face the lock in this time.
@export var face_time: float = 0.25
## Leaving: the lock is out of reach beyond this distance (m) from the picker's eyes.
@export var leave_distance: float = 2.5
## A picked lock's screen closes this long after it opened (the plug turns).
@export var close_after_open: float = 0.8

@export_group("Practice locks")
## An opened practice lock re-locks with a new layout after this many seconds.
@export var practice_relock_delay: float = 3.0
## The pins drop and settle at their new heights over this many seconds.
@export var relayout_time: float = 0.5
## The tiers a practice lock can be (Simple, Standard, Secure, High-security).
@export var tiers: Array[LockpickTier] = []


## The noise loudness of an event kind (PinTumbler event kinds), 0 for silent ones.
func loudness(kind: StringName) -> float:
	var table: Dictionary[StringName, float] = {
		&"set": noise_click,
		&"scrape": noise_scrape,
		&"rake": noise_scrape,
		&"tick": noise_tick,
		&"overset": noise_jam,
		&"false_set": noise_clunk,
		&"open": noise_open,
		&"snap": noise_snap,
	}
	return table.get(kind, 0.0)


## Tier `index` clamped to the list, or null without tiers.
func tier(index: int) -> LockpickTier:
	if tiers.is_empty():
		return null
	return tiers[clampi(index, 0, tiers.size() - 1)]
