# workspace Project Index

Generated: 2026-02-06

## Purpose
This repository is a sophisticated, GitOps-driven monorepo for managing a homelab environment. It integrates a Node.js backend, a React frontend, Home Assistant for automation, and a custom Python-based templating engine (MCP) to automate and manage the entire infrastructure.

## Directory Structure
- `api/`: The Node.js/Express backend service that provides the core API.
- `dashboard/`: The React/Vite-based frontend application for user interaction.
- `home-assistant-config/`: Contains the configuration for the central Home Assistant instance.
- `.mcp/`: A custom Python-based templating and automation engine called Model Context Protocol.
- `docs/`: Contains high-level architecture, planning, and process documents.
- `scripts/`: Various shell scripts for deployment, maintenance, and other operational tasks.

## Key Files
- `PROJECT_INDEX.md`: This file, providing a high-level overview of the repository.
- `api/server.js`: The main entry point for the backend Node.js application.
- `dashboard/vite.config.ts`: Configuration file for the Vite-based frontend, confirming the use of React.
- `home-assistant-config/configuration.yaml`: The core configuration file for the Home Assistant instance.
- `.mcp/template-applicator.py`: The core script for the MCP automation engine.
- `.gitignore`: Defines ignored files, which is important for understanding the repository's structure as it is quite comprehensive.
- `docs/3-TIER-DEPLOYMENT.md`: High-level deployment strategy document.

## Architecture Patterns
The project follows a GitOps-driven monorepo approach. It has a clear separation of concerns with a backend API, a frontend dashboard, and a declarative configuration for Home Assistant. Automation is a key pattern, implemented through the custom MCP engine.

## Entry Points
- **Backend**: The API is started by running `node api/server.js`.
- **Frontend**: The frontend is a standard Vite application, likely started with `npm run dev` from the `dashboard/` directory.

## Dependencies
The project has several key external dependencies and integrations:
- **Proxmox**: For virtualization and container management.
- **NetBox**: As a source of truth for IPAM and DCIM.
- **Traefik**: Used as a reverse proxy and load balancer.
- **Home Assistant**: The core of the home automation system.

## Common Tasks
- **Build**: The frontend can be built using Vite's build command (`npm run build` in `dashboard/`). The backend does not require a build step.
- **Test**: Testing setups exist for both the `api` and `dashboard` directories, likely using Jest. Tests can be run with `npm test`.
- **Deploy**: Deployment is handled via scripts, with `update-production.sh` being a likely candidate for production deployments. The overall strategy is detailed in `docs/3-TIER-DEPLOYMENT.md`.
