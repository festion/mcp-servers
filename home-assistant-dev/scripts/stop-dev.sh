#!/bin/bash
# =============================================================================
# HOME ASSISTANT DEVELOPMENT ENVIRONMENT - STOP SCRIPT
# =============================================================================
# Stops the Home Assistant development Docker container

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${YELLOW}🛑 Stopping Home Assistant Development Environment${NC}"
echo "=================================================="

# Change to project directory
cd "$PROJECT_DIR"

# Stop the development environment
echo -e "${YELLOW}🔄 Stopping containers...${NC}"
docker compose down

echo -e "${GREEN}✅ Development environment stopped successfully!${NC}"
echo ""
echo "📋 To start again: ./scripts/start-dev.sh"