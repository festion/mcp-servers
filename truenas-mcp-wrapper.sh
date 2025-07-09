#!/bin/bash

# TrueNAS MCP Server Wrapper Script
# This script provides a secure wrapper for the TrueNAS MCP server
# It manages environment variables, logging, and server lifecycle

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/mcp-servers/mcp-servers/truenas-mcp-server"
LOG_FILE="$SCRIPT_DIR/logs/truenas-mcp.log"
PID_FILE="$SCRIPT_DIR/truenas-mcp.pid"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Default configuration
DEFAULT_TRUENAS_URL="http://truenas.internal.lakehouse.wtf"
DEFAULT_API_KEY="1-FROvjtWKEp98m4xP8moCp265r5YeGSnnRaGIaFAyppq9AjlbNsPbLIzIGBCb7PG2"
DEFAULT_VERIFY_SSL="false"
DEFAULT_TIMEOUT="30"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [TrueNAS-MCP] $1" | tee -a "$LOG_FILE"
}

# Function to check if server is running
is_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Function to start the server
start_server() {
    if is_running; then
        log "TrueNAS MCP server is already running (PID: $(cat "$PID_FILE"))"
        return 0
    fi

    log "Starting TrueNAS MCP server..."
    
    # Set environment variables
    export TRUENAS_URL="${TRUENAS_URL:-$DEFAULT_TRUENAS_URL}"
    export TRUENAS_API_KEY="${TRUENAS_API_KEY:-$DEFAULT_API_KEY}"
    export TRUENAS_VERIFY_SSL="${TRUENAS_VERIFY_SSL:-$DEFAULT_VERIFY_SSL}"
    export TRUENAS_TIMEOUT="${TRUENAS_TIMEOUT:-$DEFAULT_TIMEOUT}"
    
    # Log configuration (mask sensitive data)
    log "Configuration:"
    log "  TRUENAS_URL: $TRUENAS_URL"
    log "  TRUENAS_API_KEY: ${TRUENAS_API_KEY:0:20}..."
    log "  TRUENAS_VERIFY_SSL: $TRUENAS_VERIFY_SSL"
    log "  TRUENAS_TIMEOUT: $TRUENAS_TIMEOUT"
    
    # Change to server directory
    cd "$SERVER_DIR" || {
        log "ERROR: Cannot change to server directory: $SERVER_DIR"
        return 1
    }
    
    # Check if server file exists
    if [ ! -f "truenas_mcp_server.py" ]; then
        log "ERROR: TrueNAS MCP server file not found: truenas_mcp_server.py"
        return 1
    fi
    
    # Start the server
    python3 truenas_mcp_server.py 2>&1 | while IFS= read -r line; do
        log "$line"
    done &
    
    # Store PID
    echo $! > "$PID_FILE"
    
    log "TrueNAS MCP server started with PID: $(cat "$PID_FILE")"
    return 0
}

# Function to stop the server
stop_server() {
    if ! is_running; then
        log "TrueNAS MCP server is not running"
        return 0
    fi
    
    PID=$(cat "$PID_FILE")
    log "Stopping TrueNAS MCP server (PID: $PID)..."
    
    # Try graceful shutdown first
    kill -TERM "$PID" 2>/dev/null
    
    # Wait for graceful shutdown
    for i in {1..10}; do
        if ! ps -p "$PID" > /dev/null 2>&1; then
            log "TrueNAS MCP server stopped gracefully"
            rm -f "$PID_FILE"
            return 0
        fi
        sleep 1
    done
    
    # Force kill if still running
    log "Force killing TrueNAS MCP server..."
    kill -KILL "$PID" 2>/dev/null
    rm -f "$PID_FILE"
    log "TrueNAS MCP server force stopped"
    return 0
}

# Function to restart the server
restart_server() {
    log "Restarting TrueNAS MCP server..."
    stop_server
    sleep 2
    start_server
}

