@echo off
REM Code Linter MCP Server - Main Executable
REM This is the file that should be placed at C:\my-tools\linter

REM Store the original directory
set ORIGINAL_DIR=%CD%

REM Change to the MCP server directory
cd /d "C:\GIT\mcp-servers\code-linter-mcp-server"

REM Set Python path to include the source directory
set PYTHONPATH=C:\GIT\mcp-servers\code-linter-mcp-server\src;%PYTHONPATH%

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python not found in PATH
    echo Please ensure Python is installed and available in PATH
    exit /b 1
)

REM Check if the MCP server module is available
python -c "import code_linter_mcp.cli" >nul 2>&1
if errorlevel 1 (
    echo Error: Code Linter MCP module not found
    echo Please ensure the module is properly installed at C:\GIT\mcp-servers\code-linter-mcp-server
    exit /b 1
)

REM Run the MCP server
python -m code_linter_mcp.cli %*

REM Restore original directory
cd /d "%ORIGINAL_DIR%"
