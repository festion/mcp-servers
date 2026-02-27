```markdown
# Project Index

## 1. Core Purpose

This repository contains a comprehensive, GitOps-managed homelab automation and orchestration platform. It automates the deployment, configuration, and management of various services, from infrastructure and networking to smart home applications. The system leverages a custom AI-driven framework (MCP/Serena) to orchestrate complex workflows, maintain documentation, and manage the overall environment.

## 2. Architecture

The architecture is a multi-layered, service-oriented system managed via GitOps principles.

-   **Orchestration Core**: A custom-built Model Context Protocol (MCP) and AI Agent (Serena) framework acts as the central brain, coordinating tasks between different services through a central API.
-   **Infrastructure Layer**: Proxmox is used for virtualization, managed by dedicated agents (`proxmox-agent`, `netbox-agent`) that report to and are controlled by the orchestration layer.
-   **Networking Layer**: Traefik serves as the reverse proxy and ingress controller. DNS and network configurations are managed through GitOps scripts.
-   **Application Layer**: A diverse set of containerized services are managed, including Home Assistant for home automation, BirdNet for audio analysis, and WikiJS for documentation.
-   **API & Frontend**: A central Node.js API (`api/`) exposes control endpoints for the system. Several frontends, including a primary `dashboard`, provide user interfaces for monitoring and interaction.

## 3. Key Files & Directories

-   **`homelab-gitops/`**: The central project defining the GitOps workflow, deployment configurations, and high-level orchestration scripts.
-   **`mcp-servers/`**: Contains the individual microservices that form the MCP, each responsible for managing a specific part of the homelab (e.g., Proxmox, Home Assistant, GitHub).
-   **`home-assistant-config/`**: The complete configuration for the Home Assistant instance, a critical component of the smart home setup.
-   **`api/`**: The central API server that connects the MCP services, agents, and frontends.
-   **`docs/`**: Contains essential documentation, including architectural diagrams, incident reports, and deployment plans.
-   **`scripts/`**: A collection of operational, deployment, and utility shell scripts used throughout the repository.
-   **`birdnet-go/` & `birdnet-gone/`**: Source code and deployment configurations for the BirdNet-Go application.

## 4. Dependencies

-   **Primary Technologies**: Docker, Git, Python, Node.js, Go, Bash
-   **Infrastructure**: Proxmox, Traefik, NetBox
-   **Core Services**: Home Assistant, WikiJS, PostgreSQL, MQTT (inferred)
-   **Development**: Jest, ESLint, Prettier, Vite
```
