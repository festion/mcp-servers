# Project Index: workspace

## 1. Core Purpose

This repository contains a comprehensive GitOps-managed homelab infrastructure. It automates the deployment, configuration, and management of various services including home automation (Home Assistant), virtualization (Proxmox), network services (Traefik, AdGuard), and custom applications. The system leverages AI agents and a custom Model Context Protocol (MCP) for advanced automation, monitoring, and self-management.

## 2. Architecture

The architecture is a multi-layered system orchestrated through GitOps principles.

-   **Infrastructure Layer:** Proxmox is used for virtualization, running various LXCs and VMs for core services.
-   **Service Layer:** Docker containers manage most applications, including Home Assistant, WikiJS, NetBox, and custom-built APIs. Traefik handles reverse proxying and ingress.
-   **Automation & Management:** A custom **Model Context Protocol (MCP)** is used for inter-service communication and state management. AI agents (`.claude/`, `serena/`) interact with this system to perform complex tasks. A suite of shell scripts (`scripts/`, `wrappers/`) and Node.js applications (`api/`) provide the backbone for deployment and orchestration.
-   **Monitoring & Logging:** A centralized logging stack using Fluent Bit and Loki is deployed under the `operations` directory to collect and analyze logs from all services.
-   **CI/CD:** GitHub Actions are used for continuous integration and deployment, triggered by commits to this repository.

## 3. Key Files

-   `homelab-gitops/`: Core directory for the GitOps deployment configurations and high-level orchestration scripts.
-   `api/server.js`: The main entry point for the custom API that integrates various services.
-   `home-assistant-config/configuration.yaml`: The primary configuration file for the Home Assistant instance, defining integrations and devices.
-   `mcp-servers/`: Contains the various microservices that implement the Model Context Protocol for different parts of the infrastructure.
-   `docs/`: Contains high-level documentation, incident reports, and standard operating procedures (SOPs).
-   `scripts/`: A collection of utility and deployment scripts for managing the infrastructure.
-   `operations/`: Configuration for the monitoring and logging stack (Fluent Bit, Loki).
-   `1-line-deploy/`: Contains scripts and documentation for simplified, single-command deployments of various services.

## 4. Dependencies

-   **Primary Technologies:** Git, Docker, Proxmox, Home Assistant, Python, Node.js, Bash.
-   **Networking:** Traefik, AdGuard DNS.
-   **Monitoring:** Fluent Bit, Loki, Grafana.
-   **Databases:** PostgreSQL (for Home Assistant), SQLite.
-   **Development:** Pre-commit hooks for linting and validation (`.pre-commit-config.yaml`).
