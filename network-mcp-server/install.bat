@echo off
setlocal enabledelayedexpansion

echo 🚀 Network MCP Server Installation
echo ==================================

REM Default paths
set "DEFAULT_SOURCE_DIR=C:\git\mcp-servers\network-mcp-server"
set "DEFAULT_INSTALL_DIR=C:\working\network-mcp-server"

REM Parse command line arguments
set "SOURCE_DIR=%DEFAULT_SOURCE_DIR%"
set "INSTALL_DIR=%DEFAULT_INSTALL_DIR%"

:parse_args
if "%~1"=="" goto end_parse
if "%~1"=="--source" (
    set "SOURCE_DIR=%~2"
    shift
    shift
    goto parse_args
)
if "%~1"=="--install-dir" (
    set "INSTALL_DIR=%~2"
    shift
    shift
    goto parse_args
)
if "%~1"=="--help" (
    goto show_help
)
if "%~1"=="-h" (
    goto show_help
)
echo ❌ Unknown argument: %~1
goto show_help

:end_parse

REM Interactive setup if not specified
if "%INSTALL_DIR%"=="%DEFAULT_INSTALL_DIR%" (
    echo.
    echo 📁 Installation Directory Setup
    echo Current default: %DEFAULT_INSTALL_DIR%
    set /p "USER_INSTALL_DIR=Enter installation directory (or press Enter for default): "
    if not "!USER_INSTALL_DIR!"=="" set "INSTALL_DIR=!USER_INSTALL_DIR!"
)

echo.
echo 📁 Source: %SOURCE_DIR%
echo 📁 Install: %INSTALL_DIR%

REM Check if source directory exists
if not exist "%SOURCE_DIR%" (
    echo ❌ ERROR: Source directory not found: %SOURCE_DIR%
    echo Please ensure the mcp-servers repository is cloned or specify correct source with --source
    pause
    exit /b 1
)

REM Check if Python is available
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ ERROR: Python is not installed or not in PATH
    echo Please install Python 3.10 or later from https://python.org/
    pause
    exit /b 1
)

REM Check Python version
for /f "tokens=2" %%i in ('python --version 2^>nul') do set PYTHON_VERSION=%%i
echo ✅ Found Python %PYTHON_VERSION%

REM Create installation directory if it doesn't exist
echo.
echo 📁 Creating installation directory...
if not exist "%INSTALL_DIR%" (
    mkdir "%INSTALL_DIR%" 2>nul
    if %errorlevel% neq 0 (
        echo ❌ ERROR: Cannot create directory: %INSTALL_DIR%
        echo Please check permissions or choose a different directory
        pause
        exit /b 1
    )
)

REM Copy source files to installation directory
echo.
echo 📋 Copying source files...
robocopy "%SOURCE_DIR%" "%INSTALL_DIR%" /E /PURGE /XD __pycache__ .git node_modules .pytest_cache /XF *.pyc *.pyo

if %errorlevel% gtr 7 (
    echo ❌ ERROR: Failed to copy source files
    pause
    exit /b 1
)
echo ✅ Source files copied successfully

REM Navigate to installation directory
cd /d "%INSTALL_DIR%"

REM Install the package in development mode
echo.
echo 📦 Installing Network MCP Server...
pip install -e .

if %errorlevel% neq 0 (
    echo ❌ ERROR: Failed to install package
    pause
    exit /b 1
)
echo ✅ Package installed successfully

REM Install development dependencies
echo.
echo 📦 Installing development dependencies...
pip install -e .[dev]

if %errorlevel% neq 0 (
    echo ⚠️  WARNING: Development dependencies installation failed
) else (
    echo ✅ Development dependencies installed
)

REM Test command availability
echo.
echo 🔍 Testing command availability...
where network-mcp-server >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ network-mcp-server command is available
    network-mcp-server --help >nul
) else (
    echo ⚠️  WARNING: network-mcp-server command not found in PATH
    echo Trying alternative method...
    python -m network_mcp.cli --help >nul
    if %errorlevel% equ 0 (
        echo ✅ Can run via: python -m network_mcp.cli
    ) else (
        echo ❌ ERROR: Cannot run network-mcp-server
        pause
        exit /b 1
    )
)

REM Create sample configuration
echo.
echo 📝 Creating sample configuration...
network-mcp-server create-config "%INSTALL_DIR%\config.json"

if %errorlevel% neq 0 (
    echo ❌ ERROR: Failed to create sample configuration
    pause
    exit /b 1
)
echo ✅ Sample configuration created: %INSTALL_DIR%\config.json

REM Validate configuration
echo.
echo 🔍 Validating configuration...
network-mcp-server validate-config "%INSTALL_DIR%\config.json"

if %errorlevel% neq 0 (
    echo ⚠️  WARNING: Configuration validation failed
) else (
    echo ✅ Configuration validated successfully
)

REM Run basic tests if available
if exist "%INSTALL_DIR%\tests" (
    echo.
    echo 🧪 Running basic tests...
    python -m pytest tests/ -v
    if %errorlevel% neq 0 (
        echo ⚠️  WARNING: Some tests failed
    ) else (
        echo ✅ All tests passed
    )
)

REM Show completion message
echo.
echo 🎉 Installation completed successfully!
echo.
echo 📋 Installation Summary:
echo ✅ Network MCP Server installed to: %INSTALL_DIR%
echo ✅ Configuration created: %INSTALL_DIR%\config.json

REM Determine script path for Claude Desktop config
for /f "tokens=*" %%i in ('where network-mcp-server 2^>nul') do set SCRIPT_PATH=%%i
if "%SCRIPT_PATH%"=="" set SCRIPT_PATH=network-mcp-server

echo.
echo 🔗 Claude Desktop Integration
echo ============================
echo Add this configuration to your Claude Desktop config file:
echo.
echo {
echo   "mcpServers": {
echo     "network-fs": {
echo       "command": "%SCRIPT_PATH%",
echo       "args": ["run", "--config", "%INSTALL_DIR%\\config.json"]
echo     }
echo   }
echo }
echo.
echo Claude Desktop config location:
echo   %USERPROFILE%\AppData\Roaming\Claude\claude_desktop_config.json
echo.
echo 📖 Next steps:
echo 1. Edit %INSTALL_DIR%\config.json with your SMB share details:
echo    - host: SMB server hostname/IP
echo    - share_name: Name of the SMB share
echo    - username: SMB username
echo    - password: SMB password
echo    - domain: SMB domain (if required)
echo 2. Test: network-mcp-server validate-config "%INSTALL_DIR%\config.json"
echo 3. Test connection: network-mcp-server run --config "%INSTALL_DIR%\config.json"
echo 4. Add the configuration above to Claude Desktop
echo 5. Restart Claude Desktop
echo.
echo ⚠️  IMPORTANT: Remember to configure your SMB credentials in config.json
echo.
goto end

:show_help
echo.
echo Network MCP Server Installer
echo.
echo Usage: install.bat [options]
echo.
echo Options:
echo   --source DIR           Source directory (default: C:\git\mcp-servers\network-mcp-server)
echo   --install-dir DIR      Installation directory (default: C:\working\network-mcp-server)
echo   --help, -h             Show this help message
echo.
echo Examples:
echo   install.bat
echo   install.bat --install-dir "D:\my-tools\network-mcp"
echo   install.bat --source "C:\custom\source" --install-dir "C:\custom\install"
echo.

:end
pause
