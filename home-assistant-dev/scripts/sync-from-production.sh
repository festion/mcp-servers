#!/bin/bash
# =============================================================================
# HOME ASSISTANT DEVELOPMENT ENVIRONMENT - SYNC FROM PRODUCTION
# =============================================================================
# Syncs configuration from production Home Assistant to development environment

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}🔄 Sync from Production Home Assistant${NC}"
echo "====================================="

# Change to project directory
cd "$PROJECT_DIR"

# Backup current dev config
BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
echo -e "${YELLOW}📦 Creating backup of current dev config...${NC}"
mkdir -p "$BACKUP_DIR"
cp -r config/ "$BACKUP_DIR/"
echo "Backup saved to: $BACKUP_DIR"

# Sync from production (when network-fs is available)
echo -e "${YELLOW}🔄 Syncing from production (192.168.1.155)...${NC}"
echo "Note: This requires the network-fs MCP server to be running"
echo "      and configured with access to production shares"

# For now, copy from local staging area
echo -e "${YELLOW}📂 Copying from local production config copy...${NC}"
rsync -av --exclude='secrets.yaml' --exclude='home-assistant.log*' --exclude='home-assistant_v2.db*' --exclude='*.log' --exclude='.storage' /home/dev/workspace/home-assistant-config/ ./config/

# Ensure development secrets file exists
if [ ! -f "./config/secrets.yaml" ]; then
    echo -e "${YELLOW}🔐 Creating development secrets file...${NC}"
    cat > "./config/secrets.yaml" << EOF
# Development secrets - safe defaults
db_url: sqlite:////config/home-assistant_v2.db
http_server_host: 0.0.0.0
http_server_port: 8123
http_base_url: http://localhost:8124
dev_mode: true
production_mode: false
hass_token: dev-token-placeholder
EOF
fi

# Remove production-specific files that shouldn't be in dev
echo -e "${YELLOW}🧹 Cleaning development environment...${NC}"
rm -f ./config/home-assistant*.log*
rm -f ./config/home-assistant_v2.db*
rm -f ./config/.storage/core.restore_state
rm -rf ./config/.storage/auth*

echo -e "${GREEN}✅ Sync completed successfully!${NC}"
echo ""
echo "📋 Next steps:"
echo "  1. Review changes: git diff config/"
echo "  2. Test configuration: ./scripts/start-dev.sh"
echo "  3. Check logs: ./scripts/logs-dev.sh -f"
echo ""
echo "🔄 To revert: cp -r $BACKUP_DIR/config/* ./config/"