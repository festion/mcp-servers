# Project Index: Homelab GitOps

## 1. Core Purpose

This repository contains the infrastructure and code for a comprehensive homelab environment managed via GitOps principles. The primary goal is to automate the deployment, configuration, and management of various services, including home automation, network infrastructure, and virtualization. It integrates a suite of open-source tools into a cohesive, centrally-managed system.

## 2. Architecture

The architecture is a multi-component system orchestrated through a central `homelab-gitops` repository. It utilizes an agent-based model for interacting with different parts of the infrastructure.

*   **Frontend:** A web-based dashboard built with Vite and a modern JavaScript framework provides a UI for monitoring and control.
*   **Backend:** A Node.js API (`api/`) serves as the central hub, managing state, orchestrating agents, and exposing endpoints for the frontend.
*   **Agents & Services (`mcp-servers`, `*-agent`):** Numerous specialized services and agents written in Python and shell script interact with specific platforms like Proxmox, NetBox, and Home Assistant.
*   **Home Automation:** A heavily customized Home Assistant instance (`home-assistant-config/`) forms the core of the smart home functionality.
*   **Infrastructure:** The entire system runs on Proxmox for virtualization, with Traefik managing ingress and networking. Services are containerized using Docker.
*   **Documentation:** A WikiJS instance, synchronized via `wikijs-sync-agent`, serves as the knowledge base, with documentation managed as code within the `docs/` directory.

## 3. Key Project Directories

*   `homelab-gitops/`: The primary repository for GitOps workflows, containing deployment scripts and high-level configuration.
*   `api/`: The core backend Node.js application that orchestrates various agents and services.
*   `dashboard/`: The source code for the frontend monitoring and control dashboard.
*   `home-assistant-config/`: The complete configuration for the Home Assistant instance, including automations, custom components, and dashboards.
*   `mcp-servers/`: A collection of custom "Model-Context-Protocol" servers that act as integration bridges to various services.
*   `proxmox-agent/` & `netbox-agent/`: Agents responsible for monitoring and managing the Proxmox and NetBox platforms.
*   `docs/`: Contains all high-level documentation, including architecture diagrams, deployment plans, and incident reports.
*   `scripts/`: A collection of shell and Python scripts for automation, deployment, and maintenance tasks.

## 4. Dependencies

*   **Languages:** JavaScript/TypeScript (Node.js), Python, Shell (Bash)
*   **Frameworks:** Vite, Express.js
*   **Platforms:** Proxmox, Docker, Home Assistant, Traefik, NetBox, WikiJS
*   **Databases:** PostgreSQL (for Home Assistant), SQLite
*   **Tooling:** Git, `npm`, `pre-commit`
