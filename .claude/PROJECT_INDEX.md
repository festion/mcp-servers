# Project Index: Workspace Monorepo

## 1. Core Purpose

This repository is a comprehensive monorepo for managing a personal homelab environment. It combines Infrastructure as Code (IaC), GitOps principles, home automation, custom application development, and system monitoring to create a unified and highly automated platform. The system manages everything from virtualization and networking to IoT devices, 3D printing, and AI-driven automation tasks.

## 2. Architecture

The architecture is a distributed system of interconnected services, managed centrally via a GitOps workflow.

-   **Infrastructure**: Proxmox is used for virtualization, with infrastructure provisioned and managed by Ansible and Terraform (`homelab-iac`).
-   **Orchestration (GitOps)**: The `homelab-gitops` project serves as the central control plane. It uses a custom script-based framework (see `mcp-servers/` and `wrappers/`) to automate configuration, deployment, and management across the homelab.
-   **Home Automation**: [Home Assistant](https://www.home-assistant.io/) is the core home automation engine, with an extensive and heavily customized configuration located in `home-assistant-config/`. This includes custom components (`hass-ab-ble-gateway-suite`), ESPHome device firmware, and complex automation routines.
-   **Applications**: A suite of custom applications provides specialized functionality:
    -   `birdnet-gone`: A Go-based application for bird sound identification and processing.
    -   `netbox-agent` & `proxmox-agent`: Data collection agents that feed system information into NetBox for inventory and documentation.
    -   `api/` & `dashboard/`: A central API and web-based frontend for managing and monitoring the homelab.
    -   `serena`: A personal AI assistant.
-   **Monitoring**: A robust monitoring and logging stack is defined in `operations/`, utilizing Fluent Bit for log shipping and Loki for aggregation, providing deep visibility into all services.
-   **AI Integration**: The system heavily leverages Large Language Models (LLMs), primarily via Claude, for code generation, automation, documentation, and project management, indicated by numerous `.claude` and `.serena` directories.

## 3. Key Files

-   **`homelab-gitops/README.md`**: Central documentation for the GitOps deployment and management workflow.
-   **`home-assistant-config/configuration.yaml`**: The main entry point for the Home Assistant configuration, defining all integrations and entities.
-   **`mcp-servers/`**: Contains the core logic for the custom "Master Control Program" automation framework.
-   **`wrappers/*.sh`**: A collection of high-level shell scripts that act as entry points for common operational tasks (e.g., deployments, backups).
-   **`api/server.js`**: The main entry point for the central management API.
-   **`dashboard/`**: Contains the source code for the unified web frontend.
-   **`docs/`**: High-level architectural documents, deployment plans, and incident reports.
-   **`1-line-deploy/`**: Scripts and documentation for simplified, single-command deployments of various services.

## 4. Dependencies

-   **Core Systems**: Proxmox, Home Assistant, Docker, NetBox, Traefik, Loki, Grafana, Zigbee2MQTT.
-   **IaC/DevOps**: Ansible, Terraform, Git, GitHub Actions.
-   **Languages & Frameworks**: Go, Python, JavaScript/TypeScript (Node.js), Shell.
-   **AI Services**: Anthropic's Claude API.
