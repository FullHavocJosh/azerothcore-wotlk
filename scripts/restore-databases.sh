#!/bin/bash
#
# Database Restore Script - Environment Variable Aware
# Restores AzerothCore databases from production backups
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

# Check if restores are enabled for this environment
if [ "$ENABLE_DB_RESTORES" != "true" ]; then
    echo "Database restores are disabled for environment: $ENV_NAME"
    echo "Set ENABLE_DB_RESTORES=true in .env to enable"
    exit 0
fi

# Configuration from environment variables
MYSQL_CONTAINER="${CONTAINER_PREFIX}-database"
BACKUP_DIR="${BACKUP_SOURCE_HOST:-/FastStorage/Shared/Azerothcore}"
LOG_DIR="${BACKUP_DIR}/logs"
LOG_FILE="$LOG_DIR/restore_$(date +%Y%m%d_%H%M%S).log"

# Database list
DATABASES=("acore_auth" "acore_characters" "acore_world")

# Create log directory
mkdir -p "$LOG_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========================================="
log "Starting database restore to $ENV_NAME environment"
log "Container: $MYSQL_CONTAINER"
log "Backup source: $BACKUP_DIR"
log "========================================="

# Function to find the latest backup
find_latest_backup() {
    local db_name=$1
    local latest_backup=$(ls -t "$BACKUP_DIR/${db_name}"-*.sql 2>/dev/null | head -n 1)
    
    if [ -z "$latest_backup" ]; then
        log "ERROR: No backup found for database $db_name"
        return 1
    fi
    
    echo "$latest_backup"
}

# Check if container is running
if ! docker ps -q -f name="$MYSQL_CONTAINER" | grep -q .; then
    log "ERROR: Database container $MYSQL_CONTAINER is not running"
    exit 1
fi

log "Found database container: $MYSQL_CONTAINER"

# Restore each database
for DB in "${DATABASES[@]}"; do
    log "----------------------------------------"
    log "Processing database: $DB"
    
    BACKUP_FILE=$(find_latest_backup "$DB")
    if [ $? -ne 0 ]; then
        log "Skipping $DB due to missing backup"
        continue
    fi
    
    log "Found backup: $BACKUP_FILE"
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "Backup size: $BACKUP_SIZE"
    
    log "Dropping existing database $DB..."
    docker exec -i "$MYSQL_CONTAINER" mysql -u root -p"$DB_PASSWORD" -e "DROP DATABASE IF EXISTS $DB;" 2>&1 | grep -v "Warning" | tee -a "$LOG_FILE"
    
    log "Creating fresh database $DB..."
    docker exec -i "$MYSQL_CONTAINER" mysql -u root -p"$DB_PASSWORD" -e "CREATE DATABASE $DB;" 2>&1 | grep -v "Warning" | tee -a "$LOG_FILE"
    
    log "Restoring $DB from backup..."
    START_TIME=$(date +%s)
    
    cat "$BACKUP_FILE" | docker exec -i "$MYSQL_CONTAINER" mysql -u root -p"$DB_PASSWORD" "$DB" 2>&1 | grep -v "Warning" | tee -a "$LOG_FILE"
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    if [ $? -eq 0 ]; then
        log "SUCCESS: Restored $DB in ${DURATION} seconds"
    else
        log "ERROR: Failed to restore $DB"
        exit 1
    fi
done

log "========================================="
log "Running post-restore transformations..."
log "========================================="

# Step 1: Delete any old TESTRNDBOT accounts (210006-210289 range from previous setup)
log "Step 1: Cleaning up old TESTRNDBOT accounts from previous setup..."

docker exec -i "$MYSQL_CONTAINER" mysql -u root -p"$DB_PASSWORD" << 'SQL_EOF' 2>&1 | grep -v "Warning" | tee -a "$LOG_FILE"
SET FOREIGN_KEY_CHECKS=0;

-- Delete old TESTRNDBOT account range (210006-210289) and their characters
DELETE FROM acore_characters.characters WHERE account BETWEEN 210006 AND 210289;
DELETE FROM acore_characters.character_achievement WHERE guid NOT IN (SELECT guid FROM acore_characters.characters);
DELETE FROM acore_characters.character_action WHERE guid NOT IN (SELECT guid FROM acore_characters.characters);
DELETE FROM acore_characters.character_inventory WHERE guid NOT IN (SELECT guid FROM acore_characters.characters);
DELETE FROM acore_auth.realmcharacters WHERE acctid BETWEEN 210006 AND 210289;
DELETE FROM acore_auth.account WHERE id BETWEEN 210006 AND 210289;

SELECT CONCAT('Deleted old TESTRNDBOT accounts (210006-210289): ', ROW_COUNT(), ' accounts') as status;

SET FOREIGN_KEY_CHECKS=1;
SQL_EOF

if [ $? -ne 0 ]; then
    log "ERROR: Failed to clean up old TESTRNDBOT accounts"
    exit 1
fi

log "SUCCESS: Old TESTRNDBOT accounts cleaned up"

# Step 2: Rename RNDBOT accounts to TESTRNDBOT
log "Step 2: Renaming RNDBOT accounts to TESTRNDBOT..."

