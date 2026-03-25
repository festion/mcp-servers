---
description: "Activate a Serena project by name"
---

Activate the Serena project: $1

1. Use mcp__plugin_serena_serena__activate_project to switch to the "$1" project.
2. After activation succeeds, read the project's `.claude/PROJECT_INDEX.md` file (at `/home/dev/workspace/$1/.claude/PROJECT_INDEX.md`). If the file exists, internalize it as context for this session. If it doesn't exist, note that no index is available.
3. If the project has a `CLAUDE.md` or `.claude/CLAUDE.md`, read that too for project-specific instructions.
4. Set the Vikunja task context by calling `vikunja_set_project` with "$1". This auto-creates the Vikunja project if it doesn't exist.
5. Rename the Konsole tab and tmux session by running: `printf '\033]0;%s\007' "$1" && tmux rename-session "$1" 2>/dev/null`
6. Show open tasks by calling `vikunja_list_tasks` with `filter="open"`. Display as a summary:
   ```
   Open tasks:
   #<id> [P<priority>] <title>  (<labels>)
   ```
   If no open tasks, say "No open tasks."
7. If ARGUMENTS contains text beyond the project name, treat it as the user's intent for this session and proceed to address it after setup.
