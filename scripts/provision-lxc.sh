#!/usr/bin/env bash

set -e

YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
BFR="\r\033[K"
HOLD="-"

header_info() {
  echo -e "${BL}"
  echo -e "   _   _       _     _                 _       _             _           _             "
  echo -e "  | | | |_ __ | |__ (_)_ __ ___   __ _| |_ ___| | ___  _ __ (_) ___  ___| |_ ___  _ __ "
  echo -e "  | | | | '_ \| '_ \| | '_ ` _ \ / _\ | __/ _ \ |/ _ \| '_ \| |/ _ \/ __| __/ _ \| '__|"
  echo -e "  | |_| | |_) | | | | | | | | | | (_| | ||  __/ | (_) | | | | |  __/ (__| || (_) | |   "
  echo -e "   \___/| .__/|_| |_|_|_| |_| |_|\__,_|\__\___|_|\___/|_| |_|_|\___|\___|\__\___/|_|   "
  echo -e "        |_|                                                                        "
  echo -e "${CL}"
}

header_info

echo -e "${YW}ℹ️  Setting up environment...${CL}"

# Ensure dependencies
if ! command -v jq &> /dev/null; then
  echo -e "${YW}🧰 jq not found. Installing...${CL}"
  apt update && apt install -y jq
fi

# Container settings
CTID=$(pvesh get /cluster/nextid)
HOSTNAME=gitops-dashboard
DISK_SIZE=4G
CPU_CORES=2
RAM_SIZE=2048
PORT=${GITOPS_PORT:-8888}  # Allow configurable port via env var

# Determine valid storage (prefer lvmthin)
VALID_STORAGE=$(pvesm status | awk '$2 == "lvmthin" {print $1}' | head -n1)

if [[ -z "$VALID_STORAGE" ]]; then
  echo -e "${RD}❌ No valid lvmthin storage found that supports container rootfs.${CL}"
  echo -e "${YW}💡 Tip: Make sure you have 'local-lvm' or similar configured for LXC rootfs.${CL}"
  exit 1
fi

TEMPLATE_PATH="/var/lib/vz/template/cache/debian-12-standard_12.2-1_amd64.tar.zst"

# Download template if not exists
if [ ! -f "$TEMPLATE_PATH" ]; then
  echo -e "${YW}⬇️  Downloading Debian 12 LXC template...${CL}"
  pveam update && pveam download $VALID_STORAGE debian-12-standard_12.2-1_amd64.tar.zst
fi

# Create the container
echo -e "${YW}ℹ️  Creating LXC container: ${CTID}${CL}"
pct create $CTID $TEMPLATE_PATH \
  -hostname $HOSTNAME \
  -storage $VALID_STORAGE \
  -rootfs ${VALID_STORAGE}:${DISK_SIZE} \
  -cores $CPU_CORES \
  -memory $RAM_SIZE \
  -net0 name=eth0,bridge=vmbr0,ip=dhcp \
  -features nesting=1 \
  -unprivileged 1 \
  -ostype debian

# Start the container
pct start $CTID
sleep 5

# Provision inside container
pct exec $CTID -- bash -c "apt update && \
  echo '➡️  Installing dependencies...' && \
  apt install -y curl git nodejs npm && \
  echo '✔️  Dependencies installed' && \
  echo '➡️  Cloning GitHub repo and building dashboard...' && \
  git clone https://github.com/festion/homelab-gitops-auditor /opt/gitops && \
  cd /opt/gitops/dashboard && \
  npm install && npm run build && \
  echo '✔️  Dashboard built and deployed' && \
  echo '➡️  Installing static file server (serve)...' && \
  npm install -g serve && \
  echo '✔️  Static file server installed' && \
  echo '➡️  Creating systemd service...' && \
  bash -c 'cat <<SERVICE > /etc/systemd/system/gitops-dashboard.service
[Unit]
Description=GitOps Dashboard Static Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/gitops/dashboard/dist
ExecStart=/usr/bin/serve -s . -l ${PORT}
Restart=always
User=root

[Install]
WantedBy=multi-user.target
SERVICE' && \
  systemctl enable gitops-dashboard.service && \
  systemctl start gitops-dashboard.service"

# Get container IP
IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')

echo -e "${GN}✅ GitOps Dashboard is up and running!${CL}"
echo -e "${BGN}🔗 http://$IP:$PORT ${CL}"
