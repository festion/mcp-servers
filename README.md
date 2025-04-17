# 🧭 GitOps Audit Dashboard

This project provides a visual dashboard for auditing the health and status of your Git repositories in a GitOps-managed homelab. It checks for uncommitted changes, stale branches, and missing files, and presents the results in an interactive web interface.

---

## 📊 Features

- **Bar & Pie Charts** for repository status breakdown
- **Live auto-refreshing** data from local or GitHub source
- **Searchable repository cards**
- **Lightweight, portable static site**
- Built with **React**, **Recharts**, and **TailwindCSS**
- Designed for self-hosting (LXC, Proxmox, etc.)

---

## 🧠 AdGuard DNS Rewrite Sync

This repository includes tooling to automate AdGuard Home rewrite records based on Nginx Proxy Manager entries.

### How It Works

- **NPM database** (`database.sqlite`) is copied from container 105 each night
- Internal domains matching `*.internal.lakehouse.wtf` are extracted
- DNS rewrites are applied to AdGuard via API using a dry-run → commit pipeline

### Cron Schedule

| Task                         | Time       |
|-----------------------------|------------|
| Fetch NPM DB snapshot       | 3:00 AM    |
| Generate dry-run rewrite log| immediately |
| Commit rewrites to AdGuard  | if dry-run found |

### Files

- `/opt/gitops/scripts/fetch_npm_config.sh`
- `/opt/gitops/scripts/generate_adguard_rewrites_from_sqlite.py`
- `/opt/gitops/scripts/gitops_dns_sync.sh`
- Logs saved in `/opt/gitops/logs/`

### Manual Testing

```bash
bash /opt/gitops/scripts/gitops_dns_sync.sh

---

## 📁 Project Structure

```text
homelab-gitops-auditor/
├── dashboard/             # Frontend React app (Vite)
│   ├── src/               # Main application code
│   └── dist/              # Build output
├── output/                # GitRepoReport.json output
├── scripts/               # Utility scripts
│   └── deploy.sh          # Build + deploy script
├── GitRepoAudit.py        # Main repo auditing script
└── ...
