#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$BACKUP_ROOT")"

source "$SCRIPT_DIR/common/backup-functions.sh"
source "$PROJECT_ROOT/scripts/common/logging.sh"
source "$PROJECT_ROOT/scripts/common/utils.sh"

setup_logging "/var/log/github-runner-backup-schedule.log"

usage() {
    cat << 'EOF'
Usage: backup-schedule.sh [OPTIONS] COMMAND

Manage automated backup scheduling for GitHub Actions runner

COMMANDS:
    setup               Set up automated backup schedule
    remove              Remove automated backup schedule
    status              Show current schedule status
    run                 Execute scheduled backup tasks
    test                Test scheduled backup configuration

OPTIONS:
    -h, --help              Show this help message
    -c, --config FILE       Backup configuration file
    --full-schedule TIME    Schedule for full backups [default: "0 2 * * 0"]
    --incremental-schedule TIME  Schedule for incremental backups [default: "0 3 * * 1-6"]
    --config-schedule TIME  Schedule for config backups [default: "0 1 * * *"]
    --validation-schedule TIME   Schedule for validation [default: "0 4 * * 0"]
    --cleanup-schedule TIME Schedule for cleanup [default: "0 5 * * 0"]
    --user USER             User to run scheduled backups [default: current user]
    --notification-url URL  Webhook URL for backup notifications
    --max-parallel NUM      Maximum parallel backup jobs [default: 1]
    --backup-window HOURS   Backup window duration in hours [default: 4]
    --maintenance-mode      Enable maintenance mode during backups
    --dry-run               Show what would be scheduled without making changes

Examples:
    ./backup-schedule.sh setup                          # Set up default schedule
    ./backup-schedule.sh setup --full-schedule "0 1 * * 6"  # Weekly full backup on Saturday
    ./backup-schedule.sh status                         # Show current schedule
    ./backup-schedule.sh remove                         # Remove all scheduled backups
    ./backup-schedule.sh test                           # Test backup configuration
EOF
}

COMMAND=""
CONFIG_FILE="$BACKUP_ROOT/config/backup.conf"
FULL_SCHEDULE="0 2 * * 0"        # Sunday 2 AM
INCREMENTAL_SCHEDULE="0 3 * * 1-6"  # Mon-Sat 3 AM
CONFIG_SCHEDULE="0 1 * * *"      # Daily 1 AM
VALIDATION_SCHEDULE="0 4 * * 0"  # Sunday 4 AM
CLEANUP_SCHEDULE="0 5 * * 0"     # Sunday 5 AM
BACKUP_USER="$(whoami)"
NOTIFICATION_URL=""
MAX_PARALLEL=1
BACKUP_WINDOW=4
MAINTENANCE_MODE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --full-schedule)
            FULL_SCHEDULE="$2"
            shift 2
            ;;
        --incremental-schedule)
            INCREMENTAL_SCHEDULE="$2"
            shift 2
            ;;
        --config-schedule)
            CONFIG_SCHEDULE="$2"
            shift 2
            ;;
        --validation-schedule)
            VALIDATION_SCHEDULE="$2"
            shift 2
            ;;
        --cleanup-schedule)
            CLEANUP_SCHEDULE="$2"
            shift 2
            ;;
        --user)
            BACKUP_USER="$2"
            shift 2
            ;;
        --notification-url)
            NOTIFICATION_URL="$2"
            shift 2
            ;;
        --max-parallel)
            MAX_PARALLEL="$2"
            shift 2
            ;;
        --backup-window)
            BACKUP_WINDOW="$2"
            shift 2
            ;;
        --maintenance-mode)
            MAINTENANCE_MODE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        setup|remove|status|run|test)
            COMMAND="$1"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$COMMAND" ]]; then
    log_error "Command is required"
    usage
    exit 1
fi

