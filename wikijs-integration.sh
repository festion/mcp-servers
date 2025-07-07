#!/usr/bin/env bash

# Copyright (c) 2024 homelab-gitops-auditor
# Author: Claude Code
# License: MIT
# https://github.com/homelab-gitops-auditor/community-scripts

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl sudo mc git
msg_ok "Installed Dependencies"

msg_info "Installing Node.js"
$STD bash <(curl -fsSL https://deb.nodesource.com/setup_20.x)
$STD apt-get install -y nodejs
msg_ok "Installed Node.js"

msg_info "Installing PM2"
$STD npm install -g pm2
msg_ok "Installed PM2"

msg_info "Creating wikijs-integration user"
useradd -r -s /bin/bash -d /opt/wikijs-integration wikijs-integration
mkdir -p /opt/wikijs-integration
chown -R wikijs-integration:wikijs-integration /opt/wikijs-integration
msg_ok "Created wikijs-integration user"

msg_info "Setting up WikiJS Integration Service"
cd /opt/wikijs-integration

# Clone the homelab-gitops-auditor repository
sudo -u wikijs-integration git clone https://github.com/homelab-gitops-auditor/homelab-gitops-auditor.git .

# Install Node.js dependencies
sudo -u wikijs-integration npm install

# Create production configuration
cat > /opt/wikijs-integration/production.env << EOF
NODE_ENV=production
PORT=3001
WIKIJS_URL=http://192.168.1.90:3000
WIKIJS_TOKEN=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhcGkiOjIsImdycCI6MSwiaWF0IjoxNzUwNjg5NzQ0LCJleHAiOjE3NTMyODE3NDQsImF1ZCI6InVybjp3aWtpLmpzIiwiaXNzIjoidXJuOndpa2kuanMifQ.rcGzUI_zmRmFhin90HM2BuB6n4CcCUYY2kHBL7aYg2C114U1GkAD_UHIEmo-6lH-qFESgh34MBTs_6-WUCxDQIg-Y2rPeKZqY8nnFrwrrFwXu6s3cyomHw4QclHWa1_OKs0BCausZWYWkgLagELx3WNw42Zs8YqH0yfjYqNQFy-Vh1jAphtoloFtKRZ0DIWSYE-oxwDywu3Qkh5XFIf0hZKOAu3XKD8da0G3WFpw4JB9v7ubHYNHJBdzp8RpLov-f6Xh5AYGuel1N4PCIbVRegpCKUVbHwZgYHrkTWwae-8D_9tphg1zAbGoQQ2bU-IPsFfcyFg8RDYViJiH2qaL0g
GITHUB_PERSONAL_ACCESS_TOKEN=ghp_test_token_for_diagnostic_purposes_only
DEBUG_WIKI_AGENT=true
EOF

chown wikijs-integration:wikijs-integration /opt/wikijs-integration/production.env
chmod 600 /opt/wikijs-integration/production.env

# Create PM2 ecosystem file
cat > /opt/wikijs-integration/ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'wikijs-integration',
    script: './api/server-mcp.js',
    cwd: '/opt/wikijs-integration',
    user: 'wikijs-integration',
    env_file: '/opt/wikijs-integration/production.env',
    instances: 1,
    exec_mode: 'fork',
    watch: false,
    max_memory_restart: '512M',
    error_file: '/var/log/wikijs-integration/error.log',
    out_file: '/var/log/wikijs-integration/out.log',
    log_file: '/var/log/wikijs-integration/combined.log',
    time: true,
    restart_delay: 5000,
    max_restarts: 10,
    min_uptime: '10s'
  }]
};
EOF

chown wikijs-integration:wikijs-integration /opt/wikijs-integration/ecosystem.config.js

# Create log directory
mkdir -p /var/log/wikijs-integration
chown wikijs-integration:wikijs-integration /var/log/wikijs-integration

# Start service with PM2
sudo -u wikijs-integration pm2 start /opt/wikijs-integration/ecosystem.config.js
sudo -u wikijs-integration pm2 save
msg_ok "Set up WikiJS Integration Service"

msg_info "Creating systemd service"
cat > /etc/systemd/system/wikijs-integration.service << EOF
[Unit]
Description=WikiJS Integration Service
After=network.target

[Service]
Type=forking
User=wikijs-integration
WorkingDirectory=/opt/wikijs-integration
ExecStart=/usr/bin/pm2 start ecosystem.config.js --no-daemon
ExecReload=/usr/bin/pm2 reload ecosystem.config.js
ExecStop=/usr/bin/pm2 stop ecosystem.config.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable wikijs-integration
systemctl start wikijs-integration
msg_ok "Created systemd service"

msg_info "Installing SQLite"
$STD apt-get install -y sqlite3
msg_ok "Installed SQLite"

msg_info "Setting up WikiJS Integration Database"
sudo -u wikijs-integration sqlite3 /opt/wikijs-integration/wiki-agent.db "PRAGMA user_version = 1;"
msg_ok "Set up WikiJS Integration Database"

msg_info "Installing nginx"
$STD apt-get install -y nginx
msg_ok "Installed nginx"

msg_info "Configuring nginx reverse proxy"
cat > /etc/nginx/sites-available/wikijs-integration << EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

ln -sf /etc/nginx/sites-available/wikijs-integration /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl enable nginx
systemctl restart nginx
msg_ok "Configured nginx reverse proxy"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"