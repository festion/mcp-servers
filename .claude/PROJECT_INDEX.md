# Project Index: workspace

## 1. Core Purpose

This repository is a comprehensive monorepo for managing a sophisticated homelab environment using GitOps principles. It automates the deployment, configuration, and management of various services, including home automation (Home Assistant), virtualization (Proxmox), network infrastructure (Traefik, NetBox), and custom applications like BirdNet audio analysis. The project heavily integrates AI and automation through a custom framework referred to as MCP (Model Context Protocol) to streamline operations, documentation, and development workflows.

## 2. Architecture

The architecture is a multi-layered system managed through declarative configurations and automation scripts.

-   **Orchestration & Automation**: The core is managed via GitOps, with deployment scripts (`deploy-*.sh`, `update-production.sh`) and CI/CD pipelines (GitHub Actions) automating the rollout of services. A custom API (`/api`) and various MCP servers (`/mcp-servers`) act as the central control plane.
-   **Infrastructure**: Proxmox is used for virtualization, with agents (`/proxmox-agent`, `/netbox-agent`) for monitoring and management. Traefik handles ingress and routing for containerized services.
-   **Home Automation**: A heavily customized Home Assistant instance (`/home-assistant-config`) serves as the central hub for smart home control, integrated with Zigbee2MQTT, ESPHome, and various custom components.
-   **Applications & Services**: The system runs a suite of services including:
    -   **BirdNet-Go/Gone**: For real-time bird sound identification.
    -   **WikiJS**: As a central documentation platform, with automated content synchronization.
    -   **NetBox**: For network and infrastructure management.
    -   **Dashboards**: Custom frontends (`/dashboard`, `/3ddash`) provide user interfaces for system monitoring and control.
-   **AI Integration**: The `serena` and `mcp-enhanced-servers` components leverage AI models for tasks like automated code commits, documentation generation, and system analysis.

## 3. Key Files

-   **`homelab-gitops/PROJECT_INDEX.md`**: Central documentation for the GitOps deployment and architecture.
-   **`home-assistant-config/configuration.yaml`**: The main configuration file for the Home Assistant instance, defining core integrations and entities.
-   **`api/server.js`**: The primary entry point for the backend API that orchestrates various services and MCP integrations.
-   **`homelab-gitops/docker-compose.production.yml`**: Defines the core services and their configurations for the production environment.
-   **`docs/3-TIER-DEPLOYMENT.md`**: Outlines the high-level deployment strategy and architecture.
-   **`update-production.sh`**: The main script for deploying updates to the production environment.
-   **`/mcp-servers/`**: Directory containing the various microservices that form the Model Context Protocol backend for automation.
-   **`/wrappers/`**: Contains shell scripts that act as simplified interfaces for controlling and interacting with the MCP servers.

## 4. Dependencies

-   **Primary Technologies**:
    -   **Proxmox**: Virtualization platform.
    -   **Docker**: Containerization for running services.
    -   **Home Assistant**: Core home automation platform.
    -   **Node.js**: Backend for the main API and various scripts.
    -   **Python**: Used for automation, MCP servers, and utility scripts.
    -   **Shell (Bash)**: Primary language for deployment and operational scripts.
-   **Key Services**:
    -   **Traefik**: Reverse proxy and load balancer.
    -   **NetBox**: IPAM & DCIM solution.
    -   **WikiJS**: Knowledge base and documentation system.
    -   **Zigbee2MQTT**: For interfacing with Zigbee devices.
    -   **PostgreSQL**: Primary database for Home Assistant and other services.
-   **Development & Operations**:
    -   **Git**: For version control and driving the GitOps workflow.
    -   **GitHub Actions**: For CI/CD and automated tasks.
    -   **ESLint / Prettier**: For code linting and formatting.
    -   **Pre-commit Hooks**: To enforce code quality standards before commits.
