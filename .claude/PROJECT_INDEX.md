I have created the `PROJECT_INDEX.md` file as requested. It summarizes the project's purpose, architecture, key files, and dependencies.
ment for a homelab ecosystem. It integrates various components including API services, a frontend dashboard, AI agents, deployment tools, monitoring systems, and configuration management (likely via MCP). Its purpose is to automate deployments, manage infrastructure, facilitate AI-driven operations, and provide centralized control and visibility across the entire homelab environment.

## Architecture

The architecture is modular, centered around an `api` service that acts as the backend for various components and integrations.

*   **`api/`**: The primary backend service, written in Node.js, responsible for handling requests, integrating with systems like MCP, GitHub, and WikiJS, and managing notifications. It likely orchestrates communication with different agents.
*   **`dashboard/`**: A frontend application, likely built with React/Vite and styled with Tailwind CSS, providing a user interface for monitoring, control, and interaction with the `api` services.
*   **`.mcp/`**: A Python-based Multi-Cloud Platform or Management Control Plane system, handling tasks such as backups, batch processing, conflict resolution, and applying configuration templates. It's a core component for infrastructure management.
*   **`agent-workspace/websocket/`**: Provides real-time communication capabilities, likely enabling various specialized agents (e.g., `netbox-agent`, `proxmox-agent`) to interact with the central system via websockets.
*   **`birdnet-gone/`**: A significant, independent application within the ecosystem, complete with its own frontend, firmware, and deployment mechanisms, suggesting a dedicated functionality (e.g., bird detection).
*   **`docs/`**: A central repository for comprehensive documentation, including architectural overviews, deployment plans, and operational procedures.

## Key Files

*   `./api/server.js`: The main entry point for the Node.js API server.
*   `./api/mcp-connector.js`: Manages the connection and integration between the API and the `.mcp` system.
*   `./dashboard/vite.config.ts`: Configuration file for the Vite build tool used by the frontend dashboard.
*   `./dashboard/src/main.ts`: The primary entry file for the TypeScript-based frontend dashboard application.
*   `./.mcp/backup-manager.py`: A Python script responsible for managing backup operations within the MCP system.
*   `./.mcp/pipeline-engine/`: Directory containing scripts or configurations for automated data processing and deployment pipelines.
*   `./agent-workspace/websocket/websocket-architecture.js`: Defines the structural and operational blueprint for the websocket communication system.
*   `./1-line-deploy/ct/`: Directory containing one-line shell scripts for quick deployments of specific services.
*   `./install.sh`: A general-purpose shell script for initial project setup and dependency installation.
*   `./setup-linting.sh`: A script to configure and enforce code linting standards across the project.
*   `./docs/DEPLOYMENT-PLANS-SUMMARY.md`: Provides a high-level overview of various deployment strategies and procedures.

## Dependencies

*   **Node.js**: The `api/` and `dashboard/` directories contain `package.json` files, indicating reliance on Node.js and npm packages (e.g., Express.js, Jest, React, Vite, Tailwind CSS).
*   **Python**: Numerous scripts within `.mcp/` and other directories suggest Python 3 as a core runtime, likely with various libraries for system interaction, data processing, and automation.
*   **Shell Utilities**: Extensive use of `.sh` scripts implies a dependency on standard Unix-like shell environments (e.g., Bash).
*   **Git**: The presence of `.git/` directories indicates Git for version control.

## Common Tasks

*   **Initial Setup**: Run `./install.sh` from the root directory to set up the environment and install core dependencies.
*   **API Development**: Navigate to `api/`, install dependencies with `npm install`, and start the server (e.g., `npm start` or a specific script).
*   **Frontend Development**: Navigate to `dashboard/`, install dependencies with `npm install`, and start the development server (e.g., `npm run dev`).
*   **Testing**:
    *   For API tests, go to `api/` and execute `npm test` (powered by Jest).
    *   For dashboard tests, go to `dashboard/` and execute `npm test` (powered by Jest).
*   **Linting and Formatting**: Execute `./setup-linting.sh` or use project-specific ESLint/Prettier commands to ensure code quality.
*   **Deployment**: Utilize specific deployment scripts like `./deploy-v1.1.0.sh`, `./update-production.sh`, or the specialized scripts found in `1-line-deploy/ct/` for targeted deployments.
