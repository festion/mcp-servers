# Project Index: workspace

## 1. Core Purpose
This workspace serves as a comprehensive monorepo for a sophisticated homelab and DevOps environment. Its primary purpose is to manage, automate, and monitor various aspects of personal infrastructure, home automation, and development workflows. It encompasses tools and configurations for home assistant, network management, 3D printing, environmental monitoring, API services, CI/CD pipelines, and AI-driven operational tasks.

## 2. Architecture
The architecture is characterized by a distributed, microservice-oriented approach, integrating a wide array of self-hosted services and custom agents. Key architectural components and patterns include:

*   **Automation & Orchestration**: Extensive use of scripts and custom agents (e.g., in `.mcp`, `mcp-servers`, `serena`) for automating tasks across the homelab, particularly with Home Assistant.
*   **API-Driven Services**: A central `api` directory provides core functionalities, likely interacting with various backend services and external platforms.
*   **Monitoring & Observability**: Dedicated dashboards (`dashboard`, `pi-status-dashboard`) and logging configurations (`operations/fluent-bit-*.yaml`) ensure system health and performance are continuously monitored.
*   **Network & Infrastructure Management**: Integrations with NetBox, Omada, and Proxmox for managing network devices, virtualized environments, and containerized deployments.
*   **CI/CD & Deployment**: Tools and scripts for streamlined deployments (`1-line-deploy`, `homelab-gitops`, GitHub Actions Runner) emphasizing automated and repeatable infrastructure as code principles.
*   **AI/Agent Development**: Directories like `.claude`, `.prompts`, `model-catalog`, and `serena` indicate a strong focus on developing and integrating AI agents for various operational and development support roles.
*   **Polyglot Development**: The codebase utilizes multiple programming languages (Python, JavaScript/TypeScript, Go, Shell scripting) to leverage the strengths of each for specific components.

## 3. Key Files
*   `./monitor-ha-cluster.sh`
*   `./deploy-ssh-keys-v2.sh`
*   `./TRAEFIK_SETUP_COMPLETE.md`
*   `./fix-spa-routing.sh`
*   `./backups/Z2M_LIVINGROOM_DIMMER_ISSUE.md`
*   `./backups/JEREMYS_LAMP_TROUBLESHOOTING.md`
*   `./backups/RESTORE_INSTRUCTIONS.md`
*   `./backups/traefik-ha-20251109/IMPLEMENTATION_LOG.md`
*   `./backups/SLZB06_STABILITY_ANALYSIS.md`
*   `./backups/DEVICE_PAIRING_INSTRUCTIONS.md`
*   `./backups/PAIRING_STATUS.md`
*   `./backups/floorplan_20251101/floorplan_dashboard.yaml`
*   `./backups/ZIGBEE_COORDINATOR_RESET_INCIDENT.md`
*   `./deploy-ssh-keys-simple.sh`
*   `./.claude/agents/gemini-analyzer.md`
*   `./.claude/settings.json`
*   `./.claude/commands/proj.md`
*   `./.claude/commands/project.md`
*   `./.claude/skills/env-intel/datasources.yaml`
*   `./.claude/skills/trends/SKILL.md`
*   `./.claude/skills/changelog/SKILL.md`
*   `./.claude/skills/refresh-infra/SKILL.md`
*   `./.claude/skills/briefing/SKILL.md`
*   `./.claude/skills/investigate/SKILL.md`
*   `./.claude/settings.local.json`
*   `./.claude/PROJECT_INDEX.md`
*   `./validate-v1.1.0.sh`
*   `./deploy-ssh-keys-all.sh`
*   `./1-line-deploy/.claude/PROJECT_INDEX.md`
*   `./1-line-deploy/README.md`
*   `./1-line-deploy/Proxmox-Agent-Deployment.md`
*   `./1-line-deploy/Homepage-Dashboard-Deployment.md`
*   `./1-line-deploy/CLAUDE.md`
*   `./1-line-deploy/Home.md`
*   `./1-line-deploy/ct/wikijs-integration.sh`
*   `./1-line-deploy/ct/netbox-agent.sh`
*   `./1-line-deploy/ct/proxmox-agent.sh`
*   `./1-line-deploy/ct/homepage.sh`
*   `./1-line-deploy/MCP_CONFIGURATION.md`
*   `./1-line-deploy/NetBox-Agent-Deployment.md`
*   `./1-line-deploy/WikiJS-Integration-Deployment.md`
*   `./1-line-deploy/Architecture-Integration.md`
*   `./1-line-deploy/Troubleshooting.md`
*   `./node_modules/engine.io-client/README.md`
*   `./node_modules/engine.io-client/package.json`
*   `./node_modules/engine.io-client/build/esm-debug/package.json`
*   `./node_modules/engine.io-client/build/cjs/package.json`
*   `./node_modules/engine.io-client/build/esm/package.json`
*   `./node_modules/ws/README.md`
*   `./node_modules/ws/package.json`

## 4. Dependencies
The project leverages a diverse set of dependencies across multiple ecosystems:

*   **Node.js/JavaScript**: Evidenced by `node_modules` directories and `package.json` files in `api`, `dashboard`, `homelab-gitops`, and the root. Specific packages include `engine.io-client` and `ws`, indicating WebSocket communication.
*   **Python**: Numerous `requirements.txt` files (e.g., `fitbit-dashboard`, `hass-ab-ble-gateway-suite`, `netbox-agent`, `proxmox-agent`, `serena`, `model-catalog`) and `pyproject.toml` (e.g., `home-assistant-config`, `model-catalog`, `serena`) suggest heavy reliance on Python for scripting, backend services, and Home Assistant integrations.
*   **Go**: The `birdnet-go` and `birdnet-gone` directories contain `go.mod` and `go.sum` files, indicating Go is used for these applications.
*   **Shell Scripting**: Extensive use of `.sh` and `.ps1` files for automation, deployment, and system management across the entire workspace.
*   **Containerization**: `Dockerfile` and `docker-compose.yml` files (e.g., in `birdnet-go`, `birdnet-gone`, `homelab-gitops`, `netbox-agent`, `serena`) indicate a strong use of Docker for isolating and deploying services.
*   **Home Assistant Integrations**: Custom components and configurations specific to Home Assistant are present in `home-assistant-config` and `hass-ab-ble-gateway-suite`.
I have finished generating the `PROJECT_INDEX.md` file.
