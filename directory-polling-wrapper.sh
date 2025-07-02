#!/bin/bash
# Directory Polling MCP Server Wrapper
# Properly implements MCP protocol for directory monitoring

# Set working directory
cd /home/dev/workspace

# Logging setup
source /home/dev/workspace/mcp-logger.sh 2>/dev/null || {
    mcp_info() { echo "[INFO] DIRECTORY-POLLING: $*"; }
    mcp_warn() { echo "[WARN] DIRECTORY-POLLING: $*"; }
    mcp_error() { echo "[ERROR] DIRECTORY-POLLING: $*"; }
}

mcp_info "Starting Directory Polling MCP server"

# Configuration
export POLLING_CONFIG="/home/dev/workspace/production-monitoring-config.json"

# Create server directory if it doesn't exist
mkdir -p /home/dev/workspace/mcp-servers/directory-polling-server

# Check if MCP server exists
if [ ! -f "/home/dev/workspace/mcp-servers/directory-polling-server/mcp-directory-polling-server.py" ]; then
    mcp_error "Directory polling MCP server not found"
    exit 1
fi

# Create default configuration if it doesn't exist
if [ ! -f "$POLLING_CONFIG" ]; then
    cat > "$POLLING_CONFIG" << 'EOF'
{
  "monitoring_profile": "production",
  "watch_directories": [
    {
      "path": "/home/dev/workspace",
      "recursive": true,
      "priority": "high",
      "patterns": ["*.md", "*.py", "*.js", "*.json", "*.yaml", "*.yml"]
    }
  ],
  "processing_rules": {
    "batch_size": 10,
    "processing_interval": 30,
    "max_queue_size": 50,
    "duplicate_detection": true
  },
  "filters": {
    "exclude_patterns": [
      "node_modules/**",
      ".git/**",
      "__pycache__/**",
      "*.log",
      "*.tmp"
    ],
    "min_file_size": 10,
    "max_file_size": 1048576
  }
}
EOF
    mcp_info "Created default configuration file"
fi

# Change to the directory polling server directory
cd /home/dev/workspace/mcp-servers/directory-polling-server

# Start the directory polling MCP server
mcp_info "Starting directory polling MCP server"

# Execute the Python MCP server (use fixed version with proper MCP protocol)
exec python3 mcp-directory-polling-server-fixed.py