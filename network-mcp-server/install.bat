@echo off
echo Installing Network MCP Server...

REM Navigate to project directory
cd /d "C:\working\network-mcp-server"

echo.
echo Step 1: Installing package in development mode...
pip install -e .

if %ERRORLEVEL% NEQ 0 (
    echo Error installing package!
    pause
    exit /b 1
)

echo.
echo Step 2: Testing command availability...
where network-mcp-server
if %ERRORLEVEL% NEQ 0 (
    echo network-mcp-server command not found in PATH
    echo Trying to find it...
    python -m network_mcp.cli --help
) else (
    echo Success! network-mcp-server command is available
    network-mcp-server --help
)

echo.
echo Step 3: Creating sample configuration...
network-mcp-server create-config "C:\working\network-mcp-server\my_config.json"

echo.
echo Step 4: Validating sample configuration...
network-mcp-server validate-config "C:\working\network-mcp-server\my_config.json"

echo.
echo Installation complete!
echo.
echo To use with Claude Desktop, add this to your config:
echo {
echo   "mcpServers": {
echo     "network-fs": {
echo       "command": "network-mcp-server",
echo       "args": ["run", "--config", "C:\\working\\network-mcp-server\\my_config.json"]
echo     }
echo   }
echo }
echo.
pause
