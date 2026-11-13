class_name EventKinds
extends RefCounted
## Every EventLog kind (ADR 0136): emitters record and consumers match these constants, never
## string literals. Kinds are game content, so they live here and not in `core/` (the mechanism);
## the few kinds `core/` records itself are aliased from its constants.
## Naming (S25): `<subject>.<what happened>`, a past participle (`actor.died`, `door.opened`) or an
## event noun (`actor.awareness`, `radio.dispatch`). Kinds name events, never states: a kind is
## never used as a tag and a tag never as a kind, although both are dotted (`actor.died` is an
## event, `actor.guard` a tag); a test checks no kind is also a tag in a scene or resource.
## Entries name entities (source, target, data values) by display name and keep the entities
## themselves (EventLogEntry.entity()): consumers attribute by tags, never by name.
## The kinds marked "Consumed" are read by gameplay code; their data keys are the contract, checked
## by tests/events/event_contract_*_test.gd against the real emitters.

const StimulusSystemScript := preload("res://core/stimulus/stimulus_system.gd")

# actor
## Consumed (MissionTally). Source entity: the character. Data: `to` (String: the new state's
## name, "alerted" ...).
const ACTOR_AWARENESS: StringName = &"actor.awareness"
const ACTOR_BARK: StringName = &"actor.bark"
## Consumed (MissionTally): counted, no keys read.
const ACTOR_BODY_FOUND: StringName = &"actor.body_found"
## Consumed (HitMarkerRules). Target entity: the character hurt. Data: `amount` (float),
## `part` (String), `by` (int: the damaging stimulus id, 0: none).
const ACTOR_DAMAGED: StringName = &"actor.damaged"
## Consumed (MissionTally, HitMarkerRules). Target entity: the character. Data: `by` (int:
## the killing stimulus id, 0: none).
const ACTOR_DIED: StringName = &"actor.died"
const ACTOR_DISENGAGED: StringName = &"actor.disengaged"
const ACTOR_ENGAGED: StringName = &"actor.engaged"
const ACTOR_FOOTSTEP: StringName = &"actor.footstep"
const ACTOR_HEALED: StringName = &"actor.healed"
const ACTOR_HEARD: StringName = &"actor.heard"
const ACTOR_HEARD_ALARM: StringName = &"actor.heard_alarm"
const ACTOR_HEARD_CALL: StringName = &"actor.heard_call"
const ACTOR_HIT_REACTED: StringName = &"actor.hit_reacted"
const ACTOR_KNOCKED_BACK: StringName = &"actor.knocked_back"
## Consumed (MissionTally, HitMarkerRules). Target entity: the character. Data: `by` (int:
## the stimulus that knocked it out).
const ACTOR_KNOCKED_OUT: StringName = &"actor.knocked_out"
const ACTOR_LANDED: StringName = &"actor.landed"
const ACTOR_RADIO: StringName = &"actor.radio"
const ACTOR_RESET: StringName = &"actor.reset"
const ACTOR_REVIVED: StringName = &"actor.revived"
const ACTOR_SHOUT: StringName = &"actor.shout"
const ACTOR_STRUCK: StringName = &"actor.struck"
## Consumed (HitMarkerRules). Target entity: the character. Data: `by` (int stimulus id).
const ACTOR_STUNNED: StringName = &"actor.stunned"
const ACTOR_WAKE: StringName = &"actor.wake"

# alarm
const ALARM_ARMED: StringName = &"alarm.armed"
const ALARM_ENDED: StringName = &"alarm.ended"
const ALARM_IGNORED: StringName = &"alarm.ignored"
const ALARM_NETWORK_FAULT: StringName = &"alarm.network_fault"
## Consumed (MissionTally, Mission). Data: `again` (bool: a ring already going),
## `point` (Vector3: where it was raised).
const ALARM_RAISED: StringName = &"alarm.raised"
const ALARM_TROUBLE: StringName = &"alarm.trouble"

# augmentation
const AUGMENTATION_ACTIVATED: StringName = &"augmentation.activated"
const AUGMENTATION_DEACTIVATED: StringName = &"augmentation.deactivated"
const AUGMENTATION_INSTALLED: StringName = &"augmentation.installed"
const AUGMENTATION_REFUSED: StringName = &"augmentation.refused"

# camera
const CAMERA_DETECTED: StringName = &"camera.detected"

# carry (any character's Carrier)
const CARRY_DROPPED: StringName = &"carry.dropped"
const CARRY_PICKED_UP: StringName = &"carry.picked_up"
const CARRY_PICKUP_REFUSED: StringName = &"carry.pickup_refused"
const CARRY_RELEASE_REFUSED: StringName = &"carry.release_refused"
const CARRY_THREW: StringName = &"carry.threw"

# computer
const COMPUTER_LOGIN: StringName = &"computer.login"
const COMPUTER_LOGOUT: StringName = &"computer.logout"
const COMPUTER_OPENED: StringName = &"computer.opened"

