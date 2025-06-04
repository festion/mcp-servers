#!/bin/bash
# Install script for Network MCP Server (Unix/Linux/macOS)
# Source to Deployment Installation

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

# Default values
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    DEFAULT_INSTALL_DIR="$HOME/mcp-servers/network-mcp-server"
else
    # Linux
    DEFAULT_INSTALL_DIR="$HOME/mcp-servers/network-mcp-server"
fi

SOURCE_DIR="$(pwd)"
INSTALL_DIR="$DEFAULT_INSTALL_DIR"

# Function to show help
show_help() {
    echo "Network MCP Server Installer"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --source DIR           Source directory (default: current directory)"
    echo "  --install-dir DIR      Installation directory (default: $DEFAULT_INSTALL_DIR)"
    echo "  --help, -h             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 --install-dir \"/opt/mcp-servers/network-mcp\""
    echo "  $0 --source \"/path/to/source\" --install-dir \"/path/to/install\""
    echo ""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            ;;
        *)
            print_error "Unknown argument: $1"
            show_help
            ;;
    esac
done

echo "🚀 Network MCP Server Installation (Source to Deployment)"
echo "========================================================="

# Set up source and installation directories
setup_directories() {
    echo "📁 Source: $SOURCE_DIR"
    echo "📁 Install: $INSTALL_DIR"
    
    # Check if we're in the right source directory
    if [ ! -f "$SOURCE_DIR/pyproject.toml" ] || [ ! -d "$SOURCE_DIR/src/network_mcp" ]; then
        print_error "Invalid source directory: $SOURCE_DIR"
        echo "Expected network-mcp-server source directory with pyproject.toml and src/network_mcp"
        exit 1
    fi
    
    print_status "Source directory validated"
    
    # Interactive install directory setup if using default
    if [ "$INSTALL_DIR" = "$DEFAULT_INSTALL_DIR" ]; then
        echo ""
        echo "📁 Installation Directory Setup"
        echo "Current default: $DEFAULT_INSTALL_DIR"
        read -p "Enter installation directory (or press Enter for default): " USER_INSTALL_DIR
        if [ -n "$USER_INSTALL_DIR" ]; then
            INSTALL_DIR="$USER_INSTALL_DIR"
            echo "📁 Using: $INSTALL_DIR"
        fi
    fi
}

