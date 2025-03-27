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
