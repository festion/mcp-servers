# Project Index

## Core Purpose

This repository contains a comprehensive GitOps-managed homelab infrastructure. It automates the deployment, configuration, and management of various services, including Home Assistant, Proxmox, NetBox, and custom applications. The system leverages a custom automation framework, the Model Context Protocol (MCP), for orchestration and integration between components.

## Architecture Overview

The project is structured as a monorepo containing multiple interconnected services and configurations:

-   **`homelab-gitops`**: The core GitOps repository that orchestrates deployments and contains the central documentation.
-   **`api`**: A Node.js backend that serves as the central control plane, integrating with MCP servers and other services.
-   **`dashboard`**: A modern web dashboard (Vite/React) for monitoring and interacting with the homelab environment.
-   **`mcp-servers`**: A collection of specialized automation servers (e.g., for GitHub, Proxmox, Home Assistant) that execute tasks based on the Model Context Protocol.
-   **Agents (`proxmox-agent`, `netbox-agent`)**: Python-based agents responsible for collecting data from and managing specific services like Proxmox and NetBox.
-   **Configuration (`home-assistant-config`)**: Extensive and detailed configuration files for Home Assistant, including automations, custom components, and dashboards.
-   **`docs`**: Contains in-depth documentation covering architecture, deployment plans, standard operating procedures (SOPs), and incident reports.

## Key Components & Files

-   **`homelab-gitops/`**: Main project directory for GitOps orchestration.
-   **`api/server.js`**: The primary entry point for the backend API server.
-   **`dashboard/vite.config.ts`**: Configuration for the frontend dashboard application.
-   **`mcp-servers/`**: Directory containing the various microservice-like automation servers.
-   **`home-assistant-config/configuration.yaml`**: The main configuration file for Home Assistant.
-   **`proxmox-agent/src/`**: Source code for the Proxmox monitoring and management agent.
-   **`netbox-agent/src/`**: Source code for the NetBox inventory and management agent.
-   **`docs/3-TIER-DEPLOYMENT.md`**: Key architectural document outlining the deployment strategy.
-   **`scripts/`**: Contains various deployment, utility, and orchestration shell scripts.

## Core Dependencies

-   **Backend & Tooling**: Node.js, Python
-   **Frontend**: React, Vite, Tailwind CSS
-   **Services**: Docker, Proxmox, Home Assistant, NetBox, Wiki.js, Traefik
-   **Automation**: Git, Shell Scripts, Python Scripts, Model Context Protocol (custom)
 scripts, `create-consolidated-config.py`, `upload-mcp-docs-to-wikijs.py`, and potentially other services like `netbox-agent`), Bash/Shell for various scripts.
*   **Build/Development:** npm/yarn (for Node.js dependency management), Vite (for dashboard build), Jest (for testing), ESLint (for linting), Prettier (for code formatting), Tailwind CSS (for dashboard styling).
*   **External Services:** Git (for version control), potentially Docker/Podman for containerization, Traefik for reverse proxy/load balancing, NetBox, Proxmox, WikiJS, BirdNET-Lite.

## Common Tasks
*   **Setup:**
    *   `./install.sh`: Installs project dependencies.
    *   `./setup-linting.sh`: Configures linting tools.
*   **Development:**
    *   `npm install` (in `api/` and `dashboard/`): Installs Node.js dependencies.
    *   `npm test` or `jest` (in `api/` and `dashboard/`): Runs unit and integration tests.
    *   `npm run dev` (in `dashboard/`): Starts the development server for the dashboard.
*   **Deployment:**
    *   `./deploy-v1.1.0.sh`: Deploys version 1.1.0 of the system.
    *   `./update-production.sh`: Updates the production environment.
    *   `./manual-deploy.sh`: Provides options for manual deployment.
    *   `./1-line-deploy/`: Contains scripts for simplified deployments of specific components.
*   **Validation:**
    *   `./validate-v1.1.0.sh`: Validates the deployed 1.1.0 version.
*   **Maintenance:**
    *   `cleanup-mcp-structure.sh`: Script for cleaning up MCP related structures.
    *   `create-consolidated-config.py`: Python script for managing configurations.
