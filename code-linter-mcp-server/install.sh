#!/bin/bash
# Install script for Code Linter MCP Server (Unix/Linux/macOS)
# Source to Deployment Installation with User Options

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
    DEFAULT_INSTALL_DIR="$HOME/mcp-servers/code-linter-mcp-server"
else
    # Linux
    DEFAULT_INSTALL_DIR="$HOME/mcp-servers/code-linter-mcp-server"
fi

SOURCE_DIR="$(pwd)"
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
INSTALL_LINTERS="ask"
INSTALL_JS_LINTERS="ask"
INSTALL_GO_LINTERS="ask"

# Function to show help
show_help() {
    echo "Code Linter MCP Server Installer"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --source DIR           Source directory (default: current directory)"
    echo "  --install-dir DIR      Installation directory (default: $DEFAULT_INSTALL_DIR)"
    echo "  --with-linters         Install Python linters without asking"
    echo "  --without-linters      Skip Python linters installation"
    echo "  --with-js-linters      Install JavaScript/TypeScript linters without asking"
    echo "  --without-js-linters   Skip JS/TS linters installation"
    echo "  --with-go-linters      Install Go linters without asking"
    echo "  --without-go-linters   Skip Go linters installation"
    echo "  --help, -h             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 --install-dir \"/opt/mcp-servers/code-linter\""
    echo "  $0 --with-linters --with-js-linters"
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
        --with-linters)
            INSTALL_LINTERS="yes"
            shift
            ;;
        --without-linters)
            INSTALL_LINTERS="no"
            shift
            ;;
        --with-js-linters)
            INSTALL_JS_LINTERS="yes"
            shift
            ;;
        --without-js-linters)
            INSTALL_JS_LINTERS="no"
            shift
            ;;
        --with-go-linters)
            INSTALL_GO_LINTERS="yes"
            shift
            ;;
        --without-go-linters)
            INSTALL_GO_LINTERS="no"
            shift
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

echo "🚀 Code Linter MCP Server Installation (Source to Deployment)"
echo "============================================================="

