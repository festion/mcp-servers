#!/bin/bash
# MCP Session Manager - Handles multi-session isolation and cleanup
# Prevents conflicts when running multiple putty instances

set -euo pipefail

# Session management configuration
MCP_SESSION_DIR="/tmp/mcp-sessions"
MCP_PID_DIR="$MCP_SESSION_DIR/pids"
MCP_CONFIG_DIR="$MCP_SESSION_DIR/configs"
MCP_LOG_DIR="$MCP_SESSION_DIR/logs"

# Get current session ID (based on terminal session)
get_session_id() {
    echo "${SSH_TTY:-${TTY:-$(tty 2>/dev/null || echo "unknown")}}" | sed 's/[^a-zA-Z0-9]/_/g'
}

# Initialize session directory structure
init_session_dirs() {
    local session_id="$1"
    mkdir -p "$MCP_PID_DIR/$session_id"
    mkdir -p "$MCP_CONFIG_DIR/$session_id"
    mkdir -p "$MCP_LOG_DIR/$session_id"
}

# Clean up orphaned processes from previous sessions
cleanup_orphaned_processes() {
    local session_id="$1"
    local pid_dir="$MCP_PID_DIR/$session_id"
    
    if [ -d "$pid_dir" ]; then
        for pid_file in "$pid_dir"/*.pid; do
            [ -f "$pid_file" ] || continue
            
            local pid=$(cat "$pid_file" 2>/dev/null || echo "")
            local service_name=$(basename "$pid_file" .pid)
            
            if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
                echo "Cleaning up orphaned PID file for $service_name (PID: $pid)"
                rm -f "$pid_file"
            elif [ -n "$pid" ]; then
                echo "Active process found for $service_name (PID: $pid)"
            fi
        done
    fi
}

# Start MCP server with session isolation
start_mcp_server() {
    local server_name="$1"
    local server_command="$2"
    local session_id="$3"
    
    local pid_file="$MCP_PID_DIR/$session_id/${server_name}.pid"
    local log_file="$MCP_LOG_DIR/$session_id/${server_name}.log"
    
    # Check if already running
    if [ -f "$pid_file" ]; then
        local existing_pid=$(cat "$pid_file")
        if kill -0 "$existing_pid" 2>/dev/null; then
            echo "Server $server_name already running for session $session_id (PID: $existing_pid)"
            return 0
        else
            rm -f "$pid_file"
        fi
    fi
    
    # Set session-specific environment
    export MCP_SESSION_ID="$session_id"
    export MCP_CONFIG_DIR="$MCP_CONFIG_DIR/$session_id"
    export MCP_PID_FILE="$pid_file"
    export MCP_LOG_FILE="$log_file"
    
    # Start server in background
    echo "Starting $server_name for session $session_id..."
    nohup bash -c "$server_command" > "$log_file" 2>&1 &
    local server_pid=$!
    echo "$server_pid" > "$pid_file"
    
    # Wait a moment to check if it started successfully
    sleep 2
    if kill -0 "$server_pid" 2>/dev/null; then
        echo "Successfully started $server_name (PID: $server_pid)"
        return 0
    else
        echo "Failed to start $server_name"
        rm -f "$pid_file"
        return 1
    fi
}

# Stop MCP server for session
stop_mcp_server() {
    local server_name="$1"
    local session_id="$2"
    
    local pid_file="$MCP_PID_DIR/$session_id/${server_name}.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Stopping $server_name (PID: $pid)..."
            kill "$pid"
            sleep 2
            if kill -0 "$pid" 2>/dev/null; then
                echo "Force killing $server_name..."
                kill -9 "$pid"
            fi
        fi
        rm -f "$pid_file"
    else
        echo "No PID file found for $server_name in session $session_id"
    fi
}

# Get next available port in range
get_available_port() {
    local start_port="$1"
    local session_id="$2"
    
    # Use session hash to offset port range
    local session_hash=$(echo "$session_id" | sum | cut -d' ' -f1)
    local port_offset=$((session_hash % 1000))
    local base_port=$((start_port + port_offset))
    
    # Find available port
    for ((port=base_port; port<base_port+100; port++)); do
        if ! ss -tuln | grep -q ":$port "; then
            echo "$port"
            return 0
        fi
    done
    
    echo "$base_port"
}

# Main function
main() {
    local action="${1:-help}"
    local session_id=$(get_session_id)
    
    # Initialize directories
    init_session_dirs "$session_id"
    
    case "$action" in
        "init")
            cleanup_orphaned_processes "$session_id"
            echo "Initialized MCP session: $session_id"
            ;;
        "start")
            local server_name="${2:-}"
            local server_command="${3:-}"
            if [ -z "$server_name" ] || [ -z "$server_command" ]; then
                echo "Usage: $0 start <server_name> '<server_command>'"
                exit 1
            fi
            start_mcp_server "$server_name" "$server_command" "$session_id"
            ;;
        "stop")
            local server_name="${2:-}"
            if [ -z "$server_name" ]; then
                echo "Usage: $0 stop <server_name>"
                exit 1
            fi
            stop_mcp_server "$server_name" "$session_id"
            ;;
        "status")
            echo "Session ID: $session_id"
            echo "Active servers:"
            if [ -d "$MCP_PID_DIR/$session_id" ]; then
                for pid_file in "$MCP_PID_DIR/$session_id"/*.pid; do
                    [ -f "$pid_file" ] || continue
                    local pid=$(cat "$pid_file" 2>/dev/null || echo "")
                    local service_name=$(basename "$pid_file" .pid)
                    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                        echo "  $service_name (PID: $pid) - RUNNING"
                    else
                        echo "  $service_name - STOPPED"
                    fi
                done
            fi
            ;;
        "cleanup")
            cleanup_orphaned_processes "$session_id"
            echo "Cleaned up session: $session_id"
            ;;
        "help"|*)
            echo "MCP Session Manager"
            echo "Usage: $0 <action> [arguments]"
            echo ""
            echo "Actions:"
            echo "  init                     - Initialize session and cleanup orphaned processes"
            echo "  start <name> '<cmd>'     - Start MCP server with session isolation"
            echo "  stop <name>              - Stop MCP server for current session"
            echo "  status                   - Show session status and running servers"
            echo "  cleanup                  - Clean up orphaned processes"
            echo "  help                     - Show this help"
            echo ""
            echo "Current session: $session_id"
            ;;
    esac
}

# Run main function
main "$@"