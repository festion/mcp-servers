# New Home Assistant Development Workflow
**Effective Date**: 2025-06-30  
**Purpose**: Modern containerized development approach replacing backwards production-first workflow

## Overview

This document outlines the new development workflow designed to eliminate production risk, improve testing, and establish proper version control practices.

## Architecture Change

### Old (Problematic) Workflow
```
Direct Production Edit → Local Sync → Git Commit
```
**Issues**: Production risk, no testing, backwards version control

### New (Recommended) Workflow
```
Local Git → Development LXC → Testing LXC → Production → Git Commit
```
**Benefits**: Zero production risk, proper testing, modern DevOps practices

## Environment Structure

### Development Environment (LXC 128)
- **Purpose**: Active feature development and experimentation
- **Target**: `192.168.1.128:8123`
- **Access**: SSH, SMB, Web UI
- **Data**: Ephemeral, Git-backed configurations
- **Rebuilds**: Monthly or as needed

### Testing Environment (LXC 129)  
- **Purpose**: Pre-production validation and QA
- **Target**: `192.168.1.129:8123`
- **Access**: SSH, SMB, Web UI
- **Data**: Production configuration mirror
- **Updates**: Weekly sync with production

### Production Environment (192.168.1.155)
- **Purpose**: Live system (unchanged)
- **Target**: `192.168.1.155:8123`
- **Access**: Read-only except approved deployments
- **Data**: Critical production data
- **Updates**: Only after testing validation

## Development Workflow Steps

### 1. Feature Development
```bash
# Start with clean Git state
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/my-new-feature

# Deploy to development environment
./deployment/deploy-to-dev.sh feature/my-new-feature

# Access development instance
open http://192.168.1.128:8123

# Iterate on changes
# Edit configurations locally
# Deploy changes: ./deployment/deploy-to-dev.sh
# Test functionality
# Repeat until satisfied
```

### 2. Testing Validation
```bash
# Merge feature to main locally
git checkout main
git merge feature/my-new-feature

# Deploy to testing environment
./deployment/deploy-to-test.sh main

# Access testing instance
open http://192.168.1.129:8123

# Comprehensive testing
# - Verify all automations work
# - Test device integrations  
# - Check dashboard functionality
# - Monitor logs for 24 hours
```

### 3. Production Deployment
```bash
# Only after successful testing
# Push changes to remote repository
git push origin main

# Deploy to production
./deployment/deploy-to-prod.sh

# Access production instance
open http://192.168.1.155:8123

# Post-deployment monitoring
# - Monitor for 30 minutes minimum
# - Check critical automations
# - Verify device integrations
# - Watch error logs
```

### 4. Version Control
```bash
# Tag successful deployments
git tag -a v$(date +%Y.%m.%d) -m "Production deployment $(date)"
git push origin --tags

# Update documentation
# Update CHANGELOG.md
# Update deployment logs
```

## Environment-Specific Configurations

### MCP Server Targeting
Each environment has its own MCP configuration:

**Development**: `environments/development/mcp-config.json`
- Points to LXC 128 (192.168.1.128)
- Development Home Assistant token
- Full filesystem access

**Testing**: `environments/testing/mcp-config.json` 
- Points to LXC 129 (192.168.1.129)
- Testing Home Assistant token
- Production-mirrored configuration

**Production**: `environments/production/mcp-config.json`
- Points to production server (192.168.1.155)
- Production Home Assistant token
- Network filesystem access

### Secrets Management
Each environment has separate secrets:
- `environments/development/secrets.yaml` - Development secrets
- `environments/testing/secrets.yaml` - Testing secrets  
- `environments/production/secrets.yaml` - Production secrets

### Configuration Exclusions
Environment-specific files are excluded during deployment:
- Development configs not deployed to testing/production
- Testing configs not deployed to production
- Local development files (.git, logs, etc.) excluded

## Quality Assurance

### Automated Checks
All deployments include:
- YAML syntax validation
- Home Assistant configuration check
- Template syntax verification
- Entity reference validation
- Backup creation before changes

### Testing Requirements
Before production deployment:
- ✅ Development testing completed
- ✅ Testing environment validation passed
- ✅ All critical automations verified
- ✅ Error log review completed
- ✅ Performance monitoring acceptable

### Rollback Procedures
Each deployment creates:
- Full Home Assistant backup
- Git commit reference
- Configuration snapshots
- Automated rollback commands provided

## Safety Features

### Development Safety
- Isolated from production
- Mock/test data only
- Full experimentation freedom
- Regular rebuilds from clean state

### Testing Safety
- Production configuration mirror
- Isolated test environment
- Comprehensive validation checks
- Automated backup before changes

### Production Safety
- Read-only access by default
- Mandatory testing validation
- Comprehensive health checks
- Immediate rollback capability
- Full backup before deployment

## Common Operations

