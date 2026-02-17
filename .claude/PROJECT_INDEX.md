OK. I've created the `PROJECT_INDEX.md` file.
16

## Purpose

This workspace appears to host a comprehensive suite of interconnected services, tools, and applications designed for system management, automation, and potentially specific domain functionalities like IoT or machine learning (e.g., `birdnet-gone`). It integrates various components including APIs, dashboards, deployment scripts, and configuration management tools to streamline operations and development across different environments.

## Architecture

The architecture seems to be modular, encompassing several key components:

- **API Layer (`api/`):** Provides core backend functionalities, likely handling data, notifications, and integration with other services like GitHub and MCP.
- **Dashboard/Frontend (`dashboard/`, `frontend/`):** User interfaces for monitoring, configuration, and interaction with the backend services. `dashboard/` suggests a React/Vite/Tailwind-based application.
- **Deployment & Automation (`1-line-deploy/`, `scripts/`, `.github/workflows/`, `cron/`, various `.sh` files):** Contains scripts and configurations for automated deployments, CI/CD, and scheduled tasks across various environments (e.g., NetBox, Proxmox, WikiJS).
- **Configuration Management (`config/`, `.mcp/`, `create-consolidated-config.py`):** Tools and files for managing system configurations, backups, and template application.
- **Specialized Services (`birdnet-gone/`, `agent-workspace/websocket/`, `netbox-agent/`, `proxmox-agent/`, `wikijs-sync-agent/`):** Dedicated services for specific tasks such as bird sound detection, real-time communication via websockets, and integration with network/virtualization management platforms.
- **Documentation (`docs/`, `PROJECT_INDEX.md`, various other `.md` files):** Extensive documentation covering deployment plans, technical guides, code quality, and project structure.

These modules likely interact through APIs, message queues (potentially implied by `websocket-server.js`), and shared configurations to form a cohesive operational environment.

## Key Files

- `./PROJECT_INDEX.md`: This file, serving as a comprehensive index for the entire workspace.
- `./api/server.js`, `./api/server-v2.js`, `./api/server-mcp.js`: Main entry points for various API servers, indicating different versions or specialized functions.
- `./api/config-loader.js`: Handles loading and managing configurations for the API services.
- `./api/github-mcp-manager.js`: Manages GitHub interactions, possibly for deployments or CI/CD integration with the MCP system.
- `./api/websocket-server.js`: Implements real-time communication capabilities for various services.
- `./dashboard/index.html`, `./dashboard/src/main.ts`, `./dashboard/vite.config.ts`: Core files for the dashboard frontend, indicating a TypeScript/Vite/React setup.
- `./birdnet-gone/cmd/birdnet-gone/main.go`: Main entry point for the Birdnet-Gone application, suggesting a Go-based service.
- `./.mcp/pipeline-engine/`: Directory likely containing the core logic for the Micro-Configuration Processor's pipeline execution.
- `./.github/workflows/main.yml`: GitHub Actions workflow definition for CI/CD processes.
- `./install.sh`, `./setup-linting.sh`, `./deploy-v1.1.0.sh`: Various shell scripts for initial setup, code quality enforcement, and deployment procedures.
- `./docs/PHASE2-IMPLEMENTATION-PLAN.md`: A key document outlining the roadmap for the next phase of development.

## Dependencies

- **Node.js/JavaScript:** Evident from `package.json`, `package-lock.json` in `api/` and `dashboard/`, along with numerous `.js` and `.ts` files. Common dependencies include Express.js for APIs, React/Vite/Tailwind for frontends, and Jest for testing.
- **Python:** Indicated by `.py` files such as `create-consolidated-config.py`, `upload-mcp-docs-to-wikijs.py`, and scripts within `.mcp/`, suggesting scripting, automation, and possibly data processing or specialized agents.
- **Go:** Suggested by `birdnet-gone/cmd/birdnet-gone/main.go`, implying some services are developed in Go.
- **Shell Scripting (Bash/Powershell):** Extensive use of `.sh` and `.ps1` files for automation, deployment, and system management.
- **Git:** Used for version control across the workspace.

## Common Tasks

- **Build/Compile:** For Node.js/TypeScript projects, `npm install` followed by `npm run build` (or `vite build` for the dashboard) would be common. Go projects would use `go build`.
- **Test:** `npm test` or `jest` commands for Node.js projects (e.g., `api/`, `dashboard/`).
- **Deploy:** Executing specific shell scripts like `deploy-v1.1.0.sh`, `manual-deploy.sh`, or scripts within `1-line-deploy/ct/` for different services and environments.
- **Linting/Formatting:** Running `npm run lint` or utilizing tools configured via `.eslintrc.js`, `.prettierrc`, and `setup-linting.sh`.
- **Run Development Servers:** `npm run dev` for frontend projects (e.g., `dashboard/`) and `node server.js` or similar for API services.
- **Configuration Management:** Executing Python scripts within `.mcp/` or `create-consolidated-config.py` for managing system configurations.
