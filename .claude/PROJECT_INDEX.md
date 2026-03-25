# Project Index: workspace

## 1. Core Purpose

This project is a comprehensive homelab and infrastructure management system, orchestrated through GitOps principles. It integrates various services including home automation (Home Assistant), virtualization (Proxmox), network monitoring (BirdNet, Traefik), and custom application development. The system is designed for high automation, centralized configuration management, and streamlined deployment of services across the homelab environment.

## 2. Architecture

The architecture is a distributed system of interconnected services and agents. A central API (`api/`) and a frontend dashboard (`dashboard/`) provide user interaction and control. Agents (`proxmox-agent`, `netbox-agent`) collect data and perform tasks on different parts of the infrastructure. Home Assistant (`home-assistant-config/`) serves as the core home automation hub. The entire system is managed via version control (`homelab-gitops/`), with deployment and configuration updates handled through automated scripts and a "Model-Context-Protocol" (MCP) for inter-service communication.

## 3. Key Files

-   `homelab-gitops/`: Top-level directory for GitOps-managed infrastructure and application configurations.
-   `home-assistant-config/configuration.yaml`: The main configuration file for the Home Assistant instance.
-   `api/server.js`: The primary entry point for the backend API server.
-   `dashboard/src/`: Source code for the main frontend dashboard application.
-   `proxmox-agent/`: Contains the agent for interacting with the Proxmox virtualization environment.
-   `netbox-agent/`: Contains the agent for interacting with the NetBox IPAM/DCIM tool.
-   `1-line-deploy/`: Scripts and documentation for simplified, one-line deployments of various services.
-   `docs/`: Contains high-level documentation, deployment plans, and incident reports.

## 4. Dependencies

-   **Runtime:** Node.js (for API and frontend), Python (for various scripts and agents), Go (`birdnet-go/`), Bash/Shell (for deployment and automation scripts).
-   **Orchestration:** Docker (as indicated by Dockerfiles and docker-compose files).
-   **Key Libraries/Frameworks:**
    -   **Frontend:** Vue.js or a similar modern JavaScript framework (indicated by `vite.config.ts` in `dashboard/`).
    -   **Backend:** Express.js or similar Node.js framework.
    -   **Automation:** Git, Pre-commit hooks.
