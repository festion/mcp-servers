# Project Index

## 1. Core Purpose

This repository contains the infrastructure, configuration, and automation for a comprehensive homelab environment. It uses a GitOps approach to manage various services, including home automation, network monitoring, virtualization, and automated documentation. The system is designed to be highly automated, with custom agents and a central API orchestrating the different components.

## 2. Architecture

The architecture is multi-tiered, consisting of:

*   **Infrastructure Layer:** Proxmox for virtualization, managed alongside NetBox for IPAM and DCIM. Traefik is used as a reverse proxy.
*   **Home Automation Core:** A heavily customized Home Assistant instance serves as the central hub for smart home devices and automations.
*   **GitOps Engine:** The `homelab-gitops` directory is the heart of the repository, containing deployment scripts, CI/CD pipeline configurations, and the production service definitions.
*   **API & Backend Services:** A Node.js API (`api/`) acts as a middleware and orchestration layer, connecting various services through a system referred to as MCP (Model Context Protocol). It manages integrations with GitHub, Wiki.js, and other services.
*   **Frontend:** A modern web dashboard (`dashboard/`) built with Vite provides a user interface for monitoring and interacting with the homelab systems.
*   **AI & Automation Agents:** Several agents (`serena/`, `wikijs-sync-agent/`) are used to automate tasks like documentation generation, system monitoring, and repository management.

## 3. Key Files

*   `homelab-gitops/README.md`: Central documentation for the GitOps deployment and management strategy.
*   `api/server.js`: The main entry point for the backend orchestration API.
*   `dashboard/vite.config.ts`: Configuration for the frontend dashboard application.
*   `home-assistant-config/configuration.yaml`: The primary configuration file for the Home Assistant instance.
*   `docs/3-TIER-DEPLOYMENT.md`: Describes the high-level deployment strategy for the services.
*   `homelab-gitops/docker-compose.production.yml`: Defines the core services running in the production environment.

## 4. Dependencies

*   **Core Technologies:** Docker, Node.js, Python, Bash
*   **Infrastructure:** Proxmox, Home Assistant, NetBox, Wiki.js, Traefik, PostgreSQL
*   **Frameworks & Libraries:** Vite, (React/Vue/Svelte inferred from dashboard config), Express.js (inferred from API)
*   **DevOps:** Git, GitHub Actions, Pre-commit hooks
t, the testing framework used for the API.
-   `api/package.json`: Defines API project metadata, scripts, and Node.js dependencies.
-   `dashboard/index.html`: The root HTML file for the frontend dashboard.
-   `dashboard/vite.config.ts`: Configuration file for Vite, the build tool for the dashboard.
-   `dashboard/tailwind.config.js`: Tailwind CSS configuration for styling the dashboard.
-   `birdnet-gone/README.md`: Provides an overview and instructions for the BirdNET-Gone project.
-   `.mcp/backup-manager.py`: Python script responsible for managing MCP backups.
-   `cron/gitops-schedule`: Defines cron jobs for GitOps-related scheduled tasks.
-   `create-consolidated-config.py`: Python script for generating consolidated configuration files.

## Dependencies

-   **Runtime**: Node.js (for `api`, `dashboard`), Python (for `.mcp` scripts, various utilities), potentially Go (for `birdnet-gone`).
-   **Development/Build**:
    -   `npm`/`yarn`: Package management for Node.js projects.
    -   `Jest`: JavaScript testing framework.
    -   `ESLint`, `Prettier`: Code linting and formatting.
    -   `Vite`: Frontend build tool (for `dashboard`).
    -   `Tailwind CSS`: CSS framework (for `dashboard`).
    -   `TypeScript`: Used for frontend development and potentially some backend components.

## Common Tasks

-   **Project Setup**: Execute `install.sh` from the root directory.
-   **Linting**: Run `setup-linting.sh` or use `npm run lint` within specific Node.js subdirectories (`api`, `dashboard`).
-   **Testing**: Navigate to `api/` or `dashboard/` and run `npm test` or `npx jest`.
-   **Building Frontend**: In the `dashboard/` directory, execute `npm run build`.
-   **Deployment**: Utilize scripts such as `deploy-v1.1.0.sh`, `quick-fix-deploy.sh`, or `update-production.sh` for various deployment scenarios.