### Daily Development
```bash
# Start development session
git checkout main && git pull
git checkout -b feature/daily-work
./deployment/deploy-to-dev.sh

# Make changes and test
# Edit files locally
./deployment/deploy-to-dev.sh  # Re-deploy changes
# Test at http://192.168.1.128:8123

# End session
git add . && git commit -m "Daily development progress"
git push origin feature/daily-work
```

### Weekly Testing Sync
```bash
# Update testing with production config
git checkout main && git pull
./deployment/deploy-to-test.sh main

# Verify testing environment health
curl http://192.168.1.129:8123/api/
```

### Emergency Production Fix
```bash
# Create hotfix branch
git checkout -b hotfix/critical-issue

# Test fix in development
./deployment/deploy-to-dev.sh hotfix/critical-issue
# Verify fix works

# Fast-track to testing (if critical)
git checkout main && git merge hotfix/critical-issue
./deployment/deploy-to-test.sh main
# Minimal testing for critical fixes

# Deploy to production
./deployment/deploy-to-prod.sh

# Clean up
git push origin main
git tag -a hotfix-$(date +%Y%m%d) -m "Emergency fix"
```

### Container Maintenance
```bash
# Rebuild development container (monthly)
# In Proxmox: pct stop 128 && pct destroy 128
# Recreate using LXC setup guide
# Redeploy current configuration

# Update testing container (weekly)
./deployment/deploy-to-test.sh main

# Production backup (daily - automated)
# ssh root@192.168.1.155 'ha backups new'
```

## Troubleshooting

### Development Issues
- **Container not responding**: Check Proxmox LXC status
- **Deployment fails**: Verify network connectivity to 192.168.1.128
- **Configuration errors**: Check YAML syntax with linter
- **HA won't start**: Review logs via SSH

### Testing Issues
- **Sync failures**: Check network connectivity to 192.168.1.129
- **Validation errors**: Review testing logs
- **Performance problems**: Check container resources
- **State mismatches**: Redeploy from clean Git state

### Production Issues
- **Deployment blocked**: Verify testing validation completed
- **Health check fails**: Immediate rollback via backup
- **Configuration errors**: Emergency rollback procedure
- **Performance degradation**: Monitor and rollback if needed

## Performance Monitoring

### Development Metrics
- Container resource usage
- Home Assistant startup time
- Configuration reload speed
- Development cycle time

### Testing Metrics
- Validation success rate
- Test coverage completeness
- Issue detection rate
- Deployment confidence level

### Production Metrics
- Deployment success rate
- System uptime percentage
- Error rate reduction
- Mean time to recovery

## Migration from Old Workflow

### Phase 1: Container Setup (Week 1)
- ✅ Create LXC 128 (Development)
- ✅ Create LXC 129 (Testing)
- ✅ Validate network connectivity
- ✅ Configure initial Home Assistant instances

### Phase 2: Workflow Implementation (Week 2)
- ✅ Implement deployment scripts
- ✅ Configure environment-specific MCP servers
- ✅ Update development documentation
- ✅ Train team on new procedures

### Phase 3: Gradual Migration (Week 3)
- [ ] Migrate current production config to testing
- [ ] Validate new workflow with small changes
- [ ] Build confidence through testing
- [ ] Document lessons learned

### Phase 4: Full Implementation (Week 4)
- [ ] Switch to new workflow exclusively
- [ ] Decommission old processes
- [ ] Complete team training
- [ ] Establish maintenance procedures

## Success Criteria

### Technical Goals
- ✅ Zero production incidents from development
- ✅ 100% change validation before production
- ✅ Automated backup/rollback procedures
- ✅ <5 minute deployment cycle time

### Process Goals
- ✅ Clear development path for all team members
- ✅ Documented procedures for all operations
- ✅ Reliable testing and validation
- ✅ Professional version control practices

### Business Goals
- ✅ Improved system reliability
- ✅ Faster feature development
- ✅ Reduced downtime risk
- ✅ Better change management

---

## Quick Reference

### Essential Commands
```bash
# Daily development
./deployment/deploy-to-dev.sh

# Pre-production testing  
./deployment/deploy-to-test.sh

# Production deployment
./deployment/deploy-to-prod.sh

# Production log maintenance
./deployment/truncate-prod-logs.sh

# Environment access
ssh root@192.168.1.128  # Development
ssh root@192.168.1.129  # Testing  
ssh root@192.168.1.155  # Production
```

### Important URLs
- **Development**: http://192.168.1.128:8123
- **Testing**: http://192.168.1.129:8123  
- **Production**: http://192.168.1.155:8123

### Emergency Contacts
- **Rollback Command**: `ssh root@{server} 'ha backups restore {backup-name}'`
- **Health Check**: `curl -f http://{server}:8123/api/`
- **Log Access**: `ssh root@{server} 'ha core logs'`

This workflow ensures professional development practices while maintaining system stability and reliability.