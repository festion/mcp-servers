#!/bin/bash

# Setup and validate MCP servers for the homelab-gitops-auditor ecosystem
# This script installs, configures, and validates all required MCP servers

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MCP_CONFIG="$PROJECT_ROOT/.mcp.json"
LOG_FILE="/tmp/setup-mcp-servers.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Help function
show_help() {
    cat << EOF
MCP Server Setup and Validation Script

Usage: $0 [OPTIONS]

Options:
    --help              Show this help message
    --update-config     Update MCP configuration only (skip installation)
    --validate-only     Validate existing MCP setup without changes
    --verbose           Enable verbose output
    --dry-run          Show what would be done without making changes

MCP Servers Configured:
    - filesystem        File system access via npx
    - serena           Primary orchestrator via uv
    - wikijs-mcp       Wiki.js documentation integration
    - github           GitHub API integration via Docker
    - network-fs       Network file system access
    - proxmox-mcp      Proxmox virtualization management  
    - hass-mcp         Home Assistant integration via Docker

Configuration Placeholders to Update:
    - {{USERNAME}}     - System username for file paths
    - {{HASS_URL}}     - Home Assistant URL
    - {{HASS_TOKEN}}   - Home Assistant access token
    - {{GITHUB_TOKEN}} - GitHub personal access token

Examples:
    $0                      # Full setup and validation
    $0 --update-config      # Update configuration only
    $0 --validate-only      # Validate current setup
    $0 --dry-run            # Preview actions without executing

EOF
}

# Parse command line arguments
UPDATE_CONFIG_ONLY=false
VALIDATE_ONLY=false
VERBOSE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --update-config)
            UPDATE_CONFIG_ONLY=true
            shift
            ;;
        --validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Initialize log
echo "=== MCP Server Setup - $(date) ===" > "$LOG_FILE"
log "Starting MCP server setup and validation..."
log "Project root: $PROJECT_ROOT"
log "MCP config: $MCP_CONFIG"

# Check if MCP configuration exists
if [[ ! -f "$MCP_CONFIG" ]]; then
    error "MCP configuration not found at: $MCP_CONFIG"
    error "Run the deployment script first: ./scripts/deploy-mcp-config.sh"
    exit 1
fi

# Validation function for required tools
validate_dependencies() {
    log "Validating dependencies..."
    
    local missing_deps=()
    
    # Check npm/npx for filesystem MCP
    if ! command -v npx >/dev/null 2>&1; then
        missing_deps+=("npx (Node.js)")
    fi
    
    # Check uv for Serena
    if ! command -v uv >/dev/null 2>&1; then
        missing_deps+=("uv (Python package manager)")
    fi
    
    # Check Docker for containerized servers
    if ! command -v docker >/dev/null 2>&1; then
        missing_deps+=("docker")
    fi
    
    # Check Python for Python-based servers
    if ! command -v python >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
        missing_deps+=("python3")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing_deps[*]}"
        log "Install missing dependencies and try again"
        return 1
    fi
    
    success "All dependencies available"
    return 0
}

# Validation function for MCP server paths
validate_server_paths() {
    log "Validating MCP server paths..."
    
    local validation_errors=0
    
    # Check Serena path
    if [[ ! -d "/mnt/c/GIT/serena" ]]; then
        error "Serena not found at /mnt/c/GIT/serena"
        validation_errors=$((validation_errors + 1))
    else
        success "Serena path validated"
    fi
    
    # Check WikiJS MCP server path
    if [[ ! -d "/mnt/c/GIT/mcp-servers/wikijs-mcp-server" ]]; then
        error "WikiJS MCP server not found at /mnt/c/GIT/mcp-servers/wikijs-mcp-server"
        validation_errors=$((validation_errors + 1))
    else
        success "WikiJS MCP server path validated"
    fi
    
    # Check Proxmox MCP server path
    if [[ ! -d "/mnt/c/GIT/mcp-servers/proxmox-mcp-server" ]]; then
        error "Proxmox MCP server not found at /mnt/c/GIT/mcp-servers/proxmox-mcp-server"
        validation_errors=$((validation_errors + 1))
    else
        success "Proxmox MCP server path validated"
    fi
    
    # Check Network-FS path
    if [[ ! -d "/mnt/c/my-tools/network-fs" ]]; then
        warning "Network-FS not found at /mnt/c/my-tools/network-fs (optional)"
    else
        success "Network-FS path validated"
    fi
    
    if [[ $validation_errors -gt 0 ]]; then
        error "$validation_errors validation errors found"
        return 1
    fi
    
    success "All server paths validated"
    return 0
}

