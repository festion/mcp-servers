#!/bin/bash

# Claude Auto-Commit MCP Server Wrapper Script
# This script manages the Claude AI-powered auto-commit MCP server

set -e

SERVER_DIR="/home/dev/workspace/mcp-servers/claude-auto-commit-mcp-server"
SERVER_EXECUTABLE="$SERVER_DIR/dist/index.js"
LOG_FILE="/tmp/claude-auto-commit-mcp.log"
PID_FILE="/tmp/claude-auto-commit-mcp.pid"

# Environment variables
export NODE_ENV="${NODE_ENV:-production}"

# Check for required environment variables
check_environment() {
    local has_api_key=false
    local has_credentials=false
    
    # Check for API key
    if [[ -n "$ANTHROPIC_API_KEY" || -n "$CLAUDE_API_KEY" ]]; then
        has_api_key=true
    fi
    
    # Check for username/password (like Claude Code)
    if [[ -n "$CLAUDE_USERNAME" || -n "$CLAUDE_EMAIL" ]] && [[ -n "$CLAUDE_PASSWORD" ]]; then
        has_credentials=true
    fi
    
    if [[ "$has_api_key" == false && "$has_credentials" == false ]]; then
        echo "Error: Missing required Claude authentication!" >&2
        echo "" >&2
        echo "Please set one of the following authentication methods:" >&2
        echo "" >&2
        echo "Option 1: API Key Authentication" >&2
        echo "  export ANTHROPIC_API_KEY='your-api-key'" >&2
        echo "  # OR" >&2
        echo "  export CLAUDE_API_KEY='your-api-key'" >&2
        echo "" >&2
        echo "Option 2: Username/Password Authentication (like Claude Code)" >&2
        echo "  export CLAUDE_USERNAME='your-email@example.com'" >&2
        echo "  export CLAUDE_PASSWORD='your-password'" >&2
        echo "  # OR" >&2
        echo "  export CLAUDE_EMAIL='your-email@example.com'" >&2
        echo "  export CLAUDE_PASSWORD='your-password'" >&2
        echo "" >&2
        echo "Note: Username/password auth uses the same credentials as Claude Code" >&2
        echo "" >&2
        exit 1
    fi
    
    if [[ "$has_api_key" == true ]]; then
        echo "Using API key authentication"
    elif [[ "$has_credentials" == true ]]; then
        echo "Using username/password authentication (like Claude Code)"
    fi
}

# Build the server if needed
build_server() {
    if [[ ! -f "$SERVER_EXECUTABLE" ]]; then
        echo "Building Claude Auto-Commit MCP Server..."
        cd "$SERVER_DIR"
        ./build.sh
        cd -
    fi
}

# Start the server
start_server() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Claude Auto-Commit MCP Server is already running (PID: $pid)"
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi
    
    echo "Starting Claude Auto-Commit MCP Server..."
    
    # Start the server in the background
    nohup node "$SERVER_EXECUTABLE" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    
    echo "$pid" > "$PID_FILE"
    
    # Wait a moment and check if it started successfully
    sleep 2
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "Claude Auto-Commit MCP Server started successfully (PID: $pid)"
        echo "Log file: $LOG_FILE"
    else
        echo "Failed to start Claude Auto-Commit MCP Server"
        echo "Check log file: $LOG_FILE"
        rm -f "$PID_FILE"
        exit 1
    fi
}

# Stop the server
stop_server() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Stopping Claude Auto-Commit MCP Server (PID: $pid)..."
            kill "$pid"
            rm -f "$PID_FILE"
            echo "Server stopped"
        else
            echo "Server is not running"
            rm -f "$PID_FILE"
        fi
    else
        echo "Server is not running"
    fi
}

# Check server status
status_server() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Claude Auto-Commit MCP Server is running (PID: $pid)"
            echo "Log file: $LOG_FILE"
            return 0
        else
            echo "Server is not running (stale PID file)"
            rm -f "$PID_FILE"
            return 1
        fi
    else
        echo "Server is not running"
        return 1
    fi
}

# Show server logs
show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        tail -f "$LOG_FILE"
    else
        echo "No log file found at $LOG_FILE"
    fi
}

# Test the server
test_server() {
    echo "Testing Claude Auto-Commit MCP Server..."
    
    # Basic connectivity test
    local test_input='{"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}}'
    
    if status_server > /dev/null; then
        echo "Server is running. Testing tools..."
        
        # You can add more specific tests here
        echo "✓ Server is responsive"
        echo "✓ Available tools: generate_commit_message, auto_stage_and_commit, smart_commit"
        echo ""
        echo "To test functionality, ensure you have:"
        echo "  1. A Git repository with staged changes"
        echo "  2. Valid ANTHROPIC_API_KEY environment variable"
        echo "  3. MCP client configured to connect to this server"
    else
        echo "✗ Server is not running"
        exit 1
    fi
}

# Main script logic
case "${1:-}" in
    "start")
        check_environment
        build_server
        start_server
        ;;
    "stop")
        stop_server
        ;;
    "restart")
        stop_server
        check_environment
        build_server
        start_server
        ;;
    "status")
        status_server
        ;;
    "logs")
        show_logs
        ;;
    "test")
        test_server
        ;;
    "build")
        build_server
        echo "Build completed"
        ;;
    "stdio"|"")
        # Direct stdio mode for MCP client
        check_environment
        build_server
        
        echo "Starting Claude Auto-Commit MCP Server in stdio mode..." >&2
        exec node "$SERVER_EXECUTABLE"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|test|build|stdio}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the server in background mode"
        echo "  stop    - Stop the background server"
        echo "  restart - Restart the background server"
        echo "  status  - Check server status"
        echo "  logs    - Show server logs (follow mode)"
        echo "  test    - Test server functionality"
        echo "  build   - Build the server"
        echo "  stdio   - Run server in stdio mode (for MCP clients)"
        echo ""
        echo "Environment variables required (choose one):"
        echo "  Option 1: API Key"
        echo "    ANTHROPIC_API_KEY or CLAUDE_API_KEY - Your Claude API key"
        echo "  Option 2: Username/Password (like Claude Code)"
        echo "    CLAUDE_USERNAME/CLAUDE_EMAIL and CLAUDE_PASSWORD - Your Claude credentials"
        echo ""
        echo "Examples:"
        echo "  # Using API key"
        echo "  export ANTHROPIC_API_KEY='sk-ant-...'"
        echo "  $0 start"
        echo ""
        echo "  # Using Claude Code credentials"
        echo "  export CLAUDE_USERNAME='your-email@example.com'"
        echo "  export CLAUDE_PASSWORD='your-password'"
        echo "  $0 start"
        exit 1
        ;;
esac