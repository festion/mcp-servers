#!/bin/bash
# Commands to run INSIDE LXC 128 console to configure SSH
# Copy these commands and run them in the LXC console

echo "🔧 LXC 128 SSH Configuration Commands"
echo "====================================="
echo ""
echo "Run these commands inside the LXC 128 console:"
echo ""

cat << 'EOF'
# 1. Check current SSH configuration
echo "📋 Current SSH config:"
grep -E "^PermitRootLogin|^PasswordAuthentication|^PubkeyAuthentication" /etc/ssh/sshd_config || echo "No explicit settings found"

# 2. Backup SSH config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# 3. Configure SSH for root access
echo ""
echo "🔧 Configuring SSH..."

# Remove any existing conflicting lines and add our config
sed -i '/^PermitRootLogin/d' /etc/ssh/sshd_config
sed -i '/^PasswordAuthentication/d' /etc/ssh/sshd_config
sed -i '/^PubkeyAuthentication/d' /etc/ssh/sshd_config

# Add our settings
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

# 4. Restart SSH service
echo "🔄 Restarting SSH service..."
systemctl restart sshd
systemctl enable sshd

# 5. Check SSH service status
echo "📊 SSH service status:"
systemctl status sshd --no-pager -l

# 6. Verify SSH config
echo ""
echo "✅ Updated SSH config:"
grep -E "^PermitRootLogin|^PasswordAuthentication|^PubkeyAuthentication" /etc/ssh/sshd_config

# 7. Test local SSH
echo ""
echo "🔍 Testing local SSH connection..."
echo "root" | ssh -o StrictHostKeyChecking=no root@localhost 'echo "Local SSH test successful"' 2>&1 || echo "Local SSH test failed"

# 8. Show network info
echo ""
echo "🌐 Network configuration:"
ip addr show | grep -E "inet.*192\.168\.1\.239|inet.*eth0"

echo ""
echo "✅ SSH configuration completed!"
echo ""
echo "Now test from your development machine:"
echo "   ssh root@192.168.1.239 'echo SSH working'"
EOF