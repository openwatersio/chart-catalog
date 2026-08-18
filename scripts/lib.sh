#!/usr/bin/env bash
# Shared settings and helpers. Source this, don't run it.
set -euo pipefail

WORK="${WORK:-work}"
OUT="${OUT:-out/charts}"
BASE_URL="${BASE_URL:-https://tiles.openwaters.io/charts}"
SOURCE="${SOURCE:-noaa-enc}"
TILE57="${TILE57:-tile57}"
# A source id names a file and an R2 prefix, so keep it to the shape the schema allows.
[[ $SOURCE =~ ^[a-z0-9-]+$ ]] || { echo "invalid source id: $SOURCE" >&2; exit 1; }
# shellcheck disable=SC2034  # used by the scripts that source this
SOURCE_DEF="sources/$SOURCE.json"

need() {
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null || { echo "$cmd is required but not installed" >&2; exit 1; }
  done
}

# GNU coreutils and BSD/macOS disagree on the sha256 command name.
sha256() {
  if command -v sha256sum >/dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi
}
