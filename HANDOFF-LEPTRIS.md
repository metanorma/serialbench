# Handoff: serialbench–leptris integration

Everything an agent needs to own the Leptris integration in serialbench.
Written 2026-08-23. Local checkout: `~/src/mn/serialbench` (branch `main`).

## Context

serialbench (https://github.com/metanorma/serialbench) benchmarks Ruby
serialization libraries. Its `benchmark-weekly` workflow
(`.github/workflows/benchmark.yml`) runs a 12-platform × 4-Ruby matrix
(platforms: ubuntu-24.04 / -arm, ubuntu-22.04 / -arm, macos-13,
macos-15-intel, macos-14, macos-15, macos-26, windows-2022, windows-2025,
windows-11-arm; Rubies: 3.1–3.4), uploads per-leg `results.yaml`
artifacts, aggregates them into a resultset, builds an HTML site, and
deploys to GitHub Pages at https://metanorma.github.io/serialbench/.

Leptris (https://github.com/leptris/leptris) is a pure-C99 XML 1.0 parser
with a W3C-conformant XPath 1.0 engine (438/438 on the W3C suite) and
full SAX. leptris-ruby (https://github.com/leptris/leptris-ruby) is its
FFI binding with a Nokogiri-compatible API. As of leptris 1.1.2,
`gem install leptris` resolves a **precompiled platform gem**
(x86_64/aarch64-linux incl. musl, x86_64/arm64-darwin, x64-mingw32/ucrt,
aarch64-mingw-ucrt) with libleptris vendored inside — install-and-parse
works on a clean machine with no system library, no env vars, no build
tools.

## Current state (integration is DONE and merged)

### The adapter

- `lib/serialbench/serializers/xml/leptris_serializer.rb`
  - parse → `Leptris::XML.parse`; generate → `to_xml(indent: 2)`;
    streaming → `Leptris::XML::SAX` with an element-counting handler
    mirroring the Nokogiri adapter's shape.
  - The SAX handler is duck-typed (no base class) with explicit no-op
    callbacks, so loading the file never triggers the FFI library load.
  - `available?` probes with a real parse, not `require` — the gem
    requires fine even when the shared library is absent (FFI loads
    lazily), so uncovered runners SKIP Leptris gracefully per-leg
    instead of failing the run.
- Registered in `lib/serialbench/serializers.rb` (`REGISTER[:xml]`),
  `Gemfile` (`gem 'leptris'`), README row, shared-example specs in
  `spec/serializers_spec.rb` (117 examples, 0 failures; the Leptris
  block executes when libleptris is reachable, skips otherwise).

### Pipeline repairs that shipped with it

These two were why the weekly pipeline and Pages site had been dead since
December 2025:

1. `Platform` model fix — lutaml-model 0.8.0 regression: attribute default
   lambdas lost access to class methods, so `Platform.current_local` (used
   by the benchmark CLI itself) raised NameError routed through
   `method_missing`. Fixed by fully qualifying
   `Serialbench::Models::Platform.detect_os` / `.detect_arch` in the
   default lambdas. 141 examples, 0 failures across models + serializers.
2. `gem 'benchmark'` added to the Gemfile — Ruby 4.0 removed it from the
   stdlib and the rake CI legs were dying at `require 'benchmark'`.

`benchmark.yml` also lists Leptris in both hardcoded places (the site's
README summary and the workflow step summary).

### Merge history

| PR | Content |
|----|---------|
| #9 | original "taurus" PR — died closed on a renamed branch; do not reuse |
| #10 | the leptris serializer (renamed from taurus after the gem rename) |
| #11 | benchmark.yml lists + `gem 'benchmark'`; folded in the Platform fix |
| #12 | re-land of the Platform fix via PR (see incident note below) |

CI was 15/15 green on the last PR merge.

### Local race numbers (leptris 1.1.0 lib, macOS arm64, Ruby 3.4.8)

Leptris is FIRST on every XML operation:

| Op / size          | leptris | nokogiri | ox    | vs best other |
|--------------------|---------|----------|-------|---------------|
| parse large        | 8.15 ms | 101.4    | 101.5 | 12.4x         |
| parse medium       | 0.84 ms | 4.9      | 3.6   | 4.3x          |
| generate large     | 80.8 ms | 88.8     | 124.9 | 1.1x          |
| generate medium    | 1.34 ms | 8.0      | 5.2   | 3.9x          |
| streaming large    | 14.7 ms | 213.8    | 157.5 | 14.5x         |
| streaming medium   | 0.59 ms | 48.4     | 107.3 | 82x           |
| Ruby alloc (large) | 0.01 MB | 539.9    | 237.4 | ~5 orders     |

Race method: local benchmark run with
`LEPTRIS_LIB_PATH=/path/to/libleptris.dylib bundle exec ruby -e` driving
`Serialbench::BenchmarkRunner` with a local env config + an XML-only
benchmark config (sizes small/medium/large; iterations 200/20/2).
Full logs of the last run: `/tmp/sbx/race7.log` (may be gone — rerun).

### Filed upstream (keep these threads alive)

- **lutaml/lutaml-model#745** — the 0.8.0 default-lambda regression.
  Bisected with isolated GEM_HOME tests: 0.7.1 ✓, 0.7.7 ✓, 0.8.0 ✗.
  serialbench was the downstream casualty.
- **lutaml/moxml#96** — proposal to add a Leptris adapter to moxml and
  make it the default. Includes the full pitch and honest caveats, plus
  a correction comment: "XPath 1.0 only" is full parity (libxml2 also
  stops at 1.0; Ox has none; Oga/REXML partial), not a deficit.
- **leptris/leptris#477** — mixed-nodeset XPath API defects (enum-space
  collision; `node_name`/`node_value` crash on text entries). Does NOT
  affect the serialbench adapter.

## First task — get the site live with Leptris

A workflow_dispatch of benchmark-weekly (**run 32621796565**) was sitting
QUEUED with zero jobs for ~40 minutes. The workflow itself is `active`
(verified via the API), so this smells like org-side Actions capacity —
billing limit or runner constraints — consistent with their scheduled
runs being cancelled since December 2025. Escalate to the user if it
stays stuck; a metanorma org admin may need to lift an Actions spending
cap. If runners free up: confirm the run completes, then verify the
Pages site renders Leptris in the XML field.

Fallback if Actions stays blocked: build the site locally with their CLI
(`serialbench environment execute` → `resultset create` → `resultset
add-result` → `resultset build-site`) using a local `kind: local`
environment config, and hand the user a leptris-inclusive `_site/` as
proof.

Expected per-leg behavior: Bundler resolves the leptris platform gem
automatically from the Gemfile — no install step exists or is needed.
Runners whose glibc predates the build host (ubuntu-22.04 legs) or other
uncovered combos report Leptris as unavailable and skip it per-leg; that
is by design.

## Ongoing ownership

1. When libleptris/leptris-ruby releases, refresh the race numbers from a
   fresh local run only — never copy stale tables forward.
2. Keep the adapter's gem requirement at leptris >= 1.1.0 (the version
   that provides the `Leptris::XML.parse` module entry point).
3. Watch leptris#477; nothing to do for serialbench until it lands.

## Rules (non-negotiable)

1. **ALL changes via PRs.** Never commit or push to main directly. An
   incident already happened once: the Platform fix went straight to main
   by accident and had to be re-landed as revert + reapply through
   PR #12. Check `git branch --show-current` before every commit.
2. Never add AI attribution (`Co-authored-by:`, "Generated with…") in
   commits, PRs, or comments.
3. PR bodies containing backticks go through `gh pr create --body-file`,
   never inline `--body`.
4. `git add` explicit file paths only — never `-A` / `.` / `*`.
5. No test doubles or mocks in specs — real library instances.
6. Pre-existing CI failures: bisect whether they exist on pristine main
   before owning them. serialbench's CI has drift history (fresh version
   resolution pulled lutaml-model 0.8.19 and broke 26 specs at once).