# Set up source and installation directories
setup_directories() {
    echo "📁 Source: $SOURCE_DIR"
    echo "📁 Install: $INSTALL_DIR"
    
    # Check if we're in the right source directory
    if [ ! -f "$SOURCE_DIR/pyproject.toml" ] || [ ! -d "$SOURCE_DIR/src/code_linter_mcp" ]; then
        print_error "Invalid source directory: $SOURCE_DIR"
        echo "Expected code-linter-mcp-server source directory with pyproject.toml and src/code_linter_mcp"
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

# Check if Python 3.11+ is available
check_python() {
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        print_error "Python is not installed or not in PATH"
        echo "Please install Python 3.11 or later"
        exit 1
    fi
    
    # Check Python version
    PYTHON_VERSION=$($PYTHON_CMD -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    PYTHON_MAJOR=$($PYTHON_CMD -c "import sys; print(sys.version_info.major)")
    PYTHON_MINOR=$($PYTHON_CMD -c "import sys; print(sys.version_info.minor)")
    
    if [ "$PYTHON_MAJOR" -lt 3 ] || [ "$PYTHON_MAJOR" -eq 3 -a "$PYTHON_MINOR" -lt 11 ]; then
        print_error "Python 3.11+ required, found $PYTHON_VERSION"
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
    print_info "Installing Code Linter MCP Server..."
    
    cd "$INSTALL_DIR"
    
    if $PIP_CMD install -e .; then
        print_status "Package installed successfully"
    else
        print_error "Failed to install package"
        exit 1
    fi
}

# Ask user about linter installation
ask_linter_installation() {
    if [ "$INSTALL_LINTERS" = "ask" ]; then
        echo ""
        echo "🔍 Python Linters Installation"
        echo "Python linters include: flake8, black, mypy, pylint, yamllint, jsonschema"
        read -p "Install Python linters? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            INSTALL_LINTERS="yes"
        else
            INSTALL_LINTERS="no"
        fi
    fi
}

# Install Python linters
install_python_linters() {
    if [ "$INSTALL_LINTERS" = "yes" ]; then
        print_info "Installing Python linters..."
        
        PYTHON_LINTERS="flake8 black mypy pylint yamllint jsonschema"
        
        if $PIP_CMD install $PYTHON_LINTERS; then
            print_status "Python linters installed"
        else
            print_warning "Some Python linters may not have installed correctly"
        fi
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

# Check for Node.js and npm
check_nodejs() {
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        NODE_VERSION=$(node --version)
        print_status "Node.js $NODE_VERSION is available"
        return 0
    else
        print_warning "Node.js/npm not found"
        return 1
    fi
}

# Ask about JS linter installation
ask_js_linter_installation() {
    if check_nodejs && [ "$INSTALL_JS_LINTERS" = "ask" ]; then
        echo ""
        echo "🔍 JavaScript/TypeScript Linters Installation"
        echo "JS/TS linters include: eslint, typescript, prettier"
        read -p "Install JavaScript/TypeScript linters? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            INSTALL_JS_LINTERS="yes"
        else
            INSTALL_JS_LINTERS="no"
        fi
    fi
}

# Install JavaScript/TypeScript linters
install_js_linters() {
    if check_nodejs && [ "$INSTALL_JS_LINTERS" = "yes" ]; then
        print_info "Installing JavaScript/TypeScript linters..."
        
        JS_PACKAGES="eslint typescript @typescript-eslint/parser @typescript-eslint/eslint-plugin prettier"
        
        if npm install -g $JS_PACKAGES; then
            print_status "JavaScript/TypeScript linters installed"
        else
            print_warning "Failed to install JS/TS linters"
            echo "You can install them manually with:"
            echo "  npm install -g $JS_PACKAGES"
        fi
    elif [ "$INSTALL_JS_LINTERS" = "yes" ] && ! check_nodejs; then
        print_warning "Cannot install JS/TS linters - Node.js/npm not available"
        echo "To install JS/TS support:"
        echo "1. Install Node.js from https://nodejs.org/"
        echo "2. Run: npm install -g eslint typescript"
    fi
}

# Check for Go
check_go() {
    if command -v go &> /dev/null; then
        GO_VERSION=$(go version | cut -d' ' -f3)
        print_status "Go $GO_VERSION is available"
        return 0
    else
        print_warning "Go not found"
        return 1
    fi
}

# Ask about Go linter installation
ask_go_linter_installation() {
    if check_go && [ "$INSTALL_GO_LINTERS" = "ask" ]; then
        echo ""
        echo "🔍 Go Linters Installation"
        echo "Go linters include: staticcheck, golint (gofmt and govet are included with Go)"
        read -p "Install additional Go linters? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            INSTALL_GO_LINTERS="yes"
        else
            INSTALL_GO_LINTERS="no"
        fi
    fi
}

# Install Go linters
install_go_linters() {
    if check_go && [ "$INSTALL_GO_LINTERS" = "yes" ]; then
        print_info "Installing Go linters..."
        
        if go install honnef.co/go/tools/cmd/staticcheck@latest && \
           go install golang.org/x/lint/golint@latest; then
            print_status "Go linters installed"
        else
            print_warning "Some Go linters may not have installed correctly"
        fi
    elif [ "$INSTALL_GO_LINTERS" = "yes" ] && ! check_go; then
        print_warning "Cannot install Go linters - Go not available"
        echo "To install Go support, install Go from https://golang.org/"
    fi
}

# Create sample configuration
create_config() {
    print_info "Creating sample configuration..."
    
    cd "$INSTALL_DIR"
    
    # Check if the command is available
    if command -v code-linter-mcp-server &> /dev/null; then
        if code-linter-mcp-server create-config --output "$INSTALL_DIR/config.json" --force; then
            print_status "Configuration created: $INSTALL_DIR/config.json"
            
            # Validate configuration
            if code-linter-mcp-server validate-config "$INSTALL_DIR/config.json"; then
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
        print_error "code-linter-mcp-server command not found"
        return 1
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
    SCRIPT_PATH=$(which code-linter-mcp-server 2>/dev/null || echo "code-linter-mcp-server")
    CONFIG_PATH="$INSTALL_DIR/config.json"
    
    echo "Add this configuration to your Claude Desktop config file:"
    echo ""
    
    cat << EOF
{
  "mcpServers": {
    "code-linter": {
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
    
    # Ask about and install linters
    ask_linter_installation
    install_python_linters
    
    # Install development dependencies
    install_dev_deps
    
    # Ask about and install JavaScript/TypeScript linters
    ask_js_linter_installation
    install_js_linters
    
    # Ask about and install Go linters
    ask_go_linter_installation
    install_go_linters
    
    # Create and validate configuration
    create_config
    
    # Run tests
    run_tests
    
    # Show completion message
    echo ""
    echo "🎉 Installation completed successfully!"
    echo ""
    echo "📋 Installation Summary:"
    echo "✅ Code Linter MCP Server installed to: $INSTALL_DIR"
    
    if [ "$INSTALL_LINTERS" = "yes" ]; then
        echo "✅ Python linters installed"
    fi
    
    if [ "$INSTALL_JS_LINTERS" = "yes" ] && command -v eslint &> /dev/null; then
        echo "✅ JavaScript/TypeScript linters installed"
    fi
    
    if [ "$INSTALL_GO_LINTERS" = "yes" ] && command -v staticcheck &> /dev/null; then
        echo "✅ Go linters installed"
    fi
    
    echo "✅ Configuration created: $INSTALL_DIR/config.json"
    
    echo ""
    echo "📖 Next steps:"
    echo "1. Review and customize $INSTALL_DIR/config.json"
    echo "2. Test the server: code-linter-mcp-server run --config \"$INSTALL_DIR/config.json\""
    echo "3. Add to Claude Desktop configuration (see below)"
    
    # Show Claude Desktop integration
    show_claude_integration
    
    echo ""
    echo "For more information, see README.md"
}

# Run main function
main
