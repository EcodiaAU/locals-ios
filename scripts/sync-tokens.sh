#!/usr/bin/env bash
# Regenerate Sources/Locals/Design/DesignTokens.swift from
# ../locals-shared/tokens/design.json. Run whenever the shared design token
# file changes; commit the resulting Swift file. Three-native pattern: web +
# iOS + Android each vendor a SYNCED copy of the shared tokens at build time.
#
# Usage: scripts/sync-tokens.sh
# Requires: node (uses Node to parse JSON without yq dep)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARED="${REPO_DIR}/../locals-shared/tokens/design.json"
OUT="${REPO_DIR}/Sources/Locals/Design/DesignTokens.swift"

if [ ! -f "$SHARED" ]; then
  echo "fatal: shared tokens not found at $SHARED" >&2
  exit 1
fi

node "${REPO_DIR}/scripts/gen-tokens.js" "$SHARED" > "$OUT"
echo "wrote $OUT"
