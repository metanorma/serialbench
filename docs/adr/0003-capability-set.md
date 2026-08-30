# ADR-0003: The capability set is the single adapter interface

Date: 2026-08-29

## Context
Adapters declared capabilities through 49 individual `supports_X?` predicates, a parallel `features` hash, and (after a partial migration) a `capabilities` Set — three interfaces that could and did contradict (nokogiri's features denied streaming it has; rexml declared xpath without implementing `xpath_query`).

## Decision
One source of truth: `capabilities` returns a `Set<Symbol>`; adapters override with `super | Set.new(...)`; the per-format `features` export derives from it; benchmark selection filters via `supports?`. New capability = one symbol. Do not reintroduce per-capability predicate methods.
