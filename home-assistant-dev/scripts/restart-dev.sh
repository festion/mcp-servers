#!/bin/bash
# =============================================================================
# HOME ASSISTANT DEVELOPMENT ENVIRONMENT - RESTART SCRIPT
# =============================================================================
# Restarts the Home Assistant development container

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${YELLOW}🔄 Restarting Home Assistant Development Environment${NC}"
echo "=================================================="

# Change to project directory
cd "$PROJECT_DIR"

# Restart the development environment
echo -e "${YELLOW}🔄 Restarting container...${NC}"
docker compose restart

# Wait for container to be ready
echo -e "${YELLOW}⏳ Waiting for Home Assistant to restart...${NC}"
sleep 15

# Check if container is running
if docker compose ps | grep -q "Up"; then
    echo -e "${GREEN}✅ Development environment restarted successfully!${NC}"
    echo ""
    echo "🌐 Home Assistant Dev URL: http://localhost:8124"
    echo "📊 Container Status:"
    docker compose ps
else
    echo -e "${RED}❌ Failed to restart development environment${NC}"
    echo "Check logs with: ./scripts/logs-dev.sh"
    exit 1
fi