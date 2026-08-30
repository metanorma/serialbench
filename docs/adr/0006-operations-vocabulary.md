# ADR-0006: One operations vocabulary

Date: 2026-08-29

## Context
Benchmark configs declared `parse`/`generate`; the runner's OPERATIONS table used `parsing`/`generation`; `xpath` was in production configs but not the model's legal values; the config's `operations:` list was never read.

## Decision
The OPERATIONS keys plus `memory` are the only legal names, end to end (config values, model validation, runner dispatch). Absent key = run everything; unknown name = `ArgumentError` with guidance. lutaml-model caveat: `default:` on a collection merges into deserialized values, so the everything-default lives in the runner, not the model.
