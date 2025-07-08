#!/bin/bash
# MCP Token Manager - Secure token persistence solution for all MCP servers

# Configuration directories
CONFIG_DIR="/home/dev/.mcp_tokens"
BACKUP_DIR="/home/dev/.mcp_tokens/backups"

# Create directories if they don't exist
mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
chmod 700 "$CONFIG_DIR" "$BACKUP_DIR"

# Token files
GITHUB_TOKEN_FILE="$CONFIG_DIR/github_token"
HASS_TOKEN_FILE="$CONFIG_DIR/hass_token"
HASS_URL_FILE="$CONFIG_DIR/hass_url"
PROXMOX_TOKEN_FILE="$CONFIG_DIR/proxmox_token"
PROXMOX_HOST_FILE="$CONFIG_DIR/proxmox_host"
PROXMOX_USER_FILE="$CONFIG_DIR/proxmox_user"
WIKIJS_TOKEN_FILE="$CONFIG_DIR/wikijs_token"
WIKIJS_URL_FILE="$CONFIG_DIR/wikijs_url"

# Function to securely store credentials
store_credential() {
    local service="$1"
    local key="$2"
    local value="$3"
    
    if [ -z "$service" ] || [ -z "$key" ] || [ -z "$value" ]; then
        echo "ERROR: Missing parameters. Usage: store_credential <service> <key> <value>"
        return 1
    fi
    
    local file_var="${service^^}_${key^^}_FILE"
    local file_path="${!file_var}"
    
    if [ -z "$file_path" ]; then
        echo "ERROR: Unknown service/key combination: $service/$key"
        return 1
    fi
    
    # Validate token/URL formats
    case "$service:$key" in
        "github:token")
            if [[ ! "$value" =~ ^ghp_[a-zA-Z0-9]{36}$ ]]; then
                echo "ERROR: Invalid GitHub token format"
                return 1
            fi
            ;;
        "hass:url"|"wikijs:url")
            if [[ ! "$value" =~ ^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$ ]]; then
                echo "ERROR: Invalid URL format"
                return 1
            fi
            ;;
        "proxmox:host")
            if [[ ! "$value" =~ ^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[a-zA-Z0-9.-]+)$ ]]; then
                echo "ERROR: Invalid host format (IP address or hostname)"
                return 1
            fi
            ;;
        "proxmox:user")
            if [[ ! "$value" =~ ^[a-zA-Z0-9_]+@[a-zA-Z0-9_]+$ ]]; then
                echo "ERROR: Invalid Proxmox user format (expected: user@realm)"
                return 1
            fi
            ;;
        "proxmox:token")
            if [[ ! "$value" =~ ^PVEAPIToken=.+$ ]]; then
                echo "ERROR: Invalid Proxmox token format (expected: PVEAPIToken=...)"
                return 1
            fi
            ;;
    esac
    
    # Backup existing credential
    if [ -f "$file_path" ]; then
        cp "$file_path" "$BACKUP_DIR/$(basename "$file_path").$(date +%Y%m%d_%H%M%S).backup"
    fi
    
    # Store credential securely
    echo "$value" > "$file_path"
    chmod 600 "$file_path"
    
    echo "$service $key stored successfully"
    return 0
}