# Check if Python 3.10+ is available
check_python() {
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        print_error "Python is not installed or not in PATH"
        echo "Please install Python 3.10 or later"
        exit 1
    fi
    
    # Check Python version
    PYTHON_VERSION=$($PYTHON_CMD -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    PYTHON_MAJOR=$($PYTHON_CMD -c "import sys; print(sys.version_info.major)")
    PYTHON_MINOR=$($PYTHON_CMD -c "import sys; print(sys.version_info.minor)")
    
    if [ "$PYTHON_MAJOR" -lt 3 ] || [ "$PYTHON_MAJOR" -eq 3 -a "$PYTHON_MINOR" -lt 10 ]; then
        print_error "Python 3.10+ required, found $PYTHON_VERSION"
        exit 1
    fi
    
    print_status "Python $PYTHON_VERSION is compatible"
}

# Check if pip is available
check_pip() {
    if ! command -v pip &> /dev/null && ! command -v pip3 &> /dev/null; then
        print_error "pip is not installed"
        echo "Please install pip for Python package management"
        exit 1
    fi
    
    if command -v pip3 &> /dev/null; then
        PIP_CMD="pip3"
    else
        PIP_CMD="pip"
    fi
    
    print_status "pip is available"
}

# Copy source files to installation directory
copy_source_files() {
    print_info "Creating installation directory..."
    mkdir -p "$INSTALL_DIR"
    
    print_info "Copying source files..."
    
    # Use rsync if available, otherwise use cp
    if command -v rsync &> /dev/null; then
        rsync -av --exclude='__pycache__' --exclude='.git' --exclude='node_modules' \
              --exclude='.pytest_cache' --exclude='.mypy_cache' --exclude='*.pyc' \
              --exclude='*.pyo' --exclude='.DS_Store' \
              "$SOURCE_DIR/" "$INSTALL_DIR/"
    else
        # Fallback to cp with find to exclude unwanted files
        find "$SOURCE_DIR" -type f \
            ! -path "*/__pycache__/*" \
            ! -path "*/.git/*" \
            ! -path "*/node_modules/*" \
            ! -path "*/.pytest_cache/*" \
            ! -path "*/.mypy_cache/*" \
            ! -name "*.pyc" \
            ! -name "*.pyo" \
            ! -name ".DS_Store" \
            -exec cp --parents {} "$INSTALL_DIR/" \; 2>/dev/null || \
        # macOS doesn't have --parents, use alternative
        (cd "$SOURCE_DIR" && find . -type f \
            ! -path "./__pycache__/*" \
            ! -path "./.git/*" \
            ! -path "./node_modules/*" \
            ! -path "./.pytest_cache/*" \
            ! -path "./.mypy_cache/*" \
            ! -name "*.pyc" \
            ! -name "*.pyo" \
            ! -name ".DS_Store" \
            -exec mkdir -p "$INSTALL_DIR/$(dirname {})" \; \
            -exec cp {} "$INSTALL_DIR/{}" \;)
    fi
    
    print_status "Source files copied successfully"
}

# Install the package
install_package() {
    print_info "Installing Network MCP Server..."
    
    cd "$INSTALL_DIR"
    
    if $PIP_CMD install -e .; then
        print_status "Package installed successfully"
    else
        print_error "Failed to install package"
        exit 1
    fi
}

# Install development dependencies
install_dev_deps() {
    print_info "Installing development dependencies..."
    
    if $PIP_CMD install -e ".[dev]"; then
        print_status "Development dependencies installed"
    else
        print_warning "Development dependencies installation failed"
    fi
}

# Test command availability
test_command() {
    print_info "Testing command availability..."
    
    if command -v network-mcp-server &> /dev/null; then
        print_status "network-mcp-server command is available"
        return 0
    else
        print_warning "network-mcp-server not in PATH, trying alternative..."
        if $PYTHON_CMD -m network_mcp.cli --help &> /dev/null; then
            print_status "Can run via: python -m network_mcp.cli"
            return 0
        else
            print_error "Cannot run network-mcp-server"
            return 1
        fi
    fi
}

# Create sample configuration
create_config() {
    print_info "Creating sample configuration..."
    
    cd "$INSTALL_DIR"
    
    # Check if the command is available
    if command -v network-mcp-server &> /dev/null; then
        if network-mcp-server create-config "$INSTALL_DIR/config.json"; then
            print_status "Configuration created: $INSTALL_DIR/config.json"
            
            # Validate configuration
            if network-mcp-server validate-config "$INSTALL_DIR/config.json"; then
                print_status "Configuration validated successfully"
                return 0
            else
                print_warning "Configuration validation failed"
                return 1
            fi
        else
            print_error "Failed to create configuration"
            return 1
        fi
    else
        # Try alternative method
        if $PYTHON_CMD -m network_mcp.cli create-config "$INSTALL_DIR/config.json"; then
            print_status "Configuration created: $INSTALL_DIR/config.json"
            
            # Validate configuration
            if $PYTHON_CMD -m network_mcp.cli validate-config "$INSTALL_DIR/config.json"; then
                print_status "Configuration validated successfully"
                return 0
            else
                print_warning "Configuration validation failed"
                return 1
            fi
        else
            print_error "Failed to create configuration"
            return 1
        fi
    fi
}

# Run tests if available
run_tests() {
    if [ -d "$INSTALL_DIR/tests" ]; then
        print_info "Running basic tests..."
        
        cd "$INSTALL_DIR"
        if $PYTHON_CMD -m pytest tests/ -v; then
            print_status "All tests passed"
        else
            print_warning "Some tests failed, but installation continues"
        fi
    fi
}

# Show Claude Desktop integration
show_claude_integration() {
    echo ""
    echo "🔗 Claude Desktop Integration"
    echo "============================="
    
    # Find the installed script
    SCRIPT_PATH=$(which network-mcp-server 2>/dev/null || echo "network-mcp-server")
    CONFIG_PATH="$INSTALL_DIR/config.json"
    
    echo "Add this configuration to your Claude Desktop config file:"
    echo ""
    
    cat << EOF
{
  "mcpServers": {
    "network-fs": {
      "command": "$SCRIPT_PATH",
      "args": ["run", "--config", "$CONFIG_PATH"]
    }
  }
}
EOF
    
    echo ""
    echo "Claude Desktop config file location:"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        echo "  ~/Library/Application Support/Claude/claude_desktop_config.json"
    else
        # Linux
        echo "  ~/.config/claude/claude_desktop_config.json"
    fi
}

# Show next steps
show_next_steps() {
    echo ""
    echo "📖 Next steps:"
    echo "1. Edit $INSTALL_DIR/config.json with your SMB share details:"
    echo "   - host: SMB server hostname or IP address"
    echo "   - share_name: Name of the SMB share"
    echo "   - username: SMB username"
    echo "   - password: SMB password"
    echo "   - domain: SMB domain (if required)"
    echo "   - port: SMB port (default: 445)"
    echo "2. Test configuration: network-mcp-server validate-config \"$INSTALL_DIR/config.json\""
    echo "3. Test connection: network-mcp-server run --config \"$INSTALL_DIR/config.json\""
    echo "4. Add to Claude Desktop configuration (see above)"
    echo "5. Restart Claude Desktop"
    echo ""
    echo "⚠️  IMPORTANT: Remember to configure your SMB credentials in config.json"
    echo "💡 TIP: You can test SMB connectivity before using with Claude Desktop"
}

# Main installation process
main() {
    echo ""
    
    # Set up directories
    setup_directories
    
    # Check prerequisites
    check_python
    check_pip
    
    # Copy source files to installation directory
    copy_source_files
    
    # Install main package
    install_package
    
    # Install development dependencies
    install_dev_deps
    
    # Test command availability
    if ! test_command; then
        exit 1
    fi
    
    # Create and validate configuration
    create_config
    
    # Run tests
    run_tests
    
    # Show completion message
    echo ""
    echo "🎉 Installation completed successfully!"
    echo ""
    echo "📋 Installation Summary:"
    echo "✅ Network MCP Server installed to: $INSTALL_DIR"
    echo "✅ Configuration created: $INSTALL_DIR/config.json"
    echo "✅ Dependencies installed"
    
    # Show Claude Desktop integration
    show_claude_integration
    
    # Show next steps
    show_next_steps
    
    echo ""
    echo "For more information, see README.md"
}

# Run main function
main
