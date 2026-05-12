# Project Index: workspace

## 1. Core Purpose

This repository contains a comprehensive suite of tools, configurations, and applications for managing a sophisticated homelab environment. It automates infrastructure provisioning, service deployment, monitoring, and home automation tasks. The system leverages a GitOps methodology and a custom agent-based framework (MCP) to maintain and operate various services, from network infrastructure to IoT devices.

## 2. Architecture

The architecture is a distributed system composed of several key layers:

*   **Infrastructure & Virtualization:** Proxmox is used as the hypervisor, managed via Infrastructure as Code (IaC) with tools like Ansible and Terraform found in `homelab-iac`.
*   **Orchestration & Deployment:** A GitOps workflow, centered in the `homelab-gitops` directory, automates the deployment of services. Custom shell scripts (`deploy-*.sh`, `1-line-deploy`) provide streamlined installation procedures.
*   **Home Automation Hub:** Home Assistant (`home-assistant-config`) serves as the central controller for smart home devices, scenes, and automations, integrating with Zigbee2MQTT, ESPHome, and various custom components.
*   **Agent-Based Automation (MCP):** A custom "Model Context Protocol" (`mcp-servers`, `wrappers`) is used to create specialized agents that perform tasks like system monitoring (`proxmox-agent`), network inventory (`netbox-agent`), and interacting with other services.
*   **API & Backend Services:** A central Node.js API (`api/`) facilitates communication between the frontend dashboards and various backend agents and services.
*   **Monitoring & Logging:** A centralized logging stack using Fluent-bit, Loki, and Grafana (`operations/`) collects and visualizes logs and metrics from across the entire homelab.
*   **Frontend:** Multiple web-based dashboards (`dashboard/`, `3ddash/`) provide user interfaces for controlling services and viewing data.

## 3. Key Files

*   `homelab-gitops/README.md`: Describes the core GitOps workflow for managing the entire homelab.
*   `home-assistant-config/configuration.yaml`: The main configuration file for the central home automation system.
*   `mcp-servers/README.md`: Provides an overview of the custom agent-based automation framework (MCP).
*   `1-line-deploy/README.md`: Documentation for the simplified, one-line deployment scripts for core services.
*   `api/server.js`: The primary entry point for the backend API that connects various system components.
*   `operations/README.md`: Outlines the monitoring and logging infrastructure based on Fluent-bit and Loki.
*   `proxmox-agent/README.md`: Documentation for the agent responsible for monitoring the Proxmox virtualization environment.
*   `netbox-agent/README.md`: Documentation for the agent that syncs infrastructure state with NetBox.
*   `docs/`: Contains high-level documentation, deployment plans, and incident reports.

## 4. Dependencies

*   **Primary Platforms:** Proxmox, Home Assistant, NetBox, Traefik, Docker, WikiJS.
*   **Languages:** Python, Go, JavaScript/TypeScript, Shell.
*   **IaC & Automation:** Ansible, Terraform, Git.
*   **Backend:** Node.js.
*   **Monitoring:** Fluent-bit, Loki, Grafana.
*   **IoT/Home Automation:** Zigbee2MQTT, ESPHome, MQTT.
*   **3D Printing:** G-code and STL files for various custom parts are stored in `3d-print/`.
