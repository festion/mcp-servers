# Project Index: workspace

## 1. Core Purpose

This repository contains a comprehensive homelab management and automation platform, orchestrated using GitOps principles. It integrates various services like Home Assistant, Proxmox, NetBox, and BirdNet for monitoring and managing a smart home and server infrastructure. The system heavily leverages AI-driven agents (Serena/Claude) and a custom Model Context Protocol (MCP) for automated tasks, documentation, and system maintenance.

## 2. Architecture

The architecture is a distributed system of services, agents, and automation scripts managed centrally through this Git repository.

-   **Orchestration & GitOps:** The `homelab-gitops` directory is the core, containing deployment scripts, configuration, and CI/CD pipeline definitions. It follows a GitOps model where the repository is the single source of truth for the system's state.
-   **API & Backend Services:** A Node.js-based API in the `/api` directory serves as the central communication hub, connecting various services and managing interactions with the MCP servers.
-   **Agent-Based Automation (MCP):** The `/mcp-servers` and `/wrappers` directories define a set of specialized agents that perform tasks like auto-commits, linting, system monitoring (Proxmox, TrueNAS), and integrations with services like Home Assistant.
-   **Infrastructure:** The system runs on Proxmox for virtualization, uses Docker for containerization, and Traefik for reverse proxying and load balancing.
-   **Applications & Services:** It manages a suite of applications including:
    -   `home-assistant-config`: Smart home automation.
    -   `netbox-agent` & `proxmox-agent`: Infrastructure and virtualization management.
    -   `birdnet-go` / `birdnet-gone`: Wildlife sound monitoring.
    -   `dashboard` / `frontend`: Custom user interfaces for system management.
-   **AI & Documentation:** Integrated AI agents (`.claude/`, `serena/`) are used for code generation, documentation (`PROJECT_INDEX.md`), and automating operational tasks.

## 3. Key Files

-   `homelab-gitops/PROJECT_INDEX.md`: Main entry point for understanding the GitOps deployment architecture and processes.
-   `api/server.js`: The primary Node.js server application that orchestrates backend services.
-   `mcp-servers/`: Directory containing the core logic for the various Model Context Protocol (MCP) agents that automate system tasks.
-   `home-assistant-config/configuration.yaml`: The main configuration file for the Home Assistant instance, defining integrations and devices.
-   `docker-compose.production.yml` (in `homelab-gitops`): Defines the production services and their configurations for Docker deployment.
-   `1-line-deploy/`: Contains streamlined scripts for deploying core services like the Homepage Dashboard, NetBox Agent, and Proxmox Agent.
-   `scripts/`: A collection of essential operational and deployment scripts for managing the entire stack.
-   `docs/`: Contains high-level documentation, deployment plans, incident reports, and standard operating procedures.

## 4. Dependencies

-   **Platforms:** Proxmox (Virtualization), Docker (Containerization), Home Assistant (Home Automation), Traefik (Networking).
-   **Languages:** JavaScript/TypeScript (Node.js for API/backend), Python (automation, agents), Go (`birdnet-go`), Shell (deployment/ops).
-   **Frameworks/Libraries:** Node.js, React (for dashboards), Vue (likely in `dashboard`).
-   **Databases:** PostgreSQL (used by Home Assistant), SQLite (used by various components).
-   **Tools:** Git, GitHub Actions (CI/CD), Zigbee2MQTT, ESPHome.
