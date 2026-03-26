# Project Index: workspace

## 1. Core Purpose

This project is a comprehensive homelab management and automation platform. It integrates infrastructure as code (GitOps), home automation, application hosting, and custom development tooling to create a unified and automated personal cloud environment. Key functions include managing virtualized infrastructure, deploying containerized applications, orchestrating smart home devices, and providing a development framework for custom integrations.

## 2. Architecture

The system is built on a multi-tiered architecture:

*   **Infrastructure Layer:** Proxmox VE serves as the hypervisor for virtual machines and LXC containers. Traefik manages ingress, reverse proxying, and service discovery. NetBox provides IPAM and infrastructure documentation.
*   **Automation Layer:** Home Assistant is the central hub for home automation, integrating with Zigbee2MQTT for Zigbee device control. A collection of shell scripts and Python/JavaScript applications (`scripts/`, `mcp-servers/`) automate deployment, configuration, and maintenance tasks.
*   **Application Layer:** A variety of self-hosted services are managed, including BirdNet-Go for audio analysis, WikiJS for documentation, and custom dashboards for monitoring and control.
*   **DevOps & Management Layer:** The `homelab-gitops` directory is the core of the GitOps workflow, defining deployment pipelines and state. A custom "Model Context Protocol" (MCP) is used for standardized communication and management between different services, exposed via a central `api`. Serena appears to be a higher-level orchestration or AI agent framework.

## 3. Key Files

*   `homelab-gitops/PROJECT_OVERVIEW.md`: Provides a high-level overview of the GitOps repository and its goals.
*   `home-assistant-config/configuration.yaml`: The central configuration file for the Home Assistant core, defining all integrations and entities.
*   `api/server.js`: The main entry point for the backend API that orchestrates various components of the homelab.
*   `mcp-servers/README.md`: Documentation for the Model Context Protocol (MCP) servers, which are specialized microservices for various tasks.
*   `1-line-deploy/README.md`: Contains scripts and instructions for simplified, automated deployment of core services.
*   `docs/`: A directory containing extensive documentation, including deployment plans, architectural decisions, and standard operating procedures.
*   `docker-compose.production.yml` (within `homelab-gitops`): Defines the primary application stack for the production environment.

## 4. Dependencies

*   **Core Software:** Proxmox, Docker, Node.js, Python, Go, Home Assistant, Traefik, NetBox, Zigbee2MQTT.
*   **Frameworks & Libraries:** Express.js (for the `api`), React/Vue.js (for frontend dashboards), various Python libraries (e.g., for automation scripts), and Go modules for applications like `birdnet-go`.
*   **Infrastructure:** Requires a server capable of running Proxmox, Zigbee coordination hardware, and various IoT devices (lights, sensors, etc.).
*   **External Services:** GitHub for version control and CI/CD (GitHub Actions).
