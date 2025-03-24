#!/bin/bash

set -e

YW=$(echo "eWVz" | base64 --decode)
N="
"
CROSS="❌"
CHECK="✅"
INFO="ℹ️"

header_info() {
  echo -e "\033[1;34m"
  echo "   _   _       _     _                 _       _             _           _             "
  echo "  | | | |_ __ | |__ (_)_ __ ___   __ _| |_ ___| | ___  _ __ (_) ___  ___| |_ ___  _ __ "
  echo "  | | | | '_ \| '_ \| | '_ \` _ \ / _\` | __/ _ \ |/ _ \| '_ \| |/ _ \/ __| __/ _ \| '__|"
  echo "  | |_| | |_) | | | | | | | | | | (_| | ||  __/ | (_) | | | | |  __/ (__| || (_) | |   "
  echo "   \___/| .__/|_| |_|_|_| |_| |_|\__,_|\__\___|_|\___/|_| |_|_|\___|\___|\__\___/|_|   "
  echo "        |_|                                                                            "
  echo -e "\033[0m"
}

header_info

### CONFIG ###
echo -e "$INFO Setting up environment..."
if ! command -v jq >/dev/null; then
  echo "🧰 jq not found. Installing..."
  apt update && apt install -y jq
fi

CTID=$(pvesh get /nodes/$(hostname)/lxc --output-format=json | jq '.[].vmid' | sort -n | tail -1)
CTID=$((CTID + 1))
HOSTNAME=gitops-dashboard
TEMPLATE=local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst
STORAGE=local-lvm
DISK_SIZE=4G
MEMORY=512
CORES=2
IP="dhcp"  # or use static like 192.168.1.120/24,gw=192.168.1.1
GIT_REPO="https://github.com/festion/homelab-gitops-auditor.git"
###

if ! pveam list local | grep -q "debian-12"; then
  echo "❗ Debian 12 template not found. Downloading..."
  pveam update && pveam download local debian-12-standard_12.2-1_amd64.tar.zst
fi

echo -e "$INFO Creating LXC container: $CTID"
pct create $CTID $TEMPLATE \
  --hostname $HOSTNAME \
  --cores $CORES \
  --memory $MEMORY \
  --net0 name=eth0,bridge=vmbr0,ip=$IP \
  --rootfs $STORAGE:$DISK_SIZE \
  --unprivileged 1 \
  --features nesting=1 \
  --start 1 \
  --onboot 1

sleep 3

if ! pct status $CTID | grep -q "running"; then
  echo -e "$CROSS LXC container $CTID failed to start. Aborting."
  exit 1
fi

echo -e "$INFO Installing software inside container $CTID..."
pct exec $CTID -- bash -c "apt update && apt install -y git curl npm nodejs"

echo -e "$INFO Cloning GitHub repo and building dashboard..."
pct exec $CTID -- bash -c "
  rm -rf /opt/gitops && \
  git clone --depth=1 $GIT_REPO /opt/gitops && \
  cd /opt/gitops/dashboard && \
  npm install && npm run build && \
  mkdir -p /var/www/gitops-dashboard && \
  cp -r dist/* /var/www/gitops-dashboard/
"

echo -e "$INFO Installing static server and launching..."
pct exec $CTID -- bash -c "npm install -g serve"
pct exec $CTID -- bash -c "nohup serve -s /var/www/gitops-dashboard -l 80 &"

IPADDR=$(pct exec $CTID -- hostname -I | awk '{print $1}')

echo -e "$CHECK Done! Your GitOps dashboard is now live."
echo -e "$INFO Served from: http://$IPADDR/"
echo -e "$INFO Container ID: $CTID (hostname: $HOSTNAME)"
echo -e "$INFO Reverse proxy this via NPM or similar."