# Function to show server status
show_status() {
    if is_running; then
        PID=$(cat "$PID_FILE")
        log "TrueNAS MCP server is running (PID: $PID)"
        
        # Show process info
        if command -v ps > /dev/null 2>&1; then
            ps -p "$PID" -o pid,ppid,cmd --no-headers 2>/dev/null | while read -r line; do
                log "Process: $line"
            done
        fi
    else
        log "TrueNAS MCP server is not running"
    fi
}

# Function to test server connectivity
test_server() {
    log "Testing TrueNAS MCP server connectivity..."
    
    cd "$SERVER_DIR" || {
        log "ERROR: Cannot change to server directory: $SERVER_DIR"
        return 1
    }
    
    # Set environment variables
    export TRUENAS_URL="${TRUENAS_URL:-$DEFAULT_TRUENAS_URL}"
    export TRUENAS_API_KEY="${TRUENAS_API_KEY:-$DEFAULT_API_KEY}"
    export TRUENAS_VERIFY_SSL="${TRUENAS_VERIFY_SSL:-$DEFAULT_VERIFY_SSL}"
    export TRUENAS_TIMEOUT="${TRUENAS_TIMEOUT:-$DEFAULT_TIMEOUT}"
    
    # Run test startup script
    if [ -f "test_startup.py" ]; then
        python3 test_startup.py
    else
        log "ERROR: test_startup.py not found"
        return 1
    fi
}

# Function to show logs
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE"
    else
        log "No log file found: $LOG_FILE"
    fi
}

# Function to show help
show_help() {
    cat << EOF
TrueNAS MCP Server Wrapper

Usage: $0 [COMMAND]

Commands:
    start     Start the TrueNAS MCP server
    stop      Stop the TrueNAS MCP server
    restart   Restart the TrueNAS MCP server
    status    Show server status
    test      Test server connectivity
    logs      Show server logs (tail -f)
    help      Show this help message

Environment Variables:
    TRUENAS_URL         TrueNAS URL (default: $DEFAULT_TRUENAS_URL)
    TRUENAS_API_KEY     TrueNAS API key (default: $DEFAULT_API_KEY)
    TRUENAS_VERIFY_SSL  Verify SSL certificates (default: $DEFAULT_VERIFY_SSL)
    TRUENAS_TIMEOUT     Request timeout in seconds (default: $DEFAULT_TIMEOUT)

Files:
    Server Directory: $SERVER_DIR
    Log File: $LOG_FILE
    PID File: $PID_FILE

Examples:
    $0 start
    $0 status
    $0 test
    TRUENAS_URL=https://my-truenas.local $0 start
EOF
}

# Main command handler
case "${1:-start}" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        restart_server
        ;;
    status)
        show_status
        ;;
    test)
        test_server
        ;;
    logs)
        show_logs
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log "Unknown command: $1"
        show_help
        exit 1
        ;;
esac

# When run without arguments, start the server directly (MCP mode)
if [ $# -eq 0 ]; then
    # Check if this is being called as an MCP server
    if [ -t 0 ]; then
        # Interactive mode - show help
        show_help
    else
        # Non-interactive mode - start server directly
        cd "$SERVER_DIR" || {
            log "ERROR: Cannot change to server directory: $SERVER_DIR"
            exit 1
        }
        
        # Set environment variables
        export TRUENAS_URL="${TRUENAS_URL:-$DEFAULT_TRUENAS_URL}"
        export TRUENAS_API_KEY="${TRUENAS_API_KEY:-$DEFAULT_API_KEY}"
        export TRUENAS_VERIFY_SSL="${TRUENAS_VERIFY_SSL:-$DEFAULT_VERIFY_SSL}"
        export TRUENAS_TIMEOUT="${TRUENAS_TIMEOUT:-$DEFAULT_TIMEOUT}"
        
        # Run the server directly
        exec python3 truenas_mcp_server.py
    fi
fi