# Proxmox Storage Crisis - Migration Plan & Analysis

## Critical Issue Discovered
- **Local-LVM Over-allocation**: 402.2GB allocated vs 374.5GB capacity
- **Overallocated by**: 27.7GB 
- **Current usage**: 96.1% (359.8GB used)
- **Free space**: Only 13.7GB remaining
- **Risk**: Imminent storage failure, VM/container creation impossible

## Power Configuration Updates Completed
Successfully updated non-critical stopped containers to onboot=0:
- CT 107 (gotify): onboot=0 ✅
- CT 108 (tandoor): onboot=0 ✅  
- CT 109 (uptimekuma): onboot=0 ✅
- CT 120 (alpine-it-tools): onboot=0 ✅
- CT 126 (vikunja): onboot=0 ✅

## Storage Distribution Analysis
- **local-lvm**: 96.1% full (CRITICAL) - 359.8GB/374.5GB
- **TrueNas_NVMe**: 30.8% used - 297.8GB/965.5GB (667.6GB available)
- **Truenas_jbod**: 5.7% used - 96.3GB/1.7TB (1.6TB available)
- **Target**: TrueNas_NVMe has sufficient capacity for all migrations

## PHASE 1 MIGRATION PLAN (IMMEDIATE - NO DOWNTIME)
**Target**: Migrate 56GB of stopped containers to free critical space

### Containers to Migrate:
1. CT 108 (tandoor): 10GB -> TrueNas_NVMe
2. CT 109 (uptimekuma): 10GB -> TrueNas_NVMe
3. CT 140 (netbox-agent): 8GB -> TrueNas_NVMe
4. CT 129 (gitops-qa): 8GB -> TrueNas_NVMe
5. CT 127 (infisical): 8GB -> TrueNas_NVMe
6. CT 126 (vikunja): 4GB -> TrueNas_NVMe
7. CT 130 (wikijs-integration): 4GB -> TrueNas_NVMe
8. CT 116 (debian): 4GB -> TrueNas_NVMe

### Phase 1 Commands:
```bash
# CT 108 (tandoor) - 10GB
pvesm alloc TrueNas_NVMe 108 vm-108-disk-0 10G
pvesm import TrueNas_NVMe vm-108-disk-0.raw local-lvm:vm-108-disk-0
pct set 108 --rootfs TrueNas_NVMe:vm-108-disk-0
pvesm free local-lvm:vm-108-disk-0

# CT 109 (uptimekuma) - 10GB
pvesm alloc TrueNas_NVMe 109 vm-109-disk-0 10G
pvesm import TrueNas_NVMe vm-109-disk-0.raw local-lvm:vm-109-disk-0
pct set 109 --rootfs TrueNas_NVMe:vm-109-disk-0
pvesm free local-lvm:vm-109-disk-0

# CT 140 (netbox-agent) - 8GB
pvesm alloc TrueNas_NVMe 140 vm-140-disk-0 8G
pvesm import TrueNas_NVMe vm-140-disk-0.raw local-lvm:vm-140-disk-0
pct set 140 --rootfs TrueNas_NVMe:vm-140-disk-0
pvesm free local-lvm:vm-140-disk-0

# CT 129 (gitops-qa) - 8GB
pvesm alloc TrueNas_NVMe 129 vm-129-disk-0 8G
pvesm import TrueNas_NVMe vm-129-disk-0.raw local-lvm:vm-129-disk-0
pct set 129 --rootfs TrueNas_NVMe:vm-129-disk-0
pvesm free local-lvm:vm-129-disk-0

# CT 127 (infisical) - 8GB
pvesm alloc TrueNas_NVMe 127 vm-127-disk-0 8G
pvesm import TrueNas_NVMe vm-127-disk-0.raw local-lvm:vm-127-disk-0
pct set 127 --rootfs TrueNas_NVMe:vm-127-disk-0
pvesm free local-lvm:vm-127-disk-0

# CT 126 (vikunja) - 4GB
pvesm alloc TrueNas_NVMe 126 vm-126-disk-0 4G
pvesm import TrueNas_NVMe vm-126-disk-0.raw local-lvm:vm-126-disk-0
pct set 126 --rootfs TrueNas_NVMe:vm-126-disk-0
pvesm free local-lvm:vm-126-disk-0

# CT 130 (wikijs-integration) - 4GB
pvesm alloc TrueNas_NVMe 130 vm-130-disk-0 4G
pvesm import TrueNas_NVMe vm-130-disk-0.raw local-lvm:vm-130-disk-0
pct set 130 --rootfs TrueNas_NVMe:vm-130-disk-0
pvesm free local-lvm:vm-130-disk-0

# CT 116 (debian) - 4GB
pvesm alloc TrueNas_NVMe 116 vm-116-disk-0 4G
pvesm import TrueNas_NVMe vm-116-disk-0.raw local-lvm:vm-116-disk-0
pct set 116 --rootfs TrueNas_NVMe:vm-116-disk-0
pvesm free local-lvm:vm-116-disk-0
```

