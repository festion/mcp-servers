#!/bin/bash
# MCP Servers Bootstrap Installer
# One-line deployment script for production servers

set -e

echo "=== MCP Servers Bootstrap Installer ==="

# Check if git is available
if ! command -v git &> /dev/null; then
    echo "Installing git..."
    apt-get update && apt-get install -y git python3 python3-pip
fi

# Clone or update repository
if [ -d "mcp-servers" ]; then
    echo "Updating existing repository..."
    cd mcp-servers
    git pull origin main
else
    echo "Cloning repository..."
    git clone https://github.com/festion/mcp-servers.git
    cd mcp-servers
fi

# Run the installer
echo "Running MCP servers installation..."
python3 install-all-mcp-servers.py --one-line

echo "=== Installation Complete ==="
echo "All MCP servers have been installed and verified."