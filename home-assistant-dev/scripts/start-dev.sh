#!/bin/bash
# =============================================================================
# HOME ASSISTANT DEVELOPMENT ENVIRONMENT - START SCRIPT
# =============================================================================
# Starts the Home Assistant development Docker container
#
# Usage: ./start-dev.sh [OPTIONS]
# Options:
#   --rebuild    Force rebuild the container
#   --logs       Follow logs after starting
#   --clean      Clean start (remove existing container/volumes)

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}🏠 Home Assistant Development Environment${NC}"
echo "=================================="

# Parse command line arguments
REBUILD=false
FOLLOW_LOGS=false
CLEAN_START=false

for arg in "$@"; do
    case $arg in
        --rebuild)
            REBUILD=true
            shift
            ;;
        --logs)
            FOLLOW_LOGS=true
            shift
            ;;
        --clean)
            CLEAN_START=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            echo "Usage: $0 [--rebuild] [--logs] [--clean]"
            exit 1
            ;;
    esac
done

# Change to project directory
cd "$PROJECT_DIR"

# Clean start if requested
if [ "$CLEAN_START" = true ]; then
    echo -e "${YELLOW}🧹 Cleaning existing containers and volumes...${NC}"
    docker compose down -v --remove-orphans 2>/dev/null || true
    docker volume prune -f 2>/dev/null || true
fi

# Stop existing container if running
echo -e "${YELLOW}🛑 Stopping existing development container...${NC}"
docker compose down 2>/dev/null || true

# Pull latest image if rebuild requested
if [ "$REBUILD" = true ]; then
    echo -e "${YELLOW}🔄 Pulling latest Home Assistant image...${NC}"
    docker compose pull
fi

# Ensure config directory has correct permissions
echo -e "${YELLOW}🔐 Setting permissions on config directory...${NC}"
chmod -R 755 config/
find config/ -type f -name "*.yaml" -exec chmod 644 {} \;

# Start the development environment
echo -e "${GREEN}🚀 Starting Home Assistant development environment...${NC}"
docker compose up -d

# Wait for container to be ready
echo -e "${YELLOW}⏳ Waiting for Home Assistant to start...${NC}"
sleep 10

# Check if container is running
if docker compose ps | grep -q "Up"; then
    echo -e "${GREEN}✅ Development environment started successfully!${NC}"
    echo ""
    echo "🌐 Home Assistant Dev URL: http://localhost:8124"
    echo "📊 Container Status:"
    docker compose ps
    echo ""
    echo "📋 Useful commands:"
    echo "  View logs:     ./scripts/logs-dev.sh"
    echo "  Stop:          ./scripts/stop-dev.sh"
    echo "  Restart:       ./scripts/restart-dev.sh"
    echo "  Shell access:  ./scripts/shell-dev.sh"
    echo ""
    
    # Follow logs if requested
    if [ "$FOLLOW_LOGS" = true ]; then
        echo -e "${YELLOW}📋 Following logs (Ctrl+C to stop)...${NC}"
        docker compose logs -f
    fi
else
    echo -e "${RED}❌ Failed to start development environment${NC}"
    echo "Check logs with: docker compose logs"
    exit 1
fi