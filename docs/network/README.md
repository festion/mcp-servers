# Network Documentation

This directory contains network infrastructure and cluster documentation.

## DNS Infrastructure

- **[AdGuard DNS Update Procedures](./ADGUARD_DNS_UPDATE_PROCEDURES.md)** - Complete guide for managing DNS:
  - Architecture overview (Primary/Secondary/Sync)
  - Standard update procedures (Web UI, API, YAML)
  - Emergency procedures and rollback
  - Common tasks (rewrites, allowlists)
  - Testing workflow for major changes
  - Troubleshooting guide

## Proxmox Cluster Audit Reports

### Latest Audit: 2025-11-09

- **[Proxmox Cluster Audit Report](./proxmox_cluster_audit_2025-11-09.md)** - Comprehensive 13-section audit covering:
  - Node resource analysis and balance
  - Container/VM distribution
  - HA configuration review
  - Single points of failure identification
  - Storage analysis
  - Disaster recovery assessment
  - Risk matrix and recommendations

- **[Quick Action Guide](./proxmox_quick_fixes.md)** - Priority fixes with step-by-step commands:
  - Critical HA enablement (Traefik, Home Assistant, DHCP)
  - Container rebalancing plan
  - Validation checklists

### Key Findings Summary

**Overall Health Score:** 7.2/10 🟡 Good with Improvements Needed

**Critical Issues:**
- 🔴 Traefik (reverse proxy) - No HA, single point of failure
- 🔴 Home Assistant - No HA, single point of failure  
- 🔴 proxmox node overloaded (46% workload, 20% capacity)
- 🔴 TrueNAS single point of failure for all shared storage

**Immediate Actions Required:**
1. Enable HA for Traefik (VMID 110)
2. Enable HA for Home Assistant (VMID 114)
3. Enable HA for DHCP servers (VMID 133, 134)
4. Rebalance 6 containers from proxmox to proxmox2

**Expected Impact:**
- Eliminates 3 of 4 critical SPOFs
- Service availability: 95% → 99.9%
- Node balance: Improved from Poor to Good
