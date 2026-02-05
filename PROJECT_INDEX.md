# workspace Project Index

Generated: 2026-02-05

## Purpose
This project is a comprehensive, polyglot monorepo for managing a personal infrastructure environment ("homelab") using GitOps principles. It features a suite of custom tools for automation, including a powerful coding agent toolkit named "Serena" and a "Master Control Program" (MCP) for orchestrating development and operational tasks. The system is designed to be interacted with by both humans and AI agents to maintain and evolve the codebase and infrastructure.

## Directory Structure
- `api/`: A Node.js/Express backend that provides a REST API for the dashboard and external tools. It's the main entry point for programmatic interaction with the system's GitOps audit and repository management features.
- `dashboard/`: A React/Vite-based web application that serves as the frontend for monitoring and managing the GitOps environment.
- `.mcp/`: The core of the "Master Control Program" (MCP), an automation and templating engine written in Python. It's used for batch processing, conflict resolution, and applying standardized configurations across repositories.
- `serena/`: A sophisticated Python-based coding agent toolkit designed to integrate with Large Language Models (LLMs). It provides IDE-like capabilities for semantic code understanding and manipulation, enabling advanced, AI-driven software development.
- `scripts/`: A collection of shell and Python scripts for various operational tasks, including deployment, maintenance, and running audits.
- `docs/`: Contains project documentation, architectural decision records (ADRs), technical guides, and operational procedures.
- `homelab-gitops/`, `proxmox-agent/`, `home-assistant-config/`: Specific projects managed within the monorepo, representing different parts of the homelab infrastructure.
- `.prompts/`: A directory for storing prompts for interacting with LLMs, indicating a deep integration with AI as part of the development workflow.

## Key Files
- `api/server.js`: The main entry point for the backend API server.
- `api/server-mcp.js`: An alternative entry point for the API server with enhanced MCP integration.
- `dashboard/vite.config.ts`: The build and development configuration file for the frontend dashboard.
- `.mcp/README.md`: Provides a detailed explanation of the MCP template application engine.
- `serena/README.md`: Documentation for the Serena coding agent toolkit.
- `upload-mcp-docs-to-wikijs.py`: A script demonstrating integration with Wiki.js for documentation management.
- Various `deploy-*.sh` and `*.py` scripts in the root directory provide top-level entry points for common tasks.

## Architecture Patterns
- **Monorepo**: The project is structured as a monorepo, containing multiple related but distinct projects and services. This simplifies dependency management and cross-project changes.
- **GitOps**: The state of the infrastructure is defined declaratively in Git. The tools in this repository are used to audit and enforce this state.
- **Agent-based Automation**: The project heavily relies on automated agents (Serena and MCP) to perform complex tasks, from code generation and refactoring to infrastructure management. LLMs are a key component of this architecture.
- **Polyglot**: The repository contains code in multiple languages, including Python, JavaScript/TypeScript, and shell script, choosing the best tool for each job.
- **Microservices-like structure**: While not strictly a microservices architecture, the project is divided into distinct components (`api`, `dashboard`, `serena`, etc.) that can be developed and deployed independently.

## Entry Points
- **Backend API**: `node api/server.js` or `node api/server-mcp.js`
- **Frontend Dashboard**: Run `npm start` or `vite` in the `dashboard/` directory.
- **Serena Agent**: Use the `serena` command-line tool.
- **Scripts**: Various scripts in the root and `scripts/` directories can be executed directly for specific tasks (e.g., `./deploy-v1.1.0.sh`).

## Dependencies
- **Node.js**: The runtime for the `api` and `dashboard` projects.
- **Python**: The runtime for `serena`, `.mcp`, and various scripts.
- **Git**: The version control system at the heart of the GitOps workflow.
- **Docker**: Used for containerizing applications and services.
- **Traefik**: Used as a reverse proxy and load balancer.
- **LLMs**: Serena is designed to integrate with various Large Language Models for its agentic capabilities.

## Common Tasks
- **Build the project**: Run `npm install` in the `api/` and `dashboard/` directories for the JavaScript projects. For Python projects, use `pip install` with the appropriate `requirements.txt` or `pyproject.toml`.
- **Run tests**: Tests can be run using framework-specific commands in each project directory (e.g., `npm test` in `api/` or `pytest` in `serena/`).
- **Deploy the application**: Use the deployment scripts in the root directory (e.g., `./deploy-v1.1.0.sh`).
- **Run a GitOps audit**: Interact with the API endpoints (e.g., `/audit/run-comprehensive`) or use the dashboard.
- **Apply a template to a repository**: Use the scripts in the `.mcp/` directory.