docker exec -i "$MYSQL_CONTAINER" mysql -u root -p"$DB_PASSWORD" << 'SQL_EOF' 2>&1 | grep -v "Warning" | tee -a "$LOG_FILE"
USE acore_auth;

SET FOREIGN_KEY_CHECKS=0;

SELECT 'Before transformation:' as status;
SELECT 
    COUNT(*) as total_accounts,
    SUM(CASE WHEN UPPER(username) LIKE 'RNDBOT%' THEN 1 ELSE 0 END) as rndbot_count,
    SUM(CASE WHEN UPPER(username) LIKE 'TESTRNDBOT%' THEN 1 ELSE 0 END) as testrndbot_count
FROM account;

-- Rename RNDBOT to TESTRNDBOT
UPDATE account 
SET username = CONCAT('TESTRNDBOT', SUBSTRING(username, 7))
WHERE UPPER(username) LIKE 'RNDBOT%';

SELECT 'After transformation:' as status;
SELECT 
    COUNT(*) as total_accounts,
    SUM(CASE WHEN UPPER(username) LIKE 'RNDBOT%' THEN 1 ELSE 0 END) as rndbot_count,
    SUM(CASE WHEN UPPER(username) LIKE 'TESTRNDBOT%' THEN 1 ELSE 0 END) as testrndbot_count
FROM account;

SET FOREIGN_KEY_CHECKS=1;
SQL_EOF

if [ $? -ne 0 ]; then
    log "ERROR: Failed to rename RNDBOT accounts"
    exit 1
fi

log "SUCCESS: RNDBOT accounts renamed to TESTRNDBOT"

# Step 3: Register all accounts to realm 2 (testing realm)
log "Step 3: Registering all accounts to realm 2..."

docker exec -i "$MYSQL_CONTAINER" mysql -u root -p"$DB_PASSWORD" << 'SQL_EOF' 2>&1 | grep -v "Warning" | tee -a "$LOG_FILE"
USE acore_auth;

SET FOREIGN_KEY_CHECKS=0;

-- Clear all existing realm registrations for realm 2
DELETE FROM realmcharacters WHERE realmid = 2;

-- Register all accounts (bot and player) to realm 2
INSERT INTO realmcharacters (acctid, realmid, numchars)
SELECT 
    c.account as acctid,
    2 as realmid,
    COUNT(*) as numchars
FROM acore_characters.characters c
INNER JOIN account a ON c.account = a.id
GROUP BY c.account;

SELECT 'Realm registrations for realm 2:' as status;
SELECT 
    COUNT(DISTINCT acctid) as registered_accounts,
    SUM(numchars) as total_characters
FROM realmcharacters
WHERE realmid = 2;

SET FOREIGN_KEY_CHECKS=1;
SQL_EOF

if [ $? -ne 0 ]; then
    log "ERROR: Failed to register accounts to realm 2"
    exit 1
fi

log "SUCCESS: All accounts registered to realm 2"

# Step 4: Clean up orphaned characters
log "Step 4: Cleaning up orphaned characters..."

docker exec -i "$MYSQL_CONTAINER" mysql -u root -p"$DB_PASSWORD" << 'SQL_EOF' 2>&1 | grep -v "Warning" | tee -a "$LOG_FILE"
SET FOREIGN_KEY_CHECKS=0;

-- Delete orphaned characters (no matching account)
DELETE FROM acore_characters.characters
WHERE account NOT IN (SELECT id FROM acore_auth.account);

-- Clean up orphaned character data
DELETE FROM acore_characters.character_achievement  
WHERE guid NOT IN (SELECT guid FROM acore_characters.characters);

DELETE FROM acore_characters.character_action
WHERE guid NOT IN (SELECT guid FROM acore_characters.characters);

DELETE FROM acore_characters.character_inventory
WHERE guid NOT IN (SELECT guid FROM acore_characters.characters);

SELECT 'Final character count:' as status;
SELECT COUNT(*) as total_characters FROM acore_characters.characters;

SET FOREIGN_KEY_CHECKS=1;
SQL_EOF

if [ $? -ne 0 ]; then
    log "ERROR: Failed to clean up orphaned characters"
    exit 1
fi

log "SUCCESS: Orphaned characters cleaned up"

log "========================================="
log "Database restore completed successfully"
log "========================================="

# Display summary
log ""
log "Summary of restored databases:"
for DB in "${DATABASES[@]}"; do
    BACKUP_FILE=$(find_latest_backup "$DB")
    BACKUP_DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$BACKUP_FILE" 2>/dev/null || stat -c "%y" "$BACKUP_FILE" 2>/dev/null | cut -d'.' -f1)
    log "  - $DB: Restored from backup dated $BACKUP_DATE"
done

log ""
log "Post-restore transformations completed:"
log "  - Old TESTRNDBOT accounts (210006-210289) deleted"
log "  - All RNDBOT accounts renamed to TESTRNDBOT"
log "  - All accounts registered to testing realm (realmid = 2)"
log "  - Orphaned characters cleaned up"

log ""
log "Log file: $LOG_FILE"
