#!/bin/bash

# MCP Server Wrapper Sync Script
# Syncs wrapper scripts from the mcp-servers repository to the workspace directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔄 Syncing MCP server wrapper scripts..."
echo "Repository: $SCRIPT_DIR"
echo "Workspace: $WORKSPACE_DIR"

# List of wrapper scripts to sync
WRAPPER_SCRIPTS=(
    "hass-mcp-wrapper.sh"
    "proxmox-mcp-wrapper.sh"
    "wikijs-mcp-wrapper.sh"
    "code-linter-wrapper.sh"
    "github-wrapper.sh"
    "network-mcp-wrapper.sh"
    "serena-enhanced-wrapper.sh"
    "directory-polling-wrapper.sh"
    "truenas-mcp-wrapper.sh"
)

# Sync each wrapper script
for script in "${WRAPPER_SCRIPTS[@]}"; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        echo "✅ Syncing $script"
        cp "$SCRIPT_DIR/$script" "$WORKSPACE_DIR/$script"
        chmod +x "$WORKSPACE_DIR/$script"
    else
        echo "⚠️  Warning: $script not found in repository"
    fi
done

echo ""
echo "🎉 Wrapper script sync completed!"
echo "📝 To run this automatically after git pull:"
echo "   git config --local core.hooksPath .githooks"
echo "   mkdir -p .githooks && cat > .githooks/post-merge << 'EOF'"
echo "#!/bin/bash"
echo "./sync-wrappers.sh"
echo "EOF"
echo "   chmod +x .githooks/post-merge"