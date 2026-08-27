#!/usr/bin/env bash
# Benchmarks one format, verifies the result, uploads the artifact.
# Called as a separate workflow step per format so each is an independent
# checkpoint — a runner eviction costs one format, not the entire leg.
set -euo pipefail

FMT="$1"
RUBY_VERSION="$2"
PLATFORM="$3"

BASE="results/runs/ci-ruby-${RUBY_VERSION}-${PLATFORM}"
RESULTS_FILE="$BASE/$FMT/results.yaml"

echo "=== Benchmarking $FMT (Ruby $RUBY_VERSION, $PLATFORM) ==="
bundle exec serialbench environment execute \
  "config/environments/ci-ruby-${RUBY_VERSION}.yml" \
  "config/benchmarks/full-${FMT}.yml" \
  "$BASE/$FMT"

echo "=== Verifying $FMT results ==="
if [ ! -f "$RESULTS_FILE" ]; then
  echo "ERROR: results.yaml not found at $RESULTS_FILE"
  exit 1
fi

SIZE=$(wc -c < "$RESULTS_FILE" | tr -d ' ')
echo "File size: $SIZE bytes"

if [ "$SIZE" -lt 1000 ]; then
  echo "ERROR: results.yaml is suspiciously small ($SIZE bytes)"
  cat "$RESULTS_FILE"
  exit 1
fi

echo "=== Validating $FMT schema ==="
bundle exec serialbench validate result "$RESULTS_FILE"

echo "=== Uploading $FMT artifact ==="
