# Project Index: mcp-servers-fix

## 1. Core Purpose

This project is a comprehensive management and orchestration system, likely for a homelab or private cloud environment. It consists of a central API, a web dashboard, a collection of specialized microservices (`mcp-servers`), and extensive scripting for deployment, automation, and validation. The system appears to leverage AI agents (Claude, Gemini) for operational tasks, analysis, and development. The `mcp-servers-fix` repository name suggests a focus on stabilizing or refactoring this complex system.

## 2. Architecture

The architecture is a multi-component system:

-   **Backend**: A Node.js API (`api/`) serves as the central control plane, handling business logic, and connecting various services through `mcp-connector.js`. It includes multiple server processes, such as a main server, a dedicated MCP server, and a WebSocket server for real-time communication.
-   **Frontend**: A modern web application (`dashboard/`) built with Vite and TypeScript, providing a user interface for monitoring and managing the system.
-   **Microservices**: A collection of specialized servers located in `mcp-servers/` and `mcp-enhanced-servers/`. These servers manage specific infrastructure components like Proxmox, TrueNAS, networking, and code linting.
-   **Automation & Scripts**: An extensive collection of shell and Python scripts (`scripts/`, `wrappers/`) handles deployment, configuration, validation, and various operational tasks. This indicates a strong emphasis on GitOps and Infrastructure-as-Code principles.
-   **AI Integration**: The `.prompts/` and `.claude/` directories contain configurations and templates for Large Language Models, suggesting they are integrated into workflows for development, automation, and project analysis.
-   **Documentation**: A rich set of documentation (`docs/`) covers deployment plans, architectural decisions, standard operating procedures, and incident reports.

## 3. Key Files

-   **`api/server.js`**: The main entry point for the core backend API.
-   **`api/server-mcp.js`**: A dedicated server for the Master Control Program (MCP) functionalities.
-   **`dashboard/vite.config.ts`**: The configuration file for the frontend dashboard application.
-   **`mcp-servers/`**: Directory containing the various specialized microservices that form the core of the management system.
-   **`scripts/deploy.sh`**: A primary script for deploying components of the system.
-   **`update-production.sh`**: Script for updating the production environment, highlighting the operational nature of the repository.
-   **`wrappers/*.sh`**: A set of simplified shell wrappers for interacting with the different MCP services.
-   **`.prompts/`**: A directory holding templates and system prompts for integrated AI agents, crucial for the project's advanced automation.
-   **`docs/`**: Contains all project documentation, including architecture, deployment plans, and incident reports.

## 4. Dependencies

-   **Backend**: Node.js, Express.js (implied by server structure).
-   **Frontend**: Vite, TypeScript, and likely a modern framework like React or Vue.
-   **Scripting**: Python, Bash/Shell.
-   **Infrastructure**: Traefik (reverse proxy), Docker/LXC (containerization), Proxmox, TrueNAS.
-   **AI**: Integrations with Claude and Gemini APIs.
-   **DevOps**: Git, GitOps principles, Pre-commit hooks, GitHub Actions (implied).
