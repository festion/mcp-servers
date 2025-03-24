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
TEMPLATE="local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
STORAGE="local-lvm"  # Ensure this is the correct storage name for your setup
IP="dhcp"
DEFAULT_HOSTNAME="gitops-dashboard"

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
    pveam update && pveam download local debian-12-standard_12.7-1_amd64.tar.zst
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

# Function to detect and update existing container or create a new one
build_or_update_container() {
  echo "Checking if container with hostname $DEFAULT_HOSTNAME exists..."
  CTID=$(pct list | grep $DEFAULT_HOSTNAME | awk '{print $1}')

  if [ -n "$CTID" ]; then
    msg_info "Container with hostname $DEFAULT_HOSTNAME exists. Updating container $CTID..."
    update_container $CTID
  else
    msg_info "No container found with hostname $DEFAULT_HOSTNAME. Creating new container..."
    create_container
  fi
}

# Function to create a new container
create_container() {
  # Automatically get the next available CTID
  CTID=$(($(pvesh get /nodes/$(hostname)/lxc --output-format=json | jq '.[].vmid' | sort -n | tail -1) + 1))

  echo "Creating container with CTID: $CTID"

  pct create $CTID $TEMPLATE \
    --hostname $DEFAULT_HOSTNAME \
    --cores $var_cpu \
    --memory $var_ram \
    --net0 name=eth0,bridge=vmbr0,ip=$IP \
    --rootfs $STORAGE:${var_disk} \
    --unprivileged $var_unprivileged \
    --features nesting=1 \
    --start 1 \
    --onboot 1

  if [ $? -eq 0 ]; then
    msg_ok "Container $CTID created and started"
  else
    msg_error "Failed to create container $CTID"
    exit 1
  fi

  install_dependencies $CTID
}

# Function to update an existing container
update_container() {
  CTID=$1
  msg_info "Updating container $CTID..."
  
  install_dependencies $CTID
}

# Function to install dependencies and setup GitOps Dashboard
install_dependencies() {
  CTID=$1
  msg_info "Installing dependencies inside container $CTID..."

  pct exec $CTID -- bash -c "apt update && apt install -y git curl npm nodejs"
  if [ $? -eq 0 ]; then
    msg_ok "Dependencies installed in container $CTID"
  else
    msg_error "Failed to install dependencies in container $CTID"
    exit 1
  fi

  msg_info "Cloning GitHub repo and building dashboard inside container $CTID..."
  pct exec $CTID -- bash -c "
    rm -rf /opt/gitops && \
    git clone --depth=1 $GIT_REPO /opt/gitops && \
    cd /opt/gitops/dashboard && \
    npm install && npm run build && \
    mkdir -p /var/www/gitops-dashboard && \
    cp -r dist/* /var/www/gitops-dashboard/
  "
  if [ $? -eq 0 ]; then
    msg_ok "Dashboard built and deployed in container $CTID"
  else
    msg_error "Failed to build and deploy the dashboard in container $CTID"
    exit 1
  fi
  get_container_ip
  install_static_server $CTID
}
get_container_ip() {
  # Fetch the container's IP address and filter out the loopback address
  CONTAINER_IP=$(pct exec $CTID -- ip a | grep -oP 'inet \K[\d.]+/24' | grep -v '127.0.0.1')
  if [[ -z "$CONTAINER_IP" ]]; then
    msg_error "Failed to fetch container IP address"
    exit 1
  fi
  # Remove the subnet mask from the IP address
  CONTAINER_IP=${CONTAINER_IP%/*}
  msg_ok "Container IP: $CONTAINER_IP"
}


# Function to install static file server (serve)
install_static_server() {
  CTID=$1
  msg_info "Installing static file server (serve) in container $CTID..."

  pct exec $CTID -- bash -c "npm install -g serve"
  if [ $? -eq 0 ]; then
    msg_ok "Static file server (serve) installed in container $CTID"
  else
    msg_error "Failed to install static file server in container $CTID"
    exit 1
  fi

 #pct exec $CTID -- bash -c "nohup serve -s /var/www/gitops-dashboard -l 8080 &"
  pct exec $CTID -- bash -c "npx serve -s /var/www/gitops-dashboard -l 8080 &"
  if [ $? -eq 0 ]; then
    msg_ok "Static file server started in container $CTID"
  else
    msg_error "Failed to start static file server in container $CTID"
    exit 1
  fi
}

# Main Script Execution
header_info
check_template
build_or_update_container

msg_ok "Provisioning and setup completed successfully!"
echo -e "${INFO}${YW} Access the GitOps Dashboard at: http://$IP:8080${CL}"
