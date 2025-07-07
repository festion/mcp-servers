#!/bin/bash
# ===== LXC 128 SSH DIAGNOSIS =====
# Purpose: Diagnose SSH connection issues to LXC 128
# Usage: ./diagnose-lxc128-ssh.sh

LXC_HOST="192.168.1.239"

echo "🔍 LXC 128 SSH Diagnosis"
echo "========================"
echo "Target: $LXC_HOST"
echo "Time: $(date)"
echo ""

# 1. Network connectivity
echo "📡 1. Network Connectivity:"
if ping -c 2 "$LXC_HOST" >/dev/null 2>&1; then
    echo "✅ Network: LXC is reachable"
else
    echo "❌ Network: LXC is not reachable"
    exit 1
fi

# 2. Port 22 availability
echo ""
echo "🚪 2. SSH Port Check:"
if timeout 5 bash -c "</dev/tcp/$LXC_HOST/22" 2>/dev/null; then
    echo "✅ Port 22: Open and accepting connections"
else
    echo "❌ Port 22: Closed or filtered"
    echo "   SSH service may not be running on LXC container"
    exit 1
fi

# 3. SSH service banner
echo ""
echo "📋 3. SSH Service Information:"
SSH_BANNER=$(timeout 10 telnet "$LXC_HOST" 22 2>/dev/null | head -1 | grep SSH || echo "No SSH banner received")
echo "   Banner: $SSH_BANNER"

# 4. Available authentication methods
echo ""
echo "🔑 4. SSH Authentication Methods:"
ssh -o ConnectTimeout=5 -o PreferredAuthentications=none -o NoHostAuthenticationForUnknownHosts=yes "$LXC_HOST" 2>&1 | grep -i "permission denied" | head -1

# 5. Check different user attempts
echo ""
echo "👤 5. User Access Tests:"

# Test common usernames
for user in root ubuntu debian admin; do
    echo -n "   Testing $user@$LXC_HOST: "
    if timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes -o NoHostAuthenticationForUnknownHosts=yes "$user@$LXC_HOST" "echo success" 2>/dev/null; then
        echo "✅ Key-based auth works"
    else
        # Check if password auth is available
        ssh_output=$(timeout 10 ssh -o ConnectTimeout=5 -o PreferredAuthentications=password -o NoHostAuthenticationForUnknownHosts=yes "$user@$LXC_HOST" "echo success" 2>&1 | head -1)
        if echo "$ssh_output" | grep -q "Permission denied (publickey)"; then
            echo "🔒 Only key-based auth allowed"
        elif echo "$ssh_output" | grep -q "Permission denied (publickey,password)"; then
            echo "🔐 Password auth available but failed"
        elif echo "$ssh_output" | grep -q "Password:"; then
            echo "🔓 Password auth available"
        else
            echo "❓ Unknown response: $ssh_output"
        fi
    fi
done

# 6. LXC Container Type Detection
echo ""
echo "📦 6. Container Information:"
echo "   Attempting to determine LXC container type..."

# Try to get container info via different methods
echo "   Testing common LXC paths and services..."

# 7. Recommendations
echo ""
echo "💡 7. Recommendations:"
echo "====================="

echo ""
echo "If this is a fresh LXC container, you may need to:"
echo ""
echo "A. Enable SSH service:"
echo "   - Console into LXC 128 directly"
echo "   - Run: systemctl enable ssh && systemctl start ssh"
echo ""
echo "B. Configure SSH for root access:"
echo "   - Edit: /etc/ssh/sshd_config"
echo "   - Add/Change: PermitRootLogin yes"
echo "   - Restart: systemctl restart ssh"
echo ""
echo "C. Set root password (if needed):"
echo "   - Run: passwd root"
echo ""
echo "D. Install SSH (if missing):"
echo "   - Run: apt update && apt install openssh-server"
echo ""
echo "🔧 Next Steps:"
echo "=============="
echo "1. Access LXC 128 console directly (via Proxmox web UI or virsh console)"
echo "2. Configure SSH as shown above"
echo "3. Test: ssh root@$LXC_HOST 'echo SSH working'"
echo "4. Run: ./deployment/setup-ssh-lxc128.sh"
echo "5. Run: ./deployment/check-lxc128-readiness.sh"