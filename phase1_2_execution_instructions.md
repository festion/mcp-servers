# Phase 1.2: LVM Auto-Extend Configuration - Execution Instructions

## Current Status
- **Storage Analysis**: COMPLETE ✅
- **Critical Issue Confirmed**: local-lvm at **85.2%** capacity (319GB/374GB)
- **Script Created**: lvm_autoextend_config.sh ready for execution

## Required Actions

### Step 1: Execute Configuration Script on Proxmox Host
The LVM auto-extend configuration must be executed directly on the Proxmox host with root privileges.

**Option A: Direct SSH Access (if available)**
```bash
ssh root@192.168.1.137
# Copy script to Proxmox host, then:
./lvm_autoextend_config.sh
```

**Option B: Copy Script to Proxmox Host**
```bash
# Copy the script to Proxmox (use SCP, web interface, or console)
scp lvm_autoextend_config.sh root@192.168.1.137:/root/

# Then execute on Proxmox host:
ssh root@192.168.1.137 "chmod +x /root/lvm_autoextend_config.sh && /root/lvm_autoextend_config.sh"
```

**Option C: Manual Execution via Proxmox Console**
1. Access Proxmox web interface (https://192.168.1.137:8006)
2. Go to node "proxmox" > Shell
3. Copy and paste the script contents or upload the file
4. Execute: `chmod +x lvm_autoextend_config.sh && ./lvm_autoextend_config.sh`

### Step 2: Verify Configuration
After script execution, verify the following:

1. **Auto-extend settings applied**: Check `/etc/lvm/lvm.conf` contains:
   ```
   thin_pool_autoextend_threshold = 80
   thin_pool_autoextend_percent = 20
   ```

2. **Configuration validated**: Script reports "✓ LVM configuration syntax is valid"

3. **Services reloaded**: LVM services restarted successfully

4. **Backup created**: Backup file `/etc/lvm/lvm.conf.backup.[timestamp]` exists

## What the Script Does

### ✅ Safety Measures
- Creates timestamped backup of `/etc/lvm/lvm.conf`
- Validates configuration syntax before applying
- Automatic rollback on validation failure
- Comprehensive error checking

### ⚙️ Configuration Changes
- **Threshold**: 80% - Auto-extend triggers when thin pool reaches 80% usage
- **Extend Percentage**: 20% - Each auto-extend increases pool size by 20%
- **Location**: Modifies `/etc/lvm/lvm.conf` activation section

### 🔍 Verification Steps
- Checks current thin pool status (`lvs pve/data`)
- Verifies volume group free space availability
- Validates LVM configuration syntax
- Reloads LVM services
- Provides comprehensive status report

## Expected Results

### Before Execution
```
Current Status:
- local-lvm: 85.2% used (319GB/374GB)
- No auto-extend protection
- Risk of allocation failures
```

### After Execution
```
Configured Protection:
- Auto-extend threshold: 80%
- Auto-extend percentage: 20%
- Triggers when: Pool reaches 80% usage
- Increases by: 20% of current size per trigger
```

### Immediate Impact
Since current usage (85.2%) is already above the threshold (80%), auto-extend should attempt to activate immediately if:
1. Volume group has free space
2. Configuration is properly applied

## Manual Verification Commands

After script execution, run these commands on Proxmox host to verify:

```bash
# Check auto-extend settings
grep -A 5 -B 5 "thin_pool_autoextend" /etc/lvm/lvm.conf

# Check thin pool status
lvs pve/data -o name,data_percent,metadata_percent,lv_when_full

# Check volume group free space
vgdisplay pve | grep "Free"

# Monitor for auto-extend events
tail -f /var/log/syslog | grep -i "autoextend\|thin"
```

## Troubleshooting

### If Auto-Extend Doesn't Work
1. **Check Volume Group Space**: Auto-extend requires free physical extents
   ```bash
   vgdisplay pve | grep "Free PE"
   ```
   If "0", add more storage to the volume group

2. **Check Configuration**: Verify settings are in correct section
   ```bash
   lvm config --validate
   ```

3. **Check Services**: Ensure LVM services are running
   ```bash
   systemctl status lvm2-lvmetad
   ```

### Rollback Procedure
If issues occur:
```bash
# Restore original configuration
cp /etc/lvm/lvm.conf.backup.[timestamp] /etc/lvm/lvm.conf
systemctl reload lvm2-lvmetad
```

## Critical Notes

⚠️ **IMMEDIATE ACTION REQUIRED**: Current usage (85.2%) exceeds threshold (80%)
⚠️ **SPACE DEPENDENCY**: Auto-extend requires free space in volume group
⚠️ **BACKUP IMPORTANT**: Script creates automatic backup for safety

## Next Phase
After successful completion of Phase 1.2, proceed to:
**Phase 1.3: Storage Monitoring Setup** - Implement automated alerts and monitoring for storage thresholds.