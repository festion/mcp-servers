# Project Index: workspace

## 1. Core Purpose
This workspace serves as a comprehensive suite for homelab automation, monitoring, and infrastructure management. It encompasses projects for 3D printing, bird sound detection, various dashboard applications, and a robust GitOps-driven deployment and operational framework for numerous services and agents.

## 2. Architecture
The architecture is distributed and service-oriented, heavily relying on agents, APIs, and microservices for various tasks. Key components include:
*   **GitOps Orchestration:** The `homelab-gitops` repository acts as a central control plane, managing deployments and configurations.
*   **API Layer:** `api` provides backend services, potentially interacting with various agents and external systems.
*   **Frontend/Dashboard:** Multiple frontend applications (`dashboard`, `frontend`, `3ddash`, `fitbit-dashboard`, `pi-status-dashboard`) provide user interfaces for monitoring and control.
*   **Agents/Services:** Numerous specialized agents and MCP servers (`netbox-agent`, `proxmox-agent`, `mcp-servers`, `birdnet-go`, `serena`, `tender`) handle specific tasks, data collection, and integrations.
*   **Infrastructure as Code (IaC):** `homelab-iac` utilizes Ansible and Terraform for provisioning and managing infrastructure.
*   **Operations & Monitoring:** `operations` contains configurations for logging (Fluent Bit, Loki) and monitoring various services, while `github-actions-runner` supports CI/CD workflows.
*   **Home Assistant Integration:** Extensive configuration and custom components for Home Assistant are present (`home-assistant-config`, `hass-ab-ble-gateway-suite`, `unified-adaptive-lighting`).

## 3. Key Files
*   `./deploy-ssh-keys-working.sh`
*   `./verify-dns-migration.sh`
*   `./dashboard/proxy-server.py`
*   `./dashboard/tsconfig.app.json`
*   `./dashboard/README.md`
*   `./dashboard/node_modules/d3-color/README.md`
*   `./dashboard/node_modules/d3-color/package.json`
*   `./dashboard/node_modules/cookie/README.md`
*   `./dashboard/node_modules/cookie/package.json`
*   `./dashboard/node_modules/babel-preset-jest/README.md`
*   `./dashboard/node_modules/babel-preset-jest/package.json`
*   `./dashboard/node_modules/fast-glob/README.md`
*   `./dashboard/node_modules/fast-glob/node_modules/glob-parent/README.md`
*   `./dashboard/node_modules/fast-glob/node_modules/glob-parent/package.json`
*   `./dashboard/node_modules/fast-glob/node_modules/glob-parent/CHANGELOG.md`
*   `./dashboard/node_modules/fast-glob/package.json`
*   `./dashboard/node_modules/d3-interpolate/README.md`
*   `./dashboard/node_modules/d3-interpolate/package.json`
*   `./dashboard/node_modules/@bcoe/v8-coverage/README.md`
*   `./dashboard/node_modules/@bcoe/v8-coverage/LICENSE.md`
*   `./dashboard/node_modules/@bcoe/v8-coverage/package.json`
*   `./dashboard/node_modules/@bcoe/v8-coverage/CHANGELOG.md`
*   `./dashboard/node_modules/@bcoe/v8-coverage/dist/lib/README.md`
*   `./dashboard/node_modules/@bcoe/v8-coverage/dist/lib/LICENSE.md`
*   `./dashboard/node_modules/@bcoe/v8-coverage/dist/lib/package.json`
*   `./dashboard/node_modules/@bcoe/v8-coverage/dist/lib/CHANGELOG.md`
*   `./dashboard/node_modules/@bcoe/v8-coverage/dist/lib/tsconfig.json`
*   `./dashboard/node_modules/@bcoe/v8-coverage/tsconfig.json`
*   `./dashboard/node_modules/camelcase-css/README.md`
*   `./dashboard/node_modules/camelcase-css/package.json`
*   `./dashboard/node_modules/signal-exit/README.md`
*   `./dashboard/node_modules/signal-exit/package.json`
*   `./dashboard/node_modules/signal-exit/dist/cjs/package.json`
*   `./dashboard/node_modules/signal-exit/dist/mjs/package.json`
*   `./dashboard/node_modules/picomatch/README.md`
*   `./dashboard/node_modules/picomatch/package.json`
*   `./dashboard/node_modules/color-convert/README.md`
*   `./dashboard/node_modules/color-convert/package.json`
*   `./dashboard/node_modules/color-convert/CHANGELOG.md`
*   `./dashboard/node_modules/d3-timer/README.md`
*   `./dashboard/node_modules/d3-timer/package.json`
*   `./dashboard/node_modules/@ungap/structured-clone/cjs/package.json`
*   `./dashboard/node_modules/@ungap/structured-clone/README.md`
*   `./dashboard/node_modules/@ungap/structured-clone/package.json`
*   `./dashboard/node_modules/@ungap/structured-clone/.github/workflows/node.js.yml`
*   `./dashboard/node_modules/type-fest/package.json`
*   `./dashboard/node_modules/type-fest/readme.md`
*   `./dashboard/node_modules/is-number/README.md`
*   `./dashboard/node_modules/is-number/package.json`
*   `./dashboard/node_modules/fb-watchman/README.md`

## 4. Dependencies
*   **Node.js/npm:**
    *   `api/package.json`
    *   `dashboard/package.json`
    *   `birdnet-go/package.json`
    *   `gw4-config-tool/package.json`
    *   `homelab-gitops/package.json`
    *   `mcp-servers/package.json`
*   **Go:**
    *   `birdnet-go/go.mod`
    *   `birdnet-gone/go.mod`
    *   `tender/go.mod`
    *   `tender-photos/go.mod`
*   **Python:**
    *   `fitbit-dashboard/requirements.txt`
    *   `hass-ab-ble-gateway-suite/requirements.txt`
    *   `home-assistant-config/requirements-dev.txt`
    *   `netbox-agent/requirements.txt`
    *   `proxmox-agent/requirements.txt`
    *   `model-catalog/pyproject.toml`
    *   `serena/pyproject.toml`
    *   `stormcrow/pyproject.toml`
*   **Ansible/Terraform:**
    *   `homelab-iac/ansible`
    *   `homelab-iac/terraform`
