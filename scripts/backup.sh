#!/usr/bin/env bash
set -euo pipefail

# backup.sh - creates a timestamped dump of the local database running
# via docker-compose.
#
# Part of Almanac. Maintained by ByteSizedBard.
#
# Usage:
#   ./scripts/backup.sh
#
# Output:
#   ./backups/almanac_YYYYMMDD_HHMMSS.dump   (pg_dump custom format)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$ROOT_DIR/backups"

DB_CONTAINER="${DB_CONTAINER:-almanac_db}"
DB_USER="${DB_USER:-app_admin}"
DB_NAME="${DB_NAME:-almanac}"

mkdir -p "$BACKUP_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.dump"

echo "==> Checking that ${DB_CONTAINER} is running..."
if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo "ERROR: container '${DB_CONTAINER}' is not running. Start it first with:"
    echo "  docker compose up -d"
    exit 1
fi

echo "==> Dumping database '${DB_NAME}' from container '${DB_CONTAINER}'..."
# Custom format (-Fc): compressed, and required for restore with pg_restore's
# selective/parallel restore features.
#
# The `if ! ... ; then` wrapper matters here: under `set -e`, a bare
# `pg_dump ... > "$BACKUP_FILE"` that fails would abort the script
# immediately, skipping the empty-file cleanup below and leaving a
# corrupt/partial timestamped dump on disk - one that restore.sh could
# then pick up as the "most recent" backup.
if ! docker exec -e PGPASSWORD="${PGPASSWORD:-app_password}" "$DB_CONTAINER" \
    pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc > "$BACKUP_FILE"; then
    echo "ERROR: pg_dump failed."
    rm -f "$BACKUP_FILE"
    exit 1
fi

if [[ -s "$BACKUP_FILE" ]]; then
    echo "==> Backup written to: $BACKUP_FILE"
    echo "==> Size: $(du -h "$BACKUP_FILE" | cut -f1)"
else
    echo "ERROR: backup file is empty - something went wrong."
    rm -f "$BACKUP_FILE"
    exit 1
fi
