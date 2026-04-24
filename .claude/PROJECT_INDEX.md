# Project Index: workspace

## 1. Core Purpose

This repository contains a comprehensive suite of tools, configurations, and automation scripts for managing a personal homelab environment. It employs GitOps principles to handle infrastructure as code (IaC), application deployments, and ongoing operations. Key functions include home automation (Home Assistant), virtualization management (Proxmox), network documentation (NetBox), and various custom services like bird sound analysis (BirdNet).

## 2. Architecture

The system is architected as a distributed collection of services, agents, and automation scripts, all managed from this central Git repository.

-   **Orchestration**: A custom "Model Context Protocol" (MCP) acts as the central automation engine, with various services and wrappers (`mcp-servers/`, `wrappers/`) to interact with different components of the homelab.
-   **GitOps**: The `homelab-gitops/` directory is the core of the GitOps workflow, defining the desired state of applications and infrastructure.
-   **Infrastructure as Code**: `homelab-iac/` contains Terraform and Ansible configurations for provisioning and managing infrastructure resources.
-   **Agents**: Custom agents (`proxmox-agent/`, `netbox-agent/`) are deployed to monitor and interact with specific systems like the Proxmox virtualization platform and NetBox IPAM.
-   **Core Services**: The system manages several key applications, including Home Assistant (`home-assistant-config/`), BirdNet (`birdnet-go/`), WikiJS, and Traefik.
-   **Frontend**: A web-based `dashboard/` provides a user interface for monitoring and interacting with the homelab environment, powered by a Node.js `api/`.

## 3. Key Files

-   `homelab-gitops/README.md`: Central documentation for the GitOps deployment and management process.
-   `home-assistant-config/configuration.yaml`: The primary configuration file for the Home Assistant instance.
-   `mcp-servers/PROJECT_INDEX.md`: Overview of the custom MCP automation servers.
-   `docs/3-TIER-DEPLOYMENT.md`: High-level architectural documentation describing the deployment strategy.
-   `1-line-deploy/README.md`: Contains scripts and documentation for simplified, one-line deployments of various services.
-   `api/server.js`: The main entry point for the backend API that powers the user dashboard.
-   `proxmox-agent/README.md`: Documentation for the Proxmox monitoring and management agent.
-   `netbox-agent/README.md`: Documentation for the NetBox integration agent.
-   `TRAEFIK_SETUP_COMPLETE.md`: A marker and potential documentation file for the Traefik reverse proxy setup.

## 4. Dependencies

-   **Languages**: Python, Go, JavaScript/TypeScript (Node.js), Shell (Bash)
-   **Frameworks/Libraries**: React/Vue (inferred from `dashboard/` tooling), Express.js (inferred from `api/`)
-   **Infrastructure**: Docker, Ansible, Terraform, Proxmox
-   **CI/CD**: GitHub Actions
-   **Key Applications**: Home Assistant, NetBox, Proxmox, Traefik, WikiJS
