#!/usr/bin/env bash

# Source external functions (if any)
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

# Variables
APP="GitOps Dashboard"
var_tags="dashboard"
var_cpu="2"
var_ram="512"
var_disk="4"
var_os="debian"
var_version="12"
var_unprivileged="1"
GIT_REPO="https://github.com/festion/homelab-gitops-auditor.git"
TEMPLATE=local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst
STORAGE=local-lvm
IP="dhcp"

# Function to display header info
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

# Function to display messages
msg_info() {
  echo -e "\n${YW}➡️  $1${CL}"
}

msg_ok() {
  echo -e "${GN}✔️  $1${CL}"
}

msg_error() {
  echo -e "${RD}❌ $1${CL}"
}

# Function to check for existing container
check_container_storage() {
  # Check if template is available
  if ! pveam list local | grep -q "debian-12"; then
    msg_info "Downloading Debian 12 template..."
    pveam update && pveam download local debian-12-standard_12.2-1_amd64.tar.zst
    msg_ok "Template downloaded"
  fi
}

# Function to provision LXC container
build_container() {
  msg_info "Creating LXC container"
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

  pct create $CTID $TEMPLATE \
    --hostname $HOSTNAME \
    --cores $CORES \
    --memory $MEMORY \
    --net0 name=eth0,bridge=vmbr0,ip=$IP \
    --rootfs $STORAGE:${DISK_SIZE}G \
    --unprivileged $var_unprivileged \
    --features nesting=1 \
    --start 1 \
    --onboot 1

  msg_ok "Container $CTID created and started"
}

# Function to install dependencies and setup GitOps Dashboard
install_dependencies() {
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
}

# Function to install static file server (serve)
install_static_server() {
  msg_info "Installing static file server (serve)..."
  pct exec $CTID -- bash -c "npm install -g serve"
  pct exec $CTID -- bash -c "nohup serve -s /var/www/gitops-dashboard -l 8080 &"
  msg_ok "Static file server started"
}

# Function to perform updates if needed
update_dashboard() {
  # Check if the repository has already been cloned and if the dashboard is up to date
  if [ ! -d "/opt/gitops" ]; then
    msg_error "GitOps Dashboard not installed! Please run the provisioning process again."
    exit 1
  fi

  msg_info "Checking for updates in GitHub repository..."
  cd /opt/gitops && git pull
  msg_ok "GitOps Dashboard is up to date"
}

# Main Script Execution
header_info
check_container_storage
build_container
install_dependencies
install_static_server
update_dashboard

msg_ok "Provisioning and setup completed successfully!"
echo -e "${INFO}${YW} Access the GitOps Dashboard at: http://$IP:8080${CL}"
