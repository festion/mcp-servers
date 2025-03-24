#!/bin/bash

set -e

# Settings
APP_DIR="/opt/homelab-gitops-auditor"
REPO_URL="https://github.com/festion/homelab-gitops-auditor.git"
BRANCH="main"
DASHBOARD_SUBDIR="dashboard"
DEPLOY_DIR="/var/www/gitops-dashboard"

echo "📦 Installing required packages..."
sudo apt update
sudo apt install -y git curl npm nginx

echo "🧹 Cleaning old files..."
sudo rm -rf "$APP_DIR"
sudo rm -rf "$DEPLOY_DIR"

echo "📥 Cloning repository..."
git clone --depth=1 --branch="$BRANCH" "$REPO_URL" "$APP_DIR"

echo "📁 Installing dependencies..."
cd "$APP_DIR/$DASHBOARD_SUBDIR"
npm install

echo "🔨 Building dashboard..."
npm run build

echo "🚚 Deploying to $DEPLOY_DIR"
sudo mkdir -p "$DEPLOY_DIR"
sudo cp -r dist/* "$DEPLOY_DIR"
sudo chown -R www-data:www-data "$DEPLOY_DIR"

echo "🌐 Configuring nginx..."
NGINX_SITE="/etc/nginx/sites-available/gitops-dashboard"
NGINX_LINK="/etc/nginx/sites-enabled/gitops-dashboard"

sudo tee "$NGINX_SITE" > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    root $DEPLOY_DIR;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

sudo ln -sf "$NGINX_SITE" "$NGINX_LINK"
sudo nginx -t && sudo systemctl reload nginx

echo "✅ Deployment complete! Visit: http://<your-lxc-ip>/"
