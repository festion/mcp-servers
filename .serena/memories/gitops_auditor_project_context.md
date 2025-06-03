# GitOps Auditor Project Context

## Current Task
User wants to start working with their existing GitOps project using Serena at `C:\GIT\homelab-gitops-auditor`. The project is already connected to GitHub.

## Configuration Status
- Successfully updated allowedDirectories config to include "C:\GIT"
- Current allowed directories: ["C:\Users\Jeremy\OneDrive\Desktop", "C:\working", "Z:\", "C:\GIT"]
- However, file operations still show access denied - likely needs Desktop Commander restart

## Project Structure Discovered
Location: `C:\GIT\homelab-gitops-auditor`

### Main Components:
1. **React Dashboard** - Frontend web interface (Vite-based)
2. **API Server** - Express.js backend on port 3070
3. **Audit Scripts** - Bash/Python scripts for GitHub sync and AdGuard DNS management
4. **Production Deployment** - Full deployment automation

### Key Directories:
- `/dashboard/` - React frontend (Vite)
- `/api/` - Express.js API server
- `/scripts/` - Utility and audit scripts
- `/audit-history/` - JSON audit results
- `/output/` - GitRepoReport.json output
- `/docs/` - Documentation

### Key Files:
- `README.md` - Comprehensive project documentation
- `DEVELOPMENT.md` - Development setup guide
- `package.json` - Node.js dependencies (React 19.1.0, TypeScript 5.8.3)
- `dev-run.sh` - Development environment startup script

## Project Features
- GitOps repository health auditing
- GitHub to local repository sync monitoring
- AdGuard Home DNS rewrite automation
- Interactive web dashboard with charts
- Auto-refreshing data with traffic light health indicators
- Repository-specific viewing with improved routing

## Current Version
v1.0.4 - Added repository-specific viewing with improved routing

## Next Steps After Restart
1. Verify `C:\GIT` directory access is working
2. Explore project structure with full Serena file access
3. Set up development environment for Serena-based development
4. Potentially create project memories for architecture and development patterns

## User Preferences
- Prefers to receive complete updated files when editing code
- Wants to work with existing GitHub-connected project at C:\GIT\homelab-gitops-auditor