**Phase 1 Result**: Usage drops from 96.1% to 81.1%

## PHASE 2 MIGRATION PLAN (REQUIRES DOWNTIME)
**Target**: Migrate large running containers for long-term stability

### High Priority Containers:
1. CT 100 (influxdb): 40GB -> TrueNas_NVMe (HIGH PRIORITY)
2. CT 200 (github-runner): 20GB -> TrueNas_NVMe (HIGH PRIORITY)
3. CT 125 (adguard): 18GB -> TrueNas_NVMe (MEDIUM PRIORITY)

### Phase 2 Commands:
```bash
# CT 100 (influxdb) - 40GB
pct stop 100
pvesm alloc TrueNas_NVMe 100 vm-100-disk-0 40G
dd if=/dev/pve/vm-100-disk-0 | ssh 192.168.1.98 "dd of=/mnt/truenas_nvme/images/100/vm-100-disk-0.raw"
pct set 100 --rootfs TrueNas_NVMe:vm-100-disk-0
pct start 100
# After verification: pvesm free local-lvm:vm-100-disk-0

# CT 200 (github-runner) - 20GB
pct stop 200
pvesm alloc TrueNas_NVMe 200 vm-200-disk-0 20G
dd if=/dev/pve/vm-200-disk-0 | ssh 192.168.1.98 "dd of=/mnt/truenas_nvme/images/200/vm-200-disk-0.raw"
pct set 200 --rootfs TrueNas_NVMe:vm-200-disk-0
pct start 200
# After verification: pvesm free local-lvm:vm-200-disk-0

# CT 125 (adguard) - 18GB
pct stop 125
pvesm alloc TrueNas_NVMe 125 vm-125-disk-0 18G
dd if=/dev/pve/vm-125-disk-0 | ssh 192.168.1.98 "dd of=/mnt/truenas_nvme/images/125/vm-125-disk-0.raw"
pct set 125 --rootfs TrueNas_NVMe:vm-125-disk-0
pct start 125
# After verification: pvesm free local-lvm:vm-125-disk-0
```

**Final Result**: Usage drops to 60.3% (134GB total recovery)

## Key Containers to Keep on Local-LVM
- **VM 114 (haos14.0)**: 52GB - Keep for performance (critical system)
- Small essential containers: grafana, nginxproxymanager, cloudflared, etc.

## Storage Capacity Verification
- **TrueNas_NVMe Available**: 667.6GB ✅ SUFFICIENT
- **Total Migration Need**: 134GB
- **Safety Margin**: 533.6GB remaining after migration

## Critical Notes
1. **Execute Phase 1 IMMEDIATELY** - no downtime required
2. Phase 2 requires maintenance window for container stops
3. Verify each migration before freeing source disks
4. Monitor performance after migrations
5. VM 114 (haos14.0) should remain on local-lvm for performance

## Additional Issues Found
- **Old Snapshots**: 2 snapshots on CT 123 (94-125 days old)
- **Old Backups**: 35 backups older than 30 days
- **SDN Error**: Internal network shows error status

## Success Metrics
- **Phase 1**: 96.1% -> 81.1% usage (CRITICAL -> WARNING)
- **Phase 2**: 81.1% -> 60.3% usage (WARNING -> HEALTHY)
- **Total Recovery**: 134GB of local-lvm space