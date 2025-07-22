#!/bin/bash
# =============================================================================
# HOME ASSISTANT DEVELOPMENT ENVIRONMENT - LOGS SCRIPT
# =============================================================================
# Shows logs from the Home Assistant development container

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}📋 Home Assistant Development Logs${NC}"
echo "=================================="

# Change to project directory
cd "$PROJECT_DIR"

# Parse command line arguments
FOLLOW=false
TAIL_LINES=50

for arg in "$@"; do
    case $arg in
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        --tail=*)
            TAIL_LINES="${arg#*=}"
            shift
            ;;
        *)
            # Unknown option
            ;;
    esac
done

# Check if container is running
if ! docker compose ps | grep -q "Up"; then
    echo -e "${YELLOW}⚠️  Development container is not running${NC}"
    echo "Start it with: ./scripts/start-dev.sh"
    exit 1
fi

# Show logs
if [ "$FOLLOW" = true ]; then
    echo -e "${YELLOW}📋 Following logs (Ctrl+C to stop)...${NC}"
    docker compose logs -f --tail="$TAIL_LINES"
else
    echo -e "${YELLOW}📋 Showing last $TAIL_LINES lines...${NC}"
    docker compose logs --tail="$TAIL_LINES"
fi