# Function to load credentials into environment
load_credentials() {
    local service="$1"
    local loaded=0
    
    if [ -z "$service" ] || [ "$service" = "all" ]; then
        # Load all services
        for svc in github hass proxmox wikijs; do
            load_credentials "$svc" >/dev/null 2>&1 && ((loaded++))
        done
        echo "Loaded credentials for $loaded services"
        return 0
    fi
    
    case "$service" in
        "github")
            if [ -f "$GITHUB_TOKEN_FILE" ]; then
                export GITHUB_PERSONAL_ACCESS_TOKEN="$(cat "$GITHUB_TOKEN_FILE")"
                echo "GitHub credentials loaded"
                return 0
            fi
            ;;
        "hass")
            if [ -f "$HASS_TOKEN_FILE" ] && [ -f "$HASS_URL_FILE" ]; then
                export HA_TOKEN="$(cat "$HASS_TOKEN_FILE")"
                export HA_URL="$(cat "$HASS_URL_FILE")"
                echo "Home Assistant credentials loaded"
                return 0
            fi
            ;;
        "proxmox")
            if [ -f "$PROXMOX_TOKEN_FILE" ] && [ -f "$PROXMOX_HOST_FILE" ] && [ -f "$PROXMOX_USER_FILE" ]; then
                export PROXMOX_TOKEN="$(cat "$PROXMOX_TOKEN_FILE")"
                export PROXMOX_HOST="$(cat "$PROXMOX_HOST_FILE")"
                export PROXMOX_USER="$(cat "$PROXMOX_USER_FILE")"
                echo "Proxmox credentials loaded"
                return 0
            fi
            ;;
        "wikijs")
            if [ -f "$WIKIJS_TOKEN_FILE" ] && [ -f "$WIKIJS_URL_FILE" ]; then
                export WIKIJS_TOKEN="$(cat "$WIKIJS_TOKEN_FILE")"
                export WIKIJS_URL="$(cat "$WIKIJS_URL_FILE")"
                echo "WikiJS credentials loaded"
                return 0
            fi
            ;;
    esac
    
    echo "ERROR: $service credentials not found or incomplete"
    return 1
}

# Legacy function for backward compatibility
load_token() {
    load_credentials github
}

# Function to verify credentials
verify_credentials() {
    local service="$1"
    
    if [ -z "$service" ] || [ "$service" = "all" ]; then
        # Verify all services
        for svc in github hass proxmox wikijs; do
            echo "=== Verifying $svc ==="
            verify_credentials "$svc"
            echo ""
        done
        return 0
    fi
    
    case "$service" in
        "github")
            if [ ! -f "$GITHUB_TOKEN_FILE" ]; then
                echo "❌ GitHub token not stored"
                return 1
            fi
            local token=$(cat "$GITHUB_TOKEN_FILE")
            echo "GitHub token: ${token:0:15}..."
            
            if command -v curl >/dev/null 2>&1; then
                echo "Testing with GitHub API..."
                local response=$(curl -s -H "Authorization: token $token" https://api.github.com/user)
                if echo "$response" | grep -q '"login"'; then
                    echo "✅ GitHub token is valid"
                    return 0
                else
                    echo "❌ GitHub token is invalid or expired"
                    return 1
                fi
            else
                echo "curl not available, skipping API test"
                return 0
            fi
            ;;
        "hass")
            if [ ! -f "$HASS_TOKEN_FILE" ] || [ ! -f "$HASS_URL_FILE" ]; then
                echo "❌ Home Assistant credentials not stored"
                return 1
            fi
            local token=$(cat "$HASS_TOKEN_FILE")
            local url=$(cat "$HASS_URL_FILE")
            echo "Home Assistant URL: $url"
            echo "Home Assistant token: ${token:0:15}..."
            echo "✅ Home Assistant credentials stored (API test requires running instance)"
            return 0
            ;;
        "proxmox")
            if [ ! -f "$PROXMOX_TOKEN_FILE" ] || [ ! -f "$PROXMOX_HOST_FILE" ] || [ ! -f "$PROXMOX_USER_FILE" ]; then
                echo "❌ Proxmox credentials not stored"
                return 1
            fi
            local token=$(cat "$PROXMOX_TOKEN_FILE")
            local host=$(cat "$PROXMOX_HOST_FILE")
            local user=$(cat "$PROXMOX_USER_FILE")
            echo "Proxmox host: $host"
            echo "Proxmox user: $user"
            echo "Proxmox token: ${token:0:25}..."
            echo "✅ Proxmox credentials stored (API test requires running instance)"
            return 0
            ;;
        "wikijs")
            if [ ! -f "$WIKIJS_TOKEN_FILE" ] || [ ! -f "$WIKIJS_URL_FILE" ]; then
                echo "❌ WikiJS credentials not stored"
                return 1
            fi
            local token=$(cat "$WIKIJS_TOKEN_FILE")
            local url=$(cat "$WIKIJS_URL_FILE")
            echo "WikiJS URL: $url"
            echo "WikiJS token: ${token:0:20}..."
            echo "✅ WikiJS credentials stored (API test requires running instance)"
            return 0
            ;;
    esac
    
    echo "❌ Unknown service: $service"
    return 1
}

