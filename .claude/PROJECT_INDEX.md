# Project Index: workspace

## 1. Core Purpose

This workspace serves as a comprehensive homelab automation, monitoring, and development environment. It integrates various systems for IoT device management (Home Assistant, Zigbee2MQTT), CI/CD pipelines (GitOps, GitHub Actions), network infrastructure (Traefik, NetBox, Proxmox), and custom applications (e.g., Birdnet, Tender, Fitbit dashboard, Serena for AI/automation). The overarching goal appears to be the orchestration and automation of a complex homelab setup, supported by extensive documentation, scripts, and monitoring tools.

## 2. Architecture

The codebase exhibits a distributed, microservices-oriented architecture. Key characteristics include:

*   **Agent-Based Automation**: Dedicated agents (e.g., `netbox-agent`, `proxmox-agent`, various `mcp-servers`) perform specific tasks and interact with respective systems.
*   **API-Driven Communication**: A central `api` directory with Node.js servers (e.g., `server.js`, `server-v2.js`, `websocket-server.js`) likely handles inter-service communication and external integrations.
*   **GitOps for Deployment & Configuration**: The `homelab-gitops` directory indicates a strong emphasis on Git as the single source of truth for infrastructure and application deployment, supported by various `deploy` and `validate` scripts.
*   **Containerization**: Extensive use of Docker/Podman is implied by `docker-compose.yml` files and `Dockerfile`s across multiple projects.
*   **Frontend Applications**: Several directories contain distinct frontend applications (e.g., `dashboard`, `birdnet-go/frontend`, `fitbit-dashboard`, `model-catalog/frontend`), suggesting a user interface layer for various services.
*   **Polyglot Development**: The presence of Python, Go, JavaScript/TypeScript, and Shell scripts indicates a polyglot development approach, leveraging the best tools for specific tasks.

## 3. Key Files

A selection of key files highlighting different aspects of the project:

*   **Deployment & Operations**:
    *   `./deploy-v1.1.0.sh`: A core script for deploying version 1.1.0.
    *   `./homelab-gitops/DEPLOYMENT_ARCHITECTURE.md`: Documents the overall deployment strategy.
    *   `./scripts/deploy-production.sh`: Script for production deployments.
    *   `./TRAEFIK_SETUP_COMPLETE.md`: Documentation related to Traefik proxy setup.
*   **Configuration & Documentation**:
    *   `./config/settings.conf`: Global configuration settings.
    *   `./docs/CONFIGURATION.md`: General configuration documentation.
    *   `./home-assistant-config/configuration.yaml`: Main configuration for Home Assistant.
    *   `./.claude/PROJECT_INDEX.md`: Internal project index for an AI assistant.
*   **API & Backend Services**:
    *   `./api/server-v2.js`: A core API server component.
    *   `./birdnet-go/main.go`: Main entry point for the Birdnet-Go application.
    *   `./mcp-servers/truenas-mcp-server`: Likely a TrueNAS integration service.
*   **Frontend/Dashboard**:
    *   `./dashboard/index.html`: Entry point for a web dashboard.
    *   `./fitbit-dashboard/app.py`: Main application file for the Fitbit dashboard.
*   **Monitoring & Health**:
    *   `./monitor-ha-cluster.sh`: Script for monitoring the Home Assistant cluster.
    *   `./operations/loki.yml`: Configuration for Loki logging system.
*   **Specialized Projects**:
    *   `./3d-print/BirdnetGoneInternals.stl`: A 3D model file, indicating physical project components.
    *   `./hass-ab-ble-gateway-suite/README.md`: Documentation for a Home Assistant BLE gateway.
    *   `./serena/README.md`: Readme for the 'Serena' project (likely an AI or automation tool).

## 4. Dependencies

The project relies on a diverse set of technologies and programming language ecosystems:

*   **Node.js/npm**: Indicated by `package.json`, `package-lock.json`, and `node_modules` directories in `api`, `dashboard`, `gw4-config-tool`, and `homelab-gitops`. Used for API services, web dashboards, and various scripts.
*   **Python/pip**: Evident from `requirements.txt` (e.g., `fitbit-dashboard`, `netbox-agent`, `proxmox-agent`, `hass-ab-ble-gateway-suite`), `pyproject.toml` (`serena`, `model-catalog`, `home-assistant-config`), and `.py` files throughout the codebase. Used for automation, agents, data processing, and dashboards.
*   **Go**: Indicated by `go.mod` and `.go` files in `birdnet-go`, `birdnet-gone`, `tender`, and related `cmd` and `internal` directories. Used for performant backend services and command-line tools.
*   **Shell Scripting**: Numerous `.sh` files are used for deployment, system operations, automation, and various utility tasks across the project.
*   **Container Runtimes**: Docker and Podman are used for packaging and running applications, as indicated by `Dockerfile` and `docker-compose.yml` files.
*   **Home Assistant**: Configuration files (`.yaml`), custom components, and related scripts indicate a heavy reliance on the Home Assistant ecosystem for smart home automation.
*   **Networking/Infrastructure Tools**: Traefik (proxy), NetBox (IPAM/DCIM), Proxmox (virtualization), Git (version control/GitOps), and various monitoring tools like Uptime Kuma and Grafana/Loki.
