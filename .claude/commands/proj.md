---
description: "Activate a Serena project by name"
---

Activate the Serena project: $1

1. Use mcp__plugin_serena_serena__activate_project to switch to the "$1" project.
2. After activation succeeds, read the project's `.claude/PROJECT_INDEX.md` file (at `/home/dev/workspace/$1/.claude/PROJECT_INDEX.md`). If the file exists, internalize it as context for this session. If it doesn't exist, note that no index is available.
3. If the project has a `CLAUDE.md` or `.claude/CLAUDE.md`, read that too for project-specific instructions.
