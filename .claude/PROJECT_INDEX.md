# Project Index: workspace

## 1. Core Purpose
This workspace serves as a comprehensive homelab automation and AI-driven management system. It integrates various projects for infrastructure as code, automated deployments, monitoring, and specialized applications. Key areas include Home Assistant configurations, network management, 3D printing workflows, BirdNET analysis, and an AI agent ecosystem for continuous operations and documentation. The `homelab-gitops` project appears to be a central orchestrator, emphasizing a GitOps approach for managing the entire environment.

## 2. Architecture
The codebase exhibits a monorepo structure, hosting numerous distinct, interconnected projects. It features a microservice/agent-based architecture where individual components handle specific functionalities (e.g., `netbox-agent`, `proxmox-agent`, `mcp-servers`, `serena`). Infrastructure and application deployments are driven by a Configuration as Code (GitOps) methodology, utilizing tools like Ansible and Terraform. Many projects include web frontends or dashboards for user interaction, alongside a robust logging and monitoring setup based on Fluent Bit. A significant portion of the architecture is dedicated to home automation via Home Assistant, extended with custom components and management scripts.

## 3. Key Files
*   **`.claude/PROJECT_INDEX.md`**: Overview of AI agent configurations and projects.
*   **`homelab-gitops/README.md`**: Primary documentation and entry point for the GitOps project.
*   **`home-assistant-config/configuration.yaml`**: Core configuration file for the Home Assistant instance.
*   **`api/server.js`, `api/server-v2.js`, `api/websocket-server.js`**: Main entry points for various API services.
*   **`birdnet-go/main.go`, `birdnet-gone/main.go`**: Core Go application files for BirdNET-related projects.
*   **`mcp-servers/README.md`**: Documentation for the Model Context Protocol (MCP) server ecosystem.
*   **`netbox-agent/README.md`**: Documentation for the NetBox integration agent.
*   **`proxmox-agent/README.md`**: Documentation for the Proxmox management agent.
*   **`serena/README.md`**: Documentation for the Serena AI agent/orchestrator.
*   **`docs/DEPLOYMENT-PLANS-SUMMARY.md`**: High-level summary of deployment strategies.
*   **`scripts/deploy.sh`**: A general-purpose deployment script.
*   **`.pre-commit-config.yaml`**: Configuration for pre-commit hooks ensuring code quality.
*   **`package.json`**: Node.js project configuration and dependencies (at root and in subdirectories like `api`, `dashboard`, `gw4-config-tool`, `homelab-gitops`, `mcp-servers`).
*   **`go.mod`**: Go module dependency definitions (found in `birdnet-go`, `birdnet-gone`, `tender` family projects).
*   **`requirements.txt`**: Python package dependencies (e.g., in `fitbit-dashboard`, `netbox-agent`, `proxmox-agent`, `hass-ab-ble-gateway-suite`).
*   **`TRAEFIK_SETUP_COMPLETE.md`**: Documentation detailing Traefik proxy setup.
*   **`backups/RESTORE_INSTRUCTIONS.md`**: Instructions for restoring various system components from backups.

## 4. Dependencies
*   **Languages**: Python, JavaScript/TypeScript, Go, Bash, PowerShell.
*   **Runtimes/Platforms**: Node.js, Python 3, Go.
*   **Web Frameworks/Libraries**: React (inferred for some frontends, e.g., `dashboard`), Express.js (for Node.js APIs), possibly Flask/FastAPI (for Python APIs/dashboards).
*   **Containerization**: Docker, Podman.
*   **Infrastructure as Code**: Ansible, Terraform.
*   **Home Automation**: Home Assistant, MQTT, Zigbee2MQTT.
*   **Monitoring/Logging**: Fluent Bit, Grafana, Loki.
*   **Version Control**: Git (central to GitOps strategy).
*   **Build Tools**: npm/yarn, go mod, pip, Gulp (older projects).
*   **Documentation**: Markdown.
