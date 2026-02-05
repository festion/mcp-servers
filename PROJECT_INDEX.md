# workspace Project Index

Generated: 2026-02-05

## Purpose
This repository is a "homelab-gitops" monorepo designed to manage a home lab environment using an Infrastructure-as-Code approach. The core of the project is a central Node.js API that orchestrates a fleet of language-agnostic, agent-like microservers to manage various services like Proxmox, GitHub, and more.

## Directory Structure
-   `api/`: The main Node.js backend, containing the central API server that orchestrates the MCP agents.
-   `mcp-servers/`: Contains individual, service-specific micro-agents (MCP servers) that are orchestrated by the main API. These are language-agnostic.
-   `dashboard/`: A web-based frontend dashboard for monitoring and interacting with the system.
-   `docs/`: Contains documentation about the project, including architecture, deployment plans, and setup guides.
-   `scripts/`: Contains various shell scripts for deployment, validation, and other operational tasks.

## Key Files
-   `api/server-mcp.js`: The primary entry point for the central Node.js API, integrating all major components.
-   `api/serena-orchestrator.js`: Handles the coordination between different MCP servers.
-   `dashboard/`: Contains the source code for the project's web-based frontend dashboard.
-   `mcp-servers/`: A directory containing the individual, service-specific agents (MCP servers).
-   `PROJECT_INDEX.md`: This file, providing an overview of the project.

## Architecture Patterns
The project follows a microservices-like architecture with a central orchestrator (`api/server-mcp.js`) and a set of language-agnostic agents (`mcp-servers/`). These agents communicate using a custom "Model Context Protocol" (MCP). This allows for a flexible and extensible system where new agents can be added to manage new services without affecting the core API.

## Entry Points
-   **Backend**: The main entry point for the backend is `node api/server-mcp.js`.
-   **Frontend**: The frontend is a web-based dashboard located in the `dashboard/` directory.

## Dependencies
-   **Backend**: Node.js, Express.js
-   **Frontend**: Vite, React/Vue (based on `vite.config.ts`, but not explicitly stated in the analysis)
-   **Agents**: Language-agnostic, with examples in Python.

## Common Tasks
-   **Starting the backend**: `node api/server-mcp.js`
-   **Building the frontend**: Check the `package.json` in the `dashboard/` directory for build scripts (e.g., `npm run build` or `vite build`).
-   **Testing**: Check for `test` scripts in `package.json` files within `api/` and `dashboard/`.
-   **Deployment**: The repository contains several deployment scripts such as `deploy-v1.1.0.sh` and `update-production.sh`.