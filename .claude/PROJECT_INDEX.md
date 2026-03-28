# Project Index: workspace

This workspace is a comprehensive monorepo managing a sophisticated homelab environment, integrating various automation, monitoring, deployment, 3D printing, and AI/agent development projects. It focuses on self-hosting, smart home capabilities (primarily Home Assistant), robust network management, and custom tooling for enhanced operational control and efficiency.

## Architecture

The codebase employs a polyglot architecture, leveraging:
*   **Python**: For backend services (e.g., MCP servers, Serena AI agent, NetBox agent), Home Assistant automations and scripts, and various utility scripts.
*   **JavaScript/TypeScript**: For web frontends (React/Vite dashboards), Node.js APIs, and GitHub Actions.
*   **Go**: For high-performance applications like the Birdnet projects.
*   **Shell Scripting (Bash/PowerShell)**: Extensively used for automation, deployment, system provisioning, CI/CD pipelines, and general system management, often following GitOps principles.
*   **Containerization**: Docker and Podman are integral for deploying services, often orchestrated with `docker-compose`.
*   **Networking & Proxying**: Traefik is used for reverse proxying and service mesh capabilities.
*   **Monitoring & Logging**: Integrates Fluent Bit, Loki, and Grafana for comprehensive system observability.

## Key Sub-Projects

*   **1-line-deploy**: Streamlined scripts and documentation for rapid deployment of core services like NetBox Agent, Proxmox Agent, WikiJS Integration, and Homepage Dashboard.
*   **3ddash**: Configuration and guides for a 3D dashboard, likely visualizing Home Assistant data or homelab status.
*   **3d-print**: Repository for 3D printing projects, including `.stl` models, `.gcode` print files, calibration data, and rendering outputs.
*   **agent-workspace**: Development and deployment of specialized agents, particularly those utilizing WebSocket communication.
*   **ai-development**: Central directory for AI-related tools, experiments, and agent development.
*   **api**: Node.js API services handling various integrations, including MCP (Multi-Container Platform) management, Serena orchestration, and WebSocket communication.
*   **backups**: Repository for backup archives (e.g., Zigbee2MQTT, Traefik, Omada) and critical troubleshooting documentation.
*   **birdnet-go**: A Go-based application for bird sound detection and analysis.
*   **birdnet-gone**: An evolution or specific deployment variant of the Birdnet system, also written in Go.
*   **dashboard**: A React/Vite frontend application serving as a central monitoring and control interface, often accompanied by a Python proxy.
*   **docs**: Extensive documentation covering deployment strategies, architectural designs, troubleshooting guides, security practices, and operational procedures for the entire homelab.
*   **github-actions-runner**: Setup and configuration for self-hosted GitHub Actions runners, including monitoring and security hardening.
*   **gw4-config-tool**: A web-based (HTML/CSS/JS) configuration utility, likely for a specific gateway or device.
*   **hass-ab-ble-gateway-suite**: Integrations and custom components to enhance Home Assistant's Bluetooth Low Energy (BLE) device management.
*   **home-assistant-config**: The primary Home Assistant configuration, encompassing automations, scripts, device integrations, dashboards, and extensive maintenance and diagnostic tools.
*   **homelab-gitops**: The core GitOps repository, managing infrastructure as code for the homelab, including CI/CD pipelines, deployment manifests, and Infisical secret management integration.
*   **mcp-enhanced-servers**: Advanced MCP server components, such as directory polling systems and documentation tools for Serena.
*   **mcp-servers**: A collection of specialized Multi-Container Platform (MCP) servers (e.g., for GitHub, Home Assistant, Proxmox, TrueNAS, Vikunja, code linting).
*   **model-catalog**: A project for cataloging and managing AI models or prompts, with a frontend and CLI.
*   **netbox-agent**: An agent designed to integrate with NetBox for IP Address Management (IPAM) and Data Center Infrastructure Management (DCIM), including API services and dashboard components.
*   **operations**: Contains operational scripts, Fluent Bit configurations for centralized logging, Loki for log aggregation, and Omada network device management tools.
*   **pi-status-dashboard**: Scripts and Grafana configurations for monitoring Raspberry Pi devices.
*   **proxmox-agent**: An agent for monitoring and managing Proxmox VE hosts, including load monitoring scripts and dashboards.
*   **scripts**: A large collection of general-purpose utility scripts for deployment, configuration, Git operations, and system provisioning.
*   **seed2smoke**: A project with distinct backend and frontend components, accompanied by documentation.
*   **serena**: An AI agent framework, primarily Python-based, designed for automation, documentation generation, and system synchronization.
*   **unified-adaptive-lighting**: Custom components extending Home Assistant's adaptive lighting functionalities.
*   **wrappers**: Shell script wrappers simplifying interaction with various MCP servers and other homelab services.

## Dependencies

*   **Programming Languages**: Python (3.x), Node.js (with npm/yarn), Go, Bash.
*   **Package Managers**: `pip` (Python), `npm` (JavaScript), `go mod` (Go).
*   **Databases**: PostgreSQL (often for Home Assistant), SQLite.
*   **Container Runtimes**: Docker, Podman.
*   **Orchestration**: `docker-compose`.
*   **Version Control**: Git.
*   **CI/CD**: GitHub Actions.
*   **Web Servers/Proxies**: Nginx, Traefik.
*   **Configuration Management**: YAML, JSON, `.env` files, Infisical for secrets.
*   **Frontend Frameworks**: React, Vite.
*   **Home Automation**: Home Assistant, ESPHome, Zigbee2MQTT.
*   **Logging**: Fluent Bit, Loki.
*   **Monitoring**: Grafana, Uptime Kuma, Prometheus.
*   **Tools**: `ripgrep`, `prettier`, `eslint`, `ruff`, `pre-commit`.
