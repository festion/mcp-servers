@echo off
REM Installation script for Proxmox MCP Server on Windows

echo Installing Proxmox MCP Server...

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.8 or higher from https://python.org
    pause
    exit /b 1
)

REM Install the package
echo Installing package and dependencies...
pip install -e .

if errorlevel 1 (
    echo ERROR: Installation failed
    pause
    exit /b 1
)

REM Verify installation
echo Verifying installation...
proxmox-mcp-server --version

if errorlevel 1 (
    echo ERROR: Installation verification failed
    pause
    exit /b 1
)

echo.
echo ✅ Proxmox MCP Server installed successfully!
echo.
echo Next steps:
echo 1. Create configuration: proxmox-mcp-server create-config
echo 2. Edit configuration with your Proxmox server details
echo 3. Set environment variables for passwords
echo 4. Add to Claude Desktop configuration
echo.
echo For detailed instructions, see INSTALL.md
pause
