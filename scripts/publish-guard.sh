#!/usr/bin/env bash
# Fails when a tracked file holds a personal marker (home path, device UDID, team ID, real email).
# Patterns: scripts/publish-guard.patterns ("deny" = flag a match, "allow" = drop a flagged match
# that ends with this regex; fake fixture email domains live there).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
p=scripts/publish-guard.patterns
deny=$(mktemp); allow=$(mktemp); trap 'rm -f "$deny" "$allow"' EXIT
awk -F'\t' '$1=="deny"{print $2}' "$p" >"$deny"
awk -F'\t' '$1=="allow"{print $2}' "$p" >"$allow"
hits=$(git grep -I -n -o -E -f "$deny" -- . ":(exclude)$p" | grep -v -E -f "$allow" || true)
if [ -n "$hits" ]; then
  echo "publish guard: personal markers in tracked files:"; echo "$hits"; exit 1
fi
echo "publish guard: clean"
