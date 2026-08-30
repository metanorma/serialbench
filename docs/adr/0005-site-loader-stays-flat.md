# ADR-0005: Site loader stays a flat store

Date: 2026-08-29 (reaffirmed 2026-08-30)

## Context
The site's `loadBenchmarks` returns a flat `BenchmarkStore` that components re-shape; a domain-query loader (leaderboard()/availability()/trend()) was proposed twice.

## Decision
Defer. After the redesign the data layer is small, single-purpose modules (parser/aggregator/trend/versions, 18 tests) and no consumer friction has appeared. Revisit when a second dashboard view forces its own query shape.
