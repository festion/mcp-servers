# Project Index: workspace

## 1. Core Purpose
This workspace appears to be a comprehensive homelab and DevOps platform, integrating various tools and services for automation, monitoring, deployment, and management of home infrastructure. It includes components for continuous integration/deployment (CI/CD), API services, Home Assistant configurations, 3D printing management, network agents, and specialized tools for managing different aspects of a home network and smart devices.

## 2. Architecture
The architecture seems to be modular and distributed, comprising:
*   **API Services:** Node.js-based APIs (e.g., `api/server.js`, `homelab-gitops/api`) likely serving as central integration points for various agents and frontends.
*   **Frontend Applications:** Several frontend projects (e.g., `dashboard`, `frontend`, `birdnet-go/frontend`, `model-catalog/frontend`) suggest web-based user interfaces for monitoring, configuration, and interaction.
*   **Agents and Integrations:** A multitude of specialized agents (e.g., `netbox-agent`, `proxmox-agent`, `wikijs-sync-agent`, `mcp-servers/*-mcp-server`) designed to interact with specific systems and services (NetBox, Proxmox, Wiki.js, Home Assistant, etc.).
*   **Configuration Management:** Extensive use of `.yaml`, `.json`, and `.conf` files across various directories (e.g., `config`, `home-assistant-config`, `homelab-gitops/config`) indicates a strong focus on declarative configuration.
*   **Deployment & Operations:** Scripts and tools for deployment (`1-line-deploy`, `deploy-v1.1.0.sh`, `homelab-gitops/scripts`), monitoring (`monitor-ha-cluster.sh`, `pi-status-dashboard`), and general operations (`operations` directory).
*   **Documentation:** Dedicated `docs` directories and `PROJECT_INDEX.md` files within subprojects highlight an emphasis on comprehensive documentation.

