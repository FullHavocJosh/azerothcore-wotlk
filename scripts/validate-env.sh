#!/bin/bash
set -euo pipefail

# Required environment variables
REQUIRED_VARS=(
    "ENV_NAME"
    "WORLDSERVER_PORT"
    "SOAP_PORT"
    "AUTHSERVER_PORT"
    "CONTAINER_PREFIX"
    "NUMA_NODE"
    "CPUSET_CPUS"
    "REALM_NAME"
    "REALM_ADDRESS"
    "DB_HOST"
    "DB_PORT"
    "MAP_UPDATE_THREADS"
    "THREAD_POOL_SIZE"
    "BOT_UPDATE_INTERVAL"
    "BOT_REACT_DELAY"
)

# Check for .env file
if [ ! -f .env ]; then
    echo "ERROR: .env file not found!"
    exit 1
fi

# Load environment variables
source .env

echo "Validating environment configuration..."
echo ""

ERRORS=0

# Check each required variable
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo "  ✗ Missing required variable: $var"
        ERRORS=$((ERRORS + 1))
    else
        echo "  ✓ $var = ${!var}"
    fi
done

echo ""

if [ $ERRORS -gt 0 ]; then
    echo "ERROR: $ERRORS missing required variables"
    exit 1
else
    echo "✓ All required variables are set"
    exit 0
fi
