@echo off
echo Network MCP Server - Quick Setup
echo ================================

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found. Please install Python 3.10+ first.
    pause
    exit /b 1
)

echo Installing Network MCP Server...
pip install -e .

if errorlevel 1 (
    echo ERROR: Installation failed.
    pause
    exit /b 1
)

echo.
echo Installation complete!
echo.
echo Next steps:
echo 1. Create config: network-mcp-server create-config my_config.json
echo 2. Edit my_config.json with your SMB details
echo 3. Test config: network-mcp-server validate-config my_config.json
echo 4. Run server: network-mcp-server run --config my_config.json
echo.
echo For Claude Desktop integration, see INSTALL.md
echo.
pause
