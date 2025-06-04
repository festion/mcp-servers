# Code Linter MCP Server - Installation Guide

This guide covers the installation of the Code Linter MCP Server from source to deployment.

## Quick Start

### Windows
```batch
# Navigate to source directory
cd C:\git\mcp-servers\code-linter-mcp-server

# Run installer with default settings
install.bat

# Or with custom install directory
install.bat --install-dir "D:\my-tools\code-linter"

# Or with all linters pre-selected
install.bat --with-linters --with-js-linters --with-go-linters
```

### Unix/Linux/macOS
```bash
# Navigate to source directory
cd /path/to/mcp-servers/code-linter-mcp-server

# Make installer executable
chmod +x install.sh

# Run installer with default settings
./install.sh

# Or with custom install directory
./install.sh --install-dir "$HOME/my-tools/code-linter"

# Or with all linters pre-selected
./install.sh --with-linters --with-js-linters --with-go-linters
```

## Installation Options

### Windows (install.bat)
- `--source DIR` - Source directory (default: C:\git\mcp-servers\code-linter-mcp-server)
- `--install-dir DIR` - Installation directory (default: C:\working\code-linter-mcp-server)
- `--with-linters` - Install Python linters without asking
- `--without-linters` - Skip Python linters installation
- `--with-js-linters` - Install JavaScript/TypeScript linters without asking
- `--without-js-linters` - Skip JS/TS linters installation
- `--with-go-linters` - Install Go linters without asking
- `--without-go-linters` - Skip Go linters installation
- `--help` - Show help message

### Unix/Linux/macOS (install.sh)
Same options as Windows, but using Unix-style paths.

### Python Installer Script
```bash
# Advanced installation with Python script
python installer.py

# Or with command line options
python installer.py --source /path/to/source --install-dir /path/to/install
```

## What Gets Installed

### Core Package
- Code Linter MCP Server package
- Core dependencies (mcp, pydantic, click)
- Development dependencies (pytest, black, mypy, etc.)

### Optional Linters
- **Python**: flake8, black, mypy, pylint, yamllint, jsonschema
- **JavaScript/TypeScript**: eslint, typescript, prettier
- **Go**: staticcheck, golint (requires Go to be installed)

### Configuration
- Sample configuration file (`config.json`)
- Validated configuration ready for use

## Prerequisites

### Required
- Python 3.11 or later
- pip (Python package manager)

### Optional (for additional language support)
- **Node.js & npm** - for JavaScript/TypeScript linting
- **Go** - for Go linting support

## Installation Process

1. **Validation** - Checks Python version and source directory
2. **Directory Setup** - Creates installation directory
3. **File Copying** - Copies source files to installation directory
4. **Package Installation** - Installs the MCP server package
5. **Linter Installation** - Installs selected linters
6. **Configuration** - Creates and validates sample configuration
7. **Testing** - Runs basic tests if available
8. **Integration Setup** - Provides Claude Desktop configuration

## Post-Installation

### Configuration
Edit the generated `config.json` file to customize:
- Enabled languages and linters
- Security settings
- Performance options
- Serena integration settings

### Testing
```bash
# Test the server
code-linter-mcp-server run --config /path/to/config.json

# Validate configuration
code-linter-mcp-server validate-config /path/to/config.json

# Check linter availability
code-linter-mcp-server check-linter-availability
```

### Claude Desktop Integration
Add the provided configuration to your Claude Desktop config file:

**Windows**: `%USERPROFILE%\AppData\Roaming\Claude\claude_desktop_config.json`
**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
**Linux**: `~/.config/claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "code-linter": {
      "command": "/path/to/code-linter-mcp-server",
      "args": ["run", "--config", "/path/to/config.json"]
    }
  }
}
```

## Troubleshooting

### Common Issues
1. **Python version too old** - Install Python 3.11+
2. **Command not found** - Check if pip scripts directory is in PATH
3. **Permission errors** - Use appropriate permissions for installation directory
4. **Linter not found** - Install missing linters manually

### Manual Linter Installation
```bash
# Python linters
pip install flake8 black mypy pylint yamllint jsonschema

# JavaScript/TypeScript linters (requires Node.js)
npm install -g eslint typescript prettier

# Go linters (requires Go)
go install honnef.co/go/tools/cmd/staticcheck@latest
go install golang.org/x/lint/golint@latest
```

### Getting Help
Run the installer with `--help` to see all available options and examples.

## Advanced Usage

### Custom Source Directory
If your source code is in a different location:
```bash
install.bat --source "C:\custom\source" --install-dir "C:\custom\install"
```

### Automated Installation
For CI/CD or automated deployments:
```bash
install.bat --with-linters --with-js-linters --install-dir "C:\automated\install"
```

### Development Installation
For development work, you may want to install in development mode and run tests:
```bash
# After installation
cd /path/to/install/directory
pip install -e .[dev]
pytest tests/ -v
```
