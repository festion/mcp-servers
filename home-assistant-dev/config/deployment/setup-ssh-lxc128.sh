#!/bin/bash
# ===== SSH SETUP FOR LXC 128 =====
# Purpose: Configure SSH key-based authentication for LXC 128
# Usage: ./setup-ssh-lxc128.sh

LXC_HOST="192.168.1.239"
LXC_USER="root"

echo "🔑 SSH Setup for LXC 128"
echo "========================"
echo "Target: $LXC_HOST"
echo "User: $LXC_USER"
echo "Time: $(date)"
echo ""

# Check if SSH key exists
echo "🔍 Checking for SSH key..."
if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
    echo "📝 No SSH key found. Generating new SSH key..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "dev@lxc-development"
    echo "✅ SSH key generated"
else
    echo "✅ SSH key already exists"
fi

# Display the public key
echo ""
echo "🔓 Your SSH public key:"
echo "======================"
cat ~/.ssh/id_rsa.pub
echo ""

# Test current SSH access
echo "🔍 Testing current SSH access..."
if ssh -o ConnectTimeout=5 -o BatchMode=yes "$LXC_USER@$LXC_HOST" "echo 'SSH already configured'" 2>/dev/null; then
    echo "✅ SSH key-based authentication already working!"
    exit 0
fi

echo "📋 SSH Setup Instructions:"
echo "=========================="
echo ""
echo "Option 1: Manual Setup (Recommended)"
echo "-----------------------------------"
echo "1. Copy the public key above"
echo "2. SSH to LXC container with password:"
echo "   ssh $LXC_USER@$LXC_HOST"
echo ""
echo "3. On the LXC container, run these commands:"
echo "   mkdir -p ~/.ssh"
echo "   chmod 700 ~/.ssh"
echo "   echo 'YOUR_PUBLIC_KEY_HERE' >> ~/.ssh/authorized_keys"
echo "   chmod 600 ~/.ssh/authorized_keys"
echo ""
echo "Option 2: Automated Setup (if you have password)"
echo "-----------------------------------------------"
echo "If you know the root password, you can use ssh-copy-id:"
echo "   ssh-copy-id $LXC_USER@$LXC_HOST"
echo ""

# Offer automated setup if ssh-copy-id is available
if command -v ssh-copy-id >/dev/null 2>&1; then
    echo "🤖 Automated Setup Available:"
    echo "============================="
    read -p "Do you want to try automated setup with ssh-copy-id? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "📤 Attempting to copy SSH key..."
        if ssh-copy-id "$LXC_USER@$LXC_HOST"; then
            echo "✅ SSH key copied successfully!"
            
            # Test the connection
            echo "🔍 Testing SSH connection..."
            if ssh -o ConnectTimeout=5 -o BatchMode=yes "$LXC_USER@$LXC_HOST" "echo 'SSH setup successful'" 2>/dev/null; then
                echo "✅ SSH key-based authentication is now working!"
                echo ""
                echo "Next step: ./deployment/check-lxc128-readiness.sh"
                exit 0
            else
                echo "❌ SSH connection test failed"
            fi
        else
            echo "❌ Failed to copy SSH key automatically"
            echo "   Please use manual setup option above"
        fi
    fi
fi

echo ""
echo "🔧 After SSH setup, test with:"
echo "   ssh $LXC_USER@$LXC_HOST 'echo SSH test successful'"
echo ""
echo "Then run readiness check:"
echo "   ./deployment/check-lxc128-readiness.sh"