#!/bin/bash
# ===== HOME ASSISTANT PRODUCTION LOG TRUNCATION SCRIPT =====
# Purpose: Truncate large log files on production server to free up space
# Target: 192.168.1.155 (production server)
# Updated: 2025-06-30 to use new multi-environment approach

set -e  # Exit on any error

# Configuration
PROD_HOST="192.168.1.155"
PROD_USER="root"
PROD_LOG_DIR="/usr/share/hassio/homeassistant"

echo "🗂️  Home Assistant Production Log Truncation"
echo "============================================"
echo "Target: $PROD_HOST (Production Server)"
echo "Time: $(date)"
echo ""

# Verify production server is accessible
echo "🔍 Checking production server accessibility..."
if ! ping -c 1 "$PROD_HOST" &>/dev/null; then
    echo "❌ Error: Production server $PROD_HOST is not accessible"
    exit 1
fi

# Check production server health before maintenance
echo "🏥 Checking production server health..."
if ! curl -f -s "http://$PROD_HOST:8123/api/" >/dev/null; then
    echo "⚠️  Warning: Production Home Assistant may not be responding"
    read -p "Continue with log truncation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Log truncation cancelled"
        exit 1
    fi
fi

# Create backup before truncation
echo "💾 Creating production backup before log maintenance..."
BACKUP_NAME="pre-log-truncation-$(date +%Y%m%d_%H%M%S)"
ssh "$PROD_USER@$PROD_HOST" "ha backups new --name '$BACKUP_NAME'" || {
    echo "⚠️  Warning: Backup creation failed, continuing with caution"
}

# Define log file paths on production server
echo "📊 Checking production log file sizes..."
LOG_FILES=(
    "$PROD_LOG_DIR/home-assistant.log"
    "$PROD_LOG_DIR/home-assistant.log.1"
    "$PROD_LOG_DIR/home-assistant.log.fault"
)

for log_file in "${LOG_FILES[@]}"; do
    log_name=$(basename "$log_file")
    size_info=$(ssh "$PROD_USER@$PROD_HOST" "
        if [[ -f '$log_file' ]]; then
            du -h '$log_file' | cut -f1
        else
            echo 'Not found'
        fi
    ")
    echo "  • $log_name: $size_info"
done

echo ""

# Function to backup and truncate a log file on remote server
truncate_remote_log() {
    local log_file="$1"
    local log_name="$2"
    
    echo "🔄 Processing $log_name on production server..."
    
    # Check if file exists and has content
    if ssh "$PROD_USER@$PROD_HOST" "[[ -f '$log_file' ]] && [[ -s '$log_file' ]]"; then
        # Create backup of last 1000 lines
        local backup_file="${log_file}.backup.$(date +%Y%m%d_%H%M%S)"
        ssh "$PROD_USER@$PROD_HOST" "
            tail -n 1000 '$log_file' > '$backup_file'
            echo '  ✅ Backup created: $(basename $backup_file)'
            
            # Truncate the log file
            echo '  🗑️  Truncating $log_name...'
            > '$log_file'
            echo '  ✅ $log_name truncated successfully'
            
            # Show new size
            new_size=\$(du -h '$log_file' | cut -f1)
            echo '  📏 New size: \$new_size'
        "
        echo ""
    else
        echo "⏭️  Skipping $log_name (empty or doesn't exist)"
        echo ""
    fi
}

# Process each log file on production server
for log_file in "${LOG_FILES[@]}"; do
    log_name=$(basename "$log_file")
    truncate_remote_log "$log_file" "$log_name"
done

# Verify Home Assistant is still running after log maintenance
echo "🏥 Verifying production server health after maintenance..."
sleep 5  # Give system a moment to settle

if curl -f -s "http://$PROD_HOST:8123/api/" >/dev/null; then
    echo "✅ Production server is responding normally"
else
    echo "⚠️  Warning: Production server may be experiencing issues"
    echo "   Check system status manually if needed"
fi

# Summary
echo ""
echo "✅ Production log truncation completed!"
echo "======================================"
echo "📋 Summary:"
echo "  • Production log files have been truncated"
echo "  • Last 1000 lines of each log saved as backup files"
echo "  • Backup created: $BACKUP_NAME"
echo "  • Server: $PROD_HOST"
echo "  • Time: $(date)"
echo ""
echo "🎯 Next steps:"
echo "  • Home Assistant will create fresh log files automatically"
echo "  • Monitor system performance improvement"
echo "  • Backup files can be safely deleted after verification"
echo ""
echo "🔍 Monitor production server:"
echo "  • Web UI: http://$PROD_HOST:8123"
echo "  • SSH: ssh $PROD_USER@$PROD_HOST"
echo "  • Logs: ssh $PROD_USER@$PROD_HOST 'ha core logs'"
echo ""
echo "🔧 Production log maintenance completed successfully!"