main() {
    log_section "GitHub Actions Runner - Backup Scheduling"
    
    case "$COMMAND" in
        setup)
            setup_backup_schedule
            ;;
        remove)
            remove_backup_schedule
            ;;
        status)
            show_schedule_status
            ;;
        run)
            run_scheduled_backup
            ;;
        test)
            test_backup_schedule
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            usage
            exit 1
            ;;
    esac
}

setup_backup_schedule() {
    log_info "Setting up automated backup schedule..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN MODE - No actual schedule changes will be made"
        preview_backup_schedule
        return 0
    fi
    
    load_backup_config "$CONFIG_FILE"
    
    # Create backup configuration directory
    local schedule_config_dir="/etc/github-runner/backup"
    if [[ ! -d "$schedule_config_dir" ]]; then
        sudo mkdir -p "$schedule_config_dir"
    fi
    
    # Create schedule configuration file
    create_schedule_configuration "$schedule_config_dir/schedule.conf"
    
    # Create backup wrapper scripts
    create_backup_wrappers "$schedule_config_dir"
    
    # Set up cron jobs
    setup_cron_jobs
    
    # Set up systemd timers (alternative to cron)
    setup_systemd_timers
    
    # Create monitoring and alerting
    setup_backup_monitoring
    
    # Create maintenance mode script
    if [[ "$MAINTENANCE_MODE" == true ]]; then
        create_maintenance_mode_script "$schedule_config_dir"
    fi
    
    log_success "Backup schedule configured successfully"
    show_schedule_status
}

create_schedule_configuration() {
    local config_file="$1"
    
    log_info "Creating schedule configuration: $config_file"
    
    sudo tee "$config_file" > /dev/null << EOF
# GitHub Actions Runner Backup Schedule Configuration
# Generated: $(date)

# Schedule Settings
FULL_BACKUP_SCHEDULE="$FULL_SCHEDULE"
INCREMENTAL_BACKUP_SCHEDULE="$INCREMENTAL_SCHEDULE"
CONFIG_BACKUP_SCHEDULE="$CONFIG_SCHEDULE"
VALIDATION_SCHEDULE="$VALIDATION_SCHEDULE"
CLEANUP_SCHEDULE="$CLEANUP_SCHEDULE"

# Execution Settings
BACKUP_USER="$BACKUP_USER"
MAX_PARALLEL_JOBS=$MAX_PARALLEL
BACKUP_WINDOW_HOURS=$BACKUP_WINDOW
MAINTENANCE_MODE=$MAINTENANCE_MODE

# Notification Settings
NOTIFICATION_URL="$NOTIFICATION_URL"
NOTIFICATION_ENABLED=$(if [[ -n "$NOTIFICATION_URL" ]]; then echo "true"; else echo "false"; fi)

# Script Paths
BACKUP_SCRIPT_DIR="$SCRIPT_DIR"
FULL_BACKUP_SCRIPT="$SCRIPT_DIR/backup-full.sh"
INCREMENTAL_BACKUP_SCRIPT="$SCRIPT_DIR/backup-incremental.sh"
CONFIG_BACKUP_SCRIPT="$SCRIPT_DIR/backup-config.sh"
VALIDATION_SCRIPT="$SCRIPT_DIR/backup-validate.sh"

# Log Settings
SCHEDULE_LOG_FILE="/var/log/github-runner-backup-schedule.log"
BACKUP_LOG_DIR="/var/log/github-runner-backup"

# Lock File Settings
BACKUP_LOCK_FILE="/var/run/github-runner-backup.lock"
LOCK_TIMEOUT=3600

# Default Backup Options
DEFAULT_DESTINATION="/var/backups/github-runner"
DEFAULT_RETENTION_DAYS=30
DEFAULT_COMPRESSION_LEVEL=6
ENABLE_ENCRYPTION=false
ENABLE_REMOTE_BACKUP=false

EOF
    
    sudo chmod 644 "$config_file"
}

