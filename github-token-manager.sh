#!/bin/bash
# GitHub Token Manager - Secure token persistence solution

TOKEN_FILE="/home/dev/.github_token"
BACKUP_FILE="/home/dev/.github_token.backup"

# Function to securely store token
store_token() {
    local token="$1"
    
    if [ -z "$token" ]; then
        echo "ERROR: No token provided"
        return 1
    fi
    
    # Validate token format
    if [[ ! "$token" =~ ^ghp_[a-zA-Z0-9]{36}$ ]]; then
        echo "ERROR: Invalid GitHub token format"
        return 1
    fi
    
    # Backup existing token
    if [ -f "$TOKEN_FILE" ]; then
        cp "$TOKEN_FILE" "$BACKUP_FILE"
    fi
    
    # Store token securely
    echo "$token" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    
    echo "GitHub token stored successfully"
    return 0
}

# Function to load token into environment
load_token() {
    if [ ! -f "$TOKEN_FILE" ]; then
        echo "ERROR: GitHub token not found. Please run: $0 store <your_token>"
        return 1
    fi
    
    local token=$(cat "$TOKEN_FILE")
    
    # Validate token
    if [[ ! "$token" =~ ^ghp_[a-zA-Z0-9]{36}$ ]]; then
        echo "ERROR: Invalid token found in storage"
        return 1
    fi
    
    export GITHUB_PERSONAL_ACCESS_TOKEN="$token"
    echo "GitHub token loaded successfully"
    return 0
}

# Function to verify token
verify_token() {
    if [ ! -f "$TOKEN_FILE" ]; then
        echo "ERROR: No token stored"
        return 1
    fi
    
    local token=$(cat "$TOKEN_FILE")
    echo "Stored token: ${token:0:15}..."
    
    # Test token with GitHub API
    if command -v curl >/dev/null 2>&1; then
        echo "Testing token with GitHub API..."
        local response=$(curl -s -H "Authorization: token $token" https://api.github.com/user)
        if echo "$response" | grep -q '"login"'; then
            echo "✅ Token is valid"
            return 0
        else
            echo "❌ Token is invalid or expired"
            return 1
        fi
    else
        echo "curl not available, skipping API test"
        return 0
    fi
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
        echo "source /home/dev/workspace/github-token-manager.sh && load_token"
        return 1
    fi
    
    local line="# Auto-load GitHub token for MCP"
    local source_line="source /home/dev/workspace/github-token-manager.sh && load_token 2>/dev/null || true"
    
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
        store_token "$2"
        ;;
    "load")
        load_token
        ;;
    "verify")
        verify_token
        ;;
    "setup")
        setup_auto_load
        ;;
    *)
        echo "GitHub Token Manager"
        echo "Usage: $0 {store|load|verify|setup}"
        echo ""
        echo "Commands:"
        echo "  store <token>  - Securely store GitHub token"
        echo "  load          - Load token into environment"
        echo "  verify        - Verify stored token"
        echo "  setup         - Setup auto-load in shell profile"
        echo ""
        echo "Example:"
        echo "  $0 store ghp_your_actual_token_here"
        echo "  $0 load"
        exit 1
        ;;
esac