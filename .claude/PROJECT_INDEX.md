# Project Index

## 1. Core Purpose

This repository contains a comprehensive suite of tools and configurations for managing a sophisticated homelab environment using a GitOps methodology. It automates the deployment, configuration, and monitoring of various services, including Home Assistant, Proxmox, NetBox, and custom applications. The primary goal is to maintain an infrastructure-as-code approach to ensure consistency, reliability, and ease of management.

## 2. Architecture

The project is structured as a monorepo with several key components:

-   **`homelab-gitops`**: The core GitOps engine, containing deployment scripts, CI/CD pipelines, and high-level configuration.
-   **`home-assistant-config`**: An extensive collection of configurations, automations, scripts, and custom components for Home Assistant.
-   **`mcp-servers`**: A suite of Node.js-based servers (Model Context Protocol) that act as agents or connectors to various services like Proxmox, TrueNAS, GitHub, and Wiki.js.
-   **`api`**: A central Node.js API that orchestrates interactions between the frontend, MCP servers, and other services.
-   **`dashboard`**: A modern frontend application (Vite/TypeScript) for monitoring and interacting with the homelab environment.
-   **Agents (`netbox-agent`, `proxmox-agent`)**: Standalone agents written in Python to gather data and perform actions on specific platforms.
-   **`operations`**: Contains infrastructure monitoring and logging configurations, primarily using Fluent Bit and Loki.
-   **`docs`**: Centralized repository for all project documentation, including architecture, deployment plans, and standard operating procedures.

## 3. Key Files

-   **`homelab-gitops/PROJECT_OVERVIEW.md`**: Main overview of the GitOps project.
-   **`home-assistant-config/configuration.yaml`**: The primary entry point for Home Assistant configuration.
-   **`api/server.js`**: Main server file for the central API.
-   **`dashboard/vite.config.ts`**: Configuration file for the frontend dashboard application.
-   **`mcp-servers/README.md`**: Describes the purpose and function of the MCP servers.
-   **`docs/3-TIER-DEPLOYMENT.md`**: Outlines the high-level deployment architecture.
-   **`docker-compose.production.yml`**: Defines the production services for the core platform.

## 4. Dependencies

-   **Languages**: JavaScript (Node.js), Python, Go, Shell (Bash)
-   **Frameworks/Platforms**: Docker, Home Assistant, Proxmox, NetBox, Traefik, Node.js
-   **Frontend**: Vite, TypeScript, Tailwind CSS
-   **Tooling**: npm, git, ESLint, Prettier, Fluent Bit, Loki
manager.py`: Key script for handling automated backups of various services.
*   `1-line-deploy/ct/*.sh`: A collection of scripts for deploying specific applications (e.g., `homepage.sh`, `netbox-agent.sh`) as containers.
*   `create-consolidated-config.py`: A utility script for aggregating various configuration sources into a unified format.
*   `PROJECT_INDEX.md`: This file, providing a high-level overview for developers and AI assistants.

## 4. Dependencies

*   **Runtime Dependencies:**
    *   **Node.js:** For the backend API (`/api`).
    *   **Python 3:** For the MCP scripts and other automation utilities.
    *   **Bash/