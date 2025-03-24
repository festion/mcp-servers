#!/bin/bash

set -e

### CONFIG ###
CTID=$(pvesh get /nodes/$(hostname)/lxc | awk '{print $1}' | sort -n | tail -1)
CTID=$((CTID + 1))
HOSTNAME=gitops-dashboard
TEMPLATE=local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst
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

echo "📦 Creating LXC container: $CTID"
pct create $CTID $TEMPLATE \
  --hostname $HOSTNAME \
  --cores $CORES \
  --memory $MEMORY \
  --net0 name=eth0,bridge=vmbr0,ip=$IP \
  --rootfs local-lvm:$DISK_SIZE \
  --unprivileged 1 \
  --features nesting=1 \
  --start 1 \
  --onboot 1

sleep 3

if ! pct status $CTID | grep -q "running"; then
  echo "❌ LXC container $CTID failed to start. Aborting."
  exit 1
fi

echo "📡 Installing software inside the container..."
pct exec $CTID -- bash -c "apt update && apt install -y git curl npm nodejs"

echo "📅 Cloning GitHub repo and building dashboard..."
pct exec $CTID -- bash -c "
  rm -rf /opt/gitops && \
  git clone --depth=1 $GIT_REPO /opt/gitops && \
  cd /opt/gitops/dashboard && \
  npm install && npm run build && \
  mkdir -p /var/www/gitops-dashboard && \
  cp -r dist/* /var/www/gitops-dashboard/
"

echo "🚀 Installing static server and launching on port 80..."
pct exec $CTID -- bash -c "npm install -g serve"
pct exec $CTID -- bash -c "nohup serve -s /var/www/gitops-dashboard -l 80 &"

IPADDR=$(pct exec $CTID -- hostname -I | awk '{print $1}')

echo "✅ Done! Your GitOps dashboard is now live."
echo "📂 Served from: http://$IPADDR/"
echo "🧰 Running in container $CTID. You can reverse proxy this in NPM."
