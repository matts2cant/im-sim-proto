# 26. Audio: starter pack plus Kenney CC0, placeholders, no auto-downloads

Status: Accepted

Date: 2026-11-05

## Context

Audio is needed for noise feedback, but sourcing it is not a v0 goal.

## Decision

Use assets/audio/sfx_starter_pack_v1 and the Kenney CC0 packs. Missing sounds are generated placeholder beeps. Never download audio automatically.

## Alternatives considered

- Download assets on demand: not allowed without the user's OK.

## Consequences

- License PDF stays with the starter pack.
- Guard barks are text plus a placeholder sound.
- Generated sounds, no third-party audio: placeholder beeps (`PlaceholderBeep`) and the lockpicking sounds baked by `tools/sfx_gen/lockpick_sfx.py` into `items/lockpick/audio/sfx/` ([ADR 0108](0108-lockpick-sounds.md)).
