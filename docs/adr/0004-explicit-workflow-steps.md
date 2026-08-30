# ADR-0004: Benchmark workflow keeps 12 explicit format steps

Date: 2026-08-30

## Context
benchmark.yml repeats a benchmark/upload/push trio per format; a composite action could collapse 12 steps to 4.

## Decision
Decline. `continue-on-error` is a caller-side property a composite cannot carry; the independent-checkpoint semantics would need re-implementation; each explicit step is a grep-able checkpoint during incident triage; the pipeline had a fragile week and the duplication is the price of the isolation property. Revisit only if a fifth format arrives.
