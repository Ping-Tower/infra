#!/bin/bash
# Usage: restore_postgres.sh <s3-key-or-local-path>
# Example: restore_postgres.sh postgres/2025/06/10/pingtower_db_20250610_020001.dump
# Example: restore_postgres.sh /tmp/pingtower_db_20250610_020001.dump
set -euo pipefail

ENV_FILE="${ENV_FILE:-/opt/pingtower/.env}"
if [[ -f "$ENV_FILE" ]]; then

  source "$ENV_FILE"
fi

: "${POSTGRES_USER:?POSTGRES_USER not set}"
: "${S3_BUCKET:?S3_BUCKET not set}"

SOURCE="${1:?Usage: $0 <s3-key-or-local-path>}"
TMP="/tmp/restore_$(date +%Y%m%d_%H%M%S).dump"

log() { echo "[$(date -Iseconds)] $*"; }

if [[ "$SOURCE" != /* ]]; then
  log "Downloading s3://${S3_BUCKET}/${SOURCE}"
  aws s3 cp "s3://${S3_BUCKET}/${SOURCE}" "$TMP"
else
  TMP="$SOURCE"
fi

log "Restoring from: $TMP"

read -rp "This will DROP and recreate pingtower_db. Continue? [yes/N] " CONFIRM
[[ "$CONFIRM" == "yes" ]] || { echo "Aborted."; exit 1; }

docker cp "$TMP" postgres:/tmp/restore.dump
docker exec postgres pg_restore \
  -U "$POSTGRES_USER" \
  --clean \
  --if-exists \
  -d pingtower_db \
  /tmp/restore.dump
docker exec postgres rm /tmp/restore.dump

[[ "$TMP" == /tmp/restore_* ]] && rm "$TMP"

log "Restore complete."