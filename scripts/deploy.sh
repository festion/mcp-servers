#!/bin/bash

# GitOps Dashboard Deployment Script
# Location: homelab-gitops-auditor/scripts/deploy.sh

set -e

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}📦 Building the GitOps Dashboard...${NC}"
cd "$(dirname "$0")/../dashboard"
npm install
npm run build

DEPLOY_PATH="/var/www/gitops-dashboard"

echo -e "${GREEN}🧹 Cleaning old deployed files in $DEPLOY_PATH...${NC}"
sudo rm -rf "$DEPLOY_PATH"/*

echo -e "${GREEN}📂 Copying build to $DEPLOY_PATH...${NC}"
sudo cp -r dist/* "$DEPLOY_PATH/"

echo -e "${GREEN}🔁 Restarting gitops-dashboard service...${NC}"
sudo systemctl restart gitops-dashboard.service

echo -e "${GREEN}✅ Deployment complete!${NC}"
echo -e "➡️  Visit: http://<your-server-ip>:8080"
