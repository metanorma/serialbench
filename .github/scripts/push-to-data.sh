#!/usr/bin/env bash
# Pushes one format's results.yaml to serialbench/data via the GitHub
# Contents API (atomic per-file, no merge conflicts from parallel legs).
# Called after each format's benchmark completes — the site rebuilds
# incrementally as data arrives.
set -euo pipefail

FMT="$1"
RUBY_VERSION="$2"
PLATFORM="$3"
RESULTS_FILE="results/runs/ci-ruby-${RUBY_VERSION}-${PLATFORM}/${FMT}/results.yaml"
DATA_TOKEN="${DATA_REPO_TOKEN:-}"

if [ -z "$DATA_TOKEN" ]; then
  echo "::warning::DATA_REPO_TOKEN not set — skipping data push"
  exit 0
fi

if [ ! -f "$RESULTS_FILE" ]; then
  echo "::warning::No results at $RESULTS_FILE — skipping"
  exit 0
fi

DATE=$(date -u +%Y-%m-%d)
TARGET_PATH="runs/${DATE}/${PLATFORM}-ruby-${RUBY_VERSION}.${FMT}.yaml"
CONTENT=$(base64 < "$RESULTS_FILE" | tr -d '\r\n')

echo "Pushing ${TARGET_PATH} to serialbench/data..."

# Try create; if file exists (422), get sha and update
HTTP_CODE=$(curl -s -o /tmp/data-push-resp.json -w "%{http_code}" -X PUT \
  -H "Authorization: Bearer ${DATA_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/serialbench/data/contents/${TARGET_PATH}" \
  -d "{\"message\": \"${PLATFORM} ruby-${RUBY_VERSION} ${FMT}\", \"content\": \"${CONTENT}\", \"branch\": \"main\"}")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
  echo "Pushed ${TARGET_PATH}"
elif [ "$HTTP_CODE" = "422" ]; then
  SHA=$(curl -sf \
    -H "Authorization: Bearer ${DATA_TOKEN}" \
    "https://api.github.com/repos/serialbench/data/contents/${TARGET_PATH}" \
    | grep -oE '"sha":\s*"[a-f0-9]+"' | head -1 | grep -oE '[a-f0-9]{40}')
  if [ -n "$SHA" ]; then
    curl -sf -X PUT \
      -H "Authorization: Bearer ${DATA_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/serialbench/data/contents/${TARGET_PATH}" \
      -d "{\"message\": \"${PLATFORM} ruby-${RUBY_VERSION} ${FMT} (update)\", \"content\": \"${CONTENT}\", \"sha\": \"${SHA}\", \"branch\": \"main\"}" > /dev/null
    echo "Updated existing ${TARGET_PATH}"
  else
    echo "::warning::422 but couldn't get sha for ${TARGET_PATH}"
  fi
else
  echo "::warning::Push failed (${HTTP_CODE}): $(cat /tmp/data-push-resp.json | head -c 200)"
fi

# Trigger site rebuild (debounced by concurrency group on the .io repo)
curl -sf -X POST \
  -H "Authorization: Bearer ${DATA_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/serialbench/serialbench.github.io/dispatches" \
  -d '{"event_type": "data-updated"}' \
  && echo "Site rebuild triggered" \
  || echo "::warning::Failed to trigger site rebuild"