# debug
const DEBUG_GAVE_ITEM: StringName = &"debug.gave_item"
const DEBUG_RESET_LEVEL: StringName = &"debug.reset_level"
const DEBUG_SPAWNED: StringName = &"debug.spawned"

# deck
const DECK_CRACKED: StringName = &"deck.cracked"
const DECK_EXPLOIT_USED: StringName = &"deck.exploit_used"
const DECK_ICEBREAKER: StringName = &"deck.icebreaker"
const DECK_PLUGGED: StringName = &"deck.plugged"
const DECK_REMOTE: StringName = &"deck.remote"
const DECK_SCAN: StringName = &"deck.scan"
const DECK_UNPLUGGED: StringName = &"deck.unplugged"
const DECK_WIFI: StringName = &"deck.wifi"
const DECK_WIFI_CRACKED: StringName = &"deck.wifi_cracked"

# device
## Consumed (MissionTally). Source entity: the sending device's entity. Data: `sent` (bool),
## `stimulus` (int, the command stimulus id, when sent), `by` (entity: who operated the
## sending device, when someone did).
const DEVICE_COMMAND: StringName = &"device.command"
const DEVICE_PANIC: StringName = &"device.panic"
## Consumed (NetworkFeedback). Source entity: the device's entity. Data: `up` (bool).
const DEVICE_STATE: StringName = &"device.state"
const DEVICE_TOGGLED: StringName = &"device.toggled"

# door
const DOOR_BLOCKED: StringName = &"door.blocked"
const DOOR_CLOSED: StringName = &"door.closed"
const DOOR_COMMAND: StringName = &"door.command"
const DOOR_OPENED: StringName = &"door.opened"
const DOOR_OPENED_FREELY: StringName = &"door.opened_freely"
const DOOR_REFUSED: StringName = &"door.refused"

# fuse
const FUSE_LIT: StringName = &"fuse.lit"

# game
const GAME_LOADED: StringName = QuickSave.LOADED_KIND
const GAME_SAVED: StringName = QuickSave.SAVED_KIND

# gas
const GAS_ENDED: StringName = &"gas.ended"
const GAS_RELEASED: StringName = &"gas.released"

# hinged_door
const HINGED_DOOR_CLOSED: StringName = &"hinged_door.closed"
const HINGED_DOOR_OPENED: StringName = &"hinged_door.opened"

# item
const ITEM_ATTACHED: StringName = &"item.attached"
const ITEM_DROPPED: StringName = &"item.dropped"
## Consumed (PickUpObjective). Source entity: who picked it up. Data: `item` (String: the
## item id).
const ITEM_PICKED_UP: StringName = &"item.picked_up"
const ITEM_PICKUP_REFUSED: StringName = &"item.pickup_refused"
const ITEM_USE_REFUSED: StringName = &"item.use_refused"
const ITEM_USED: StringName = &"item.used"

# jamming
const JAMMING_ENDED: StringName = &"jamming.ended"
const JAMMING_STARTED: StringName = &"jamming.started"

# keychain
const KEYCHAIN_KEY_ADDED: StringName = &"keychain.key_added"
const KEYCHAIN_KEY_REMOVED: StringName = &"keychain.key_removed"

# laser
const LASER_TOGGLED: StringName = &"laser.toggled"
const LASER_TRIPPED: StringName = &"laser.tripped"

# level
const LEVEL_EXIT: StringName = &"level.exit"
const LEVEL_EXIT_REFUSED: StringName = &"level.exit_refused"
const LEVEL_RESET: StringName = LevelReset.RESET_KIND

# light
const LIGHT_FLASHLIGHT: StringName = &"light.flashlight"

# lock
const LOCK_CODE_ENTERED: StringName = &"lock.code_entered"
const LOCK_GRANTED: StringName = &"lock.granted"
const LOCK_LOCKED: StringName = &"lock.locked"
const LOCK_PICK_BROKE: StringName = &"lock.pick_broke"
const LOCK_PICK_CANCELLED: StringName = &"lock.pick_cancelled"
const LOCK_PICK_STARTED: StringName = &"lock.pick_started"
const LOCK_PICKED: StringName = &"lock.picked"
const LOCK_RELOCKED: StringName = &"lock.relocked"
const LOCK_UNLOCKED: StringName = &"lock.unlocked"

# log
const LOG_ENTRY_ADDED: StringName = &"log.entry_added"

# loot
const LOOT_OPENED: StringName = &"loot.opened"

# mine
const MINE_ARMED: StringName = &"mine.armed"
const MINE_DISARM_FAILED: StringName = &"mine.disarm_failed"
const MINE_DISARMED: StringName = &"mine.disarmed"
const MINE_TRIGGERED: StringName = &"mine.triggered"

