#!/bin/bash
# =============================================================================
# HOME ASSISTANT DEVELOPMENT ENVIRONMENT - SHELL ACCESS SCRIPT
# =============================================================================
# Provides shell access to the Home Assistant development container

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}🐚 Home Assistant Development Shell${NC}"
echo "=================================="

# Change to project directory
cd "$PROJECT_DIR"

# Check if container is running
if ! docker compose ps | grep -q "Up"; then
    echo -e "${RED}❌ Development container is not running${NC}"
    echo "Start it with: ./scripts/start-dev.sh"
    exit 1
fi

echo -e "${YELLOW}🔗 Connecting to development container...${NC}"
echo "Type 'exit' to return to host shell"
echo ""

# Connect to container shell
docker compose exec homeassistant-dev /bin/bash