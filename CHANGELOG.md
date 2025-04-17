# Changelog

## [v1.0.0] - 2025-04-17
### Added
- `fetch_npm_config.sh`: Extracts `database.sqlite` from NPM container (LXC 105) via Proxmox
- `generate_adguard_rewrites_from_sqlite.py`: Parses NPM config and syncs `*.internal.lakehouse.wtf` rewrites to AdGuard Home
- `gitops_dns_sync.sh`: Master sync script to fetch, dry-run, then commit rewrite updates
- Logging added to all scripts under `/opt/gitops/logs/`
- Cron integration via `/etc/cron.d/gitops-schedule` to run nightly at 3AM
- Enforced dry-run before commit
- Automatically creates missing log directories

### Changed
- Rewrites are now matched and normalized using lowercase for reliable comparison
- `.last_adguard_dry_run.json` file is removed after each commit to enforce one dry-run per commit

### Notes
- Designed to run in GitOps-managed LXC container (CTID 123)
- Rewrite targets: `*.internal.lakehouse.wtf` → `192.168.1.95`
