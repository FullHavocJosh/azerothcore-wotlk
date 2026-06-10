#!/bin/bash
#
# Startup Containers Script - Environment Variable Aware
# Starts containers at boot ONLY during allowed hours
# Runs database restore BEFORE starting containers (if enabled)
# Protection: Only starts if containers are NOT already running
#

set -e

# Wait for system to stabilize
sleep 60

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "ERROR: .env file not found in $PROJECT_DIR"
    exit 1
fi

# Source environment variables
source "$PROJECT_DIR/.env"

LOG_FILE="${PROJECT_DIR}/logs/startup.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Check if containers are already running
RUNNING_COUNT=$(docker ps --filter name="${CONTAINER_PREFIX}" --format '{{.Names}}' | wc -l)

CURRENT_HOUR=$(date +%H)
CURRENT_TIME=$(date)

echo "=== Boot-time check at $CURRENT_TIME ===" >> $LOG_FILE
echo "Environment: $ENV_NAME" >> $LOG_FILE
echo "Current hour: $CURRENT_HOUR" >> $LOG_FILE
echo "Running ${CONTAINER_PREFIX} containers: $RUNNING_COUNT" >> $LOG_FILE

# Protection: Don't restart if already running
if [ $RUNNING_COUNT -gt 0 ]; then
    echo "DECISION: Containers already running - No action needed (protection)" >> $LOG_FILE
    echo "=== Boot-time check completed at $(date) ===" >> $LOG_FILE
    echo "" >> $LOG_FILE
    exit 0
fi

# Check if current hour is between 0-15 (12:01 AM - 3:59 PM)
if [ $CURRENT_HOUR -ge 0 ] && [ $CURRENT_HOUR -le 15 ]; then
    echo "DECISION: Boot time is between 12:01 AM - 3:59 PM AND containers are off - Starting containers" >> $LOG_FILE
    
    # Step 1: Run database restore if enabled
    if [ "$ENABLE_DB_RESTORES" = "true" ]; then
        echo "Step 1: Running database restore (ENABLE_DB_RESTORES=true)..." >> $LOG_FILE
        
        cd "$PROJECT_DIR"
        ./scripts/restore-databases.sh >> $LOG_FILE 2>&1
        
        if [ $? -eq 0 ]; then
            echo "SUCCESS: Database restore completed" >> $LOG_FILE
        else
            echo "ERROR: Database restore failed - Aborting container startup" >> $LOG_FILE
            exit 1
        fi
    else
        echo "Step 1: Skipping database restore (ENABLE_DB_RESTORES=false)" >> $LOG_FILE
    fi
    
    # Step 2: Start containers
    echo "Step 2: Starting containers..." >> $LOG_FILE
    
    cd "$PROJECT_DIR"
    make up >> $LOG_FILE 2>&1
    
    if [ $? -eq 0 ]; then
        echo "SUCCESS: Containers started successfully" >> $LOG_FILE
    else
        echo "ERROR: Failed to start containers" >> $LOG_FILE
        exit 1
    fi
else
    echo "DECISION: Boot time is after 4:00 PM - NOT starting containers" >> $LOG_FILE
fi

echo "=== Boot-time check completed at $(date) ===" >> $LOG_FILE
echo "" >> $LOG_FILE
