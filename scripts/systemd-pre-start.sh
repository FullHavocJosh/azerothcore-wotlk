#!/bin/bash
set -e

cd /root/azerothcore-wotlk

# Source environment file
if [ -f .env ]; then
  source .env
else
  echo ERROR: .env file not found
  exit 1
fi

echo Environment: ENV_NAME=
echo Database restore enabled: ENABLE_DB_RESTORES=

# Run database restore if enabled
if [ "${ENABLE_DB_RESTORES}" = "true" ]; then
  echo "Running database restore..."
  /root/azerothcore-wotlk/scripts/restore-databases.sh
else
  echo "Database restore disabled (ENABLE_DB_RESTORES=${ENABLE_DB_RESTORES})"
fi