7. Never force-push, never delete files you didn't create, never push
   tags. Reversibility first.

## Useful local paths (this machine)

- serialbench checkout: `~/src/mn/serialbench`
- a built libleptris 1.1.0: `/tmp/leptris-v110/build/src/libleptris.dylib`
  (rebuildable: fetch the release tarball from
  `https://api.github.com/repos/leptris/leptris/tarball/v1.1.0`, cmake
  with `-DLEPTRIS_BUILD_SHARED=ON -DLEPTRIS_BUILD_STATIC=OFF
  -DBUILD_TESTING=OFF -DLEPTRIS_BUILD_CLI=OFF
  -DLEPTRIS_BUILD_BENCHMARKS=OFF -DLEPTRIS_BUILD_MAN_PAGES=OFF
  -DLEPTRIS_ENABLE_UTF8PROC=OFF -DLEPTRIS_ENABLE_ICONV=OFF`)
- local race driver: see "Local race numbers" above; env/benchmark yml
  shape is documented inline in the runner invocation

## Acceptance for this handoff

- benchmark-weekly completes on main and the Pages site shows Leptris in
  the XML field with plausible numbers — or, if Actions is org-blocked, a
  locally built site demonstrating it plus a clear escalation note.
- The moxml#96 and lutaml-model#745 threads are kept current if either
  upstream responds.
