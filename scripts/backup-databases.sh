#!/bin/bash
#
# Database Backup Script - Environment Variable Aware
# Backs up AzerothCore databases to shared storage
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
    echo "Database backups are disabled for environment: $ENV_NAME"
    echo "Set ENABLE_DB_BACKUPS=true in .env to enable"
    exit 0
fi

# Configuration from environment variables
MYSQL_CONTAINER="${CONTAINER_PREFIX}-database"
BACKUP_DIR="${BACKUP_DEST_DIR:-/FastStorage/Shared/Azerothcore}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Database list
DATABASES=("acore_auth" "acore_characters" "acore_world")

echo "========================================="
echo "Starting database backup"
echo "Environment: $ENV_NAME"
echo "Container: $MYSQL_CONTAINER"
echo "Backup directory: $BACKUP_DIR"
echo "========================================="

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Backup each database
for DB in "${DATABASES[@]}"; do
    echo "Backing up $DB..."
    
    BACKUP_FILE="$BACKUP_DIR/$DB-$TIMESTAMP.sql"
    
    docker exec -i "$MYSQL_CONTAINER" mysqldump -u root -p"$DB_PASSWORD" "$DB" > "$BACKUP_FILE"
    
    if [ $? -eq 0 ]; then
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        echo "SUCCESS: Backup of $DB completed at $(date) (Size: $BACKUP_SIZE)"
    else
        echo "ERROR: Failed to backup $DB"
        exit 1
    fi
done

echo "========================================="
echo "All database backups completed"
echo "========================================="

# Optional: Clean up old backups (keep last 7 days)
find "$BACKUP_DIR" -name "*.sql" -type f -mtime +7 -delete 2>/dev/null || true
echo "Old backups cleaned up (kept last 7 days)"
