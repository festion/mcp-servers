# Project Index

## 1. Core Purpose

This repository contains a comprehensive homelab management and automation platform built around GitOps principles. It automates the deployment, configuration, and monitoring of various services, including Home Assistant, Proxmox, Netbox, and more. The system is designed to be highly modular, with a central API, specialized agents, and a unified dashboard for control and visibility.

## 2. Architecture

The architecture is a multi-component system orchestrated via a central GitOps repository.

-   **Backend API (`/api`)**: A Node.js/Express-based server that acts as the central control plane, managing state and orchestrating agents.
-   **Frontend Dashboard (`/dashboard`)**: A Vite/React-based single-page application providing a user interface for monitoring and interacting with the homelab services.
-   **Service Agents (`/netbox-agent`, `/proxmox-agent`)**: Standalone applications responsible for integrating with specific services (Proxmox, Netbox) and reporting data back to the main API.
-   **MCP Servers (`/mcp-servers`)**: A collection of specialized microservices (Model Context Protocol) that handle specific tasks like GitHub integration, Home Assistant automation, and system polling.
-   **Home Automation (`/home-assistant-config`)**: Extensive configuration and automation scripts for the Home Assistant instance, managing a wide array of devices and scenes.
-   **Deployment & Operations (`/scripts`, `/homelab-gitops`)**: A suite of shell scripts and configuration files that manage the entire lifecycle of the platform, from initial setup to production updates, following GitOps best practices.
-   **Documentation (`/docs`, `/wikijs-sync-agent`)**: Centralized project documentation, plans, and standard operating procedures, with an agent to sync content to a Wiki.js instance.

## 3. Key Files & Directories

-   `homelab-gitops/`: The core GitOps repository defining the desired state of the entire system.
-   `api/server.js`: The entry point for the main backend API.
-   `dashboard/src/`: The source code for the frontend user interface.
-   `home-assistant-config/configuration.yaml`: The primary configuration file for Home Assistant.
-   `mcp-servers/`: Directory containing various specialized backend microservices.
-   `netbox-agent/src/`: Source code for the NetBox integration agent.
-   `proxmox-agent/src/`: Source code for the Proxmox integration agent.
-   `docs/`: Contains high-level architecture, deployment plans, and incident reports.
-   `scripts/`: Contains critical deployment, validation, and operational scripts.

## 4. Dependencies

-   **Primary Languages**: JavaScript (Node.js), Python, Bash/Shell
-   **Frameworks**: Express.js (API), React/Vite (Dashboard)
-   **Key Services**: Home Assistant, Proxmox, Netbox, Traefik, Wiki.js, Zigbee2MQTT, Docker
-   **Tooling**: Git, GitHub Actions, Pre-commit, ESLint, Prettier
-   **Databases**: PostgreSQL (for Home Assistant), SQLite (for agents/tooling)
