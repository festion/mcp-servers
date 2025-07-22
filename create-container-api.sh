#!/bin/bash

# Create WikiJS Integration Container via Proxmox API
echo "Creating WikiJS Integration Container..."

# Container configuration
VMID=130
HOSTNAME="wikijs-integration"
CORES=2
MEMORY=1024
DISK_SIZE=4
TEMPLATE="debian-12-standard_12.7-1_amd64.tar.zst"
IP="192.168.1.200/24"
GATEWAY="192.168.1.1"
NAMESERVER="192.168.1.1"

# Create container via API
curl -k -X POST "https://192.168.1.137:8006/api2/json/nodes/proxmox/lxc" \
  -H "Authorization: PVEAPIToken=root@pam!test=test-token-for-diagnostic" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "vmid=$VMID" \
  -d "ostemplate=local:vztmpl/$TEMPLATE" \
  -d "hostname=$HOSTNAME" \
  -d "cores=$CORES" \
  -d "memory=$MEMORY" \
  -d "rootfs=local-lvm:$DISK_SIZE" \
  -d "net0=name=eth0,bridge=vmbr0,ip=$IP,gw=$GATEWAY,type=veth" \
  -d "nameserver=$NAMESERVER" \
  -d "tags=gitops;integration;nodejs;wikijs;production" \
  -d "unprivileged=1" \
  -d "start=1"

echo -e "\n\nContainer creation initiated. Checking status..."

# Wait a moment for creation
sleep 5

# Check if container was created
curl -k -s "https://192.168.1.137:8006/api2/json/nodes/proxmox/lxc/$VMID/status/current" \
  -H "Authorization: PVEAPIToken=root@pam!test=test-token-for-diagnostic" | \
  jq -r '.data.status // "not found"'