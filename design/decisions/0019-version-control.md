# 19. Version control: local git, branch per milestone

Status: Accepted

Date: 2026-11-05

## Context

No remote exists yet; work is done by agents.

## Decision

Use local git. One feature branch per milestone, merged into master with --no-ff once tests and lint pass. Small fixes may go directly on master. The chief-engineer agent commits.

## Alternatives considered

- Trunk only.
- GitHub remote and CI: deferred.

## Consequences

- CI is deferred until a remote exists.
- Git LFS and a remote are in the [backlog](../backlog.md).
