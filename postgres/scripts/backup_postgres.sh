#!/bin/bash
# Runs via cron: 0 2 * * * /opt/pingtower/scripts/backup_postgres.sh >> /var/log/pingtower-backup.log 2>&1
set -euo pipefail

ENV_FILE="${ENV_FILE:-/opt/pingtower/.env}"
if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
fi

: "${POSTGRES_USER:?POSTGRES_USER not set}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD not set}"
: "${S3_BUCKET:?S3_BUCKET not set}"

DATE=$(date +%Y%m%d_%H%M%S)
DATEPATH=$(date +%Y/%m/%d)
FILENAME="pingtower_db_${DATE}.dump"
S3_KEY="postgres/${DATEPATH}/${FILENAME}"
TMP="/tmp/${FILENAME}"

log() { echo "[$(date -Iseconds)] $*"; }

log "START backup_postgres"

docker exec postgres pg_dump \
  -U "$POSTGRES_USER" \
  -d pingtower_db \
  -F c \
  -Z 9 \
  -f "/tmp/${FILENAME}"

docker cp "postgres:/tmp/${FILENAME}" "$TMP"
docker exec postgres rm "/tmp/${FILENAME}"

log "Dump created: $(du -sh "$TMP" | cut -f1)"

aws s3 cp "$TMP" "s3://${S3_BUCKET}/${S3_KEY}" \
  --storage-class STANDARD_IA \
  --only-show-errors

rm "$TMP"

log "OK: s3://${S3_BUCKET}/${S3_KEY}"