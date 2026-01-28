---
name: refresh-infra
description: Refresh infrastructure reference documentation from live sources. Use when starting work on operations project or when infrastructure data seems stale.
---

# Refresh Infrastructure Reference

Refreshes the `infrastructure_reference.md` Serena memory from live data sources.

## Usage

When invoked, run the refresh script and offer options based on findings.

## Workflow

1. **Run check first:**
   ```bash
   cd /home/dev/workspace/operations && ./scripts/refresh-infrastructure-docs.sh --check
   ```

2. **Review gaps** - Show user the summary of:
   - Missing mgmt.lakehouse.wtf DNS entries
   - Missing DHCP reservations
   - Data freshness

3. **Offer actions:**
   - "Update memory file" → Run `--update`
   - "Show DNS fix commands" → Run `--fix-dns`
   - "No action needed" → Done

4. **If updating**, commit the change:
   ```bash
   cd /home/dev/workspace/operations
   git add .serena/memories/infrastructure_reference.md
   git commit -m "docs: refresh infrastructure reference $(date +%Y-%m-%d)"
   ```

## Arguments

- `/refresh-infra` - Check and offer to update
- `/refresh-infra --update` - Directly update without prompting
- `/refresh-infra --fix-dns` - Show DNS fix commands only
