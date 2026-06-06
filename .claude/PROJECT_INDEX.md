# Project Index: workspace

## 1. Core Purpose

This monorepo serves as a comprehensive suite for homelab management, automation, and development. It encompasses projects for home automation (e.g., Home Assistant configurations, BLE gateways), monitoring and data collection (e.g., Birdnet for avian soundscapes, various dashboards, Netbox agent for infrastructure), 3D printing designs and utilities, and a robust internal development and operations platform. The platform includes a "Multi-Container Project" (MCP) system for orchestrating microservices, GitOps workflows for infrastructure as code, and various agents for specific tasks (e.g., WikiJS integration, Proxmox management). The overall goal appears to be the creation and maintenance of a highly automated, observable, and extensible smart home and homelab environment.

## 2. Architecture

The codebase exhibits a modular, multi-language, and often containerized architecture. Key architectural patterns include:

*   **Microservices/Containerization:** Numerous directories like `api`, `birdnet-go`, `birdnet-gone`, `netbox-agent`, `proxmox-agent`, `mcp-servers`, `homelab-gitops`, and `serena` contain `Dockerfile` or `docker-compose.yml` files, indicating container-based deployments. The "MCP" system likely orchestrates these services.
*   **Frontend/Backend Separation:** Projects like `api`, `dashboard`, `frontend`, `birdnet-go`, `birdnet-gone`, `fitbit-dashboard`, `model-catalog`, `seed2smoke`, `tender`, and `tender-photos` show clear distinctions between API backends (Go, Node.js, Python) and web frontends (React/Vite, HTML/JS).
*   **Configuration as Code (GitOps/IaC):** `homelab-gitops`, `homelab-iac` (Ansible, Terraform), and `home-assistant-config` demonstrate a strong emphasis on managing infrastructure and application configurations through version control.
*   **Scripting and Automation:** A significant number of shell scripts (`scripts/`, `install.sh`, `deploy-*.sh`, `fix-*.sh`, `monitor-*.sh`) are used for deployment, maintenance, and operational tasks.
*   **Documentation-Driven Development:** Extensive use of Markdown files for documentation, architecture, deployment plans, and project overviews (`docs/`, `PROJECT_INDEX.md`, `README.md`, `CLAUDE.md` in many subdirectories) suggests a strong emphasis on documenting processes and systems.

## 3. Key Files

*   `./deploy-ssh-keys-working.sh`: A shell script likely used for deploying SSH keys to various systems, potentially for automation or secure access within the homelab environment.
*   `./verify-dns-migration.sh`: A script for verifying the successful migration or configuration of DNS settings, crucial for network stability.
*   `./dashboard/proxy-server.py`: A Python script acting as a proxy server for the dashboard, possibly to handle API requests, authentication, or overcome CORS issues.
*   `./dashboard/tsconfig.app.json`: Configuration file for TypeScript compilation specific to the dashboard application, indicating it's a TypeScript-based frontend project.
*   `./dashboard/README.md`: Provides essential information and instructions for the dashboard project, including setup, usage, and development guidelines.
*   `./dashboard/node_modules/d3-color/README.md`, `./dashboard/node_modules/d3-color/package.json`: Documentation and package definition for `d3-color`, a JavaScript library for color manipulation, used in the dashboard.
*   `./dashboard/node_modules/cookie/README.md`, `./dashboard/node_modules/cookie/package.json`: Documentation and package definition for the `cookie` JavaScript library, used for HTTP cookie parsing and serialization in the dashboard.
*   `./dashboard/node_modules/babel-preset-jest/README.md`, `./dashboard/node_modules/babel-preset-jest/package.json`: Documentation and package definition for `babel-preset-jest`, indicating that the dashboard project uses Jest for testing and Babel for JavaScript transpilation.
*   `./dashboard/node_modules/fast-glob/README.md`, `./dashboard/node_modules/fast-glob/package.json`: Documentation and package definition for `fast-glob`, a utility for finding files using glob patterns, likely used in the dashboard's build or development processes.
*   `./dashboard/node_modules/ @bcoe/v8-coverage/README.md`, `./dashboard/node_modules/ @bcoe/v8-coverage/package.json`: Documentation and package definition for `@bcoe/v8-coverage`, suggesting that the dashboard project integrates with V8 code coverage tools, likely for testing and quality analysis.

## 4. Dependencies

Inferred dependencies based on file types and common project structures:

*   **Programming Languages:** Go, Python, JavaScript/TypeScript, Shell scripting (Bash).
*   **Package Managers:** `npm`/`yarn` (JavaScript/TypeScript - evident from `package.json`, `package-lock.json`, `node_modules`), `go mod` (Go - evident from `go.mod`, `go.sum`), `pip`/`uv` (Python - evident from `requirements.txt`, `pyproject.toml`, `uv.lock`).
*   **Frontend Frameworks/Libraries:** React (implied by Vite/TypeScript configuration in `dashboard`), D3.js (for data visualization, `d3-color`, `d3-interpolate`, `d3-timer` in `dashboard`), Tailwind CSS (for styling, `tailwind.config.js`).
*   **Backend Frameworks/Libraries:** Node.js (Express.js or similar, in `api`), FastAPI/Flask/Django (Python, in various Python-based services), Go standard library and web frameworks.
*   **Containerization:** Docker, Docker Compose, Podman.
*   **Home Automation:** Home Assistant, Zigbee2MQTT, ESPHome, BLE-related libraries.
*   **Infrastructure as Code:** Ansible, Terraform.
*   **Testing:** Jest (JavaScript/TypeScript), Pytest (Python).
*   **Linting/Formatting:** ESLint, Prettier.
*   **Version Control:** Git.
