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
#TEMPLATE=local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst
TEMPLATE=local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst
STORAGE="local-lvm"  # Ensure this is the correct storage name for your setup
IP="dhcp"

# Function to display header info
header_info() {
  echo -e "${BL}"
  echo "   _   _       _     _                 _       _             _           _             "
  echo "  | | | |_ __ | |__ (_)_ __ ___   __ _| |_ ___| | ___  _ __ (_) ___  ___| |_ ___  _ __ "
  echo "  | | | | '_ \| '_ \| | '_ \` _ \ / _\` | __/ _ \ |/ _ \| '_ \| |/ _ \/ __| __/ _ \| '__|"
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

# Function to check if Debian template is available and download if not
check_template() {
  echo "Checking if Debian 12 template is available..."
  if ! pveam list local | grep -q "debian-12"; then
    msg_info "Debian 12 template not found. Downloading it now..."
    pveam update && pveam download local debian-12-standard_12.2-1_amd64.tar.zst
    if [ $? -eq 0 ]; then
      msg_ok "Template downloaded successfully"
    else
      msg_error "Failed to download template. Exiting..."
      exit 1
    fi
  else
    msg_ok "Debian 12 template already available"
  fi
}

# Function to provision LXC container
build_container() {
  echo "Starting container creation process..."
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

  echo "Provisioning LXC container with the following configuration:"
  echo "CTID: $CTID"
  echo "Hostname: $HOSTNAME"
  echo "Disk Size: $DISK_SIZE GB"
  echo "Memory: $MEMORY MB"
  echo "Cores: $CORES"
  echo "Storage: $STORAGE"

  # Corrected rootfs argument to use storage and disk size correctly
  pct create $CTID $TEMPLATE \
    --hostname $HOSTNAME \
    --cores $CORES \
    --memory $MEMORY \
    --net0 name=eth0,bridge=vmbr0,ip=$IP \
    --rootfs $STORAGE:${DISK_SIZE} \
    --unprivileged $var_unprivileged \
    --features nesting=1 \
    --start 1 \
    --onboot 1

  if [ $? -eq 0 ]; then
    msg_ok "Container $CTID created and started"
  else
    msg_error "Failed to create container $CTID"
  fi
}

# Function to install dependencies and setup GitOps Dashboard
install_dependencies() {
  msg_info "Installing NodeJS, npm, git, curl inside container..."
  pct exec $CTID -- bash -c "apt update && apt install -y git curl npm nodejs xsel"
  if [ $? -eq 0 ]; then
    msg_ok "Dependencies installed"
  else
    msg_error "Failed to install dependencies"
  fi

  msg_info "Cloning GitHub repo and building dashboard..."
  pct exec $CTID -- bash -c "
    rm -rf /opt/gitops && \
    git clone --depth=1 $GIT_REPO /opt/gitops && \
    cd /opt/gitops/dashboard && \
    npm install && npm run build && \
    mkdir -p /var/www/gitops-dashboard && \
    cp -r dist/* /var/www/gitops-dashboard/
  "
  if [ $? -eq 0 ]; then
    msg_ok "Dashboard built and deployed"
  else
    msg_error "Failed to build and deploy the dashboard"
  fi
}

# Function to install static file server (serve)
install_static_server() {
  msg_info "Installing static file server (serve)..."
  pct exec $CTID -- bash -c "npm install -g serve"
  pct exec $CTID -- bash -c "nohup serve -s /var/www/gitops-dashboard -l 8080 &"
  if [ $? -eq 0 ]; then
    msg_ok "Static file server started"
  else
    msg_error "Failed to start static file server"
  fi
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
  if [ $? -eq 0 ]; then
    msg_ok "GitOps Dashboard is up to date"
  else
    msg_error "Failed to update GitOps Dashboard"
  fi
}

# Main Script Execution
header_info
check_template
build_container
install_dependencies
install_static_server
update_dashboard

msg_ok "Provisioning and setup completed successfully!"
echo -e "${INFO}${YW} Access the GitOps Dashboard at: http://$IP:8080${CL}"
