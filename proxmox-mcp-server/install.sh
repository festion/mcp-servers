#!/bin/bash
# Installation script for Proxmox MCP Server on Unix/Linux/macOS

set -e

echo "Installing Proxmox MCP Server..."

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed or not in PATH"
    echo "Please install Python 3.8 or higher"
    exit 1
fi

# Check Python version
python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
required_version="3.8"

if [ "$(printf '%s\n' "$required_version" "$python_version" | sort -V | head -n1)" != "$required_version" ]; then
    echo "ERROR: Python $python_version found, but Python $required_version or higher is required"
    exit 1
fi

# Check if we're in an externally managed environment
if python3 -c "import sys; exit(0 if hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix) else 1)" 2>/dev/null; then
    echo "✅ Virtual environment detected"
    VENV_ACTIVE=true
else
    echo "⚠️  No virtual environment detected. Creating one..."
    VENV_ACTIVE=false
    
    # Create virtual environment
    if [ ! -d "venv" ]; then
        echo "Creating virtual environment..."
        python3 -m venv venv
    fi
    
    # Activate virtual environment
    echo "Activating virtual environment..."
    source venv/bin/activate
    
    # Upgrade pip in virtual environment
    pip install --upgrade pip
fi

# Install the package
echo "Installing package and dependencies..."
pip install -e .

# Verify installation
echo "Verifying installation..."
if [ "$VENV_ACTIVE" = "false" ]; then
    ./venv/bin/proxmox-mcp-server --version
    EXECUTABLE_PATH="$(pwd)/venv/bin/proxmox-mcp-server"
else
    proxmox-mcp-server --version
    EXECUTABLE_PATH="$(which proxmox-mcp-server)"
fi

echo ""
echo "✅ Proxmox MCP Server installed successfully!"
echo ""
if [ "$VENV_ACTIVE" = "false" ]; then
    echo "📁 Virtual environment created at: $(pwd)/venv"
    echo "🔧 Executable path: $EXECUTABLE_PATH"
    echo ""
    echo "To use the server:"
    echo "  source venv/bin/activate  # Activate virtual environment"
    echo "  proxmox-mcp-server --help # Use the server"
    echo ""
    echo "Or use the full path in Claude Desktop:"
    echo "  \"command\": \"$EXECUTABLE_PATH\""
else
    echo "🔧 Executable path: $EXECUTABLE_PATH"
fi
echo ""
echo "Next steps:"
echo "1. Create configuration: proxmox-mcp-server create-config"
echo "2. Edit configuration with your Proxmox server details"
echo "3. Set environment variables for passwords"
echo "4. Add to Claude Desktop configuration"
echo ""
echo "For detailed instructions, see INSTALL.md"