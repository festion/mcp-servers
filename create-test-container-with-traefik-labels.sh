#!/bin/bash
# Script to create a test container with Traefik plugin auto-discovery
# This demonstrates the hybrid approach for dev/testing containers

set -e

VMID=9999
HOSTNAME="traefik-test"
IP="192.168.1.250"
MEMORY=512
CORES=1
DOMAIN="traefiktest.internal.lakehouse.wtf"

echo "=== Creating Test Container with Traefik Auto-Discovery ==="
echo "VMID: $VMID"
echo "Hostname: $HOSTNAME"
echo "IP: $IP"
echo "Domain: $DOMAIN"
echo ""

# Check if container already exists
if pct status $VMID &>/dev/null; then
    echo "⚠️  Container $VMID already exists!"
    read -p "Do you want to destroy and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopping and destroying container $VMID..."
        pct stop $VMID 2>/dev/null || true
        pct destroy $VMID
    else
        echo "Exiting..."
        exit 1
    fi
fi

# Find available Debian/Ubuntu template
echo "Looking for container template..."
TEMPLATE=$(pveam available | grep -E 'debian-12|ubuntu-24' | head -1 | awk '{print $2}')
if [ -z "$TEMPLATE" ]; then
    echo "❌ No suitable template found. Please download one first:"
    echo "   pveam update"
    echo "   pveam download local debian-12-standard"
    exit 1
fi
echo "Using template: $TEMPLATE"

# Create container
echo "Creating container..."
pct create $VMID local:vztmpl/$TEMPLATE \
    --hostname $HOSTNAME \
    --memory $MEMORY \
    --cores $CORES \
    --net0 name=eth0,bridge=vmbr0,ip=$IP/24,gw=192.168.1.1 \
    --unprivileged 1 \
    --features nesting=1 \
    --onboot 0

# Add Traefik labels to container description
echo "Adding Traefik labels to container description..."
pct set $VMID -description "$(cat <<'LABELS'
Test container for Traefik auto-discovery demonstration

This container is automatically discovered by the traefik-proxmox-provider plugin.
The labels below configure Traefik routing without needing static YAML files.

traefik.enable=true
traefik.http.routers.traefiktest.rule=Host(`traefiktest.internal.lakehouse.wtf`)
traefik.http.routers.traefiktest.entrypoints=websecure
traefik.http.routers.traefiktest.tls.certresolver=cloudflare
traefik.http.services.traefiktest.loadbalancer.server.port=80
LABELS
)"

# Start container
echo "Starting container..."
pct start $VMID

# Wait for container to be ready
echo "Waiting for container to boot..."
sleep 5

# Install nginx
echo "Installing nginx web server..."
pct exec $VMID -- bash -c "
    apt-get update -qq && 
    apt-get install -y -qq nginx &&
    echo '<html><body><h1>Traefik Plugin Auto-Discovery Test</h1><p>This page is served via Traefik auto-discovery!</p><p>Container ID: $VMID</p><p>Domain: $DOMAIN</p></body></html>' > /var/www/html/index.html &&
    systemctl restart nginx
"

echo ""
echo "✅ Test container created successfully!"
echo ""
echo "Container Details:"
echo "  - VMID: $VMID"
echo "  - Hostname: $HOSTNAME"
echo "  - IP: $IP"
echo "  - Domain: https://$DOMAIN"
echo ""
echo "⏱️  The Traefik plugin polls every 30 seconds."
echo "   Wait ~30-60 seconds, then test the route:"
echo ""
echo "   curl -k https://$DOMAIN"
echo ""
echo "Or watch the Traefik logs to see discovery:"
echo "   ssh root@192.168.1.110 'tail -f /var/log/traefik/traefik.log | grep -E \"vmid $VMID|traefiktest\"'"
echo ""
echo "To view container labels:"
echo "   pct config $VMID | grep -A 10 description"
echo ""
echo "To remove the test container:"
echo "   pct stop $VMID && pct destroy $VMID"
echo ""
