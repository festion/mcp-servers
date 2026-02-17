Done. What's next?
 Index

Generated: 2026-02-17

## Purpose
This workspace serves as a multi-project repository integrating various systems for automation, monitoring, and AI-driven operations. It encompasses APIs, dashboards, deployment scripts, agent configurations, and documentation for managing a complex environment, likely related to smart home or lab infrastructure. The projects range from web-based interfaces to backend services and specialized agents for specific tasks.

## Architecture
The architecture appears to be a decentralized collection of services and agents communicating through various means. Key components include:
*   **API Services (`api/`):** Node.js-based backend services exposing endpoints for managing system components, handling data export, notifications, and integrations.
*   **Web Dashboards (`dashboard/`, `3ddash/`):** Frontend applications (likely React/Vite for `dashboard/`) for visualization and interaction with the underlying systems. `3ddash` suggests a specialized 3D visualization dashboard.
*   **Management/Control Plane (`.mcp/`):** Python scripts and configurations for backup, batch processing, conflict resolution, and templating, acting as a central orchestration layer.
*   **Specialized Agents (`agent-workspace/websocket/`, `birdnet-gone/`, `wikijs-sync-agent/`, `netbox-agent/`, `proxmox-agent/`):** Independent modules designed for specific tasks like real-time communication, environmental monitoring, and synchronization with external services.
*   **Deployment & Automation (`1-line-deploy/`, `scripts/`, `.github/workflows/`):** Shell scripts and GitHub Actions for automated deployment, setup, and maintenance across various services.

## Key Files
*   `PROJECT_INDEX.md`: This file, providing an overview of the workspace.
*   `.mcp/README.md`: Documentation for the Management/Control Plane.
*   `api/server.js`, `api/server-v2.js`, `api/websocket-server.js`: Main entry points for API and WebSocket services.
*   `api/MCP_INTEGRATION.md`: Documentation on how APIs integrate with the Management/Control Plane.
*   `dashboard/index.html`, `dashboard/src/main.ts`: Main entry point and source for the web dashboard.
*   `dashboard/vite.config.ts`, `dashboard/tailwind.config.js`: Configuration for the dashboard's build process and styling.
*   `birdnet-gone/`: Contains the BirdNET-Go project, likely for bird sound analysis and deployment.
*   `docs/*.md`: Comprehensive documentation files covering various aspects of the system, deployment plans, and operational procedures.
*   `.prompts/`: Directory for various AI prompts, indicating prompt engineering practices.
*   `install.sh`, `setup-linting.sh`, `deploy-v1.1.0.sh`: Scripts for initial setup, code quality, and deployment.

## Dependencies
*   **Node.js/npm:**
    *   `api/package.json`: Lists runtime and development dependencies for backend services (e.g., `express`, `jest`).
    *   `dashboard/package.json`: Lists dependencies for the frontend dashboard (e.g., `react`, `typescript`, `vite`, `tailwindcss`, `jest`).
*   **Python:**
    *   Implied by `.mcp/`, `create-consolidated-config.py`, `upload-mcp-docs-to-wikijs.py`. Specific dependencies would be in `requirements.txt` or inferred from imports within Python files (e.g., `Flask`, `FastAPI` for web services, general utility libraries).
*   **Shell/Bash:**
    *   Various `.sh` scripts (`install.sh`, `deploy-v1.1.0.sh`) indicate reliance on standard Unix utilities.
*   **Git:**
    *   Used for version control across the workspace.

## Common Tasks
*   **Setup:**
    *   Run `install.sh` to initialize the development environment.
    *   Execute `setup-linting.sh` for code quality tools.
*   **Development:**
    *   Start API services (e.g., `node api/server.js`).
    *   Start dashboard development server (e.g., `npm run dev` in `dashboard/`).
*   **Testing:**
    *   Run tests for API: `npm test` in `api/`.
    *   Run tests for Dashboard: `npm test` in `dashboard/`.
*   **Deployment:**
    *   Use `deploy-v1.1.0.sh` or `update-production.sh` for deploying changes.
    *   Utilize scripts in `1-line-deploy/` for specific component deployments.
*   **Documentation:**
    *   Refer to `docs/` for operational guides and project plans.
