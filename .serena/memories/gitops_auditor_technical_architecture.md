# GitOps Auditor Technical Architecture

## Technology Stack
- **Frontend**: React 19.1.0 + Vite + TailwindCSS + Recharts
- **Backend**: Express.js API server (Node.js)
- **Scripts**: Bash + Python 3
- **Database**: SQLite (NPM Proxy Manager integration)
- **Deployment**: systemd services + NGINX
- **Version Control**: Git + GitHub integration

## Development vs Production Architecture

### Development Mode
- API Server: Manual start on localhost:3070
- Dashboard: Vite dev server on localhost:5173
- Base directory: Project folder with relative paths
- Data storage: `./audit-history/` in project root
- CORS enabled for development

### Production Mode
- API Server: systemd service
- Dashboard: Static NGINX serving
- Base directory: `/opt/gitops/`
- Data storage: `/opt/gitops/audit-history/`
- API accessed via relative paths

## Key Scripts and Their Functions

### Repository Auditing
- `sync_github_repos.sh` - Main GitHub sync auditor
- Output: JSON with health status (green/yellow/red)
- Creates timestamped audit files + latest.json symlink

### AdGuard DNS Integration
- `fetch_npm_config.sh` - Extract NPM database
- `generate_adguard_rewrites_from_sqlite.py` - Generate DNS rewrites
- `gitops_dns_sync.sh` - Main DNS sync orchestrator
- Domain scheme: `*.internal.lakehouse.wtf`

### Deployment
- `manual-deploy.sh` - Production deployment packager
- `dev-run.sh` - Development environment startup
- `install.sh` - Production installation script

## Data Flow
1. GitHub API → Local repo comparison
2. NPM SQLite DB → AdGuard DNS rewrites  
3. Audit results → JSON → Dashboard visualization
4. Dashboard → API → File system data

## Health Status Logic
- **Green**: All repos exist and clean
- **Yellow**: Some dirty/extra repos
- **Red**: Missing repositories detected