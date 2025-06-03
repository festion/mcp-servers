@echo off
echo Installing Code Linter MCP Server...

REM Check if Python is available
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.11 or later
    pause
    exit /b 1
)

REM Install the package in development mode
echo Installing package...
pip install -e .

if %errorlevel% neq 0 (
    echo ERROR: Failed to install package
    pause
    exit /b 1
)

REM Install optional linter dependencies
echo.
echo Installing Python linters...
pip install flake8 black mypy yamllint

REM Create sample configuration
echo.
echo Creating sample configuration...
code-linter-mcp-server create-config --output example_config.json --force

REM Validate configuration
echo.
echo Validating configuration...
code-linter-mcp-server validate-config example_config.json

echo.
echo ================================
echo Installation completed!
echo ================================
echo.
echo Next steps:
echo 1. Edit example_config.json to customize settings
echo 2. Install additional linters as needed:
echo    - Go: gofmt, govet (included with Go)
echo    - JavaScript: npm install -g eslint
echo    - TypeScript: npm install -g typescript @typescript-eslint/parser
echo 3. Add to Claude Desktop configuration:
echo    "code-linter": {
echo      "command": "code-linter-mcp-server",
echo      "args": ["run", "--config", "path/to/config.json"]
echo    }
echo.
pause
