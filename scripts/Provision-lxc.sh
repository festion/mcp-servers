#!/bin/bash

set -e

### CONFIG ###
CTID=120
HOSTNAME=gitops-dashboard
TEMPLATE=local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst
DISK_SIZE=4G
MEMORY=512
CORES=2
IP="dhcp"  # or use static like 192.168.1.120/24,gw=192.168.1.1
GIT_REPO="https://github.com/festion/homelab-gitops-auditor.git"
###

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

echo "⏳ Waiting for container to start..."
sleep 5

echo "📡 Installing software inside the container..."
pct exec $CTID -- bash -c "apt update && apt install -y git curl npm"

echo "📅 Cloning GitHub repo and building dashboard..."
pct exec $CTID -- bash -c "
  rm -rf /opt/gitops && \
  git clone --depth=1 $GIT_REPO /opt/gitops && \
  cd /opt/gitops/dashboard && \
  npm install && npm run build && \
  mkdir -p /var/www/gitops-dashboard && \
  cp -r dist/* /var/www/gitops-dashboard/
"

echo "✅ Done! Your GitOps dashboard is now built."
echo "📂 Dashboard files located in: /var/www/gitops-dashboard"
IPADDR=$(pct exec $CTID -- hostname -I | awk '{print $1}')
echo "👉 To expose it, configure a reverse proxy to: http://$IPADDR/"
