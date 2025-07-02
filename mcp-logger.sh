#!/bin/bash
# Centralized MCP Logging System
# Provides logging functions for all MCP wrapper scripts

# Create logs directory if it doesn't exist
LOGS_DIR="/home/dev/workspace/logs"
mkdir -p "$LOGS_DIR"

# Log files
MCP_MAIN_LOG="$LOGS_DIR/mcp-main.log"
MCP_ERROR_LOG="$LOGS_DIR/mcp-errors.log"
MCP_DEBUG_LOG="$LOGS_DIR/mcp-debug.log"

# Colors for console output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
mcp_log() {
    local level="$1"
    local server="$2"
    local message="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to main log
    echo "[$timestamp] [$level] [$server] $message" >> "$MCP_MAIN_LOG"
    
    # Log to specific files based on level
    case "$level" in
        "ERROR")
            echo "[$timestamp] [$server] $message" >> "$MCP_ERROR_LOG"
            echo -e "${RED}[ERROR]${NC} [$server] $message" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} [$server] $message" >&2
            ;;
        "INFO")
            echo -e "${GREEN}[INFO]${NC} [$server] $message"
            ;;
        "DEBUG")
            echo "[$timestamp] [$server] $message" >> "$MCP_DEBUG_LOG"
            if [[ "${MCP_DEBUG:-0}" == "1" ]]; then
                echo -e "${BLUE}[DEBUG]${NC} [$server] $message"
            fi
            ;;
    esac
}

# Convenience functions
mcp_info() {
    mcp_log "INFO" "$1" "$2"
}

mcp_warn() {
    mcp_log "WARN" "$1" "$2"
}

mcp_error() {
    mcp_log "ERROR" "$1" "$2"
}

mcp_debug() {
    mcp_log "DEBUG" "$1" "$2"
}

# Function to rotate logs when they get too large
rotate_logs() {
    local max_size=10485760  # 10MB in bytes
    
    for log_file in "$MCP_MAIN_LOG" "$MCP_ERROR_LOG" "$MCP_DEBUG_LOG"; do
        if [[ -f "$log_file" ]] && [[ $(stat -c%s "$log_file") -gt $max_size ]]; then
            mv "$log_file" "${log_file}.old"
            touch "$log_file"
            mcp_info "SYSTEM" "Rotated log file: $log_file"
        fi
    done
}

# Function to clean old logs
clean_old_logs() {
    find "$LOGS_DIR" -name "*.log.old" -mtime +7 -delete
    mcp_info "SYSTEM" "Cleaned old log files"
}

# Export functions for use in wrapper scripts
export -f mcp_log mcp_info mcp_warn mcp_error mcp_debug rotate_logs clean_old_logs