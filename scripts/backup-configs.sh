#!/bin/bash
#
# Config Backup Script - Environment Variable Aware
# Backs up customized .conf files (gitignored, host-local only) to shared storage
#

set -e # Exit on error

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "ERROR: .env file not found in $PROJECT_DIR"
    exit 1
fi

# Source environment variables
source "$PROJECT_DIR/.env"

# Check if backups are enabled for this environment
if [ "$ENABLE_DB_BACKUPS" != "true" ]; then
    echo "Config backups are disabled for environment: $ENV_NAME"
    echo "Set ENABLE_DB_BACKUPS=true in .env to enable"
    exit 0
fi

# Configuration from environment variables
BACKUP_DIR="${BACKUP_DEST_DIR:-/FastStorage/Shared/Azerothcore}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "========================================="
echo "Starting config backup"
echo "Environment: $ENV_NAME"
echo "Config directory: $PROJECT_DIR/env/dist/etc"
echo "Backup directory: $BACKUP_DIR"
echo "========================================="

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

cd "$PROJECT_DIR"

# Every *.conf file under env/dist/etc is gitignored and host-local only --
# *.conf.dist templates are reproducible from the engine/module source and
# excluded. Discovered dynamically so a newly added module's conf is picked
# up automatically.
mapfile -t CONF_FILES < <(find env/dist/etc -type f -name '*.conf')

if [ ${#CONF_FILES[@]} -eq 0 ]; then
    echo "No .conf files found under env/dist/etc -- nothing to back up"
    exit 0
fi

BACKUP_FILE="$BACKUP_DIR/confs-$TIMESTAMP.tar.gz"

tar -czf "$BACKUP_FILE" "${CONF_FILES[@]}"

if [ $? -eq 0 ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "SUCCESS: Config backup completed at $(date) (Size: $BACKUP_SIZE, ${#CONF_FILES[@]} files)"
else
    echo "ERROR: Failed to back up configs"
    exit 1
fi

echo "========================================="
echo "Config backup completed"
echo "========================================="

# Clean up old backups (keep last 7 days), matching DB backup retention
find "$BACKUP_DIR" -name "confs-*.tar.gz" -type f -mtime +7 -delete 2>/dev/null || true
echo "Old config backups cleaned up (kept last 7 days)"
