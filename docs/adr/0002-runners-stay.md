# ADR-0002: Docker and ASDF runners stay

Date: 2026-08-28

## Context
An architecture round deleted the docker/asdf runners as "unused by CI" (only LocalRunner executes in GitHub Actions).

## Decision
Restore and keep them. The owner's requirement: every platform remains benchmarkable through the gem, not just what current CI exercises. Round 4 then repaired the asdf dispatch so the runner is actually reachable (`Runners.for`). Do not re-suggest deleting runners.
