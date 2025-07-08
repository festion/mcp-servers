#!/bin/bash

# MCP Servers Setup Script for Development Container
# Run this script inside the container as the dev user

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "================================================================"
echo "          MCP Servers Setup for Development Container"
echo "================================================================"
echo ""

# Check if we're the dev user
if [ "$(whoami)" != "dev" ]; then
    error "This script should be run as the dev user"
    echo "Please run: su - dev"
    exit 1
fi

# Ensure we're in the workspace
cd ~/workspace

log "Setting up MCP servers..."

# 1. Install core MCP dependencies
log "Installing MCP framework dependencies..."
npm install -g @modelcontextprotocol/inspector 2>/dev/null || true
python3 -m pip install --user mcp 2>/dev/null || true

# 2. Set up filesystem MCP (already working)
log "Filesystem MCP server is already configured"

# 3. Set up GitHub MCP server
log "Setting up GitHub MCP server..."
npm install -g @modelcontextprotocol/server-github 2>/dev/null || {
    warning "GitHub MCP server not available via npm, will configure manually"
}

# 4. Create MCP configuration directory
mkdir -p ~/.config/claude-code
mkdir -p ~/workspace/mcp-config

# 5. Create basic MCP configuration
log "Creating MCP configuration..."

cat > ~/.config/claude-code/config.json << 'EOF'
{
  "mcpServers": {
    "filesystem": {
      "command": "node",
      "args": ["/home/dev/workspace/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js", "/home/dev/workspace"],
      "env": {}
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}"
      }
    }
  }
}
EOF

success "Basic MCP configuration created"

# 6. Set up network-fs wrapper (already working)
log "Network-fs wrapper is already configured"

# 7. Install additional MCP servers
log "Installing additional MCP server dependencies..."

# Install Home Assistant MCP server dependencies
python3 -m pip install --user homeassistant requests websockets 2>/dev/null || true

# Install Proxmox MCP dependencies
python3 -m pip install --user proxmoxer 2>/dev/null || true

# 8. Create wrapper scripts for Python-based MCP servers
log "Creating MCP server wrapper scripts..."