# Legacy function for backward compatibility
verify_token() {
    verify_credentials github
}

# Function to add to shell profile
setup_auto_load() {
    local shell_profile=""
    
    if [ -n "$BASH_VERSION" ]; then
        shell_profile="$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ]; then
        shell_profile="$HOME/.zshrc"
    else
        echo "Unsupported shell. Please manually add to your shell profile:"
        echo "source /home/dev/workspace/github-token-manager.sh && load_credentials all"
        return 1
    fi
    
    local line="# Auto-load MCP credentials"
    local source_line="source /home/dev/workspace/github-token-manager.sh && load_credentials all 2>/dev/null || true"
    
    if ! grep -q "$source_line" "$shell_profile"; then
        echo "$line" >> "$shell_profile"
        echo "$source_line" >> "$shell_profile"
        echo "Auto-load setup added to $shell_profile"
        echo "Restart your shell or run: source $shell_profile"
    else
        echo "Auto-load already configured in $shell_profile"
    fi
}

# Main command handling
case "$1" in
    "store")
        if [ "$#" -eq 4 ]; then
            store_credential "$2" "$3" "$4"
        elif [ "$#" -eq 2 ]; then
            # Legacy support for GitHub token
            store_credential "github" "token" "$2"
        else
            echo "Usage: $0 store <service> <key> <value>"
            echo "   or: $0 store <github_token> (legacy)"
            echo ""
            echo "Examples:"
            echo "  $0 store github token ghp_your_token_here"
            echo "  $0 store hass token your_hass_token_here"
            echo "  $0 store hass url http://192.168.1.155:8123"
            echo "  $0 store proxmox token 'PVEAPIToken=root@pam!token=uuid'"
            echo "  $0 store proxmox host 192.168.1.137"
            echo "  $0 store proxmox user root@pam"
            echo "  $0 store wikijs token your_wikijs_token_here"
            echo "  $0 store wikijs url http://192.168.1.90:3000"
            exit 1
        fi
        ;;
    "load")
        load_credentials "${2:-all}"
        ;;
    "verify")
        verify_credentials "${2:-all}"
        ;;
    "setup")
        setup_auto_load
        ;;
    "list")
        echo "Stored credentials:"
        for service in github hass proxmox wikijs; do
            echo "=== $service ==="
            verify_credentials "$service" 2>/dev/null || echo "  Not configured"
        done
        ;;
    *)
        echo "MCP Token Manager - Secure credential management for all MCP servers"
        echo "Usage: $0 {store|load|verify|setup|list}"
        echo ""
        echo "Commands:"
        echo "  store <service> <key> <value>  - Store credential for service"
        echo "  load [service]                 - Load credentials (default: all)"
        echo "  verify [service]               - Verify credentials (default: all)"
        echo "  setup                          - Setup auto-load in shell profile"
        echo "  list                           - List all stored credentials"
        echo ""
        echo "Supported services: github, hass, proxmox, wikijs"
        echo ""
        echo "Examples:"
        echo "  $0 store github token ghp_your_token_here"
        echo "  $0 store hass token your_hass_token_here"
        echo "  $0 store hass url http://192.168.1.155:8123"
        echo "  $0 load github"
        echo "  $0 verify all"
        exit 1
        ;;
esac