# mission
const MISSION_BRIEFING_CLOSED: StringName = &"mission.briefing_closed"
const MISSION_COMPLETED: StringName = &"mission.completed"
const MISSION_EXTRACTION_REFUSED: StringName = &"mission.extraction_refused"
const MISSION_LEFT: StringName = &"mission.left"
const MISSION_OBJECTIVE_COMPLETED: StringName = &"mission.objective_completed"
const MISSION_REINFORCEMENTS: StringName = &"mission.reinforcements"
const MISSION_RESTARTED: StringName = &"mission.restarted"
const MISSION_STARTED: StringName = &"mission.started"

# network
const NETWORK_LOGIN: StringName = &"network.login"
const NETWORK_PASSWORD: StringName = &"network.password"
const NETWORK_WIFI_KEY: StringName = &"network.wifi_key"

# object
## Consumed (MissionTally). Source entity: the object. Data: `by` (int stimulus id),
## `reason` (StringName: `burnt_out` when a fire finished it).
const OBJECT_BROKEN: StringName = &"object.broken"
const OBJECT_BURNT_OUT: StringName = &"object.burnt_out"
## Consumed (MissionTally). Target entity: the object. Data: `health` (float, left), `by`
## (int stimulus id).
const OBJECT_DAMAGED: StringName = &"object.damaged"
## Consumed (MissionTally). Source entity: the object. Data: `by` (int stimulus id).
const OBJECT_EXPLODED: StringName = &"object.exploded"
## Consumed (MissionTally). Source entity: the object. Data: `by` (int stimulus id).
const OBJECT_IGNITED: StringName = &"object.ignited"
const OBJECT_IMPACT: StringName = &"object.impact"
const OBJECT_STUCK: StringName = &"object.stuck"

# payload
const PAYLOAD_RELEASED: StringName = &"payload.released"

# player
const PLAYER_MANTLED: StringName = &"player.mantled"

# power
## Consumed (NetworkFeedback). Source entity: who switched the breaker. Data: `on` (bool).
const POWER_SWITCHED: StringName = &"power.switched"

# radio
const RADIO_DISPATCH: StringName = &"radio.dispatch"
const RADIO_JAMMED: StringName = &"radio.jammed"

# range
const RANGE_BODIES_RESET: StringName = &"range.bodies_reset"
const RANGE_BUTTON: StringName = &"range.button"
const RANGE_RESTOCKED: StringName = &"range.restocked"
const RANGE_TUNING_OPENED: StringName = &"range.tuning_opened"

# receptron
const RECEPTRON_FIRED: StringName = StimulusReceiver.FIRED_KIND

# router
const ROUTER_RULES: StringName = &"router.rules"

# siren
const SIREN_STARTED: StringName = &"siren.started"
const SIREN_STOPPED: StringName = &"siren.stopped"

# skill
const SKILL_TIER_CHANGED: StringName = &"skill.tier_changed"

# stimulus
const STIMULUS_DROPPED: StringName = StimulusSystemScript.DROPPED_KIND
## Consumed (MissionTally, HitMarkerRules). Source entity: the stimulus source (absent when it
## was freed); target entity: a CONTACT stimulus's target. Data: `id` (int), `type`
## (StringName), `cause_id` (int, 0: none), `source` (its name, display only).
const STIMULUS_EMITTED: StringName = StimulusSystemScript.EMITTED_KIND
const STIMULUS_RECEIVED: StringName = StimulusReceiver.RECEIVED_KIND

# thrower (Thrower still passes these as literals to its _log helper: to switch at its next edit)
const THROWER_STUCK: StringName = &"thrower.stuck"
const THROWER_THROWN: StringName = &"thrower.thrown"

# tracer
const TRACER_FULL: StringName = &"tracer.full"
const TRACER_GAIN: StringName = &"tracer.gain"

# turret
const TURRET_DETECTED: StringName = &"turret.detected"
const TURRET_DISENGAGED: StringName = &"turret.disengaged"
const TURRET_ENGAGED: StringName = &"turret.engaged"
const TURRET_RETARGETED: StringName = &"turret.retargeted"

# weapon
const WEAPON_DROPPED: StringName = &"weapon.dropped"
const WEAPON_DRY_FIRE: StringName = &"weapon.dry_fire"
const WEAPON_EQUIPPED: StringName = &"weapon.equipped"
const WEAPON_FIRED: StringName = &"weapon.fired"
const WEAPON_HOLSTERED: StringName = &"weapon.holstered"
const WEAPON_RELOAD_STARTED: StringName = &"weapon.reload_started"
const WEAPON_RELOADED: StringName = &"weapon.reloaded"
const WEAPON_REMOVED: StringName = &"weapon.removed"
const WEAPON_SCOPED: StringName = &"weapon.scoped"
const WEAPON_STOWED: StringName = &"weapon.stowed"
const WEAPON_SWUNG: StringName = &"weapon.swung"
const WEAPON_THROWN: StringName = &"weapon.thrown"

## Prefix of the Mission's own kinds (`mission.*`), which its tallies skip.
const MISSION_PREFIX: String = "mission."
