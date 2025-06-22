# Files to be Deleted - Proxmox Agent Migration

This document lists all files from the original `proxmox-agent` project that should be deleted after successful migration to the `proxmox-mcp-server`.

## ⚠️ IMPORTANT NOTICE

**All functionality from the standalone Proxmox agent scripts has been migrated to the new Proxmox MCP Server.**

The standalone scripts are now **DEPRECATED** and should be replaced with the MCP server integration.

## Files to Delete

Please delete the following files and directories from `/mnt/c/GIT/proxmox-agent/`:

### Python Scripts (Deprecated)
- `/mnt/c/GIT/proxmox-agent/proxmox_assessment.py` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/storage_cleanup_analysis.py` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/execute_cleanup.py` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/comprehensive_environment_audit.py` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/high_priority_optimization_implementation.py` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/post_cleanup_verification.py` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/root_filesystem_cleanup.py` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/verify_storage_cleanup.py` ⚠️ **DEPRECATED**

### Shell Scripts (Deprecated)
- `/mnt/c/GIT/proxmox-agent/backup_storage_analysis.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/backup_storage_cleanup.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/cleanup_temp_directories.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/debug_ssh_setup.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/emergency_backup_fix.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/execute_backup_cleanup.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/final_optimization_status.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/fix_proxmox_security_updates.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/fix_proxmox_ssh.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/fix_ssh_key_mismatch.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/fix_ssh_on_server.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/install_missing_optimizations.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/investigate_backup_storage.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/recreate_ssh_access.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/remove_old_backups.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/root_filesystem_cleanup.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/security_updates_setup.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/snapshot_lifecycle_management.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/ssh_key_setup_fix.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/storage_monitoring_setup.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/test_ssh_key_formats.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/troubleshoot_ssh_access.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/verify_and_fix_ssh_keys.sh` ⚠️ **DEPRECATED**
- `/mnt/c/GIT/proxmox-agent/verify_optimizations.sh` ⚠️ **DEPRECATED**

### Data Files (Can be archived)
- `/mnt/c/GIT/proxmox-agent/proxmox_assessment_data.json` 📁 **Archive if needed**
- `/mnt/c/GIT/proxmox-agent/comprehensive_environment_audit.json` 📁 **Archive if needed**
- `/mnt/c/GIT/proxmox-agent/storage_cleanup_analysis.json` 📁 **Archive if needed**
- `/mnt/c/GIT/proxmox-agent/post_cleanup_verification.json` 📁 **Archive if needed**
- `/mnt/c/GIT/proxmox-agent/cleanup_execution_log.json` 📁 **Archive if needed**

### Configuration Files (Can be archived)
- `/mnt/c/GIT/proxmox-agent/requirements.txt` ⚠️ **DEPRECATED** (New one in MCP server)

### Documentation Files (Some can be archived)
- `/mnt/c/GIT/proxmox-agent/ASSESSMENT_REPORT.md` 📁 **Archive if needed**
- `/mnt/c/GIT/proxmox-agent/FINAL_CLEANUP_INSTRUCTIONS.md` 📁 **Archive if needed**
- `/mnt/c/GIT/proxmox-agent/HIGH_PRIORITY_IMPLEMENTATION_GUIDE.md` 📁 **Archive if needed**
- `/mnt/c/GIT/proxmox-agent/OPTIMIZATION_ACTION_PLAN.md` 📁 **Archive if needed**
- `/mnt/c/GIT/proxmox-agent/STORAGE_ANALYSIS_EXPLANATION.md` 📁 **Archive if needed**
- `/mnt/c/GIT/proxmox-agent/STORAGE_CLEANUP_REPORT.md` 📁 **Archive if needed**
- `/mnt/c/GIT/proxmox-agent/EXECUTE_HIGH_PRIORITY_OPTIMIZATIONS.txt` 📁 **Archive if needed**
- `/mnt/c/GIT/proxmox-agent/SSH_KEY_COMMANDS.txt` 📁 **Archive if needed**

### Files to Keep (Updated for MCP integration)
- `/mnt/c/GIT/proxmox-agent/README.md` ✅ **Update with deprecation notice**
- `/mnt/c/GIT/proxmox-agent/CLAUDE.md` ✅ **Keep as project memory**
- `/mnt/c/GIT/proxmox-agent/.gitignore` ✅ **Keep**

## Migration Mapping

| Original Script | New MCP Tool | Status |
|----------------|--------------|--------|
| `proxmox_assessment.py` | `run_health_assessment` | ✅ Migrated |
| `storage_cleanup_analysis.py` | `manage_snapshots`, `optimize_storage` | ✅ Migrated |
| `execute_cleanup.py` | `execute_maintenance` | ✅ Migrated |
| `comprehensive_environment_audit.py` | `get_audit_report` | ✅ Migrated |
| `post_cleanup_verification.py` | `run_health_assessment` | ✅ Migrated |
| `root_filesystem_cleanup.py` | `optimize_storage` | ✅ Migrated |
| `verify_storage_cleanup.py` | `get_storage_status` | ✅ Migrated |
| All other scripts | Various MCP tools | ✅ Migrated |

## How to Use New MCP Server

Instead of running standalone scripts, use Claude with the MCP server:

### Old Way (Deprecated):
```bash
python proxmox_assessment.py
```

### New Way:
```
Ask Claude: "Run a health assessment of my Proxmox environment"
```

### Old Way (Deprecated):
```bash
python storage_cleanup_analysis.py
```

### New Way:
```
Ask Claude: "Analyze snapshots older than 90 days for cleanup"
```

### Old Way (Deprecated):
```bash
python execute_cleanup.py
```

### New Way:
```
Ask Claude: "Execute maintenance tasks including snapshot cleanup"
```

## Deletion Commands

To delete the deprecated files, run these commands:

```bash
cd /mnt/c/GIT/proxmox-agent

# Delete Python scripts
rm -f *.py

# Delete shell scripts  
rm -f *.sh

# Delete data files (archive first if needed)
rm -f *.json

# Delete text documentation (archive first if needed)
rm -f *.txt *.md

# Keep only essential files
# README.md should be updated with deprecation notice
# CLAUDE.md should be kept as project memory
# .gitignore should be kept
```

## Backup Before Deletion

If you want to keep any historical data or documentation, consider creating an archive:

```bash
cd /mnt/c/GIT/proxmox-agent
mkdir ../proxmox-agent-archive
cp *.json *.md *.txt ../proxmox-agent-archive/
# Then proceed with deletion
```

## Post-Migration Verification

After deletion, verify the MCP server works correctly:

1. **Test Configuration:**
   ```bash
   cd /mnt/c/GIT/mcp-servers/proxmox-mcp-server
   proxmox-mcp-server validate-config example_config.json --test-connection
   ```

2. **Test with Claude:**
   - Open Claude Desktop
   - Ask: "Get basic information about my Proxmox system"
   - Verify all tools are working

3. **Test Key Functionality:**
   - System information retrieval
   - Health assessment
   - Storage analysis
   - Resource monitoring

## Support

If you encounter any issues after migration:

1. Check the new MCP server documentation in `/mnt/c/GIT/mcp-servers/proxmox-mcp-server/README.md`
2. Review configuration in `example_config.json`
3. Test connection with `proxmox-mcp-server validate-config --test-connection`

The new MCP server provides all the functionality of the original scripts with enhanced security, better error handling, and seamless Claude integration.