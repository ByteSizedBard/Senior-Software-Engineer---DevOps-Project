#!/usr/bin/env bash
set -euo pipefail

# restore.sh - restores a backup produced by backup.sh into a brand-new,
# empty database (so restore is proven independently of the current data),
# then runs a quick verification query.
#
# Part of Almanac. Maintained by ByteSizedBard.
#
# Usage:
#   ./scripts/restore.sh                       # restores the most recent backup
#   ./scripts/restore.sh backups/almanac_XXXX.dump   # restores a specific file

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$ROOT_DIR/backups"

DB_CONTAINER="${DB_CONTAINER:-almanac_db}"
DB_USER="${DB_USER:-app_admin}"
DB_NAME="${DB_NAME:-almanac}"
RESTORE_DB_NAME="${RESTORE_DB_NAME:-almanac_restore_test}"

BACKUP_FILE="${1:-}"
if [[ -z "$BACKUP_FILE" ]]; then
    BACKUP_FILE="$(ls -t "$BACKUP_DIR"/*.dump 2>/dev/null | head -n1 || true)"
    if [[ -z "$BACKUP_FILE" ]]; then
        echo "ERROR: no backup file given and none found in $BACKUP_DIR"
        echo "Usage: ./scripts/restore.sh [path-to-backup.dump]"
        exit 1
    fi
    echo "==> No file specified, using most recent backup: $BACKUP_FILE"
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "ERROR: backup file not found: $BACKUP_FILE"
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo "ERROR: container '${DB_CONTAINER}' is not running. Start it first with:"
    echo "  docker compose up -d"
    exit 1
fi

echo "==> Dropping any previous '${RESTORE_DB_NAME}' test database..."
docker exec -e PGPASSWORD="${PGPASSWORD:-app_password}" "$DB_CONTAINER" \
    psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS ${RESTORE_DB_NAME};"

echo "==> Creating a fresh, empty database '${RESTORE_DB_NAME}'..."
docker exec -e PGPASSWORD="${PGPASSWORD:-app_password}" "$DB_CONTAINER" \
    psql -U "$DB_USER" -d postgres -c "CREATE DATABASE ${RESTORE_DB_NAME};"

echo "==> Restoring '$BACKUP_FILE' into '${RESTORE_DB_NAME}'..."
docker exec -i -e PGPASSWORD="${PGPASSWORD:-app_password}" "$DB_CONTAINER" \
    pg_restore -U "$DB_USER" -d "$RESTORE_DB_NAME" --no-owner --no-privileges < "$BACKUP_FILE"

echo ""
echo "==> Verifying restore..."
BOOKINGS_COUNT=$(docker exec -e PGPASSWORD="${PGPASSWORD:-app_password}" "$DB_CONTAINER" \
    psql -U "$DB_USER" -d "$RESTORE_DB_NAME" -t -A -c "SELECT COUNT(*) FROM hotel_bookings;")
EVENTS_COUNT=$(docker exec -e PGPASSWORD="${PGPASSWORD:-app_password}" "$DB_CONTAINER" \
    psql -U "$DB_USER" -d "$RESTORE_DB_NAME" -t -A -c "SELECT COUNT(*) FROM booking_events;")
INDEX_EXISTS=$(docker exec -e PGPASSWORD="${PGPASSWORD:-app_password}" "$DB_CONTAINER" \
    psql -U "$DB_USER" -d "$RESTORE_DB_NAME" -t -A -c \
    "SELECT COUNT(*) FROM pg_indexes WHERE indexname = 'idx_hotel_bookings_city_created_at';")

echo "    hotel_bookings rows: $BOOKINGS_COUNT"
echo "    booking_events rows: $EVENTS_COUNT"
echo "    optimization index present: $([[ "$INDEX_EXISTS" == "1" ]] && echo yes || echo no)"

if [[ "$BOOKINGS_COUNT" -gt 0 && "$EVENTS_COUNT" -gt 0 && "$INDEX_EXISTS" == "1" ]]; then
    echo ""
    echo "==> RESTORE VERIFIED OK."
    exit 0
else
    echo ""
    echo "==> RESTORE VERIFICATION FAILED - one or more checks returned 0 / missing."
    exit 1
fi
