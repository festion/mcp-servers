# Project Index

This document provides a high-level overview of the monorepo for a comprehensive homelab and automation infrastructure.

## 1. Core Purpose

This repository orchestrates a suite of services for home automation, network monitoring, and infrastructure management. It uses a GitOps methodology to automate deployment, configuration, and maintenance of services like Home Assistant, BirdNet-Go (a bird sound classification service), Proxmox virtualization, NetBox IPAM, and more. A custom orchestration layer, referred to as MCP (Model Context Protocol), is used to manage and integrate these components.

## 2. Architecture

The architecture is a container-based, service-oriented system managed via GitOps principles.

-   **Orchestration**: A custom-built system involving `mcp-servers` and `serena` for automation and inter-service communication. AI agents (`.claude/`, `.serena/`) are integrated for development and operational tasks.
-   **Containerization**: Most services are deployed as Docker containers, with configurations defined in `docker-compose` files and deployment scripts.
-   **Core Services**:
    -   **`home-assistant-config`**: Manages a highly customized Home Assistant instance for smart home control.
    -   **`birdnet-go` / `birdnet-gone`**: Go-based applications for real-time bird sound identification.
    -   **`api`**: A central Node.js API to integrate and manage various backend services.
    -   **`dashboard` / `frontend`**: Web interfaces for user interaction with the system.
    -   **`netbox-agent` / `proxmox-agent`**: Agents for monitoring and managing the underlying infrastructure on NetBox and Proxmox.
-   **Automation**: Extensive use of shell scripts (`.sh`), Python, and Node.js for deployment, backups, and maintenance tasks.

## 3. Key Files

-   `homelab-gitops/README.md`: Central documentation for the GitOps deployment process.
-   `homelab-gitops/docker-compose.production.yml`: Defines the core production services stack.
-   `home-assistant-config/configuration.yaml`: Primary configuration file for the Home Assistant instance.
-   `mcp-servers/`: Contains the core logic for the custom MCP automation servers.
-   `api/server.js`: The main entry point for the backend API services.
-   `docs/`: Contains high-level documentation, deployment plans, and incident reports.
-   `scripts/`: A collection of operational and deployment scripts.

## 4. Dependencies

The project is polyglot and relies on several key technologies:

-   **Primary Languages**: Go, Node.js (JavaScript/TypeScript), Python, and Shell (Bash).
-   **Frameworks/Runtimes**: Docker, Node.js, Python (various libraries), Go standard library.
-   **Key Applications**: Home Assistant, Proxmox VE, NetBox, Wiki.js, Traefik.
-   **Databases**: PostgreSQL (for Home Assistant), SQLite.
-   **Configuration**: YAML, JSON.