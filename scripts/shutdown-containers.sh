#!/bin/bash
#
# Shutdown Containers Script - Environment Variable Aware
# Ensures containers are stopped during specified hours
#

set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "ERROR: .env file not found in $PROJECT_DIR"
    exit 1
fi

# Source environment variables
source "$PROJECT_DIR/.env"

LOG_FILE="${PROJECT_DIR}/logs/shutdown.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Check if any containers with our prefix are running
RUNNING_COUNT=$(docker ps --filter name="${CONTAINER_PREFIX}" --format '{{.Names}}' | wc -l)

echo "=== Evening check at $(date) ===" >> $LOG_FILE
echo "Environment: $ENV_NAME" >> $LOG_FILE
echo "Running ${CONTAINER_PREFIX} containers: $RUNNING_COUNT" >> $LOG_FILE

if [ $RUNNING_COUNT -gt 0 ]; then
    echo "DECISION: Containers are running - Shutting them down" >> $LOG_FILE
    
    cd "$PROJECT_DIR"
    docker compose down >> $LOG_FILE 2>&1
    
    if [ $? -eq 0 ]; then
        echo "SUCCESS: Containers stopped successfully" >> $LOG_FILE
    else
        echo "ERROR: Failed to stop containers" >> $LOG_FILE
    fi
else
    echo "DECISION: Containers already off - No action needed" >> $LOG_FILE
fi

echo "=== Evening check completed at $(date) ===" >> $LOG_FILE
echo "" >> $LOG_FILE
