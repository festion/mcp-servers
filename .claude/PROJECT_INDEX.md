# Project Index

This document provides a high-level overview of the `homelab-gitops` repository, which manages a comprehensive home automation and infrastructure management system.

## 1. Core Purpose

This project automates the deployment, configuration, and management of a sophisticated homelab environment. It uses a GitOps approach to maintain infrastructure-as-code, integrating various services for home automation, network management, virtualization, and application hosting. A key feature is the "Model Context Protocol" (MCP) and "Serena" agent framework, a custom AI-driven system for task orchestration, system monitoring, and automated documentation.

## 2. Architecture

The architecture is multi-tiered, consisting of:

-   **Orchestration & Automation:**
    -   **`homelab-gitops`**: The central repository for all configurations and deployment scripts, acting as the single source of truth.
    -   **MCP (Model Context Protocol) / `mcp-servers`**: A suite of specialized Node.js servers that act as agents to manage different subsystems (Proxmox, GitHub, Home Assistant, etc.).
    -   **`serena`**: A Python-based AI agent framework that orchestrates complex tasks across the various MCP servers.
    -   **Scripts (`scripts/`, `wrappers/`)**: A collection of bash scripts for deployment, validation, and maintenance tasks.

-   **Core Services:**
    -   **Home Automation (`home-assistant-config/`)**: A highly customized Home Assistant setup with numerous integrations, automations, and custom components.
    -   **Virtualization & Network (`proxmox-agent`, `netbox-agent`)**: Agents and configurations for managing Proxmox VE and NetBox for DCIM/IPAM.
    -   **API & Backend (`api/`)**: A central Node.js API that provides endpoints for system integration and management, including a WebSocket server for real-time communication.
    -   **Dashboards (`dashboard/`, `3ddash/`)**: Multiple web-based UIs for system monitoring and control, built with modern frontend frameworks.

-   **Supporting Systems:**
    -   **`birdnet-gone`**: A standalone Go application for bird sound identification.
    -   **Documentation (`docs/`, `wikijs-sync-agent`)**: Contains extensive manual documentation and an automated agent to sync repository content to a WikiJS instance.
    -   **Backups (`backups/`)**: Stores configuration backups for critical services like Zigbee2MQTT and Traefik.

## 3. Key Files & Directories

-   **`homelab-gitops/`**: The primary repository managing the entire stack.
-   **`home-assistant-config/configuration.yaml`**: The central configuration file for Home Assistant.
-   **`mcp-servers/`**: Contains the individual microservices for the MCP automation framework.
-   **`serena/`**: The core directory for the Serena AI orchestration agent.
-   **`api/server.js`**: The main entry point for the backend API services.
-   **`dashboard/`**: Source code for the main web-based dashboard.
-   **`docs/`**: High-level system documentation, architecture diagrams, and standard operating procedures.
-   **`deploy-v1.1.0.sh` & `update-production.sh`**: Key deployment scripts for rolling out changes.
-   **`1-line-deploy/`**: Contains scripts and documentation for simplified, single-command deployments of core services.

## 4. Dependencies

-   **Infrastructure**: Proxmox VE, TrueNAS, Docker, Traefik
-   **Core Applications**: Home Assistant, NetBox, WikiJS, PostgreSQL, Mosquitto (MQTT)
-   **Languages**: Python, Node.js, Go, Bash
-   **Frameworks**: React (Vite), Express.js
-   **Tools**: Git, GitHub Actions, `pre-commit`, `eslint`
ckage.json`: Manages Node.js dependencies for the API services (e.g., Express, Jest).
    *   `dashboard/package.json`: Manages Node.js dependencies for the dashboard (e.g., React, Vite, Jest, Tailwind CSS, PostCSS, ESLint, TypeScript).
*   **Python**:
    *   Implied by `.mcp/*.py` scripts, `create-consolidated-config.py`, `dashboard/proxy-server.py`, `upload-mcp-docs-to-wikijs.py`. Specific dependencies would be listed in `requirements.txt` files (not explicitly shown but expected in Python projects).
*   **Go**:
    *   Implied by `birdnet-gone/cmd/` and `.go` files. `go.mod` (not explicitly shown) would define Go module dependencies.
*   **Shell/Bash**:
    *   Numerous `.sh` scripts (`install.sh`, `deploy-v1.1.0.sh`, `cleanup-mcp-structure.sh`, etc.) indicate reliance on standard Unix/Linux utilities and shell scripting capabilities.

## Common Tasks

*   **Installation**: Run `./install.sh` to set up the workspace.
*   **Linting**: Execute `./setup-linting.sh` to configure and run linters for code quality.
*   **Building API/Dashboard**: Navigate to `api/` or `dashboard/` and run `npm install` followed by `npm run build` (for dashboard) or potentially `node server.js` (for API).
*   **Testing**: Navigate to `api/` or `dashboard/` and run `npm test` or `jest` to execute unit/integration tests.
*   **Deployment**:
    *   Use scripts in `1-line-deploy/ct/` for specific component deployments (e.g., `1-line-deploy/ct/homepage.sh`).
    *   For general deployments, use `./deploy-v1.1.0.sh` or `./manual-deploy.sh`.
    *   To update production, use `./update-production.sh`.
*   **MCP Operations**: Run Python scripts in `.mcp/` for specific tasks (e.g., `.mcp/backup-manager.py`).
