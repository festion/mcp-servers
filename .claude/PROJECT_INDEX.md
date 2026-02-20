```markdown
# Project Index

## 1. Core Purpose

This repository is a comprehensive GitOps-based management system for a personal homelab. It automates the deployment, configuration, monitoring, and documentation of a wide array of services, from core infrastructure to home automation and custom applications. The project heavily leverages automation and a custom protocol (MCP) to maintain a desired state defined in this repository.

## 2. Architecture

The architecture is a distributed system orchestrated via GitOps principles, with several key components:

*   **Orchestration Core (`homelab-gitops`):** Acts as the central control plane. It contains deployment scripts, state management, and the core logic for the GitOps workflow.
*   **Model Context Protocol (MCP):** A set of micro-servers (`mcp-servers/`) that act as agents or connectors to various systems (Proxmox, Home Assistant, GitHub, etc.). They execute tasks and report status back to the orchestration core.
*   **API & Frontend:** A Node.js API (`api/`) provides a programmatic interface to the system, while a Vue/Vite-based `dashboard/` offers a user-friendly interface for control and monitoring.
*   **Managed Services:** The repository manages numerous applications, including:
    *   **Home Automation:** Extensive configuration for `home-assistant-config`.
    *   **Infrastructure:** Agents for `netbox-agent` and `proxmox-agent` to manage network and virtualization.
    *   **Applications:** Self-contained projects like `birdnet-gone` (sound analysis) and `3ddash` (3D dashboard).
*   **Automated Documentation:** A `wikijs-sync-agent` automatically discovers, processes, and uploads documentation to a WikiJS instance, ensuring documentation stays current with the codebase.

## 3. Key Files & Directories

*   `homelab-gitops/`: The main directory for the GitOps orchestration, containing deployment plans and automation scripts.
*   `mcp-servers/`: Contains the individual agent implementations for the Model Context Protocol.
*   `api/server.js`: The primary entry point for the backend control API.
*   `dashboard/src/`: Source code for the main user-facing dashboard.
*   `home-assistant-config/`: Contains the complete configuration for the Home Assistant instance.
*   `docs/`: High-level documentation, architecture diagrams, and operational procedures.
*   `scripts/`: A collection of utility, deployment, and maintenance scripts used across the repository.
*   `1-line-deploy/`: Scripts and documentation for simplified, one-command deployments of various services.

## 4. Dependencies

*   **Languages:** Python, JavaScript/TypeScript (Node.js), Shell (Bash)
*   **Frameworks:** Vite, Jest, Express.js
*   **Tools:** Docker, Git, Pre-commit hooks
*   **Infrastructure:** Proxmox, Home Assistant, Netbox, Traefik, WikiJS
```
 Scripts for deploying and updating the project.

## Dependencies
*   **Node.js / npm**: Utilized by the `api/` and `dashboard/` modules for backend services, frontend development, and dependency management.
*   **Python**: Used for various scripting, automation tasks, and potentially components within the `.mcp/` system.
*   **Go**: The `birdnet-gone/` application is developed using Go.
*   **Bash**: Extensively used across the project for scripting, deployment, and operational tasks.

## Common Tasks
*   **Project Setup:**
    *   `./install.sh`: Run to perform initial project setup and install core dependencies.
    *   `./setup-linting.sh`: Configures code linting tools and rules.
*   **Development:**
    *   Navigate to `api/` or `dashboard/` and run `npm install` to install Node.js dependencies.
    *   In `dashboard/`, `npm run dev` starts the local development server for the UI.
    *   In `api/`, `node server.js` (or similar for `server-v2.js`, `server-mcp.js`) starts the API server.
    *   In `birdnet-gone/`, `go run cmd/birdnet-gone/main.go` executes the BirdNET-Gone application.
*   **Testing:**
    *   Navigate to `api/` or `dashboard/` and run `npm test` or `jest` to execute unit/integration tests.
*   **Deployment:**
    *   `./deploy-v1.1.0.sh`: Deploys a specific version of the project.
    *   `./quick-fix-deploy.sh`: For rapid deployment of emergency fixes.
    *   Scripts within `1-line-deploy/ct/` (e.g., `./1-line-deploy/ct/homepage.sh`): For deploying individual components.
    *   `./update-production.sh`: Script to update the production environment.
*   **Code Quality:**
    *   `npm run lint` (in `api/` or `dashboard/`): Runs configured linters for JavaScript/TypeScript code.
    *   `ruff check .` (if configured): Checks Python code for style and errors.
```
```markdown
# workspace Project Index

Generated: 2026-02-20

## Purpose
This workspace is a comprehensive monorepo designed for home automation, CI/CD, API services, and AI development. It integrates various components for deploying services, managing configurations, handling data exports, and interacting with specialized applications like BirdNET-Lite. The project aims to provide a robust and automated platform for managing complex system deployments and operations.

## Architecture
The project is structured into several interconnected modules:
*   **`api/`**: Contains core backend services, likely Node.js based, handling configuration loading, integrations (e.g., GitHub, MCP), data export, and exposing various API endpoints.
*   **`dashboard/`**: A frontend application, likely built with Vite, React/Vue, and Tailwind CSS, serving as a user interface for monitoring and interacting with the backend services and deployed systems.
*   **`birdnet-gone/`**: A standalone application (potentially Go backend and a separate frontend) focused on specific functionality, possibly audio analysis or similar tasks, with its own deployment and configuration.
*   **`1-line-deploy/`**: A collection of simplified deployment scripts and documentation for rapidly deploying various agents (NetBox, Proxmox, WikiJS, Homepage Dashboard).
*   **`.mcp/`**: A "Master Control Program" module for managing critical aspects like backups, resolving conflicts, handling dependencies, and