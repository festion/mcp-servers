#!/bin/bash

# Test script for PAM-based auto-reboot system

echo "=== PAM Auto-Reboot System Test ==="
echo

# Check if PAM hooks are installed
echo "1. Checking PAM configuration..."
if grep -q "pam-session-end.sh" /etc/pam.d/sshd; then
    echo "   ✅ SSH PAM hook installed"
else
    echo "   ❌ SSH PAM hook missing"
fi

if grep -q "pam-session-end.sh" /etc/pam.d/login; then
    echo "   ✅ Login PAM hook installed"
else
    echo "   ❌ Login PAM hook missing"
fi

# Check script permissions
echo
echo "2. Checking script permissions..."
if [[ -x "/home/dev/workspace/pam-session-end.sh" ]]; then
    echo "   ✅ pam-session-end.sh is executable"
else
    echo "   ❌ pam-session-end.sh not executable"
fi

if [[ -x "/home/dev/workspace/check-and-reboot.sh" ]]; then
    echo "   ✅ check-and-reboot.sh is executable"
else
    echo "   ❌ check-and-reboot.sh not executable"
fi

# Check log file
echo
echo "3. Checking log file..."
if [[ -f "/var/log/pam-session-end.log" ]]; then
    echo "   ✅ Log file exists"
    echo "   📄 Recent log entries:"
    tail -5 /var/log/pam-session-end.log | sed 's/^/      /'
else
    echo "   ❌ Log file missing"
fi

# Check current sessions
echo
echo "4. Current session status..."
session_count=$(loginctl list-sessions --no-legend 2>/dev/null | wc -l)
who_count=$(who | wc -l)

if [[ $who_count -gt $session_count ]]; then
    session_count=$who_count
fi

echo "   📊 Active sessions: $session_count"
echo "   👤 Current users:"
who | sed 's/^/      /'

# Backup information
echo
echo "5. Backup files..."
if [[ -f "/etc/pam.d/sshd.backup" ]]; then
    echo "   ✅ SSH PAM backup exists"
else
    echo "   ❌ SSH PAM backup missing"
fi

if [[ -f "/etc/pam.d/login.backup" ]]; then
    echo "   ✅ Login PAM backup exists"
else
    echo "   ❌ Login PAM backup missing"
fi

echo
echo "=== System Status ==="
echo "📈 Uptime: $(uptime)"
echo "💾 Memory: $(free -h | grep Mem | awk '{print $3"/"$2" used"}')"
echo "🔄 Auto-reboot system: ACTIVE"

echo
echo "=== Test Commands ==="
echo "Monitor logs: tail -f /var/log/pam-session-end.log"
echo "Test session detection: sudo /home/dev/workspace/pam-session-end.sh"
echo "Manual reboot test: sudo /home/dev/workspace/check-and-reboot.sh"

echo
echo "⚠️  WARNING: The system will auto-reboot when the last session ends!"
echo "   Grace period: 30 seconds"
echo "   To disable: Remove lines from /etc/pam.d/sshd and /etc/pam.d/login"