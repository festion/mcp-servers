# Project Index: workspace

## 1. Core Purpose

This repository contains a comprehensive, GitOps-driven framework for managing and automating a complex homelab environment. It integrates various services, including home automation (Home Assistant), infrastructure monitoring (Proxmox, Netbox), and custom applications. The system leverages a custom agent-based orchestration layer, referred to as the Model Context Protocol (MCP), to automate deployment, configuration, and maintenance tasks.

## 2. Architecture

The architecture is a multi-service system orchestrated via GitOps principles and a custom MCP agent framework.

-   **Orchestration Layer**: The `homelab-gitops` project serves as the central control plane. It uses a collection of scripts (`scripts/`, `wrappers/`) and MCP servers (`mcp-servers/`) to manage deployments and state. AI agents (`.claude`, `serena`) are heavily integrated for intelligent automation.
-   **Backend API**: A central Node.js API (`api/`) provides data exchange and control, connecting the frontend dashboard to various backend services and the MCP.
-   **Frontend UI**: A web-based `dashboard/` provides a user interface for monitoring and interacting with the homelab services.
-   **Core Services**: The system manages core homelab applications including Home Assistant (`home-assistant-config/`), Proxmox virtualization (`proxmox-agent/`), and Netbox DCIM (`netbox-agent/`). Traefik is used for reverse proxying and routing.
-   **IoT & Edge Devices**: Includes projects like `birdnet-go` (audio analysis) and `hass-ab-ble-gateway-suite` (Bluetooth Low Energy gateways), indicating integration with physical hardware.

## 3. Key Files

-   **`homelab-gitops/README.md`**: Central documentation for the GitOps deployment and management project.
-   **`api/server.js`**: Main entry point for the backend API service that connects various components.
-   **`dashboard/vite.config.ts`**: Configuration for the frontend dashboard application, indicating a modern TypeScript/Vite-based stack.
-   **`home-assistant-config/configuration.yaml`**: The primary configuration file for the Home Assistant instance.
-   **`mcp-servers/README.md`**: Documentation for the Model Context Protocol (MCP) servers, which form the core of the custom automation engine.
-   **`1-line-deploy/README.md`**: Entry point for the simplified, scripted deployment of various homelab services.
-   **`docs/3-TIER-DEPLOYMENT.md`**: Describes the high-level deployment strategy and architecture.
-   **`TRAEFIK_SETUP_COMPLETE.md`**: Key documentation regarding the setup and configuration of the Traefik reverse proxy.

## 4. Dependencies

-   **Backend**: Node.js, Express.js
-   **Frontend**: TypeScript, Vite (likely with a framework like Vue or React)
-   **Core Applications**: Home Assistant, Proxmox, Netbox, Traefik, Docker
-   **Databases**: PostgreSQL (inferred from Home Assistant scripts)
-   **Scripting**: Python, Bash/Shell
-   **DevOps**: Git, Docker, GitHub Actions, Pre-commit hooks
