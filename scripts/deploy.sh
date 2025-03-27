#!/usr/bin/env bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Resolve script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/..")"
DASHBOARD_DIR="$PROJECT_ROOT/dashboard"
DEPLOY_PATH="/var/www/gitops-dashboard"

echo -e "${GREEN}📦 Building the GitOps Dashboard...${NC}"

# Check if dashboard directory exists
if [ ! -d "$DASHBOARD_DIR" ]; then
  echo -e "${RED}❌ Error: Dashboard directory not found at $DASHBOARD_DIR${NC}"
  exit 1
fi

cd "$DASHBOARD_DIR"
npm install
npm run build

echo -e "${GREEN}🚚 Deploying to $DEPLOY_PATH...${NC}"
mkdir -p "$DEPLOY_PATH"
cp -r dist/* "$DEPLOY_PATH"

echo -e "${GREEN}✅ Deployment complete!${NC}"
