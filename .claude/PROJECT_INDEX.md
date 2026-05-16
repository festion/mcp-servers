# Project Index: workspace

## 1. Core Purpose

This repository is a comprehensive monorepo for managing a personal homelab environment. It employs GitOps and Infrastructure-as-Code (IaC) principles to automate the deployment, configuration, and monitoring of a wide range of services. Key areas include home automation, network infrastructure, application hosting, and system monitoring. The system heavily utilizes custom scripting, agent-based automation (MCP), and integrations between various open-source platforms.

## 2. Architecture

The architecture is a multi-layered system built on a Proxmox virtualization environment.

-   **IaC & Configuration Management:** Ansible is used for configuration management (`homelab-iac`), and Terraform for infrastructure provisioning. The entire configuration is managed via Git (`homelab-gitops`), enabling version control and automated deployments.
-   **Service Orchestration:** Docker is used for containerizing applications. Traefik acts as the reverse proxy and load balancer, routing traffic to the various services.
-   **Home Automation:** Home Assistant (`home-assistant-config`) serves as the central hub for smart home devices, automations, and dashboards. It integrates with various custom components and scripts.
-   **Network Services:** AdGuard Home provides network-wide ad-blocking and DNS services. NetBox is used for IPAM and network documentation, with a custom agent (`netbox-agent`) to keep it updated.
-   **Monitoring & Observability:** A robust monitoring stack is in place, using Fluent-bit for log aggregation, Loki for log storage, and Grafana for visualization (`operations`, `pi-status-dashboard`).
-   **Custom Tooling & APIs:** A central API (`api`) and numerous wrapper scripts (`wrappers`, `scripts`) provide orchestration and integration between services. A custom agent framework, "MCP" (Model Context Protocol), is used throughout for complex, automated tasks.
-   **Specialized Applications:** The repository hosts several specific applications, including `birdnet-go` (a bird sound identification service), `3d-print` files for physical manufacturing, and `tender` (a photo sharing application).

## 3. Key Files

-   `homelab-gitops/`: Core project for GitOps-based homelab management, containing application configurations and deployment scripts.
-   `homelab-iac/`: The Infrastructure-as-Code root, containing Ansible playbooks and Terraform configurations for provisioning the entire infrastructure.
-   `home-assistant-config/`: Contains the complete configuration for the Home Assistant instance, including automations, dashboards, and custom components.
-   `mcp-servers/`: Directory for the Model Context Protocol (MCP) servers, which are specialized agents for automating tasks across the homelab (e.g., interacting with TrueNAS, Proxmox, etc.).
-   `operations/`: Contains configurations and scripts for the observability stack, primarily Fluent-bit parsers and pipelines for log collection.
-   `ansible/playbooks/site.yml`: The main Ansible playbook that orchestrates the configuration of the entire homelab.
-   `ansible/roles/traefik/files/dynamic/routers.yml`: Dynamic routing configuration for the Traefik reverse proxy, defining how services are exposed.
-   `netbox-agent/`: A custom-built agent to automatically discover and populate network device information into NetBox.
-   `proxmox-agent/`: A custom agent for monitoring and managing the Proxmox virtualization environment.
-   `birdnet-go/`: A Go-based application for real-time bird sound identification.
-   `wrappers/`: A collection of shell scripts that simplify interaction with various MCP agents and services.

## 4. Dependencies

-   **Primary Platforms:** Proxmox VE, Home Assistant, Docker, Kubernetes (implied via GitOps tooling).
-   **Networking:** Traefik, AdGuard Home, Kea DHCP.
-   **Infrastructure & Automation:** Ansible, Terraform, Git.
-   **Monitoring:** Grafana, Loki, Fluent-bit.
-   **Databases & Services:** PostgreSQL, MQTT (Mosquitto), Zigbee2MQTT, Vaultwarden, Wiki.js, NetBox.
-   **Languages & Runtimes:** Python, Go, Node.js, Bash/Shell.