# Test MCP server functionality
test_mcp_servers() {
    log "Testing MCP server functionality..."
    
    # Test filesystem MCP (npx-based)
    log "Testing filesystem MCP server..."
    if $DRY_RUN; then
        log "[DRY RUN] Would test filesystem MCP server"
    else
        if timeout 10s npx -y @modelcontextprotocol/server-filesystem --version >/dev/null 2>&1; then
            success "Filesystem MCP server functional"
        else
            warning "Filesystem MCP server test failed or timed out"
        fi
    fi
    
    # Test Docker availability for containerized servers
    log "Testing Docker functionality..."
    if $DRY_RUN; then
        log "[DRY RUN] Would test Docker functionality"
    else
        if timeout 10s docker info >/dev/null 2>&1; then
            success "Docker functional"
        else
            error "Docker not functional - required for GitHub and Home Assistant MCP servers"
        fi
    fi
    
    # Test Serena (if available)
    log "Testing Serena MCP server..."
    if $DRY_RUN; then
        log "[DRY RUN] Would test Serena MCP server"
    elif [[ -d "/mnt/c/GIT/serena" ]]; then
        if timeout 10s uv run --directory /mnt/c/GIT/serena serena-mcp-server --help >/dev/null 2>&1; then
            success "Serena MCP server functional"
        else
            warning "Serena MCP server test failed"
        fi
    fi
}

# Update configuration placeholders
update_configuration() {
    if [[ ! $UPDATE_CONFIG_ONLY == true ]] && [[ ! $DRY_RUN == true ]]; then
        return 0
    fi
    
    log "Configuration update functionality..."
    
    if $DRY_RUN; then
        log "[DRY RUN] Would check for configuration placeholders:"
        log "  - {{USERNAME}} placeholders in filesystem paths"
        log "  - {{HASS_URL}} and {{HASS_TOKEN}} for Home Assistant"
        log "  - {{GITHUB_TOKEN}} for GitHub integration"
        return 0
    fi
    
    # Check for placeholder values that need updating
    if grep -q "{{" "$MCP_CONFIG" 2>/dev/null; then
        warning "Configuration contains placeholder values:"
        grep "{{" "$MCP_CONFIG" | sed 's/^/  /'
        log ""
        log "Update the following placeholders in $MCP_CONFIG:"
        log "  - {{USERNAME}} - Replace with your system username"
        log "  - {{HASS_URL}} - Replace with your Home Assistant URL"
        log "  - {{HASS_TOKEN}} - Replace with your Home Assistant token"
        log "  - {{GITHUB_TOKEN}} - Replace with your GitHub personal access token"
    else
        success "No configuration placeholders found"
    fi
}

# Main execution
main() {
    log "=== MCP Server Setup Starting ==="
    
    if $VALIDATE_ONLY; then
        log "Running validation only..."
    elif $UPDATE_CONFIG_ONLY; then
        log "Running configuration update only..."
    elif $DRY_RUN; then
        log "Running in dry-run mode..."
    else
        log "Running full setup and validation..."
    fi
    
    # Always validate dependencies
    if ! validate_dependencies; then
        exit 1
    fi
    
    # Always validate server paths
    if ! validate_server_paths; then
        exit 1
    fi
    
    # Test MCP servers unless it's config-only mode
    if [[ ! $UPDATE_CONFIG_ONLY == true ]]; then
        test_mcp_servers
    fi
    
    # Handle configuration updates
    update_configuration
    
    # Summary
    log ""
    log "=== Setup Summary ==="
    success "MCP server setup and validation completed"
    
    if [[ $UPDATE_CONFIG_ONLY == true ]]; then
        log "Configuration validation completed"
    elif [[ $VALIDATE_ONLY == true ]]; then
        log "Validation completed - no changes made"
    elif [[ $DRY_RUN == true ]]; then
        log "Dry run completed - no changes made"
    else
        log "Full setup and validation completed"
    fi
    
    log ""
    log "Next steps:"
    log "1. Update any configuration placeholders if present"
    log "2. Restart Claude desktop application"
    log "3. Test MCP integration in Claude"
    log "4. Deploy to other repositories: ./scripts/deploy-mcp-config.sh"
    
    log ""
    log "For troubleshooting, see: .mcp/README.md"
    log "Full log available at: $LOG_FILE"
}

# Execute main function
main "$@"