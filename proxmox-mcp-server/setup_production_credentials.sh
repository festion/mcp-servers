#!/bin/bash
# Setup script for Proxmox MCP Server production credentials

set -euo pipefail

echo "🔧 Proxmox MCP Server - Production Credentials Setup"
echo "======================================================"
echo

# Check if we're in the right directory
if [[ ! -f "config.json" ]]; then
    echo "❌ Error: Please run this script from the proxmox-mcp-server directory"
    exit 1
fi

echo "📋 Current Configuration:"
echo "  Host: 192.168.1.137:8006" 
echo "  User: root@pam"
echo "  Auth: API Token (preferred) or Password"
echo

# Function to test connectivity
test_connectivity() {
    echo "🧪 Testing connectivity with provided credentials..."
    if python test_api_connectivity.py; then
        echo "✅ Connection successful!"
        return 0
    else
        echo "❌ Connection failed!"
        return 1
    fi
}

# Check current setup
echo "🔍 Checking current setup..."
if [[ -n "${PROXMOX_TOKEN:-}" ]] && [[ "$PROXMOX_TOKEN" != *"your-real-token-here"* ]]; then
    echo "✅ PROXMOX_TOKEN environment variable is set"
    if test_connectivity; then
        echo "🎉 Production credentials are already working!"
        exit 0
    fi
elif [[ -f ".env" ]] && grep -q "PROXMOX_TOKEN.*PVEAPIToken" .env && ! grep -q "your-real-token-here" .env; then
    echo "✅ PROXMOX_TOKEN found in .env file"
    source .env
    export PROXMOX_TOKEN
    if test_connectivity; then
        echo "🎉 Production credentials are already working!"
        exit 0
    fi
fi

echo "⚠️  No valid production credentials found."
echo

# Provide setup instructions
echo "📝 Setup Instructions:"
echo "======================"
echo
echo "Method 1: API Token (Recommended)"
echo "----------------------------------"
echo "1. Open Proxmox web interface: https://192.168.1.137:8006"
echo "2. Login with your admin credentials"
echo "3. Navigate to: Datacenter → Permissions → API Tokens"
echo "4. Click 'Add' and configure:"
echo "   - User: root@pam"
echo "   - Token ID: homelab (or any name)"
echo "   - Expire: Never (or set date)"
echo "   - Privilege Separation: UNCHECKED"
echo "5. Copy the generated token (starts with PVEAPIToken=)"
echo

echo "Method 2: Password Authentication"
echo "--------------------------------"
echo "Use your root password for authentication"
echo

# Interactive setup
echo "🚀 Interactive Setup:"
echo "====================="
echo
read -p "Do you want to configure credentials now? (y/n): " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    echo "Choose authentication method:"
    echo "1. API Token (recommended)"
    echo "2. Password"
    echo
    read -p "Enter choice (1 or 2): " -r choice
    
    if [[ $choice == "1" ]]; then
        echo
        read -p "Enter your Proxmox API token (PVEAPIToken=...): " -r token
        if [[ -n "$token" ]] && [[ "$token" == PVEAPIToken=* ]]; then
            echo "PROXMOX_TOKEN=\"$token\"" >> .env
            echo "✅ Token saved to .env file"
            echo
            export PROXMOX_TOKEN="$token"
            test_connectivity
        else
            echo "❌ Invalid token format. Token should start with 'PVEAPIToken='"
            exit 1
        fi
    elif [[ $choice == "2" ]]; then
        echo
        read -s -p "Enter your Proxmox password: " password
        echo
        if [[ -n "$password" ]]; then
            echo "PROXMOX_PASSWORD=\"$password\"" >> .env
            echo "✅ Password saved to .env file"
            echo
            export PROXMOX_PASSWORD="$password"
            test_connectivity
        else
            echo "❌ Password cannot be empty"
            exit 1
        fi
    else
        echo "❌ Invalid choice"
        exit 1
    fi
else
    echo
    echo "💡 To configure later:"
    echo "   - Set environment variable: export PROXMOX_TOKEN='PVEAPIToken=...'"
    echo "   - Or update .env file with your credentials"
    echo "   - Then run: python test_api_connectivity.py"
fi

echo
echo "📚 Next Steps:"
echo "  1. Test: python test_api_connectivity.py"
echo "  2. Run server: python run_server.py"
echo "  3. Test MCP: python test_mcp_functionality.py"