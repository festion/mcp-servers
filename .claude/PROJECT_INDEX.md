I have created the `PROJECT_INDEX.md` file.
2-22

## Purpose
This workspace appears to be a comprehensive collection of projects related to home automation, system monitoring, and potentially AI-driven integrations. It encompasses various services, APIs, frontends, and specialized agents designed to manage and interact with different components within a home or lab environment. The overall goal seems to be to provide a unified platform for monitoring, control, and automation through a modular and interconnected architecture.

## Architecture
The architecture is distributed, featuring multiple interconnected components. A central API (`api/server.js`) likely serves as the backbone, interacting with specialized agents (e.g., `netbox-agent`, `proxmox-agent`, `wikijs-integration`) and potentially a Multi-Component Platform (MCP) through `mcp-connector.js`. WebSocket servers (`agent-workspace/websocket`, `api/websocket-server.js`) facilitate real-time communication. Frontend applications and dashboards (`dashboard`, `3ddash`) provide user interfaces, while services like `birdnet-go` operate as independent Go-based applications. Configuration and deployment scripts tie these various modules together.

## Key Files
*   `./1-line-deploy/Architecture-Integration.md`: Documentation on architectural integration for 1-line deployments.
*   `./1-line-deploy/CLAUDE.md`: Claude AI specific documentation or configuration for the 1-line deploy project.
*   `./1-line-deploy/ct/homepage.sh`: Script for deploying the homepage/dashboard.
*   `./1-line-deploy/ct/netbox-agent.sh`: Script for deploying the NetBox agent.
*   `./1-line-deploy/ct/proxmox-agent.sh`: Script for deploying the Proxmox agent.
*   `./1-line-deploy/ct/wikijs-integration.sh`: Script for deploying WikiJS integration.
*   `./1-line-deploy/MCP_CONFIGURATION.md`: Configuration guide for the MCP in 1-line deploy.
*   `./agent-workspace/websocket/websocket-architecture.js`: Defines the architecture of the WebSocket agent.
*   `./api/config-loader.js`: Handles loading configuration for the API services.
*   `./api/csv-export.js`: Module for exporting data to CSV format.
*   `./api/email-notifications.js`: Manages email notification functionalities.
*   `./api/github-mcp-manager.js`: Integrates GitHub actions with the MCP.
*   `./api/jest.config.js`: Jest configuration for API unit tests.
*   `./api/mcp-connector.js`: Connects the API to the Multi-Component Platform.
*   `./api/MCP_INTEGRATION.md`: Documentation on MCP integration with the API.
*   `./api/server.js`: Main entry point for the API server (likely Node.js/Express).
*   `./api/websocket-server.js`: Implements WebSocket communication within the API.
*   `./birdnet-go/main.go`: Main entry point for the Birdnet-Go application.
*   `./birdnet-go/go.mod`: Go module definition for Birdnet-Go, listing dependencies.
*   `./.mcp/backup-manager.py`: Python script for managing MCP backups.
*   `./.mcp/pipeline-engine/`: Directory likely containing scripts or configurations for MCP data pipelines.
*   `./.prompts/PROMPTS_OVERVIEW.md`: Overview of prompt engineering within the project.
*   `./create-consolidated-config.py`: Python script for consolidating configurations.
*   `./install.sh`: General installation script for the workspace.
*   `./setup-linting.sh`: Script for setting up linting tools.
*   `./deploy-v1.1.0.sh`: Script for deploying version 1.1.0.

## Dependencies
The project uses a mix of technologies:
*   **Node.js/npm**: Indicated by `package.json`, `package-lock.json`, and `.js` files in the `api/` directory.
*   **Go Modules**: Used by `birdnet-go/` as shown by `go.mod` and `go.sum`.
*   **Python**: Suggested by `.py` files in the root and `.mcp/` directories.
*   **Shell Scripting**: Extensive use of `.sh` scripts for various tasks.
*   **Linting Tools**: Configuration files like `.eslintrc.js`, `.golangci.yaml`, `.prettierrc` suggest ESLint, GoLinter, and Prettier are used.

## Common Tasks
*   **Installation**: Run `./install.sh` to set up the workspace.
*   **Deployment**: Use `./deploy-v1.1.0.sh` or specific scripts like `./1-line-deploy/ct/*.sh` for deploying services.
*   **Validation**: Execute `./validate-v1.1.0.sh` to ensure deployments are correct.
*   **Testing**: For Node.js APIs, run `npm test` or `npx jest` (referencing `api/jest.config.js`). For Go projects, `go test` in the `birdnet-go/` directory.
*   **Linting/Formatting**: Run `./setup-linting.sh` and use tools like Prettier, ESLint, or GoLinter (e.g., `golangci-lint run` in `birdnet-go/`).
*   **Development Server**: Potentially `npm start` or `node server.js` in relevant directories (e.g., `api/`).
