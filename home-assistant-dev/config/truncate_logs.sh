#!/bin/bash
# ===== HOME ASSISTANT LOG TRUNCATION SCRIPT =====
# Purpose: Truncate large log files to free up space and improve performance
# Created: 2025-06-21 for audit troubleshooting session completion

echo "🗂️  Home Assistant Log Truncation Script"
echo "========================================"

# Define log file paths (updated for new multi-environment workflow)
# For local development logs (if they exist)
LOG_DIR="./logs"
MAIN_LOG="$LOG_DIR/home-assistant.log"
OLD_LOG="$LOG_DIR/home-assistant.log.1" 
FAULT_LOG="$LOG_DIR/home-assistant.log.fault"

# Check if logs exist and show current sizes
echo "📊 Current log file sizes:"
if [[ -f "$MAIN_LOG" ]]; then
    MAIN_SIZE=$(du -h "$MAIN_LOG" | cut -f1)
    echo "  • home-assistant.log: $MAIN_SIZE"
else
    echo "  • home-assistant.log: Not found"
fi

if [[ -f "$OLD_LOG" ]]; then
    OLD_SIZE=$(du -h "$OLD_LOG" | cut -f1)
    echo "  • home-assistant.log.1: $OLD_SIZE"
else
    echo "  • home-assistant.log.1: Not found"
fi

if [[ -f "$FAULT_LOG" ]]; then
    FAULT_SIZE=$(du -h "$FAULT_LOG" | cut -f1)
    echo "  • home-assistant.log.fault: $FAULT_SIZE"
else
    echo "  • home-assistant.log.fault: Not found"
fi

echo ""

# Function to backup and truncate a log file
truncate_log() {
    local log_file="$1"
    local log_name="$2"
    
    if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
        echo "🔄 Processing $log_name..."
        
        # Create backup of last 1000 lines
        local backup_file="${log_file}.backup.$(date +%Y%m%d_%H%M%S)"
        tail -n 1000 "$log_file" > "$backup_file"
        echo "  ✅ Backup created: $(basename "$backup_file")"
        
        # Truncate the log file
        echo "  🗑️  Truncating $log_name..."
        > "$log_file"
        echo "  ✅ $log_name truncated successfully"
        
        # Show new size
        local new_size=$(du -h "$log_file" | cut -f1)
        echo "  📏 New size: $new_size"
        echo ""
    else
        echo "⏭️  Skipping $log_name (empty or doesn't exist)"
        echo ""
    fi
}

# Process each log file
truncate_log "$MAIN_LOG" "home-assistant.log"
truncate_log "$OLD_LOG" "home-assistant.log.1"
truncate_log "$FAULT_LOG" "home-assistant.log.fault"

# Summary
echo "✅ Log truncation completed!"
echo "📋 Summary:"
echo "  • Log files have been truncated to free up space"
echo "  • Last 1000 lines of each log saved as backup files"
echo "  • Backup files created with timestamp: $(date +%Y%m%d_%H%M%S)"
echo ""
echo "🎯 Next steps:"
echo "  • Home Assistant will create fresh log files on next restart"
echo "  • Monitor system performance improvement"
echo "  • Backup files can be safely deleted after verification"
echo ""
echo "🔧 Local log truncation completed!"
echo ""
echo "📝 Note: For production server log truncation, use:"
echo "   ./deployment/truncate-prod-logs.sh"