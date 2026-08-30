# ADR-0001: Three-repo split with incremental per-format pushes

Date: 2026-08-28

## Context
The monolith coupled benchmark code, result storage, and site rendering; every publish was a batch job whose failure lost everything.

## Decision
Three repos: `serialbench/serialbench` (gem), `serialbench/data` (append-only YAML runs), `serialbench/serialbench.github.io` (Astro site). Each Result Leg pushes its file to data via the Contents API immediately and triggers a site rebuild; legs are `continue-on-error` so one eviction never blocks the others.