## 3. Key Files
*   `./monitor-ha-cluster.sh`: Script for monitoring the Home Assistant cluster.
*   `./deploy-ssh-keys-v2.sh`: Version 2 script for deploying SSH keys.
*   `./TRAEFIK_SETUP_COMPLETE.md`: Documentation indicating the completion of Traefik setup.
*   `./fix-spa-routing.sh`: Script to fix single-page application routing issues.
*   `./backups/Z2M_LIVINGROOM_DIMMER_ISSUE.md`: Documentation on a Zigbee2MQTT living room dimmer issue.
*   `./backups/JEREMYS_LAMP_TROUBLESHOOTING.md`: Troubleshooting guide for a specific lamp.
*   `./backups/RESTORE_INSTRUCTIONS.md`: Instructions for restoring backups.
*   `./backups/traefik-ha-20251109/IMPLEMENTATION_LOG.md`: Implementation log for Traefik HA on a specific date.
*   `./backups/SLZB06_STABILITY_ANALYSIS.md`: Stability analysis for SLZB06.
*   `./backups/DEVICE_PAIRING_INSTRUCTIONS.md`: Instructions for device pairing.
*   `./backups/PAIRING_STATUS.md`: Status of device pairing.
*   `./backups/floorplan_20251101/floorplan_dashboard.yaml`: Floorplan dashboard configuration.
*   `./backups/ZIGBEE_COORDINATOR_RESET_INCIDENT.md`: Documentation on a Zigbee coordinator reset incident.
*   `./deploy-ssh-keys-simple.sh`: Simple script for deploying SSH keys.
*   `./.claude/agents/gemini-analyzer.md`: Gemini analyzer agent documentation.
*   `./.claude/settings.json`: Claude agent settings.
*   `./.claude/commands/proj.md`: Claude command documentation for 'proj'.
*   `./.claude/commands/project.md`: Claude command documentation for 'project'.
*   `./.claude/skills/env-intel/datasources.yaml`: Datasources for environment intelligence skill.
*   `./.claude/skills/trends/SKILL.md`: Documentation for the trends skill.
*   `./.claude/skills/changelog/SKILL.md`: Documentation for the changelog skill.
*   `./.claude/skills/refresh-infra/SKILL.md`: Documentation for the refresh infrastructure skill.
*   `./.claude/skills/briefing/SKILL.md`: Documentation for the briefing skill.
*   `./.claude/skills/investigate/SKILL.md`: Documentation for the investigate skill.
*   `./.claude/settings.local.json`: Local settings for Claude agent.
*   `./.claude/PROJECT_INDEX.md`: Project index for Claude agent.
*   `./validate-v1.1.0.sh`: Script to validate version 1.1.0.
*   `./.mcp.json`: Model Context Protocol (MCP) configuration.
*   `./deploy-ssh-keys-all.sh`: Script to deploy SSH keys to all systems.
*   `./1-line-deploy/.claude/PROJECT_INDEX.md`: Project index for 1-line-deploy Claude agent.
*   `./1-line-deploy/README.md`: README for the 1-line-deploy project.
*   `./1-line-deploy/Proxmox-Agent-Deployment.md`: Proxmox agent deployment documentation for 1-line-deploy.
*   `./1-line-deploy/Homepage-Dashboard-Deployment.md`: Homepage dashboard deployment documentation for 1-line-deploy.
*   `./1-line-deploy/CLAUDE.md`: Claude agent documentation for 1-line-deploy.
*   `./1-line-deploy/Home.md`: Home documentation for 1-line-deploy.
*   `./1-line-deploy/ct/wikijs-integration.sh`: Wiki.js integration script for 1-line-deploy.
*   `./1-line-deploy/ct/netbox-agent.sh`: NetBox agent script for 1-line-deploy.
*   `./1-line-deploy/ct/proxmox-agent.sh`: Proxmox agent script for 1-line-deploy.
*   `./1-line-deploy/ct/homepage.sh`: Homepage script for 1-line-deploy.
*   `./1-line-deploy/MCP_CONFIGURATION.md`: MCP configuration documentation for 1-line-deploy.
*   `./1-line-deploy/NetBox-Agent-Deployment.md`: NetBox agent deployment documentation for 1-line-deploy.
*   `./1-line-deploy/WikiJS-Integration-Deployment.md`: Wiki.js integration deployment documentation for 1-line-deploy.
*   `./1-line-deploy/Architecture-Integration.md`: Architecture integration documentation for 1-line-deploy.
*   `./1-line-deploy/Troubleshooting.md`: Troubleshooting documentation for 1-line-deploy.
*   `./node_modules/engine.io-client/README.md`: README for engine.io-client.
*   `./node_modules/engine.io-client/package.json`: package.json for engine.io-client.
*   `./node_modules/engine.io-client/build/esm-debug/package.json`: package.json for engine.io-client esm-debug build.
*   `./node_modules/engine.io-client/build/cjs/package.json`: package.json for engine.io-client cjs build.
*   `./node_modules/engine.io-client/build/esm/package.json`: package.json for engine.io-client esm build.
*   `./node_modules/ws/README.md`: README for 'ws' (websocket) package.

## 4. Dependencies
*   **JavaScript/Node.js:** Evidenced by `package.json` and `node_modules` directories in `api/`, `dashboard/`, `homelab-gitops/`, `gw4-config-tool/`, and `wikijs-sync-agent/`. Specific packages include `engine.io-client`, `ws`, `debug`, `socket.io-client`, and `@modelcontextprotocol`.
*   **Python:** Indicated by `.py` files throughout the repository (e.g., `create-consolidated-config.py`, `upload-mcp-docs-to-wikijs.py`, `mcp-enhanced-servers/*.py`), `requirements.txt` (in `netbox-agent/`, `hass-ab-ble-gateway-suite/`, `proxmox-agent/`), and `pyproject.toml` (in `home-assistant-config/`, `model-catalog/`, `serena/`).
*   **Go:** Suggested by `birdnet-go/` and `birdnet-gone/` directories, which typically contain `go.mod` and `go.sum` files.
*   **Shell Scripts:** Numerous `.sh` files for automation, deployment, and system management.
