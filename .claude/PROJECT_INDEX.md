# Project Index: workspace

## 1. Core Purpose

This repository contains the infrastructure, configurations, and automation for a comprehensive homelab environment. It uses a GitOps approach to manage a variety of services, including home automation, virtualization, network management, and application hosting. A central theme is the use of a custom Model Context Protocol (MCP) for orchestration and inter-service communication.

## 2. Architecture

The project is structured as a monorepo managed via GitOps principles. Key architectural components include:

*   **Orchestration & API:** A central Node.js API (`/api`) acts as the backend, integrating with various services. It leverages a custom MCP (Model Context Protocol) via specialized servers (`/mcp-servers`) for state management and automation logic.
*   **Home Automation:** A heavily customized Home Assistant instance (`/home-assistant-config`) serves as the core of the smart home, managing devices, automations, and dashboards.
*   **Virtualization & Networking:** The system manages Proxmox for virtualization (`/proxmox-agent`), NetBox for IPAM/DCIM (`/netbox-agent`), and Traefik for reverse proxying and load balancing.
*   **Application Services:** The stack includes a variety of self-hosted applications such as WikiJS for documentation, BirdNet for audio analysis, and custom dashboards (`/dashboard`).
*   **Automation & Deployment:** Deployments and operational tasks are heavily automated using a combination of shell scripts (`/scripts`, `/wrappers`), Python scripts, and GitHub Actions for CI/CD. The `1-line-deploy` system provides a simplified installation path for core components.
*   **3D Printing:** A dedicated section (`/3d-print`) stores models, g-code, and related assets for 3D printing projects.

## 3. Key Files

*   `homelab-gitops/`: The core directory embodying the GitOps workflow and housing production deployment configurations.
*   `home-assistant-config/configuration.yaml`: The main configuration file for the Home Assistant instance.
*   `api/server.js`: The primary entry point for the backend API that orchestrates various services.
*   `mcp-servers/`: Contains the individual microservices that constitute the Model Context Protocol backend.
*   `docs/`: Contains high-level documentation, incident reports, and architecture decision records.
*   `1-line-deploy/`: Scripts and configurations for simplified, single-command deployment of key infrastructure services.
*   `scripts/`: A collection of operational and deployment shell scripts for managing the ecosystem.
*   `TRAEFIK_SETUP_COMPLETE.md`: A key document indicating the setup state of the Traefik reverse proxy.

## 4. Dependencies

*   **Primary Languages:** JavaScript (Node.js), Python, Shell (Bash)
*   **Core Services:** Home Assistant, Proxmox, NetBox, Traefik, Zigbee2MQTT, WikiJS
*   **Frameworks:** Express.js (in API), Vue.js (in Dashboard)
*   **Tools:** Docker, Git, GitHub Actions, Node.js/NPM, Python Poetry/uv
*   **Hardware:** ESP32 devices, 3D printers, various smart home sensors and devices.
