# Project Index: workspace

## 1. Core Purpose
This workspace serves as a comprehensive suite for managing and automating a homelab environment. It encompasses tools and configurations for infrastructure as code (GitOps), CI/CD pipelines, various monitoring and automation agents (e.g., for NetBox, Proxmox, Home Assistant), API services, smart home integrations, 3D printing management, and specialized applications like Birdnet. The primary goal is to provide robust, automated, and observable control over the homelab infrastructure and services.

## 2. Architecture
The codebase exhibits a modular, distributed architecture. Key architectural patterns include:
*   **Agent-based Systems**: Multiple independent agents (e.g., `netbox-agent`, `proxmox-agent`, `mcp-servers` components) are designed to interact with specific systems, collect data, or perform automated tasks.
*   **API Services**: Dedicated `api` components expose functionalities, likely serving as integration points for various services and frontends.
*   **GitOps**: The `homelab-gitops` directory indicates a strong adherence to GitOps principles for managing infrastructure and application deployments, with configuration and deployment scripts version-controlled.
*   **Dashboards**: Several `dashboard` projects suggest a focus on data visualization and monitoring for various aspects of the homelab.
*   **Microservices/Modular Components**: The numerous top-level directories for distinct functionalities (e.g., `birdnet-go`, `serena`, `tender`) imply a breakdown into smaller, manageable services or applications.
*   **Containerization**: The presence of `Dockerfile` and `docker-compose.yml` in several projects points to extensive use of containerization for deployment and isolation.

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
The project utilizes a mix of technologies, primarily:
*   **JavaScript/TypeScript (Node.js)**: Evident in `api`, `dashboard`, `gw4-config-tool`, `mcp-servers` and `homelab-gitops` through `package.json`, `package-lock.json`, and `.js`/`.ts` files. Frontend frameworks like React (in `dashboard`) are also present.
*   **Go**: Used in projects like `birdnet-go`, `birdnet-gone`, `biometric-gateway`, `tender`, and `tender-photos`, indicated by `go.mod` files.
*   **Python**: Found in `fitbit-dashboard`, `home-assistant-config`, `model-catalog`, `netbox-agent`, `proxmox-agent`, `serena`, `stormcrow`, and various `scripts`, indicated by `requirements.txt` and `.py` files.
*   **Shell Scripting (Bash)**: Numerous `.sh` files across the repository for automation, deployment, and utility tasks.
*   **YAML/JSON**: Used extensively for configuration (`.yaml`, `.json` files in `home-assistant-config`, `homelab-iac`, `operations`, etc.) and potentially for CI/CD pipelines.
*   **Markdown**: Used for documentation (`.md` files throughout the repository).
*   **Docker/Containerization**: `Dockerfile` and `docker-compose.yml` files are present in multiple service directories, indicating containerized deployments.
