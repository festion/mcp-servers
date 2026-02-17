OK. I've created the `PROJECT_INDEX.md` file.
17

## Purpose

The `workspace` project appears to be a comprehensive monorepo or integrated development environment for a variety of services and applications. It encompasses API backends, frontend dashboards, specialized agents (e.g., `netbox-agent`, `proxmox-agent`, `websocket-agent`), automation scripts, and documentation. Its primary purpose is likely to facilitate the development, deployment, and management of interconnected systems, potentially focusing on home automation, network management, and AI/ML integration.

## Architecture

The architecture is modular, organized into distinct directories representing functional units:

*   **`api/`**: Houses various backend services, including configuration loaders, CSV export, email notifications, GitHub/MCP management, and WebSocket servers. This is a central hub for data processing and external integrations.
*   **`dashboard/`**: Contains a modern web frontend (likely React/Vite/Tailwind) for visualizing data and interacting with the backend services.
*   **`birdnet-gone/`**: A standalone application or service, possibly related to audio processing or environmental monitoring, with its own frontend, firmware, and deployment scripts.
*   **`.mcp/` (Micro-Controller Platform)**: Manages backups, batch processing, conflict resolution, and template application, suggesting a system for managing configurations or deployments across multiple devices or instances.
*   **`.prompts/`**: Stores AI prompts and related resources, indicating a focus on LLM-driven development or automation.
*   **`1-line-deploy/`**: Contains simplified deployment scripts for various agents and integrations (NetBox, Proxmox, WikiJS).
*   **`agent-workspace/websocket/`**: Implements a WebSocket-based agent for real-time communication and task execution.
*   **`docs/`**: Centralized documentation for various aspects of the system, including deployment plans, configuration, and operational procedures.

These modules likely interact via RESTful APIs, WebSockets, and shared file system operations, orchestrated by scripts and potentially a centralized control plane.

## Key Files

*   **`.eslintrc.js`, `.prettierrc`**: Configuration files for code linting and formatting, ensuring code quality and consistency.
*   **`install.sh`, `setup-linting.sh`**: Shell scripts for initial project setup and environment configuration.
*   **`deploy-v1.1.0.sh`, `quick-fix-deploy.sh`, `manual-deploy.sh`**: Scripts for deploying various versions or types of updates.
*   **`update-production.sh`**: Script specifically for pushing updates to a production environment.
*   **`api/server.js`, `api/server-v2.js`, `api/websocket-server.js`**: Main entry points for API and WebSocket backend services.
*   **`api/package.json`**: Defines dependencies and scripts for the API backend.
*   **`dashboard/index.html`, `dashboard/vite.config.ts`, `dashboard/tailwind.config.js`**: Core files for the frontend dashboard, including its entry point, build configuration (Vite), and styling (Tailwind CSS).
*   **`create-consolidated-config.py`**: Python script likely used for merging or generating configuration files.
*   **`PROJECT_INDEX.md`**: This file, serving as a high-level overview of the entire workspace.
*   **`cron/gitops-schedule`**: Defines cron jobs, likely for GitOps-driven automation or scheduled tasks.

## Dependencies

*   **JavaScript/Node.js**: Evidenced by `.js` files, `package.json`, `package-lock.json`, and `node_modules` directories in `api/` and `dashboard/`. Common frameworks include Express.js for APIs, React for UIs, and Vite for bundling.
*   **Python**: Indicated by `.py` files (e.g., `create-consolidated-config.py`, `.mcp/*.py`). Common uses might include scripting, automation, and potentially backend services.
*   **Bash**: Many `.sh` files suggest heavy reliance on shell scripting for automation, deployment, and operational tasks.
*   **Go**: The `birdnet-gone/` directory contains `cmd/`, `internal/`, and other structures typical of Go projects, suggesting Go is used for specific services or components.
*   **YAML/JSON**: Used extensively for configuration (`.mcp/config.yaml`, `.claude/settings.json`, `.pre-commit-config.yaml`).
*   **Containerization (Docker/Podman)**: Directories like `birdnet-gone/Docker/` and `birdnet-gone/Podman/` suggest containerized deployments.

## Common Tasks

1.  **Setup & Installation**: Run `install.sh` and `setup-linting.sh` to prepare the development environment.
2.  **Linting & Formatting**: Use ESLint and Prettier (configured by `.eslintrc.js`, `.prettierrc`) via `npm run lint` (or similar, inferred from `setup-linting.sh` and `dashboard/eslint.config.js`) to maintain code quality.
3.  **Building**: For the `dashboard`, use `npm run build` (or `vite build`) within the `dashboard/` directory. For `api` services, they are typically run directly. Go projects would use `go build`.
4.  **Testing**: For `api` and `dashboard`, run tests using `jest` (e.g., `npm test` or `jest`, as indicated by `jest.config.js` files).
5.  **Running Services**:
    *   **API**: Navigate to `api/` and run `node server.js` or `node server-v2.js` or `node websocket-server.js`.
    *   **Dashboard**: Navigate to `dashboard/` and run `npm run dev` (or `vite`) for local development, or serve the built `dist/` content.
6.  **Deployment**: Utilize scripts in `1-line-deploy/` or root-level scripts like `deploy-v1.1.0.sh`, `quick-fix-deploy.sh`, `manual-deploy.sh`, `update-production.sh`. Specific deployment steps will depend on the target service (e.g., NetBox Agent, Proxmox Agent, WikiJS Integration).
7.  **Configuration**: Manage settings via files in `config/`, `.mcp/`, and potentially environment variables. The `create-consolidated-config.py` script may be relevant here.
