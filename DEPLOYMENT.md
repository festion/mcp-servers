# MCP Server Wrapper Deployment

This repository includes an automated deployment system for MCP server wrapper scripts.

## 🚀 Deployment Options

### 1. Manual Sync
```bash
./sync-wrappers.sh
```
Copies all wrapper scripts from the repository to `/home/dev/workspace/`.

### 2. Automatic Sync (Git Hook)
```bash
git config --local core.hooksPath .githooks
```
Automatically syncs wrapper scripts after every `git pull` or `git merge`.

### 3. CI/CD Pipeline (GitHub Actions)
- **Workflow**: `.github/workflows/deploy-wrappers.yml`
- **Runner**: Self-hosted local runner 
- **Triggers**: Push to main branch with changes to `*-wrapper.sh` files
- **Features**: Direct local deployment, validation, and optional MCP server testing

## 📁 Managed Wrapper Scripts

The deployment system manages these wrapper scripts:
- `hass-mcp-wrapper.sh` - Home Assistant MCP server
- `proxmox-mcp-wrapper.sh` - Proxmox MCP server  
- `wikijs-mcp-wrapper.sh` - WikiJS MCP server
- `code-linter-wrapper.sh` - Code Linter MCP server
- `github-wrapper.sh` - GitHub MCP server
- `network-mcp-wrapper.sh` - Network MCP server
- `serena-enhanced-wrapper.sh` - Serena MCP server
- `directory-polling-wrapper.sh` - Directory Polling MCP server
- `truenas-mcp-wrapper.sh` - TrueNAS MCP server

## 🔧 Configuration

### Environment Variables
All wrapper scripts load tokens from `/home/dev/.mcp_tokens/`:
- `hass_token`, `hass_url` - Home Assistant
- `proxmox_token`, `proxmox_host`, `proxmox_user` - Proxmox  
- `wikijs_token`, `wikijs_url` - WikiJS
- `github_token` - GitHub (also checks `/home/dev/.github_token`)

### Security
- Tokens stored in `/home/dev/.mcp_tokens/` with 600 permissions
- All wrapper scripts validate token configuration before execution
- Fallback to environment variables if secure storage unavailable

## 🏗️ Development Workflow

1. **Modify wrapper scripts** in this repository
2. **Test locally**: `./sync-wrappers.sh`  
3. **Commit changes**: Git hooks will auto-sync on pull
4. **CI/CD deployment** (if enabled): Automatic deployment to production

## 📋 Troubleshooting

### Sync Issues
```bash
# Check sync script status
./sync-wrappers.sh

# Verify git hooks are enabled  
git config core.hooksPath
```

### Token Issues
```bash
# Check token files exist
ls -la /home/dev/.mcp_tokens/

# Test individual wrapper
/home/dev/workspace/hass-mcp-wrapper.sh
```

### CI/CD Issues
- Check GitHub Actions logs for deployment failures
- Ensure local GitHub runner is active and healthy
- Verify runner has access to `/home/dev/workspace/` and `/home/dev/.mcp_tokens/`
- Use "workflow_dispatch" to manually trigger deployment from GitHub UI