@echo off
setlocal enabledelayedexpansion

echo 🚀 Code Linter MCP Server Installation
echo =====================================

REM Default paths
set "DEFAULT_SOURCE_DIR=C:\git\mcp-servers\code-linter-mcp-server"
set "DEFAULT_INSTALL_DIR=C:\working\code-linter-mcp-server"

REM Parse command line arguments
set "SOURCE_DIR=%DEFAULT_SOURCE_DIR%"
set "INSTALL_DIR=%DEFAULT_INSTALL_DIR%"
set "INSTALL_LINTERS=ask"
set "INSTALL_JS_LINTERS=ask"
set "INSTALL_GO_LINTERS=ask"

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
if "%~1"=="--with-linters" (
    set "INSTALL_LINTERS=yes"
    shift
    goto parse_args
)
if "%~1"=="--without-linters" (
    set "INSTALL_LINTERS=no"
    shift
    goto parse_args
)
if "%~1"=="--with-js-linters" (
    set "INSTALL_JS_LINTERS=yes"
    shift
    goto parse_args
)
if "%~1"=="--without-js-linters" (
    set "INSTALL_JS_LINTERS=no"
    shift
    goto parse_args
)
if "%~1"=="--with-go-linters" (
    set "INSTALL_GO_LINTERS=yes"
    shift
    goto parse_args
)
if "%~1"=="--without-go-linters" (
    set "INSTALL_GO_LINTERS=no"
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
    echo Please install Python 3.11 or later from https://python.org/
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
echo 📦 Installing Code Linter MCP Server...
pip install -e .

if %errorlevel% neq 0 (
    echo ❌ ERROR: Failed to install package
    pause
    exit /b 1
)
echo ✅ Package installed successfully

REM Ask about Python linters if not specified
if "%INSTALL_LINTERS%"=="ask" (
    echo.
    echo 🔍 Python Linters Installation
    echo Python linters include: flake8, black, mypy, pylint, yamllint, jsonschema
    choice /C YN /M "Install Python linters? (Y/N)"
    if errorlevel 2 (
        set "INSTALL_LINTERS=no"
    ) else (
        set "INSTALL_LINTERS=yes"
    )
)

REM Install Python linter dependencies
if "%INSTALL_LINTERS%"=="yes" (
    echo.
    echo 📦 Installing Python linters...
    pip install flake8 black mypy pylint yamllint jsonschema
    
    if %errorlevel% neq 0 (
        echo ⚠️  WARNING: Some Python linters may not have installed correctly
    ) else (
        echo ✅ Python linters installed successfully
    )
)

REM Install development dependencies
echo.
echo 📦 Installing development dependencies...
pip install -e .[dev]

if %errorlevel% neq 0 (
    echo ⚠️  WARNING: Development dependencies installation failed
) else (
    echo ✅ Development dependencies installed
)

REM Check for Node.js and npm
echo.
echo 🔍 Checking for JavaScript/TypeScript linting support...
where node >nul 2>&1
set "NODE_AVAILABLE=no"
if %errorlevel% equ 0 (
    where npm >nul 2>&1
    if %errorlevel% equ 0 (
        echo ✅ Node.js and npm found
        set "NODE_AVAILABLE=yes"
    ) else (
        echo ⚠️  WARNING: npm not found
    )
) else (
    echo ⚠️  WARNING: Node.js not found
)

REM Ask about JS linters if Node.js is available and not specified
if "%NODE_AVAILABLE%"=="yes" (
    if "%INSTALL_JS_LINTERS%"=="ask" (
        echo.
        echo 🔍 JavaScript/TypeScript Linters Installation
        echo JS/TS linters include: eslint, typescript, prettier
        choice /C YN /M "Install JavaScript/TypeScript linters? (Y/N)"
        if errorlevel 2 (
            set "INSTALL_JS_LINTERS=no"
        ) else (
            set "INSTALL_JS_LINTERS=yes"
        )
    )
    
    if "%INSTALL_JS_LINTERS%"=="yes" (
        echo.
        echo 📦 Installing JavaScript/TypeScript linters...
        npm install -g eslint typescript @typescript-eslint/parser @typescript-eslint/eslint-plugin prettier
        if %errorlevel% equ 0 (
            echo ✅ JavaScript/TypeScript linters installed
        ) else (
            echo ⚠️  WARNING: Failed to install JS/TS linters
        )
    )
) else (
    if "%INSTALL_JS_LINTERS%"=="yes" (
        echo ⚠️  WARNING: Cannot install JS/TS linters - Node.js/npm not available
        echo To install JavaScript/TypeScript support:
        echo 1. Install Node.js from https://nodejs.org/
        echo 2. Run: npm install -g eslint typescript
    )
)

REM Check for Go
echo.
echo 🔍 Checking for Go support...
where go >nul 2>&1
set "GO_AVAILABLE=no"
if %errorlevel% equ 0 (
    echo ✅ Go found and ready for Go linting
    set "GO_AVAILABLE=yes"
) else (
    echo ⚠️  WARNING: Go not found
)

REM Ask about Go linters if Go is available and not specified
if "%GO_AVAILABLE%"=="yes" (
    if "%INSTALL_GO_LINTERS%"=="ask" (
        echo.
        echo 🔍 Go Linters Installation
        echo Go linters include: gofmt, govet, staticcheck
        choice /C YN /M "Install additional Go linters (staticcheck, golint)? (Y/N)"
        if errorlevel 2 (
            set "INSTALL_GO_LINTERS=no"
        ) else (
            set "INSTALL_GO_LINTERS=yes"
        )
    )
    
    if "%INSTALL_GO_LINTERS%"=="yes" (
        echo.
        echo 📦 Installing Go linters...
        go install honnef.co/go/tools/cmd/staticcheck@latest
        go install golang.org/x/lint/golint@latest
        if %errorlevel% equ 0 (
            echo ✅ Go linters installed
        ) else (
            echo ⚠️  WARNING: Some Go linters may not have installed correctly
        )
    )
) else (
    if "%INSTALL_GO_LINTERS%"=="yes" (
        echo ⚠️  WARNING: Cannot install Go linters - Go not available
        echo To install Go support, download from https://golang.org/
    )
)

REM Create sample configuration
echo.
echo 📝 Creating sample configuration...
code-linter-mcp-server create-config --output "%INSTALL_DIR%\config.json" --force

if %errorlevel% neq 0 (
    echo ❌ ERROR: Failed to create sample configuration
    pause
    exit /b 1
)
echo ✅ Sample configuration created: %INSTALL_DIR%\config.json

REM Validate configuration
echo.
echo 🔍 Validating configuration...
code-linter-mcp-server validate-config "%INSTALL_DIR%\config.json"

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
echo ✅ Code Linter MCP Server installed to: %INSTALL_DIR%
if "%INSTALL_LINTERS%"=="yes" echo ✅ Python linters installed
if "%INSTALL_JS_LINTERS%"=="yes" echo ✅ JavaScript/TypeScript linters installed
if "%INSTALL_GO_LINTERS%"=="yes" echo ✅ Go linters installed
echo ✅ Configuration created: %INSTALL_DIR%\config.json

REM Determine script path for Claude Desktop config
for /f "tokens=*" %%i in ('where code-linter-mcp-server 2^>nul') do set SCRIPT_PATH=%%i
if "%SCRIPT_PATH%"=="" set SCRIPT_PATH=code-linter-mcp-server

echo.
echo 🔗 Claude Desktop Integration
echo ============================
echo Add this configuration to your Claude Desktop config file:
echo.
echo {
echo   "mcpServers": {
echo     "code-linter": {
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
echo 1. Customize %INSTALL_DIR%\config.json as needed
echo 2. Test: code-linter-mcp-server run --config "%INSTALL_DIR%\config.json"
echo 3. Add the configuration above to Claude Desktop
echo 4. Restart Claude Desktop
echo.
goto end

:show_help
echo.
echo Code Linter MCP Server Installer
echo.
echo Usage: install.bat [options]
echo.
echo Options:
echo   --source DIR           Source directory (default: C:\git\mcp-servers\code-linter-mcp-server)
echo   --install-dir DIR      Installation directory (default: C:\working\code-linter-mcp-server)
echo   --with-linters         Install Python linters without asking
echo   --without-linters      Skip Python linters installation
echo   --with-js-linters      Install JavaScript/TypeScript linters without asking
echo   --without-js-linters   Skip JS/TS linters installation
echo   --with-go-linters      Install Go linters without asking
echo   --without-go-linters   Skip Go linters installation
echo   --help, -h             Show this help message
echo.
echo Examples:
echo   install.bat
echo   install.bat --install-dir "D:\my-tools\code-linter"
echo   install.bat --with-linters --with-js-linters
echo   install.bat --source "C:\custom\source" --install-dir "C:\custom\install"
echo.

:end
pause
