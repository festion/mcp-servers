# GitHub Actions Runner LXC - Proxmox VE

Deploy a GitHub Actions self-hosted runner in an unprivileged LXC container on Proxmox VE.

## ⚡ Quick Deploy

**One-line deployment from Proxmox host:**

```bash
GITHUB_TOKEN=ghp_your_token bash -c "$(wget -qLO - https://raw.githubusercontent.com/festion/home-assistant-config/main/proxmox-github-runner-lxc.sh)"
```

## 📋 Features

- **Unprivileged LXC** - Secure containerization
- **Docker Support** - Full Docker capability with nesting
- **Auto-configuration** - Registers runner automatically 
- **Systemd Service** - Runs as system service with auto-restart
- **Management Script** - Easy start/stop/restart/logs
- **Resource Efficient** - Minimal resource usage vs VM
- **One-line Deploy** - Community script style deployment

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GITHUB_TOKEN` | *required* | GitHub personal access token |
| `LXC_ID` | `200` | LXC container ID |
| `RUNNER_NAME` | `homelab-runner` | Runner display name |
| `RUNNER_LABELS` | `homelab,docker,self-hosted,linux,lxc` | Runner labels |
| `LXC_MEMORY` | `2048` | Memory in MB |
| `LXC_CORES` | `2` | CPU cores |
| `LXC_DISK` | `20` | Disk size in GB |
| `LXC_STORAGE` | `local-lvm` | Proxmox storage |

### Examples

```bash
# Deploy with defaults
GITHUB_TOKEN=ghp_xxx bash proxmox-github-runner-lxc.sh

# Custom configuration
GITHUB_TOKEN=ghp_xxx LXC_ID=201 RUNNER_NAME=prod-runner LXC_MEMORY=4096 bash proxmox-github-runner-lxc.sh

# Production deployment
GITHUB_TOKEN=ghp_xxx LXC_ID=210 RUNNER_NAME=ci-runner LXC_CORES=4 LXC_MEMORY=8192 LXC_DISK=40 bash proxmox-github-runner-lxc.sh
```

## 🎮 Management

### From Proxmox Host

```bash
# Check status
pct exec 200 -- runner-manager status

# Start/stop/restart
pct exec 200 -- runner-manager start
pct exec 200 -- runner-manager stop
pct exec 200 -- runner-manager restart

# View logs
pct exec 200 -- runner-manager logs

# Reconfigure with new token
pct exec 200 -- runner-manager reconfigure

# Enter container
pct enter 200
```

### From Inside Container

```bash
# All management commands
runner-manager status
runner-manager start
runner-manager stop
runner-manager restart
runner-manager logs
runner-manager reconfigure
```

## 🔒 Security

- **Unprivileged Container** - No root access to host
- **Docker Nesting** - Secure docker-in-docker capability
- **Network Isolation** - Isolated network namespace
- **Minimal Attack Surface** - Only required packages installed
- **Systemd Hardening** - Service runs as non-root user

## 🗂️ Directory Structure

```
/home/runner/
├── actions-runner/          # GitHub Actions runner files
├── _work/                   # Job workspace
├── config.sh               # Configuration script
├── run.sh                  # Runner service script
└── .runner                 # Runner configuration

/usr/local/bin/runner-manager # Management script
/etc/systemd/system/github-runner.service # Systemd service
```

## 🔧 Troubleshooting

### Check Container Status
```bash
pct status 200
pct exec 200 -- systemctl status github-runner
```

### Check Runner Logs
```bash
pct exec 200 -- journalctl -u github-runner.service -f
```

### Check Docker
```bash
pct exec 200 -- docker ps
pct exec 200 -- docker version
```

### Network Issues
```bash
pct exec 200 -- ping github.com
pct exec 200 -- curl -I https://api.github.com
```

### Reconfigure Runner
```bash
pct exec 200 -- runner-manager reconfigure
```

## 🗑️ Cleanup

```bash
# Stop and destroy container
bash proxmox-github-runner-lxc.sh destroy confirm
```

## 📊 Resource Usage

**Typical Usage:**
- **CPU**: 0.1-2 cores (depends on job load)
- **Memory**: 512MB-2GB (depends on job requirements)
- **Storage**: 5-20GB (depends on cached data)
- **Network**: Minimal (job-dependent)

**Recommended Minimums:**
- **CPU**: 2 cores
- **Memory**: 2GB
- **Storage**: 20GB

## 🔄 Updates

The runner auto-updates by default. To disable:

```bash
pct exec 200 -- sudo -u runner bash -c "cd /home/runner && ./config.sh --disableupdate"
```

## 🌐 GitHub Integration

After deployment, the runner appears in:
- Repository Settings → Actions → Runners
- Available for workflow jobs with matching labels

Use in workflows:
```yaml
jobs:
  build:
    runs-on: [self-hosted, homelab, lxc]
    steps:
      - uses: actions/checkout@v4
      - name: Run in LXC
        run: echo "Running on LXC runner!"
```

## 🆘 Support

For issues:
1. Check runner logs: `pct exec 200 -- runner-manager logs`
2. Verify GitHub token permissions
3. Ensure container has network access
4. Check Proxmox container settings

## 📜 License

MIT License - Feel free to modify and redistribute.