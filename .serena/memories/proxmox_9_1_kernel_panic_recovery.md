# Proxmox 9.1 Kernel Panic Recovery Guide

## Overview

Some users have reported kernel panic issues after upgrading to Proxmox VE 9.1. This memory documents the symptoms, root causes, and recovery procedures.

## Symptoms

- Kernel panic on boot after upgrading to Proxmox 9.1
- System fails to boot into the new kernel version
- Grub boot issues or missing initramfs

## Common Root Causes

Based on community reports, kernel panics after Proxmox upgrades can be caused by:

1. **Grub/Initramfs Issues**: The grub boot script doesn't generate properly or doesn't include the initrd in grub.cfg during upgrade
2. **ZFS/Docker Conflicts**: Kernel panics with Docker in LXC containers on ZFS 2.0 (livelist feature issues)
3. **Hardware Compatibility**: Issues with specific hardware like Realtek USB NICs or NVMe devices
4. **USB Subsystem**: Page faults in xhci_hcd module during USB control transfers (kernel 6.8.12-9-pve)
5. **Ventoy Installation**: Residual kernel parameters from Ventoy installations causing boot failures

## Recovery Procedure

### Method 1: Boot to Lower Kernel Version via Grub

1. **Access Grub Menu**:
   - Option A: Use the Proxmox ISO to boot the Grub menu
   - Option B: Boot directly to Grub from the root drive
   - Select "Advanced" from the boot menu

2. **Boot into a Lower Kernel Version**

3. **Run Recovery Commands**:
   ```bash
   apt install grub-efi-amd64
   update-initramfs -u -k <Kernel-Version-Update>-pve
   update-grub
   ```

4. **Reboot** the system

### Method 2: Configure Package Manager

If the system is partially accessible, try:
```bash
dpkg --configure -a
```

This can help resolve incomplete package configurations that may prevent proper grub generation.

## Preventive Measures

### Before Upgrading to 9.1:

1. **Document Current Kernel**: Note your current working kernel version
   ```bash
   uname -r
   ```

2. **Ensure Grub is Healthy**:
   ```bash
   apt install --reinstall grub-efi-amd64
   update-grub
   ```

3. **Verify Initramfs**:
   ```bash
   ls -lh /boot/initrd.img-*
   ```

4. **Check for ZFS/Docker Issues** (if applicable):
   - If running Docker in LXC on ZFS, add preventive configuration:
   ```bash
   cat > /etc/modprobe.d/zfs.conf << EOF
   options zfs zfs_livelist_min_percent_shared=100
   EOF
   ```

5. **Enable Serial Console** (optional but helpful for debugging):
   - Edit `/etc/default/grub` and add console parameters for remote debugging

### After Upgrade:

1. **Don't Remove Old Kernels Immediately**: Keep at least 2-3 previous kernel versions until you've verified stability
2. **Monitor System Logs**: Check `journalctl -xe` and `dmesg` for any hardware-related errors
3. **Test HA Functionality**: If using HA clustering, verify proper failover behavior

## Known Working Kernel Versions

- Document your working kernel versions here after successful operation:
  - Current cluster kernels: 6.8.12-5-pve (from your cluster status)

## Additional Resources

- [Proxmox kernel panic forum discussions](https://forum.proxmox.com/tags/kernel-panic/)
- [Proxmox 9 upgrade experiences](https://medium.com/@PlanB./proxmox-9-upgrade-gone-wrong-one-users-kernel-panic-nightmare-028db74383bc)
- [Adventures in upgrading Proxmox](https://blog.vasi.li/adventures-in-upgrading-proxmox/)

## Emergency Boot Options

If you cannot access grub normally:

1. **Boot from Proxmox ISO in rescue mode**
2. **Mount your root filesystem**:
   ```bash
   mount /dev/mapper/pve-root /mnt  # Adjust for your setup
   mount /dev/sda2 /mnt/boot/efi     # Adjust for your EFI partition
   mount --bind /dev /mnt/dev
   mount --bind /proc /mnt/proc
   mount --bind /sys /mnt/sys
   ```

3. **Chroot and repair**:
   ```bash
   chroot /mnt
   apt install grub-efi-amd64
   update-initramfs -u -k all
   update-grub
   exit
   ```

4. **Unmount and reboot**:
   ```bash
   umount /mnt/sys /mnt/proc /mnt/dev /mnt/boot/efi /mnt
   reboot
   ```

## Your Cluster Specifics

- **Current PVE Version**: 9.0 (as of last check)
- **Target Version**: 9.1
- **Active Nodes**: 192.168.1.137, 192.168.1.125, 192.168.1.126
- **HA Status**: Cluster appears healthy with proper quorum

### Upgrade Strategy for Your 3-Node Cluster:

1. **Upgrade one node at a time**
2. **Start with a non-primary node** (192.168.1.125 or 192.168.1.126)
3. **Verify HA migration** works properly before proceeding to next node
4. **Keep SSH access to other nodes** available during the upgrade
5. **Monitor Uptime Kuma** for service availability during the upgrade

## Notes

- Last updated: 2025-11-23
- Issue discovered during planning for 9.1 upgrade
- Recovery procedure confirmed by community reports