create_backup_wrappers() {
    local config_dir="$1"
    
    log_info "Creating backup wrapper scripts..."
    
    # Full backup wrapper
    sudo tee "$config_dir/run-full-backup.sh" > /dev/null << 'EOF'
#!/bin/bash
set -euo pipefail

CONFIG_FILE="/etc/github-runner/backup/schedule.conf"
source "$CONFIG_FILE"

# Lock management
exec 200>"$BACKUP_LOCK_FILE"
if ! flock -n 200; then
    echo "Another backup is running, exiting..."
    exit 1
fi

# Logging
exec 1> >(tee -a "$SCHEDULE_LOG_FILE")
exec 2>&1

echo "[$(date)] Starting scheduled full backup"

# Enter maintenance mode if enabled
if [[ "$MAINTENANCE_MODE" == "true" ]]; then
    "$BACKUP_SCRIPT_DIR/maintenance-mode.sh" enable
fi

# Run full backup
if "$FULL_BACKUP_SCRIPT" --destination "$DEFAULT_DESTINATION" --retention "$DEFAULT_RETENTION_DAYS" --compression "$DEFAULT_COMPRESSION_LEVEL"; then
    echo "[$(date)] Full backup completed successfully"
    BACKUP_STATUS="success"
else
    echo "[$(date)] Full backup failed"
    BACKUP_STATUS="failed"
fi

# Exit maintenance mode
if [[ "$MAINTENANCE_MODE" == "true" ]]; then
    "$BACKUP_SCRIPT_DIR/maintenance-mode.sh" disable
fi

# Send notification
if [[ "$NOTIFICATION_ENABLED" == "true" ]]; then
    curl -X POST "$NOTIFICATION_URL" \
         -H "Content-Type: application/json" \
         -d "{\"type\":\"full_backup\",\"status\":\"$BACKUP_STATUS\",\"timestamp\":\"$(date -Iseconds)\"}" \
         2>/dev/null || true
fi

echo "[$(date)] Full backup job completed"
EOF
    
    # Incremental backup wrapper
    sudo tee "$config_dir/run-incremental-backup.sh" > /dev/null << 'EOF'
#!/bin/bash
set -euo pipefail

CONFIG_FILE="/etc/github-runner/backup/schedule.conf"
source "$CONFIG_FILE"

# Lock management
exec 200>"$BACKUP_LOCK_FILE"
if ! flock -n 200; then
    echo "Another backup is running, exiting..."
    exit 1
fi

# Logging
exec 1> >(tee -a "$SCHEDULE_LOG_FILE")
exec 2>&1

echo "[$(date)] Starting scheduled incremental backup"

# Run incremental backup with auto-baseline
if "$INCREMENTAL_BACKUP_SCRIPT" --auto-baseline --destination "$DEFAULT_DESTINATION" --retention 7; then
    echo "[$(date)] Incremental backup completed successfully"
    BACKUP_STATUS="success"
else
    echo "[$(date)] Incremental backup failed"
    BACKUP_STATUS="failed"
fi

# Send notification
if [[ "$NOTIFICATION_ENABLED" == "true" ]]; then
    curl -X POST "$NOTIFICATION_URL" \
         -H "Content-Type: application/json" \
         -d "{\"type\":\"incremental_backup\",\"status\":\"$BACKUP_STATUS\",\"timestamp\":\"$(date -Iseconds)\"}" \
         2>/dev/null || true
fi

echo "[$(date)] Incremental backup job completed"
EOF
    
    # Config backup wrapper
    sudo tee "$config_dir/run-config-backup.sh" > /dev/null << 'EOF'
#!/bin/bash
set -euo pipefail

CONFIG_FILE="/etc/github-runner/backup/schedule.conf"
source "$CONFIG_FILE"

# Logging
exec 1> >(tee -a "$SCHEDULE_LOG_FILE")
exec 2>&1

echo "[$(date)] Starting scheduled configuration backup"

# Run config backup
if "$CONFIG_BACKUP_SCRIPT" --destination "$DEFAULT_DESTINATION/config" --include-env --include-docker; then
    echo "[$(date)] Configuration backup completed successfully"
    BACKUP_STATUS="success"
else
    echo "[$(date)] Configuration backup failed"
    BACKUP_STATUS="failed"
fi

# Send notification
if [[ "$NOTIFICATION_ENABLED" == "true" ]]; then
    curl -X POST "$NOTIFICATION_URL" \
         -H "Content-Type: application/json" \
         -d "{\"type\":\"config_backup\",\"status\":\"$BACKUP_STATUS\",\"timestamp\":\"$(date -Iseconds)\"}" \
         2>/dev/null || true
fi

echo "[$(date)] Configuration backup job completed"
EOF
    
    # Validation wrapper
    sudo tee "$config_dir/run-validation.sh" > /dev/null << 'EOF'
#!/bin/bash
set -euo pipefail

CONFIG_FILE="/etc/github-runner/backup/schedule.conf"
source "$CONFIG_FILE"

# Logging
exec 1> >(tee -a "$SCHEDULE_LOG_FILE")
exec 2>&1

echo "[$(date)] Starting scheduled backup validation"

# Run validation
if "$VALIDATION_SCRIPT" --all --destination "$DEFAULT_DESTINATION" --checksum; then
    echo "[$(date)] Backup validation completed successfully"
    VALIDATION_STATUS="success"
else
    echo "[$(date)] Backup validation failed"
    VALIDATION_STATUS="failed"
fi

# Send notification
if [[ "$NOTIFICATION_ENABLED" == "true" ]]; then
    curl -X POST "$NOTIFICATION_URL" \
         -H "Content-Type: application/json" \
         -d "{\"type\":\"validation\",\"status\":\"$VALIDATION_STATUS\",\"timestamp\":\"$(date -Iseconds)\"}" \
         2>/dev/null || true
fi

echo "[$(date)] Validation job completed"
EOF
    
    # Make all wrapper scripts executable
    sudo chmod +x "$config_dir"/*.sh
}

setup_cron_jobs() {
    log_info "Setting up cron jobs..."
    
    local cron_config_dir="/etc/github-runner/backup"
    local cron_entries=""
    
    # Create cron entries
    cron_entries+="# GitHub Actions Runner Backup Schedule"$'\n'
    cron_entries+="# Generated: $(date)"$'\n'
    cron_entries+=""$'\n'
    
    # Full backup
    cron_entries+="# Full backup - $FULL_SCHEDULE"$'\n'
    cron_entries+="$FULL_SCHEDULE $BACKUP_USER $cron_config_dir/run-full-backup.sh >/dev/null 2>&1"$'\n'
    cron_entries+=""$'\n'
    
    # Incremental backup
    cron_entries+="# Incremental backup - $INCREMENTAL_SCHEDULE"$'\n'
    cron_entries+="$INCREMENTAL_SCHEDULE $BACKUP_USER $cron_config_dir/run-incremental-backup.sh >/dev/null 2>&1"$'\n'
    cron_entries+=""$'\n'
    
    # Config backup
    cron_entries+="# Configuration backup - $CONFIG_SCHEDULE"$'\n'
    cron_entries+="$CONFIG_SCHEDULE $BACKUP_USER $cron_config_dir/run-config-backup.sh >/dev/null 2>&1"$'\n'
    cron_entries+=""$'\n'
    
    # Validation
    cron_entries+="# Backup validation - $VALIDATION_SCHEDULE"$'\n'
    cron_entries+="$VALIDATION_SCHEDULE $BACKUP_USER $cron_config_dir/run-validation.sh >/dev/null 2>&1"$'\n'
    cron_entries+=""$'\n'
    
    # Write cron file
    echo "$cron_entries" | sudo tee /etc/cron.d/github-runner-backup > /dev/null
    
    # Set correct permissions
    sudo chmod 644 /etc/cron.d/github-runner-backup
    
    log_success "Cron jobs configured"
}

setup_systemd_timers() {
    log_info "Setting up systemd timers (alternative to cron)..."
    
    local systemd_dir="/etc/systemd/system"
    
    # Full backup timer
    sudo tee "$systemd_dir/github-runner-backup-full.timer" > /dev/null << EOF
[Unit]
Description=GitHub Actions Runner Full Backup Timer
Requires=github-runner-backup-full.service

[Timer]
OnCalendar=$(convert_cron_to_systemd "$FULL_SCHEDULE")
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF
    
    # Full backup service
    sudo tee "$systemd_dir/github-runner-backup-full.service" > /dev/null << EOF
[Unit]
Description=GitHub Actions Runner Full Backup
After=network.target

[Service]
Type=oneshot
User=$BACKUP_USER
ExecStart=/etc/github-runner/backup/run-full-backup.sh
TimeoutStartSec=0
StandardOutput=journal
StandardError=journal
EOF
    
    # Incremental backup timer
    sudo tee "$systemd_dir/github-runner-backup-incremental.timer" > /dev/null << EOF
[Unit]
Description=GitHub Actions Runner Incremental Backup Timer
Requires=github-runner-backup-incremental.service

[Timer]
OnCalendar=$(convert_cron_to_systemd "$INCREMENTAL_SCHEDULE")
Persistent=true
RandomizedDelaySec=180

[Install]
WantedBy=timers.target
EOF
    
    # Incremental backup service
    sudo tee "$systemd_dir/github-runner-backup-incremental.service" > /dev/null << EOF
[Unit]
Description=GitHub Actions Runner Incremental Backup
After=network.target

[Service]
Type=oneshot
User=$BACKUP_USER
ExecStart=/etc/github-runner/backup/run-incremental-backup.sh
TimeoutStartSec=0
StandardOutput=journal
StandardError=journal
EOF
    
    # Reload systemd and enable timers
    sudo systemctl daemon-reload
    
    # Enable but don't start timers (user choice)
    log_info "Systemd timers created. Enable with:"
    log_info "  sudo systemctl enable --now github-runner-backup-full.timer"
    log_info "  sudo systemctl enable --now github-runner-backup-incremental.timer"
}

setup_backup_monitoring() {
    log_info "Setting up backup monitoring..."
    
    local monitoring_script="/etc/github-runner/backup/backup-monitor.sh"
    
    sudo tee "$monitoring_script" > /dev/null << 'EOF'
#!/bin/bash
set -euo pipefail

CONFIG_FILE="/etc/github-runner/backup/schedule.conf"
source "$CONFIG_FILE"

LOG_FILE="/var/log/github-runner-backup-monitor.log"

# Check backup health
check_backup_health() {
    local current_time=$(date +%s)
    local one_day_ago=$((current_time - 86400))
    local one_week_ago=$((current_time - 604800))
    
    # Check for recent backups
    local recent_full_backup=""
    local recent_incremental_backup=""
    
    if [[ -d "$DEFAULT_DESTINATION" ]]; then
        # Find recent full backup
        while IFS= read -r -d '' manifest_file; do
            if [[ -f "$manifest_file" ]]; then
                local backup_type
                backup_type=$(jq -r '.backup_type // "unknown"' "$manifest_file" 2>/dev/null)
                local backup_time
                backup_time=$(jq -r '.timestamp // 0' "$manifest_file" 2>/dev/null)
                
                if [[ "$backup_type" == "full" ]] && [[ "$backup_time" -gt "$one_week_ago" ]]; then
                    recent_full_backup="found"
                    break
                fi
            fi
        done < <(find "$DEFAULT_DESTINATION" -name "*.manifest.json" -print0 2>/dev/null)
        
        # Find recent incremental backup
        while IFS= read -r -d '' manifest_file; do
            if [[ -f "$manifest_file" ]]; then
                local backup_type
                backup_type=$(jq -r '.backup_type // "unknown"' "$manifest_file" 2>/dev/null)
                local backup_time
                backup_time=$(jq -r '.timestamp // 0' "$manifest_file" 2>/dev/null)
                
                if [[ "$backup_type" == "incremental" ]] && [[ "$backup_time" -gt "$one_day_ago" ]]; then
                    recent_incremental_backup="found"
                    break
                fi
            fi
        done < <(find "$DEFAULT_DESTINATION" -name "*.manifest.json" -print0 2>/dev/null)
    fi
    
    # Report status
    local status_message=""
    local alert_level="info"
    
    if [[ -z "$recent_full_backup" ]]; then
        status_message+="WARNING: No full backup found in the last 7 days. "
        alert_level="warning"
    fi
    
    if [[ -z "$recent_incremental_backup" ]]; then
        status_message+="WARNING: No incremental backup found in the last 24 hours. "
        alert_level="warning"
    fi
    
    if [[ -z "$status_message" ]]; then
        status_message="Backup health check passed - recent backups found."
        alert_level="success"
    fi
    
    echo "[$(date)] $status_message" >> "$LOG_FILE"
    
    # Send notification if enabled
    if [[ "$NOTIFICATION_ENABLED" == "true" ]]; then
        curl -X POST "$NOTIFICATION_URL" \
             -H "Content-Type: application/json" \
             -d "{\"type\":\"health_check\",\"status\":\"$alert_level\",\"message\":\"$status_message\",\"timestamp\":\"$(date -Iseconds)\"}" \
             2>/dev/null || true
    fi
}

check_backup_health
EOF
    
    sudo chmod +x "$monitoring_script"
    
    # Add monitoring to cron (daily check)
    echo "0 6 * * * $BACKUP_USER $monitoring_script >/dev/null 2>&1" | sudo tee -a /etc/cron.d/github-runner-backup > /dev/null
}

create_maintenance_mode_script() {
    local config_dir="$1"
    
    log_info "Creating maintenance mode script..."
    
    sudo tee "$config_dir/maintenance-mode.sh" > /dev/null << 'EOF'
#!/bin/bash
set -euo pipefail

MAINTENANCE_FLAG="/var/run/github-runner-maintenance"
SERVICE_NAME="github-runner"

enable_maintenance() {
    echo "Enabling maintenance mode..."
    
    # Stop runner service
    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        systemctl stop "$SERVICE_NAME"
        echo "stopped_service" > "$MAINTENANCE_FLAG"
    else
        echo "no_service" > "$MAINTENANCE_FLAG"
    fi
    
    echo "Maintenance mode enabled"
}

disable_maintenance() {
    echo "Disabling maintenance mode..."
    
    if [[ -f "$MAINTENANCE_FLAG" ]]; then
        local previous_state
        previous_state=$(cat "$MAINTENANCE_FLAG")
        
        if [[ "$previous_state" == "stopped_service" ]]; then
            systemctl start "$SERVICE_NAME"
            echo "Service restarted"
        fi
        
        rm -f "$MAINTENANCE_FLAG"
    fi
    
    echo "Maintenance mode disabled"
}

case "${1:-}" in
    enable)
        enable_maintenance
        ;;
    disable)
        disable_maintenance
        ;;
    status)
        if [[ -f "$MAINTENANCE_FLAG" ]]; then
            echo "Maintenance mode is ENABLED"
            exit 0
        else
            echo "Maintenance mode is DISABLED"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {enable|disable|status}"
        exit 1
        ;;
esac
EOF
    
    sudo chmod +x "$config_dir/maintenance-mode.sh"
}

remove_backup_schedule() {
    log_info "Removing automated backup schedule..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN MODE - No actual schedule changes will be made"
        show_what_would_be_removed
        return 0
    fi
    
    # Remove cron jobs
    if [[ -f /etc/cron.d/github-runner-backup ]]; then
        sudo rm -f /etc/cron.d/github-runner-backup
        log_info "Removed cron jobs"
    fi
    
    # Disable and remove systemd timers
    local systemd_services=(
        "github-runner-backup-full.timer"
        "github-runner-backup-incremental.timer"
        "github-runner-backup-full.service"
        "github-runner-backup-incremental.service"
    )
    
    for service in "${systemd_services[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            sudo systemctl disable "$service"
        fi
        if [[ -f "/etc/systemd/system/$service" ]]; then
            sudo rm -f "/etc/systemd/system/$service"
        fi
    done
    
    sudo systemctl daemon-reload
    
    # Remove configuration directory
    if [[ -d "/etc/github-runner/backup" ]]; then
        sudo rm -rf "/etc/github-runner/backup"
        log_info "Removed backup configuration"
    fi
    
    log_success "Backup schedule removed successfully"
}

show_schedule_status() {
    log_section "Backup Schedule Status"
    
    # Check cron jobs
    if [[ -f /etc/cron.d/github-runner-backup ]]; then
        log_info "Cron jobs configured:"
        cat /etc/cron.d/github-runner-backup | grep -v "^#" | grep -v "^$" || true
    else
        log_info "No cron jobs configured"
    fi
    
    echo
    
    # Check systemd timers
    log_info "Systemd timers:"
    systemctl list-timers | grep "github-runner-backup" || log_info "No systemd timers active"
    
    echo
    
    # Check recent backup activity
    log_info "Recent backup activity:"
    if [[ -f "/var/log/github-runner-backup-schedule.log" ]]; then
        tail -5 "/var/log/github-runner-backup-schedule.log" 2>/dev/null || log_info "No recent activity logged"
    else
        log_info "No schedule log file found"
    fi
    
    echo
    
    # Check backup storage
    if [[ -d "/var/backups/github-runner" ]]; then
        local backup_count
        backup_count=$(find "/var/backups/github-runner" -name "*.manifest.json" 2>/dev/null | wc -l)
        log_info "Current backups: $backup_count"
        
        local storage_usage
        storage_usage=$(du -sh "/var/backups/github-runner" 2>/dev/null | cut -f1)
        log_info "Storage usage: $storage_usage"
    else
        log_info "No backup storage directory found"
    fi
}

run_scheduled_backup() {
    log_info "Running scheduled backup tasks..."
    
    # This function is called by the schedule manager
    # Determine which backup to run based on current time and schedule
    
    local current_hour
    current_hour=$(date +%H)
    local current_dow
    current_dow=$(date +%u)  # 1=Monday, 7=Sunday
    
    # Simple logic for determining backup type
    if [[ "$current_dow" == "7" ]] && [[ "$current_hour" == "02" ]]; then
        log_info "Running full backup (Sunday 2 AM)"
        /etc/github-runner/backup/run-full-backup.sh
    elif [[ "$current_hour" == "03" ]]; then
        log_info "Running incremental backup (daily 3 AM)"
        /etc/github-runner/backup/run-incremental-backup.sh
    elif [[ "$current_hour" == "01" ]]; then
        log_info "Running configuration backup (daily 1 AM)"
        /etc/github-runner/backup/run-config-backup.sh
    else
        log_info "No scheduled backup for current time"
    fi
}

test_backup_schedule() {
    log_info "Testing backup schedule configuration..."
    
    local test_results=()
    local test_passed=0
    local test_failed=0
    
    # Test 1: Check if backup scripts exist and are executable
    local backup_scripts=(
        "$SCRIPT_DIR/backup-full.sh"
        "$SCRIPT_DIR/backup-incremental.sh"
        "$SCRIPT_DIR/backup-config.sh"
        "$SCRIPT_DIR/backup-validate.sh"
    )
    
    for script in "${backup_scripts[@]}"; do
        if [[ -x "$script" ]]; then
            test_results+=("✓ Backup script exists and is executable: $(basename "$script")")
            ((test_passed++))
        else
            test_results+=("✗ Backup script missing or not executable: $(basename "$script")")
            ((test_failed++))
        fi
    done
    
    # Test 2: Check backup destination
    if [[ -d "/var/backups/github-runner" ]]; then
        test_results+=("✓ Backup destination directory exists")
        ((test_passed++))
    else
        test_results+=("✗ Backup destination directory not found")
        ((test_failed++))
    fi
    
    # Test 3: Check log directory
    if [[ -d "/var/log" ]]; then
        test_results+=("✓ Log directory accessible")
        ((test_passed++))
    else
        test_results+=("✗ Log directory not accessible")
        ((test_failed++))
    fi
    
    # Test 4: Check required commands
    local required_commands=("tar" "gzip" "jq" "curl")
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            test_results+=("✓ Required command available: $cmd")
            ((test_passed++))
        else
            test_results+=("✗ Required command missing: $cmd")
            ((test_failed++))
        fi
    done
    
    # Test 5: Test notification URL if configured
    if [[ -n "$NOTIFICATION_URL" ]]; then
        if curl -f -s -X POST "$NOTIFICATION_URL" \
             -H "Content-Type: application/json" \
             -d '{"type":"test","status":"success","timestamp":"'$(date -Iseconds)'"}' >/dev/null 2>&1; then
            test_results+=("✓ Notification URL is reachable")
            ((test_passed++))
        else
            test_results+=("✗ Notification URL is not reachable")
            ((test_failed++))
        fi
    fi
    
    # Display results
    log_section "Schedule Test Results"
    for result in "${test_results[@]}"; do
        echo "$result"
    done
    
    echo
    log_info "Tests passed: $test_passed"
    log_info "Tests failed: $test_failed"
    
    if [[ "$test_failed" -eq 0 ]]; then
        log_success "All schedule tests passed"
        return 0
    else
        log_error "Some schedule tests failed"
        return 1
    fi
}

preview_backup_schedule() {
    log_section "Backup Schedule Preview"
    
    echo "Scheduled backup jobs that would be created:"
    echo "============================================="
    echo
    echo "Full Backup:        $FULL_SCHEDULE"
    echo "Incremental Backup: $INCREMENTAL_SCHEDULE"
    echo "Config Backup:      $CONFIG_SCHEDULE"
    echo "Validation:         $VALIDATION_SCHEDULE"
    echo "Cleanup:            $CLEANUP_SCHEDULE"
    echo
    echo "Execution User:     $BACKUP_USER"
    echo "Max Parallel Jobs:  $MAX_PARALLEL"
    echo "Backup Window:      $BACKUP_WINDOW hours"
    echo "Maintenance Mode:   $MAINTENANCE_MODE"
    echo
    if [[ -n "$NOTIFICATION_URL" ]]; then
        echo "Notification URL:   $NOTIFICATION_URL"
    else
        echo "Notifications:      Disabled"
    fi
}

show_what_would_be_removed() {
    log_section "Items that would be removed:"
    
    echo "Files:"
    echo "  - /etc/cron.d/github-runner-backup"
    echo "  - /etc/systemd/system/github-runner-backup-*.timer"
    echo "  - /etc/systemd/system/github-runner-backup-*.service"
    echo "  - /etc/github-runner/backup/ (entire directory)"
    echo
    echo "Services:"
    echo "  - github-runner-backup-full.timer"
    echo "  - github-runner-backup-incremental.timer"
}

convert_cron_to_systemd() {
    local cron_schedule="$1"
    
    # Basic conversion from cron to systemd OnCalendar format
    # This is a simplified conversion for common patterns
    
    case "$cron_schedule" in
        "0 2 * * 0")
            echo "Sun 02:00:00"
            ;;
        "0 3 * * 1-6")
            echo "Mon..Sat 03:00:00"
            ;;
        "0 1 * * *")
            echo "01:00:00"
            ;;
        "0 4 * * 0")
            echo "Sun 04:00:00"
            ;;
        "0 5 * * 0")
            echo "Sun 05:00:00"
            ;;
        *)
            # Fallback - return a daily schedule
            echo "daily"
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi