# Project Index: workspace

## 1. Core Purpose
This workspace serves as a comprehensive GitOps-driven homelab and development platform. Its core purpose includes:
*   **Infrastructure Automation & Management:** Deploying, configuring, and managing various homelab services and infrastructure components (e.g., Proxmox, NetBox, Traefik, Home Assistant, WikiJS) using automated scripts and configuration as code.
*   **Monitoring & Observability:** Implementing monitoring solutions (e.g., Uptime Kuma, Grafana, Loki) for system health, application performance, and network activity.
*   **CI/CD & Development Workflows:** Providing tools and frameworks for continuous integration and deployment, including GitHub Actions runners, MCP (Model Context Protocol) servers for automated code generation, linting, and system interactions.
*   **Application Development:** Housing various applications and services, including APIs (Node.js), dashboards (React/Vite), and specialized agents (Python, Go) for specific tasks like bird sound detection (birdnet-go/gone) and 3D printing management.
*   **Documentation & Knowledge Management:** Generating and integrating documentation, often automated, for systems, deployments, and troubleshooting.

## 2. Architecture
The codebase exhibits a hybrid architectural approach:
*   **Monorepo Structure:** A single repository containing multiple loosely coupled sub-projects and services.
*   **GitOps Principles:** Configuration and deployment managed through Git, with automated processes (e.g., cron jobs, GitHub Actions) ensuring desired state.
*   **Microservices/Agent-Based:** Many functionalities are encapsulated in distinct directories representing individual services or agents (e.g., `netbox-agent`, `proxmox-agent`, `mcp-servers`, `birdnet-go/gone`), often communicating via APIs or message queues (e.g., websockets, MQTT).
*   **API-Driven:** Extensive use of APIs for inter-service communication and external integrations, particularly within the `api` directory (Node.js) and various `mcp-servers`.
*   **Containerization:** Frequent use of Docker and Docker Compose for deployment (e.g., `homelab-gitops`, `birdnet-gone`, `serena`).
*   **Event-Driven:** Components like `mcp-servers` suggest an event-driven architecture, reacting to changes or external triggers.
*   **Web Frontend/Backend Separation:** Clear separation between frontend applications (e.g., `dashboard`, `frontend`, `birdnet-go/frontend`) and backend services (`api`, various agents).

## 3. Key Files
*   **`.pre-commit-config.yaml`**: Pre-commit hooks for code quality and standardization.
*   **`install.sh`, `deploy-v1.1.0.sh`, `update-production.sh`**: Primary deployment and installation scripts for the overall homelab.
*   **`VERSION`**: Tracks the current version of the project.
*   **`PROJECT_INDEX.md` files (various directories)**: Internal documentation indexing for sub-projects.
*   **`dashboard/`**: Frontend application for system monitoring and control (likely React/Vite).
*   **`api/`**: Centralized Node.js API services, including integrations with MCP, GitHub, and Serena.
*   **`homelab-gitops/`**: Core GitOps repository for managing deployments, configurations, and CI/CD pipelines. Contains deployment scripts, Docker Compose files, and documentation for the GitOps workflow.
*   **`home-assistant-config/`**: Home Assistant configuration files, automations, scripts, and related tools.
*   **`mcp-servers/`**: Collection of Model Context Protocol (MCP) servers, likely acting as specialized agents or microservices for various tasks (e.g., `claude-auto-commit-mcp-server`, `github-mcp-server`, `home-assistant-mcp-server`).
*   **`birdnet-go/`, `birdnet-gone/`**: Go-based applications for bird sound detection and analysis.
*   **`netbox-agent/`, `proxmox-agent/`**: Python-based agents for interacting with NetBox and Proxmox APIs.
*   **`serena/`**: A Python-based project (likely an AI agent or automation tool) with its own build and deployment setup.
*   **`docs/`**: General documentation for various aspects of the homelab, including deployment plans, troubleshooting, and architectural overviews.
*   **`scripts/`**: A collection of utility scripts for various automation, configuration, and maintenance tasks.
*   **`wrappers/`**: Shell scripts acting as wrappers or entry points for various `mcp-servers` functionalities.
*   **`ops/`**: Operational scripts and configurations, particularly for Fluent Bit logging and Loki.

## 4. Dependencies
*   **Languages & Runtimes:**
    *   **JavaScript/TypeScript:** Node.js (for `api`, `dashboard`, `homelab-gitops` and various CLI tools), React (for `dashboard` frontend), Vue/other frameworks for `birdnet-go/frontend`, `gw4-config-tool`.
    *   **Python:** Used extensively for agents (`netbox-agent`, `proxmox-agent`, `serena`, `mcp-enhanced-servers`), various scripts (`create-consolidated-config.py`, `sync_npm_to_adguard.py`), Home Assistant configurations, and the `model-catalog`.
    *   **Go:** Used for `birdnet-go` and `birdnet-gone` applications.
    *   **Bash/Shell scripting:** Heavily used for automation, deployment, and system management across the entire workspace.
*   **Frameworks & Libraries:**
    *   **Node.js Ecosystem:** Express.js (for APIs), Jest (testing), various npm packages.
    *   **Python Ecosystem:** FastAPI (potentially in some agents), pytest (testing), specific libraries for Home Assistant integration, `uv` (for `model-catalog`, `serena`).
    *   **Go Ecosystem:** Standard Go libraries, specific packages for `birdnet-go/gone`.
*   **DevOps & Infrastructure Tools:**
    *   **Git:** Version control and core of GitOps.
    *   **Docker/Docker Compose:** Containerization and orchestration.
    *   **Proxmox VE:** Virtualization and container management.
    *   **NetBox:** IP address management (IPAM) and data center infrastructure management (DCIM).
    *   **Traefik:** Edge router/reverse proxy.
    *   **Home Assistant:** Home automation platform.
    *   **Wiki.js:** Documentation platform.
    *   **Uptime Kuma, Grafana, Loki, Fluent Bit:** Monitoring, logging, and observability stack.
    *   **MCP (Model Context Protocol):** Custom protocol or framework for agent-based interactions (inferred from `mcp-servers`).
    *   **Infisical:** Secret management (mentioned in `homelab-gitops/INFISICAL_INTEGRATION.md`).
    *   **GitHub Actions:** CI/CD pipeline automation.
*   **Configuration & Build Tools:**
    *   `npm`, `yarn` (for Node.js projects).
    *   `go mod` (for Go projects).
    *   `pip`, `venv`, `uv` (for Python projects).
    *   `Gulp` (for `gw4-config-tool`).
    *   `Vite`, `ESLint`, `Prettier`, `Tailwind CSS` (for `dashboard`).
*   **Databases:**
    *   PostgreSQL (implied by `home-assistant-config/fix_postgres_lxc.sh`).
    *   SQLite (implied by `scripts/generate_adguard_rewrites_from_sqlite.py`).
    *   Redis (often used with message queues/caching, though not explicitly seen in file names).
