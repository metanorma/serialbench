# ADR-0007: The data repo is the checkpoint ledger

Date: 2026-09-02

## Context
A leg's format steps are continue-on-error, so a Benchmark step failing inside a green job was invisible: autoheal (job-level) never saw it, and the missing format file surfaced only as a coverage gap (19 of 184 missing on 2026-09-01). Rerunning whole green jobs to recover one format costs ~45 minutes of re-measurement per leg — deliberate duplicate work.

## Decision
The data repo is the source of truth for what a leg has delivered:
1. Every leg ends with a completeness check that queries the data repo for all four of its format files; any miss fails the leg, making gaps visible to autoheal.
2. Benchmark steps skip a format whose file already exists — but only on rerun attempts (`github.run_attempt > 1`), so first attempts always measure fresh code.
3. Consequently autoheal's reruns are surgical: pushed formats skip in seconds and only the missing format is measured — eviction windows shrink from ~45 minutes to a single format's runtime.

Gaps that survive the 5-attempt cap surface as red runs, never as silent holes.
