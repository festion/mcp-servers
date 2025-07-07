# Home Assistant LXC Development Environment Plan
**Status**: LXC 128 already exists, ready for implementation  
**Date**: 2025-06-30

## Overview
Restructure Home Assistant development workflow from backwards production-first approach to modern containerized development using LXC containers.

## Architecture Design

### Current (Problematic) Workflow
```
Direct Production Edit (192.168.1.155) → Local Sync → Git Commit
```
**Issues**: No testing, production risk, backwards version control

### New (Recommended) Workflow  
```
Local Git → Dev LXC 128 → Test LXC 129 → Production 192.168.1.155 → Git Commit
```
**Benefits**: Proper testing, version control, zero production risk

## LXC Container Specifications

### Development Container (LXC 128) ✅ EXISTS
```yaml
Container: ha-dev-128
Purpose: Active development and feature work
OS: Home Assistant OS (latest)
Resources:
  CPU: 4 cores
  RAM: 4GB
  Storage: 32GB
  Network: 192.168.1.128/24
Status: Already created, ready for configuration
```

### Testing Container (LXC 129) - TO CREATE
```yaml
Container: ha-test-129  
Purpose: Pre-production validation and QA
OS: Home Assistant OS (production version)
Resources:
  CPU: 4 cores
  RAM: 4GB
  Storage: 32GB
  Network: 192.168.1.129/24
Status: Needs to be created
```

### Production Server (Existing 192.168.1.155)
```yaml
Server: ha-prod-155
Purpose: Live production system
Status: Maintained as-is, read-only except approved deployments
```

## Implementation Status

### ✅ Completed
- LXC container specifications documented
- Deployment pipeline scripts created
- Environment-specific MCP configurations
- Comprehensive workflow documentation
- Legacy path references updated

### 🔄 Next Steps
1. **Configure existing LXC 128**
   - Install Home Assistant OS
   - Configure network access (SSH, SMB, Web UI)
   - Set up development-specific integrations

2. **Create LXC 129 (Testing)**
   ```bash
   pct create 129 local:vztmpl/haos-generic-x86-64.tar.gz \
     --cores 4 --memory 4096 --swap 512 --storage local-lvm:32 \
     --net0 name=eth0,bridge=vmbr0,ip=192.168.1.129/24,gw=192.168.1.1 \
     --hostname ha-test-129
   ```

3. **Deploy Current Configuration**
   - Sync production config to testing environment
   - Validate functionality and integrations
   - Establish baseline testing procedures

## Development Workflow

### Daily Development Process
```bash
# 1. Start with clean Git state
git checkout main && git pull

# 2. Create feature branch
git checkout -b feature/my-changes

# 3. Deploy to development (LXC 128)
./deployment/deploy-to-dev.sh

# 4. Develop and test at http://192.168.1.128:8123

# 5. Deploy to testing when ready
./deployment/deploy-to-test.sh

# 6. Final production deployment
./deployment/deploy-to-prod.sh
```

### Safety Features
- **Automated backups** before all deployments
- **Configuration validation** at each step
- **Health checks** after deployments
- **Immediate rollback** capability
- **Environment isolation** prevents production impact

## Environment-Specific Configurations

### MCP Server Targeting
- **Development**: Points to 192.168.1.128
- **Testing**: Points to 192.168.1.129  
- **Production**: Points to 192.168.1.155

### Secrets Management
Each environment maintains separate secrets:
- Development secrets (mock/test data)
- Testing secrets (sanitized production data)
- Production secrets (real credentials)

## Benefits of New Approach

### Technical Benefits
- **Zero production risk** during development
- **Proper testing validation** before deployment
- **Version control best practices**
- **Containerized reproducible environments**
- **Professional DevOps workflow**

### Process Benefits
- **Clear development path** for team members
- **Documented procedures** for all operations
- **Reliable testing and validation**
- **Automated backup/rollback procedures**

### Business Benefits
- **Improved system reliability**
- **Faster feature development**
- **Reduced downtime risk**
- **Better change management**

## Migration Plan

### Phase 1: Container Setup ✅ PARTIALLY COMPLETE
- [x] LXC 128 exists (ready for HA installation)
- [ ] Create LXC 129 (testing environment)
- [ ] Configure Home Assistant on both containers
- [ ] Validate network connectivity

### Phase 2: Workflow Implementation
- [ ] Configure environment-specific MCP servers
- [ ] Test deployment scripts with both containers
- [ ] Validate backup/rollback procedures
- [ ] Train team on new processes

### Phase 3: Production Migration
- [ ] Migrate current production config to testing
- [ ] Validate new workflow with small changes
- [ ] Build confidence through testing iterations
- [ ] Establish monitoring and maintenance procedures

### Phase 4: Full Implementation
- [ ] Switch to new workflow exclusively
- [ ] Decommission old backwards process
- [ ] Complete team training
- [ ] Document lessons learned

## Success Criteria

### Technical Goals
- 100% change validation before production
- <5 minute deployment cycle time
- Automated backup/rollback procedures
- Zero production incidents from development

### Process Goals
- Clear development procedures for all team members
- Documented operations for all common tasks
- Reliable testing and validation workflow
- Professional version control practices

## Risk Mitigation

### Development Risks
- Container resource limitations → Monitor and adjust as needed
- Network connectivity issues → Redundant access methods (SSH, SMB, Web)
- Configuration complexity → Automated deployment scripts

### Testing Risks
- Production parity concerns → Regular sync from production
- Validation gaps → Comprehensive testing checklists
- Time constraints → Automated testing procedures

### Production Risks
- Deployment failures → Automated health checks and rollback
- Configuration errors → Multi-stage validation
- Downtime concerns → Non-breaking deployment practices

## Quick Reference

### Essential Commands
```bash
# Development deployment
./deployment/deploy-to-dev.sh

# Testing deployment  
./deployment/deploy-to-test.sh

# Production deployment
./deployment/deploy-to-prod.sh

# Production maintenance
./deployment/truncate-prod-logs.sh
```

### Environment Access
- **Development**: http://192.168.1.128:8123
- **Testing**: http://192.168.1.129:8123  
- **Production**: http://192.168.1.155:8123

### Emergency Procedures
- **Health Check**: `curl -f http://{server}:8123/api/`
- **Rollback**: `ssh root@{server} 'ha backups restore {backup-name}'`
- **Logs**: `ssh root@{server} 'ha core logs'`

## Conclusion

This plan transforms the Home Assistant development workflow from a risky backwards approach to a modern, professional containerized workflow. With LXC 128 already existing, implementation can begin immediately with container configuration and testing environment creation.

The new workflow eliminates production risk while improving development speed, testing quality, and system reliability through proper DevOps practices.