#!/bin/bash
set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for .env file
if [ ! -f .env ]; then
    echo -e "${RED}ERROR: .env file not found!${NC}"
    echo ""
    echo "Please create .env by copying the appropriate environment file:"
    echo "  Production: cp .env.production .env"
    echo "  Testing:    cp .env.testing .env"
    echo ""
    echo "Or create a symlink:"
    echo "  ln -s .env.testing .env"
    exit 1
fi

# Load environment variables
source .env
export $(grep -v '^#' .env | xargs)

echo -e "${GREEN}Generating configuration files for environment: ${ENV_NAME}${NC}"
echo ""

# Create output directory
mkdir -p config/generated

# Check if envsubst is available
if ! command -v envsubst &> /dev/null; then
    echo -e "${RED}ERROR: envsubst not found!${NC}"
    echo "Please install gettext-base: apt-get install gettext-base"
    exit 1
fi

# Generate docker-compose.override.yml
if [ -f docker-compose.override.yml.template ]; then
    echo "  → docker-compose.override.yml"
    envsubst < docker-compose.override.yml.template > docker-compose.override.yml
fi

echo ""
echo -e "${GREEN}✓ Configuration files generated successfully${NC}"
echo ""
echo "Generated files:"
echo "  - docker-compose.override.yml"
echo ""
echo "Next steps:"
echo "  1. Review generated configs in config/generated/"
echo "  2. Run: docker compose up -d"
echo "  3. Or use: make up"
