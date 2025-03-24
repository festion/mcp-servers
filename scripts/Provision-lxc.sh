#!/usr/bin/env bash

YW=$(echo "eWVz" | base64 --decode)
BL='\033[36m'
GN='\033[1;92m'
RD='\033[01;31m'
YW='\033[33m'
CL='\033[m'

header_info() {
  echo -e "${BL}"
  echo "   _   _       _     _                 _       _             _           _             "
  echo "  | | | |_ __ | |__ (_)_ __ ___   __ _| |_ ___| | ___  _ __ (_) ___  ___| |_ ___  _ __ "
  echo "  | | | | '_ \| '_ \| | '_ \` _ \ / _\` | __/ _ \ |/ _ \| '_ \| |/ _ \\/ __| __/ _ \| '__|"
  echo "  | |_| | |_) | | | | | | | | | | (_| | ||  __/ | (_) | | | | |  __/ (__| || (_) | |   "
  echo "   \___/| .__/|_| |_|_|_| |_| |_|\__,_|\__\___|_|\___/|_| |_|_|\___|\___|\__\___/|_|   "
  echo "        |_|                                                                            "
  echo -e "${CL}"
}

msg_info() {
  echo -e "\n${YW}➡️  $1${CL}"
}

msg_ok() {
  echo -e "${GN}✔️  $1${CL}"
}

msg_error() {
  echo -e "${RD}❌ $1${CL}"
}

header_info

# Prompt for settings
read -p "Container ID (CTID) [default: next available]: " USER_CTID
read -p "Container Hostname [default: gitops-dashboard]: " USER_HOSTNAME
read -p "Disk Size (in GB) [default: 4]: " USER_DISK
read -p "Memory (in MB) [default: 512]: " USER_MEM
read -p "Cores [default: 2]: " USER_CORES

CTID=${USER_CTID:-$(($(pvesh get /nodes/$(hostname)/lxc --output-format=json | jq '.[].vmid' | sort -n | tail -1) + 1))}
HOSTNAME=${USER_HOSTNAME:-gitops-dashboard}
DISK_SIZE=${USER_DISK:-4}
MEMORY=${USER_MEM:-512}
CORES=${USER_CORES:-2}
TEMPLATE=local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst
STORAGE=local-lvm
IP="dhcp"
GIT_REPO="https://github.com/festion/homelab-gitops-auditor.git"

# Ensure template is available
if ! pveam list local | grep -q "debian-12"; then
  msg_info "Downloading Debian 12 template..."
  pveam update && pveam download local debian-12-standard_12.2-1_amd64.tar.zst
  msg_ok "Template downloaded"
fi

msg_info "Creating LXC container $CTID"
pct create $CTID $TEMPLATE \
  --hostname $HOSTNAME \
  --cores $CORES \
  --memory $MEMORY \
  --net0 name=eth0,bridge=vmbr0,ip=$IP \
  --rootfs $STORAGE:${DISK_SIZE}G \
  --unprivileged 1 \
  --features nesting=1 \
  --start 1 \
  --onboot 1
msg_ok "Container $CTID created and started"

# Wait for LXC to be up
sleep 3

msg_info "Installing NodeJS, npm, git, curl inside container..."
pct exec $CTID -- bash -c "apt update && apt install -y git curl npm nodejs"
msg_ok "Dependencies installed"

msg_info "Cloning GitHub repo and building dashboard..."
pct exec $CTID -- bash -c "
  rm -rf /opt/gitops && \
  git clone --depth=1 $GIT_REPO /opt/gitops && \
  cd /opt/gitops/dashboard && \
  npm install && npm run build && \
  mkdir -p /var/www/gitops-dashboard && \
  cp -r dist/* /var/www/gitops-dashboard/
"
msg_ok "Dashboard built and deployed"

msg_info "Installing static file server (serve)..."
pct exec $CTID -- bash -c "npm install -g serve"
pct exec $CTID -- bash -c "nohup serve -s /var/www/gitops-dashboard -l