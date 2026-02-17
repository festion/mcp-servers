I have created the `PROJECT_INDEX.md` file as requested.
ose
This repository serves as a monorepo integrating diverse projects and tools crucial for home lab management, automation, and development. It encompasses API services, a responsive dashboard, automated deployment scripts, configuration management utilities, and specialized applications like Birdnet-Gone. The overarching goal is to standardize and streamline operational and development workflows across various environments and systems.

## Architecture
The architecture is structured around several interconnected, yet distinct, components:

*   **API Services (`api/`):** Provides the backend backbone, handling data processing, notifications, and integration with various configuration management and external systems. It features multiple server entry points (`server.js`, `server-v2.js`, `websocket-server.js`) and modules for configuration loading and MCP integration.
*   **Dashboard (`dashboard/`):** A modern frontend application (likely built with React, Vite, and Tailwind CSS) that consumes data from the API services to offer system monitoring, control interfaces, and visualizations.
*   **Birdnet-Gone (`birdnet-gone/`):** A specialized, self-contained application, potentially deployed as a containerized service, focused on audio analysis or related tasks. It includes its own frontend and backend components.
*   **Configuration Management Tools (`.mcp/`, `.serena/`, `.claude/`):** Internal systems responsible for managing project configurations, orchestrating deployments, and potentially integrating with AI agents for enhanced development or operational support.
*   **Deployment & Automation Scripts (`1-line-deploy/`, `scripts/`, various `.sh` files):** A comprehensive collection of bash scripts and modules designed for simplified, repeatable deployment, updates, and initial setup of various services (e.g., NetBox agent, Proxmox agent, WikiJS integration).
*   **Documentation (`docs/`, various `.md` files):** Extensive markdown-based documentation providing detailed technical guides, deployment strategies, and project overviews, serving as a central knowledge base.

These components interact through clearly defined APIs, shared configurations, and automated processes orchestrated by the various scripting and internal tooling.

## Key Files
*   `./PROJECT_INDEX.md`: This top-level index for the entire workspace.
*   `./.eslintrc.js`, `./.prettierrc`: Configuration files for JavaScript/TypeScript linting and code formatting.
*   `./.pre-commit-config.yaml`: Configuration for Git pre-commit hooks to ensure code quality before commits.
*   `./install.sh`: General script for initial project setup and dependency installation.
*   `./setup-linting.sh`: Script specifically for configuring linting tools across the repository.
*   `./deploy-v1.1.0.sh`, `./update-production.sh`: Scripts used for deploying specific versions and updating production environments.
*   `./api/server.js`, `./api/server-v2.js`: Main entry points for the core API services.
*   `./api/websocket-server.js`: Entry point for WebSocket communication services.
*   `./api/config-loader.js`: Module responsible for loading application configurations in the API.
*   `./api/mcp-connector.js`: Module facilitating connection and integration with the Master Configuration Processor (MCP).
*   `./api/jest.config.js`: Jest testing framework configuration for the API project.
*   `./api/MCP_INTEGRATION.md`: Documentation detailing the integration of MCP within the API.
*   `./dashboard/index.html`: The main entry file for the frontend dashboard application.
*   `./dashboard/src/`: Contains the source code for the dashboard's React components and logic.
*   `./dashboard/vite.config.ts`: Configuration file for Vite, the dashboard's build tool.
*   `./dashboard/tailwind.config.js`: Configuration for Tailwind CSS used in the dashboard.
*   `./birdnet-gone/cmd/`: Backend command-line utilities and Go source code for Birdnet-Gone.
*   `./birdnet-gone/frontend/`: Frontend source code for the Birdnet-Gone application.
*   `./.mcp/`: Directory containing scripts and configurations for the Master Configuration Processor.
*   `./.serena/project.yml`: Project configuration file for the Serena system.
*   `./.claude/settings.json`: Configuration settings for the Claude agent.
*   `./1-line-deploy/`: Directory housing simplified, one-line deployment scripts and related documentation.
*   `./docs/`: Comprehensive repository for general project documentation, guides, and plans.

## Dependencies
*   **Node.js & npm:** Primary environment for API services and the dashboard frontend (managed via `package.json` files).
*   **Python:** Utilized for various automation scripts, backend tooling, and potentially parts of the `.mcp/` system.
*   **Bash/Shell:** Extensively used for deployment, setup, and operational scripting across the repository.
*   **Vite, React, Tailwind CSS:** Core technologies for the `dashboard` frontend development.
*   **Jest:** The testing framework employed for both API and dashboard unit/integration tests.
*   **Go:** Used in the `birdnet-gone` project for its backend components.

## Common Tasks
*   **Initial Setup:**
    *   Execute `./install.sh` to perform a comprehensive project installation.
    *   Run `./setup-linting.sh` to configure and enable code linting tools.
    *   Navigate to `api/` and `dashboard/` directories and run `npm install` to install Node.js dependencies.
*   **Development:**
    *   From `dashboard/`, execute `npm run dev` to start the local development server for the dashboard.
    *   API development typically involves running the appropriate `node` command for the specific `server.js` file (e.g., `node server.js` from `api/`).
*   **Testing:**
    *   In `api/` or `dashboard/`, run `npm test` or `jest` directly to execute unit and integration tests.
*   **Deployment & Updates:**
    *   Use `./deploy-v1.1.0.sh` for deploying a specific version of the system.
    *   Execute `./update-production.sh` to apply updates to production environments.
    *   Specific deployments (e.g., NetBox agent, Proxmox agent, WikiJS integration, homepage dashboard) can be triggered using scripts in `./1-line-deploy/ct/` (e.g., `./1-line-deploy/ct/netbox-agent.sh`).
*   **Code Quality:**
    *   Run `npm run lint` in relevant Node.js projects (`api/`, `dashboard/`) to check for code style and errors.
    *   Utilize `prettier --write .` to automatically format code across the repository.
