# Changelog

## [v1.0.0] - 2025-04-17
### Added
- AdGuard DNS sync tool:
  - `fetch_npm_config.sh`: Extracts NPM's `database.sqlite`
  - `generate_adguard_rewrites_from_sqlite.py`: Generates and syncs AdGuard DNS rewrites for `*.internal.lakehouse.wtf`
  - `gitops_dns_sync.sh`: Master runner for scheduled syncing
- Enforced dry-run before commit
- Log output for every step with timestamps
- Cron job setup: `/etc/cron.d/gitops-schedule` runs nightly at 3AM
- Snapshot auto-naming and log rotation ready

### Changed
- Only `*.internal.lakehouse.wtf` records are touched or reported
- All domain names normalized to lowercase for consistency
- `.last_adguard_dry_run.json` cleaned up after commit
