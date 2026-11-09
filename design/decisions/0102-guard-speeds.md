# 102. Guard speeds: patrol at 1.5 m/s, run at 4.0 m/s, sprint stance from 3.0 m/s

Status: Accepted (amends the speeds of [ADR 0068](0068-awareness-states-and-guard-behaviour.md))

Date: 2026-11-09

## Context

M9h playtest feedback: "Make guards patrol at walking speed and run a little slower." Every guard pace comes from one tuning resource, `actors/guard/guard_walker.tres` (`NavWalkerConfig`): `walk_speed` 1.8, `investigate_speed` 2.5, `run_speed` 5.0 m/s, and `sprint_tag_speed` 4.0 (a requested speed at or above it sets `stance.sprint`, the louder footsteps). Patrols used `walk_speed`; measured in the guard fixture, a patrolling guard covered exactly 1.80 m/s and a running one 5.00 m/s. 1.8 m/s is a brisk march (people stroll at about 1.4), and at 5 m/s a running guard nearly kept up with the sprinting player (6 m/s). The player walks at 4, sprints at 6 and crouch-walks at 2 m/s.

## Decision

- **Patrol 1.5 m/s, run 4.0 m/s** (`walk_speed`, `run_speed` in `guard_walker.tres`; no code change). A sprinting player outruns a running guard; a walking player does not gain on one.
- **Investigate stays 2.5 m/s**, between the two: a suspicious guard walks briskly to the point, and the combat advance (to 11 m) keeps its pace.
- **`sprint_tag_speed` 3.0** (was 4.0): with the run at 4.0 the old threshold would have been knife-edge (a request exactly at the threshold). 3.0 leaves 1.0 m/s below the run and 0.5 above the investigate pace, so running is sprinting (loud footsteps, sprint stride) and walking or investigating is not.
- Which pace each state uses is unchanged:

  | Pace | m/s | Used for |
  |---|---|---|
  | Walk | 1.5 | Patrols, returning to a post, Searching after the first point, the combat sidestep and backing off |
  | Investigate | 2.5 | Suspicious (walking to the point), the combat advance |
  | Run | 4.0 | Alerted (chase), a loud noise, the first search point (a call, a body, the alarm; reinforcements search this way), the baton's approach |

- **Combat** needs no retune: guards fire only below `fire_max_speed` 0.3 m/s, which they reach 0.26 s after stopping from a run (was 0.34 s, deceleration 14 m/s²); the backing-off pace drops to 1.5 m/s.
- **Measured** by `tests/actors/guard/guard_speed_test.gd` in the guard fixture on flat navmesh: patrol 1.50 m/s over a 6 m stretch of a straight 10 m leg, run 4.00 m/s over 5 m of a 9 m chase (within 5 %), and the running guard carries the sprint stance.

### Warehouse patrols

Laps grow by about 20 % of their walking time (`warehouse_patrol_timing_test.gd`, now 70 s simulated, since the longest lap passed 60 s): G2 48.7 -> 56.5 s, G3 36.9 -> 42.3 s, G4 52.2 -> 61.3 s, G9 51.3 -> 60.3 s, G10 45.2 -> 51.0 s. The bridge's east end, passed once a lap by G10 at its turn, went to 45.8 s unwatched, beyond the 45 s ceiling. A gap at a turn is the time the guard spends out of the crossing's 5 m, so moving the turn point within the radius or changing the wait at it does not shorten it; only the far end does. **G10 now waits 1 s at its west end** (`CatwalkWestA`, was 3 s; `tools/level_gen/warehouse_people.py`): the bridge gap is 43.8 s and the shortest gap at the annex roof door (the turn just past it) 4.9 s, both inside the 4-45 s targets with about 1 s to spare. Every crossing is now watched less often (largest gaps 19-44 s, were 17-39 s); the routes themselves are unchanged.

## Consequences

- Patrols read as walking; chases are escapable by sprinting and not by walking.
- The compound is watched a little less (largest gaps up to 43.8 s); the bridge end and the annex roof door sit about 1 s inside the targets, so any further slow-down or longer wait there needs a route change.
- The route scenario suites wait on guard conditions and needed no change; they simulate a little longer where they wait for a patrol to pass (measured back to back, 3 shards: culvert 72.5 -> 78.6 s, vault 88.0 -> 95.5 s, rush unchanged at 16 s). The patrol timing suite simulates 70 s instead of 60 (about 18 s of wall time).
