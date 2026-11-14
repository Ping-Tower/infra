#!/bin/bash
# Runs via cron: 0 3 * * 0 /opt/pingtower/scripts/backup_clickhouse.sh >> /var/log/pingtower-backup.log 2>&1
set -euo pipefail

ENV_FILE="${ENV_FILE:-/opt/pingtower/.env}"
if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
fi

: "${CLICKHOUSE_USER:?CLICKHOUSE_USER not set}"
: "${CLICKHOUSE_PASSWORD:?CLICKHOUSE_PASSWORD not set}"
: "${S3_BUCKET:?S3_BUCKET not set}"

DATE=$(date +%Y%m%d_%H%M%S)
DATEPATH=$(date +%Y/%m/%d)
FILENAME="server_pings_${DATE}.bin"
S3_KEY="clickhouse/${DATEPATH}/${FILENAME}"
TMP="/tmp/${FILENAME}"

log() { echo "[$(date -Iseconds)] $*"; }

log "START backup_clickhouse"

ROW_COUNT=$(docker exec clickhouse clickhouse-client \
  --user "$CLICKHOUSE_USER" \
  --password "$CLICKHOUSE_PASSWORD" \
  --query "SELECT count() FROM pingtower_analytics.server_pings")

log "Exporting ${ROW_COUNT} rows"

docker exec clickhouse clickhouse-client \
  --user "$CLICKHOUSE_USER" \
  --password "$CLICKHOUSE_PASSWORD" \
  --query "SELECT * FROM pingtower_analytics.server_pings FORMAT Native" \
  > "$TMP"

log "Export done: $(du -sh "$TMP" | cut -f1)"

aws s3 cp "$TMP" "s3://${S3_BUCKET}/${S3_KEY}" \
  --storage-class STANDARD_IA \
  --only-show-errors

rm "$TMP"

log "OK: s3://${S3_BUCKET}/${S3_KEY}"