# GitHub MCP wrapper (for when token is configured)
cat > ~/workspace/github-mcp-wrapper.sh << 'EOF'
#!/bin/bash
if [ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
    echo "ERROR: GitHub MCP server requires configuration. Please set GITHUB_PERSONAL_ACCESS_TOKEN environment variable."
    exit 1
fi
npx -y @modelcontextprotocol/server-github
EOF
chmod +x ~/workspace/github-mcp-wrapper.sh

# Home Assistant MCP wrapper
cat > ~/workspace/hass-mcp-wrapper.sh << 'EOF'
#!/bin/bash
cd /home/dev/workspace
export HASS_URL="${HASS_URL:-http://192.168.1.175:8123}"
export HASS_TOKEN="${HASS_TOKEN:-your_hass_token_here}"
python3 -m pip show homeassistant-mcp-server >/dev/null 2>&1 || {
    echo "Home Assistant MCP server not installed"
    exit 1
}
python3 -c "import homeassistant_mcp_server; homeassistant_mcp_server.main()"
EOF
chmod +x ~/workspace/hass-mcp-wrapper.sh

# 9. Create MCP configuration template with all servers
log "Creating comprehensive MCP configuration template..."

cat > ~/workspace/mcp-config/claude-code-config-template.json << 'EOF'
{
  "mcpServers": {
    "filesystem": {
      "command": "node",
      "args": ["/home/dev/workspace/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js", "/home/dev/workspace"],
      "env": {}
    },
    "github": {
      "command": "bash",
      "args": ["/home/dev/workspace/github-mcp-wrapper.sh"],
      "env": {
        "GITHUB_TOKEN": "your_github_token_here"
      }
    },
    "hass-mcp": {
      "command": "bash",
      "args": ["/home/dev/workspace/hass-mcp-wrapper.sh"],
      "env": {
        "HASS_URL": "http://192.168.1.175:8123",
        "HASS_TOKEN": "your_hass_token_here"
      }
    },
    "network-fs": {
      "command": "bash",
      "args": ["/home/dev/workspace/network-mcp-wrapper.sh"],
      "env": {}
    }
  }
}
EOF

# 10. Create setup instructions
log "Creating setup instructions..."

cat > ~/workspace/mcp-config/SETUP_INSTRUCTIONS.md << 'EOF'
# MCP Servers Setup Instructions

## Current Status
- ✅ Filesystem MCP: Working
- ✅ Network-fs MCP: Working
- ⚠️  GitHub MCP: Needs token
- ⚠️  Home Assistant MCP: Needs token
- ❌ Proxmox MCP: Needs installation
- ❌ Serena MCP: Needs repository

## Quick Setup

### 1. Configure GitHub MCP
```bash
# Set your GitHub token
export GITHUB_TOKEN="ghp_your_token_here"
echo 'export GITHUB_TOKEN="ghp_your_token_here"' >> ~/.zshrc

# Update configuration
sed -i 's/your_github_token_here/'"$GITHUB_TOKEN"'/g' ~/.config/claude-code/config.json
```

### 2. Configure Home Assistant MCP
```bash
# Set your Home Assistant details
export HASS_URL="http://192.168.1.175:8123"
export HASS_TOKEN="your_long_lived_access_token"
echo 'export HASS_URL="http://192.168.1.175:8123"' >> ~/.zshrc
echo 'export HASS_TOKEN="your_long_lived_access_token"' >> ~/.zshrc

# Update configuration
sed -i 's/your_hass_token_here/'"$HASS_TOKEN"'/g' ~/.config/claude-code/config.json
```

### 3. Test MCP Servers
```bash
# Test basic connectivity
claude mcp list

# Start Claude Code
claude
```

### 4. Add More Servers (Optional)
Copy the template configuration and add servers as needed:
```bash
cp ~/workspace/mcp-config/claude-code-config-template.json ~/.config/claude-code/config.json
# Edit with your tokens and settings
```

## Troubleshooting

### Connection Issues
- Check Claude Code config: `claude mcp list`
- Test individual servers: `node /path/to/server.js`
- Check logs: `claude --debug`

### Missing Dependencies
- Install MCP framework: `npm install -g @modelcontextprotocol/inspector`
- Install Python deps: `python3 -m pip install --user mcp homeassistant requests`

### Token Issues
- GitHub: Generate at https://github.com/settings/tokens
- Home Assistant: Create long-lived token in HA profile
EOF

# 11. Apply minimal working configuration
log "Applying minimal working MCP configuration..."

cat > ~/.config/claude-code/config.json << 'EOF'
{
  "mcpServers": {
    "filesystem": {
      "command": "node",
      "args": ["/home/dev/workspace/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js", "/home/dev/workspace"],
      "env": {}
    }
  }
}
EOF

# 12. Install filesystem MCP server if missing
log "Ensuring filesystem MCP server is available..."
if [ ! -f "/home/dev/workspace/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js" ]; then
    npm install @modelcontextprotocol/server-filesystem
fi

echo ""
success "MCP servers setup complete!"
echo ""
echo "================================================================"
echo "                        NEXT STEPS"
echo "================================================================"
echo ""
echo "1. Test current setup:"
echo "   claude mcp list"
echo ""
echo "2. Add GitHub token (optional):"
echo "   export GITHUB_TOKEN='ghp_your_token_here'"
echo ""
echo "3. Add Home Assistant token (optional):"
echo "   export HASS_TOKEN='your_long_lived_token'"
echo ""
echo "4. Start Claude Code:"
echo "   claude"
echo ""
echo "5. View detailed setup instructions:"
echo "   cat ~/workspace/mcp-config/SETUP_INSTRUCTIONS.md"
echo ""
