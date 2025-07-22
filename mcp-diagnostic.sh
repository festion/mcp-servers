#!/bin/bash
# MCP Server Diagnostic Script
# Tests each MCP server individually and reports status

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/home/dev/workspace/mcp-diagnostic.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to test a wrapper script
test_wrapper() {
    local name="$1"
    local script="$2"
    
    echo -e "\n${YELLOW}Testing $name...${NC}"
    log_message "Testing $name wrapper: $script"
    
    if [[ ! -f "$script" ]]; then
        echo -e "${RED}❌ Script not found: $script${NC}"
        log_message "ERROR: $name script not found at $script"
        return 1
    fi
    
    if [[ ! -x "$script" ]]; then
        echo -e "${RED}❌ Script not executable: $script${NC}"
        log_message "ERROR: $name script not executable"
        return 1
    fi
    
    # Test if script runs without immediate error
    timeout 10s "$script" &>/dev/null &
    local pid=$!
    sleep 2
    
    if kill -0 $pid 2>/dev/null; then
        kill $pid 2>/dev/null
        echo -e "${GREEN}✅ $name appears to be working${NC}"
        log_message "SUCCESS: $name wrapper started successfully"
        return 0
    else
        wait $pid
        local exit_code=$?
        echo -e "${RED}❌ $name failed with exit code $exit_code${NC}"
        log_message "ERROR: $name wrapper failed with exit code $exit_code"
        return 1
    fi
}

# Function to check MCP server dependencies
check_dependencies() {
    echo -e "\n${YELLOW}Checking dependencies...${NC}"
    
    # Check if node is installed for filesystem server
    if command -v node &> /dev/null; then
        echo -e "${GREEN}✅ Node.js found: $(node --version)${NC}"
        log_message "Node.js version: $(node --version)"
    else
        echo -e "${RED}❌ Node.js not found${NC}"
        log_message "ERROR: Node.js not found"
    fi
    
    # Check if python is available for various servers
    if command -v python3 &> /dev/null; then
        echo -e "${GREEN}✅ Python3 found: $(python3 --version)${NC}"
        log_message "Python3 version: $(python3 --version)"
    else
        echo -e "${RED}❌ Python3 not found${NC}"
        log_message "ERROR: Python3 not found"
    fi
    
    # Check if docker is available for some servers
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✅ Docker found: $(docker --version)${NC}"
        log_message "Docker version: $(docker --version)"
    else
        echo -e "${YELLOW}⚠️ Docker not found (needed for some servers)${NC}"
        log_message "WARNING: Docker not found"
    fi
}

# Function to check server implementations
check_implementations() {
    echo -e "\n${YELLOW}Checking server implementations...${NC}"
    
    local servers=(
        "Filesystem:/home/dev/workspace/node_modules/@modelcontextprotocol/server-filesystem"
        "Network-FS:/home/dev/workspace/mcp-servers/mcp-servers/network-mcp-server"
        "Code-Linter:/home/dev/workspace/mcp-servers/mcp-servers/code-linter-mcp-server"
        "Proxmox:/home/dev/workspace/mcp-servers/mcp-servers/proxmox-mcp-server"
        "WikiJS:/home/dev/workspace/mcp-servers/mcp-servers/wikijs-mcp-server"
        "Home-Assistant:/home/dev/workspace/home-assistant-mcp-server"
        "Serena:/home/dev/workspace/serena"
    )
    
    for server_info in "${servers[@]}"; do
        local name="${server_info%%:*}"
        local path="${server_info##*:}"
        
        if [[ -d "$path" ]]; then
            echo -e "${GREEN}✅ $name implementation found${NC}"
            log_message "$name implementation exists at $path"
        else
            echo -e "${RED}❌ $name implementation missing${NC}"
            log_message "ERROR: $name implementation missing at $path"
        fi
    done
}

# Main diagnostic function
main() {
    echo -e "${YELLOW}=== MCP Server Diagnostic Report ===${NC}"
    echo "Started at: $(date)"
    echo "Log file: $LOG_FILE"
    
    log_message "=== MCP Diagnostic Started ==="
    
    # Clear previous log
    > "$LOG_FILE"
    
    check_dependencies
    check_implementations
    
    echo -e "\n${YELLOW}Testing individual wrapper scripts...${NC}"
    
    local wrappers=(
        "Filesystem:node /home/dev/workspace/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js /home/dev/workspace"
        "Network-FS:/home/dev/workspace/network-mcp-wrapper.sh"
        "Code-Linter:/home/dev/workspace/code-linter-wrapper.sh"
        "Proxmox:/home/dev/workspace/proxmox-mcp-wrapper.sh"
        "WikiJS:/home/dev/workspace/wikijs-mcp-wrapper.sh"
        "Home-Assistant:/home/dev/workspace/hass-mcp-wrapper.sh"
        "Serena:/home/dev/workspace/serena-mcp-wrapper.sh"
        "GitHub:/home/dev/workspace/github-wrapper.sh"
    )
    
    local success_count=0
    local total_count=${#wrappers[@]}
    
    for wrapper_info in "${wrappers[@]}"; do
        local name="${wrapper_info%%:*}"
        local script="${wrapper_info##*:}"
        
        if test_wrapper "$name" "$script"; then
            ((success_count++))
        fi
    done
    
    echo -e "\n${YELLOW}=== Summary ===${NC}"
    echo -e "Successful servers: ${GREEN}$success_count${NC}/$total_count"
    echo -e "Failed servers: ${RED}$((total_count - success_count))${NC}/$total_count"
    
    log_message "=== Diagnostic Summary ==="
    log_message "Successful: $success_count/$total_count"
    log_message "Failed: $((total_count - success_count))/$total_count"
    log_message "=== MCP Diagnostic Completed ==="
    
    echo -e "\nFull log available at: ${YELLOW}$LOG_FILE${NC}"
}

# Run main function
main "$@"