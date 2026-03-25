# Project Index: workspace

## 1. Core Purpose

This repository serves as a comprehensive management and automation platform for a personal homelab environment. It utilizes a GitOps approach to manage infrastructure, applications, and configurations. Key functions include Home Assistant automation, 3D printing management, system monitoring with agents for Proxmox and NetBox, and a custom AI-driven orchestration system (MCP/Serena/Claude) for complex task automation and self-management.

## 2. Architecture

The architecture is a multi-layered system centered around the `homelab-gitops` directory, which acts as the single source of truth.

-   **Orchestration & Automation:** A custom "Model Context Protocol" (MCP) is implemented through various servers (`mcp-servers`) and wrappers (`wrappers`). These interact with different services like Home Assistant, Proxmox, GitHub, and TrueNAS. AI agents (`.claude`, `.serena`, `agent-workspace`) are used to automate complex workflows, documentation, and code management.
-   **API & Frontend:** A central API (`api/`) built on Node.js orchestrates backend services and agents. A Vue.js dashboard (`dashboard/`) provides a user interface for monitoring and control.
-   **Home Automation:** A significant portion of the repository is dedicated to Home Assistant (`home-assistant-config`), including custom components, dashboards, automations, and device integrations (Zigbee2MQTT, ESPHome).
-   **Infrastructure & Deployment:** Infrastructure is managed via scripts for Proxmox, Docker containers, and network services like Traefik. Deployment is automated through shell scripts (`1-line-deploy`, `deploy-*.sh`) and GitHub Actions.
-   **Monitoring & Logging:** The `operations` directory contains configurations for logging and monitoring tools like Fluent Bit and Loki, providing visibility into the health of various services.

## 3. Key Files

-   **`homelab-gitops/`**: The core GitOps repository containing the desired state of the entire system.
-   **`home-assistant-config/configuration.yaml`**: The main configuration file for the Home Assistant instance, defining integrations and core setup.
-   **`mcp-servers/`**: Contains the various microservice-like servers that form the backbone of the MCP automation system.
-   **`api/server.js`**: The entry point for the main Node.js API that connects many of the project's components.
-   **`1-line-deploy/`**: Contains scripts and documentation for simplified, one-command deployment of various services.
-   **`docs/`**: A central location for system documentation, incident reports, and standard operating procedures.
-   **`wrappers/`**: A collection of shell scripts that act as simplified interfaces or entry points for controlling the various MCP servers.
-   **`operations/`**: Manages the operational aspects of the homelab, including logging (Fluent Bit, Loki) and monitoring configurations.

## 4. Dependencies

-   **Primary Languages:** Python, JavaScript/TypeScript, Shell (Bash)
-   **Core Technologies:** Git, Docker, Node.js, Home Assistant, Proxmox VE
-   **Key Services:** Traefik, NetBox, Wiki.js, Zigbee2MQTT, Fluent Bit, Loki
-   **Frameworks:** Vue.js (for the dashboard)
-   **Configuration Management:** YAML, JSON, Shell Scripts
