I have created the `PROJECT_INDEX.md` file as you requested. It provides a concise overview of the codebase, including its purpose, architecture, key files, and dependencies.
litates automation, development, and operational tasks across different domains including API services, frontend dashboards, specialized agents, configuration management (MCP), and dedicated applications like BirdNET-Gone. The project aims to streamline deployments, enhance system monitoring, and provide robust infrastructure for ongoing development and operations.

### Architecture
The architecture is modular, featuring distinct components that interact through APIs and shared configurations.
- **API Services (`api/`):** Node.js-based backend providing endpoints for data management, GitHub and WikiJS integration, MCP interaction, and email notifications. It serves as the central hub for system interactions.
- **Frontend Dashboard (`dashboard/`):** A Vite-based React application utilizing Tailwind CSS, responsible for presenting system status, operational data, and user interfaces for various functionalities.
- **Management & Control Plane (MCP) (`.mcp/`):** Python-based utilities for backups, batch processing, conflict resolution, and template application, forming a critical part of infrastructure management.
- **Agents (`agent-workspace/`, `.claude/agents/`, `.serena/`):** Independent processes (e.g., WebSocket agents, NetBox agent, Proxmox agent) designed for specific automation and monitoring tasks.
- **BirdNET-Gone (`birdnet-gone/`):** A self-contained application, likely involving embedded systems (firmware/), data processing, and its own user interface, integrated into the larger ecosystem.
- **Documentation (`docs/`):** Extensive markdown documentation detailing deployment, configuration, code quality, and project roadmaps, essential for project understanding and maintainability.

### Key Files
- `./PROJECT_INDEX.md`: This file, a high-level overview of the workspace.
- `./api/server.js`: Main entry point for the API backend.
- `./api/mcp-connector.js`: Module handling communication and integration with the MCP.
- `./dashboard/index.html`: Entry point for the frontend dashboard application.
- `./dashboard/vite.config.ts`: Configuration for the Vite build tool used by the dashboard.
- `./.mcp/backup-manager.py`: Python script for managing system backups.
- `./.mcp/pipeline-engine/`: Directory containing components for data processing or deployment pipelines within the MCP.
- `./birdnet-gone/frontend/`: Directory for the BirdNET-Gone application's frontend.
- `./birdnet-gone/firmware/`: Directory containing firmware code for hardware components in BirdNET-Gone.
- `./docs/PHASE2-IMPLEMENTATION-PLAN.md`: Documentation outlining the implementation strategy for Phase 2 of the project.
- `./install.sh`: Master script for initial project setup and dependency installation.
- `./deploy-v1.1.0.sh`: Script for deploying version 1.1.0 of the project.
- `./.pre-commit-config.yaml`: Configuration for pre-commit hooks to enforce code quality and standards.

### Dependencies
The project leverages a polyglot environment with key dependencies:
- **Node.js/NPM:** For API services (`api/package.json`) and frontend applications (`dashboard/package.json`).
- **Python:** For MCP utilities (`.mcp/`), various automation scripts (`create-consolidated-config.py`, `upload-mcp-docs-to-wikijs.py`).
- **Shell (Bash):** Extensively used for deployment, setup, and various operational scripts (`.sh` files across the repository).
- **Git:** Version control is managed via Git, with pre-commit hooks configured (`.pre-commit-config.yaml`).
- **Docker/Podman:** Implied for containerized deployments (seen in `birdnet-gone/Docker/`, `birdnet-gone/Podman/`).
- **Vite/React/Tailwind CSS:** For the `dashboard` frontend development.

### Common Tasks
- **Initial Setup:** Run `./install.sh` to set up the development environment and install dependencies.
- **Linting & Formatting:** Use `./setup-linting.sh` or configured pre-commit hooks (`.pre-commit-config.yaml`) to ensure code quality. Specific commands might be `npm run lint` or `npm run format` within `api/` and `dashboard/` directories.
- **Building:** For the dashboard, `npm run build` within `dashboard/` using Vite. API services typically start directly via Node.js.
- **Testing:** Execute `npm test` or `jest` commands within `api/` and `dashboard/` as defined in their `package.json` and `jest.config.js` files.
- **Deployment:** Utilize specific deployment scripts such as `quick-fix-deploy.sh`, `manual-deploy.sh`, `deploy-v1.1.0.sh`, or `update-production.sh` as appropriate for different environments or versions.
- **Development Server:** For the dashboard, `npm run dev` within `dashboard/` to start a local development server. For API, `node server.js` or similar in `api/`.
