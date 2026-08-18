#!/usr/bin/env bash
# Push a built collection to R2.
#
# Ordering is the atomicity mechanism: archives first, then the collection's own documents,
# then the root catalog. The root is the only entry point readers have, so it lands last,
# after everything it vouches for. Legs are chained with && so a failed upload stops the
# ones that would reference it.
#
# copy, never sync: a stale extra object under the prefix is harmless, a swept prefix is not.
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"
need rclone jq

: "${TILES_BUCKET:?TILES_BUCKET unset}"
: "${RCLONE_CONFIG_R2_ENDPOINT:?RCLONE_CONFIG_R2_ENDPOINT unset}"
: "${RCLONE_CONFIG_R2_ACCESS_KEY_ID:?RCLONE_CONFIG_R2_ACCESS_KEY_ID unset}"
: "${RCLONE_CONFIG_R2_SECRET_ACCESS_KEY:?RCLONE_CONFIG_R2_SECRET_ACCESS_KEY unset}"

src="$OUT/$SOURCE"
dest="r2:$TILES_BUCKET/charts/$SOURCE"
[ -f "$src/items.json" ] || { echo "nothing built for $SOURCE" >&2; exit 1; }

# Everything except the two documents that advertise it: the per-chart directories, their
# text notes, and the partition file.
rclone copy "$src" "$dest" \
  --exclude 'collection.json' --exclude 'items.json' \
  --retries 5 --transfers 16 --checkers 32 --stats 30s --stats-one-line &&
rclone copyto "$src/items.json" "$dest/items.json" --retries 5 &&
rclone copyto "$src/collection.json" "$dest/collection.json" --retries 5 &&
rclone copyto "$OUT/catalog.json" "r2:$TILES_BUCKET/charts/catalog.json" --retries 5

echo "published $SOURCE to $dest"
