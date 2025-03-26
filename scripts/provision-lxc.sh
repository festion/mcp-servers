#!/bin/bash
set -e

### CONFIG ###
if ! command -v jq >/dev/null; then
  echo "🧰 jq not found. Installing..."
  apt update && apt install -y jq
fi

HOSTNAME="gitops-dashboard"
TEMPLATE="local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
DISK_SIZE="4G"
MEMORY=512
CORES=2
IP="dhcp"
GIT_REPO="https://github.com/festion/homelab-gitops-auditor.git"
SERVICE_PORT=8080

# Find existing CT by hostname
existing_ctid=""
for vmid in $(pct list | awk 'NR>1 {print $1}'); do
    if [[ "$(pct config $vmid | awk '/^hostname:/ {print $2}')" == "$HOSTNAME" ]]; then
        existing_ctid=$vmid
        break
    fi
done

if [ -n "$existing_ctid" ]; then
    echo "✅ Container '$HOSTNAME' exists (CTID: $existing_ctid). Updating..."
    CTID=$existing_ctid
else
    highest=$(pct list | awk 'NR>1 {print $1}' | sort -n | tail -1)
    CTID=$(( highest+1 ))
    echo "📦 Creating LXC $CTID"

    if ! pveam list local | grep -q "debian-12"; then
        pveam update && pveam download local debian-12-standard_12.2-1_amd64.tar.zst
    fi

    pct create $CTID $TEMPLATE \
        --hostname $HOSTNAME \
        --cores $CORES \
        --memory $MEMORY \
        --net0 name=eth0,bridge=vmbr0,ip=$IP \
        --rootfs local-lvm:vm-${CTID}-disk-0,size=${DISK_SIZE} \
        --unprivileged 1 \
        --features nesting=1 \
        --start 1 \
        --onboot 1

    sleep 3
    pct status $CTID | grep -q running || { echo "❌ Failed to start CT $CTID"; exit 1; }
fi

echo "📡 Installing dependencies..."
pct exec $CTID -- bash -lc "apt update && apt install -y git curl npm nodejs python3"

echo "📅 Building dashboard..."
pct exec $CTID -- bash -lc "
  rm -rf /opt/gitops
  git clone --depth=1 $GIT_REPO /opt/gitops
  cd /opt/gitops/dashboard
  npm install && npm run build
  mkdir -p /var/www/gitops-dashboard
  cp -r dist/* /var/www/gitops-dashboard/
"

echo "🚀 Launching HTTP server on port $SERVICE_PORT..."
pct exec $CTID -- bash -lc "nohup python3 -m http.server $SERVICE_PORT --directory /var/www/gitops-dashboard &"

IPADDR=$(pct exec $CTID -- hostname -I | awk '{print $1}')
echo "📂 Served at http://$IPADDR:$SERVICE_PORT/"

sleep 3
status_code=$(curl -s -o /dev/null -w "%{http_code}" http://$IPADDR:$SERVICE_PORT)
if [ "$status_code" -eq 200 ]; then
  echo "✅ Service running (HTTP $status_code)"
else
  echo "⚠️ Service unreachable (HTTP $status_code). Try:"
  echo "    pct exec $CTID -- ss -tulpn | grep :$SERVICE_PORT"
  echo "    curl -I http://$IPADDR:$SERVICE_PORT"
fi

echo "✅ Done — GitOps dashboard live in CT $CTID."
