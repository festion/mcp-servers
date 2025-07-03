# Project Board Deployment Guide

## Overview
This guide provides step-by-step instructions for creating standardized project boards across all target repositories, since the GitHub MCP Server doesn't currently support project board management.

## Target Repositories for Project Board Creation

### High Priority Repositories
1. **festion/mcp-servers** - MCP server collection
2. **festion/homelab-gitops-auditor** - DevOps platform  
3. **festion/hass-ab-ble-gateway-suite** - Home Assistant BLE integration
4. **festion/proxmox-agent** - Proxmox monitoring agent
5. **festion/blender** - 3D printing Blender integration

### Medium Priority Repositories  
6. **festion/homelab-project-template** - Project template repository

## Standard Project Board Structure

### Board Name Convention
- Format: `{Repository Name} Development Board`
- Examples:
  - "MCP Servers Development Board"
  - "Homelab GitOps Auditor Development Board"
  - "HASS AB BLE Gateway Suite Development Board"

### Standard Columns (in order)
1. **📋 Backlog**
   - Description: "New and planned items awaiting prioritization"
   - Purpose: Collect new issues and feature requests

2. **✅ Ready**  
   - Description: "Items ready to start development"
   - Purpose: Prioritized and approved work items

3. **🚀 In Progress**
   - Description: "Active work currently being developed"
   - Purpose: Track ongoing development work

4. **👀 Review**
   - Description: "Items under review or testing"
   - Purpose: Code review, testing, and validation phase

5. **🧪 Testing**
   - Description: "Items being tested or validated"
   - Purpose: QA, integration testing, user acceptance

6. **✨ Done**
   - Description: "Completed and deployed items"
   - Purpose: Successfully completed work

## Repository-Specific Instructions

### 1. festion/mcp-servers
**URL**: https://github.com/festion/mcp-servers/projects

**Project Board Setup**:
- **Name**: "MCP Servers Development Board"
- **Description**: "Track development across all MCP server components"
- **Template**: Board (classic)

**Initial Issue Assignment**:
- **Backlog**: Issues #1-7 (Home Assistant MCP features)
- **Ready**: Issue #9 (Project Board Creation & Management)
- **In Progress**: Current active development items

### 2. festion/homelab-gitops-auditor  
**URL**: https://github.com/festion/homelab-gitops-auditor/projects

**Project Board Setup**:
- **Name**: "Homelab GitOps Platform Development Board"
- **Description**: "Track Phase 2 platform development and enhancements"
- **Template**: Board (classic)

**Initial Issue Assignment**:
- **Backlog**: Issue #2 (Epic), #3-6 (Phase 2 features)
- **Ready**: High priority Phase 2 features
- **Done**: Completed v1.x features and template engine

### 3. festion/hass-ab-ble-gateway-suite
**URL**: https://github.com/festion/hass-ab-ble-gateway-suite/projects

**Project Board Setup**:
- **Name**: "HASS AB BLE Gateway Suite Development Board"
- **Description**: "Track Home Assistant BLE Gateway integration development"
- **Template**: Board (classic)

**Initial Issue Assignment**:
- **Backlog**: All open issues (currently 2 issues)
- **Ready**: High priority integration features
- **In Progress**: Active dashboard development

### 4. festion/proxmox-agent
**URL**: https://github.com/festion/proxmox-agent/projects

**Project Board Setup**:
- **Name**: "Proxmox Agent Development Board"  
- **Description**: "Track Proxmox monitoring and management agent development"
- **Template**: Board (classic)

**Initial Issue Assignment**:
- **Backlog**: All open issues (currently 0 issues)
- **Ready**: Next planned features for monitoring agent
- **Done**: Initial agent implementation

### 5. festion/blender
**URL**: https://github.com/festion/blender/projects

**Project Board Setup**:
- **Name**: "Blender 3D Printing Development Board"
- **Description**: "Track 3D printing file editing and Serena integration"  
- **Template**: Board (classic)

**Initial Issue Assignment**:
- **Backlog**: All open issues (currently 0 issues)
- **Ready**: 3D printing workflow features
- **In Progress**: Serena MCP integration development

### 6. festion/homelab-project-template
**URL**: https://github.com/festion/homelab-project-template/projects

**Project Board Setup**:
- **Name**: "Homelab Project Template Development Board"
- **Description**: "Track template improvements and standardization efforts"
- **Template**: Board (classic)

**Initial Issue Assignment**:
- **Backlog**: Template enhancement requests
- **Ready**: Documentation improvements
- **Done**: Initial template structure

## Manual Creation Steps

### Step 1: Navigate to Repository Projects
1. Go to the repository URL
2. Click on the "Projects" tab
3. Click "New project" button

### Step 2: Create Project Board
1. Select "Board (classic)" template
2. Enter the project name from above
3. Enter the description from above
4. Set visibility to "Public" (or as appropriate)
5. Click "Create project"

### Step 3: Configure Columns
1. Delete default columns if present
2. Add each standard column in order:
   - Click "Add a column"
   - Enter column name and description
   - Select "No automation" (we'll configure later)
   - Repeat for all 6 columns

### Step 4: Configure Automation (Optional)
For each column, you can set up automation:
- **Ready**: Newly added issues
- **In Progress**: When assigned or moved manually
- **Review**: When pull request is opened
- **Done**: When issue is closed or pull request is merged

### Step 5: Add Initial Issues
1. Go to each column
2. Click "Add cards"
3. Search and add relevant issues to appropriate columns
4. Drag and drop to reorder as needed

## Automation Recommendations

### GitHub Actions Integration
Create workflows to automatically move cards:

```yaml
name: Update Project Board
on:
  issues:
    types: [opened, closed]
  pull_request:
    types: [opened, closed, merged]
```

### Manual Movement Rules
- **Issue opened** → Backlog
- **Issue assigned** → Ready  
- **PR opened** → Review
- **Issue closed** → Done
- **PR merged** → Done

## Maintenance

### Weekly Board Review
1. Review Backlog for new items
2. Move Ready items to In Progress as capacity allows
3. Ensure Done column reflects completed work
4. Archive old completed items monthly

### Monthly Board Cleanup
1. Archive completed items older than 30 days
2. Review and update column automation
3. Assess board effectiveness and adjust structure if needed

## Success Metrics

### Board Utilization
- All active issues assigned to appropriate columns
- Regular movement of cards through workflow
- Team adoption of board for project tracking

### Workflow Efficiency  
- Reduced time in Review and Testing columns
- Consistent use of standard column structure
- Clear visibility into project progress

## Next Steps

1. **Create boards manually** following this guide
2. **Train team members** on board usage and conventions
3. **Set up automation** for card movement
4. **Monitor adoption** and adjust processes as needed
5. **Scale to additional repositories** as project portfolio grows

## Support

For questions about project board setup or best practices:
- Reference this guide for standard procedures
- Consult GitHub documentation for advanced features
- Consider upgrading to GitHub Projects (beta) for enhanced capabilities when available