#!/bin/bash
# GitHub Actions Runner Alert Handler
# Automated response system for monitoring alerts

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ALERT_LOG="$PROJECT_ROOT/logs/alerts.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
MAX_RESTART_ATTEMPTS=3
RESTART_COOLDOWN=300  # 5 minutes
NOTIFICATION_WEBHOOK="${SLACK_WEBHOOK:-}"
EMAIL_RECIPIENTS="${ALERT_EMAIL:-}"

# Logging functions
log_alert() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$ALERT_LOG"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    log_alert "INFO: $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    log_alert "WARN: $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_alert "ERROR: $1"
}

log_critical() {
    echo -e "${RED}[CRITICAL]${NC} $1"
    log_alert "CRITICAL: $1"
}

# Ensure logs directory exists
mkdir -p "$(dirname "$ALERT_LOG")"

# Usage function
usage() {
    cat << EOF
Usage: $0 <alert_type> <alert_message> [options]

Handle monitoring alerts for GitHub Actions Runner

ALERT TYPES:
    critical        Critical system failures requiring immediate action
    high            High priority issues requiring prompt attention
    warning         Warning conditions that may need investigation
    info            Informational alerts for logging

OPTIONS:
    --source NAME       Alert source system (default: monitoring)
    --metric NAME       Specific metric that triggered alert
    --value VALUE       Current metric value
    --threshold VALUE   Alert threshold value
    --duration TIME     How long condition has persisted
    --no-action         Log only, don't take automated actions
    --force-restart     Force restart even if cooldown active
    --dry-run           Show what actions would be taken without executing

EXAMPLES:
    $0 critical "Container down" --metric container_status --value down
    $0 warning "High memory usage" --metric memory_percent --value 85 --threshold 80
    $0 info "Backup completed" --no-action

NOTIFICATION SETUP:
    Set SLACK_WEBHOOK environment variable for Slack notifications
    Set ALERT_EMAIL environment variable for email notifications

EOF
}

# Notification functions
send_slack_notification() {
    local message="$1"
    local urgency="$2"
    local color=""
    
    case "$urgency" in
        "critical") color="danger" ;;
        "high") color="warning" ;;
        "warning") color="warning" ;;
        *) color="good" ;;
    esac
    
    if [ -n "$NOTIFICATION_WEBHOOK" ]; then
        local payload=$(cat << EOF
{
    "attachments": [
        {
            "color": "$color",
            "title": "GitHub Actions Runner Alert",
            "text": "$message",
            "fields": [
                {
                    "title": "Severity",
                    "value": "$urgency",
                    "short": true
                },
                {
                    "title": "Timestamp",
                    "value": "$(date)",
                    "short": true
                },
                {
                    "title": "Host",
                    "value": "$(hostname)",
                    "short": true
                }
            ]
        }
    ]
}
EOF
        )
        
        if curl -X POST -H 'Content-type: application/json' \
           --data "$payload" \
           "$NOTIFICATION_WEBHOOK" >/dev/null 2>&1; then
            log_info "Slack notification sent"
        else
            log_warn "Failed to send Slack notification"
        fi
    fi
}

send_email_notification() {
    local subject="$1"
    local message="$2"
    local urgency="$3"
    
    if [ -n "$EMAIL_RECIPIENTS" ] && command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "[$urgency] $subject" "$EMAIL_RECIPIENTS"
        log_info "Email notification sent to $EMAIL_RECIPIENTS"
    fi
}

# System status checks
check_container_status() {
    local container_name="$1"
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        return 0  # Running
    else
        return 1  # Not running
    fi
}

check_system_resources() {
    local memory_threshold=90
    local disk_threshold=90
    
    # Memory check
    local memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ "$memory_usage" -gt "$memory_threshold" ]; then
        log_warn "High memory usage: ${memory_usage}%"
        return 1
    fi
    
    # Disk check
    local disk_usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt "$disk_threshold" ]; then
        log_warn "High disk usage: ${disk_usage}%"
        return 1
    fi
    
    return 0
}

check_network_connectivity() {
    if curl -s --connect-timeout 10 https://api.github.com >/dev/null; then
        return 0
    else
        log_warn "GitHub API connectivity check failed"
        return 1
    fi
}

# Remediation actions
restart_container() {
    local container_name="$1"
    local restart_file="/tmp/runner_restart_count"
    local restart_time_file="/tmp/runner_last_restart"
    local current_time=$(date +%s)
    
    # Check restart cooldown
    if [ -f "$restart_time_file" ]; then
        local last_restart=$(cat "$restart_time_file")
        local time_diff=$((current_time - last_restart))
        if [ "$time_diff" -lt "$RESTART_COOLDOWN" ] && [ "${FORCE_RESTART:-false}" != "true" ]; then
            log_warn "Restart cooldown active. Last restart was $((time_diff)) seconds ago."
            return 1
        fi
    fi
    
    # Check restart attempts
    local restart_count=0
    if [ -f "$restart_file" ]; then
        restart_count=$(cat "$restart_file")
    fi
    
    if [ "$restart_count" -ge "$MAX_RESTART_ATTEMPTS" ]; then
        log_error "Maximum restart attempts ($MAX_RESTART_ATTEMPTS) reached. Manual intervention required."
        send_slack_notification "Maximum restart attempts reached for $container_name. Manual intervention required." "critical"
        return 1
    fi
    
    log_info "Attempting to restart container: $container_name (attempt $((restart_count + 1)))"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY RUN] Would restart container: $container_name"
        return 0
    fi
    
    # Perform restart
    if docker restart "$container_name" >/dev/null 2>&1; then
        log_info "Container $container_name restarted successfully"
        echo "$current_time" > "$restart_time_file"
        echo "$((restart_count + 1))" > "$restart_file"
        
        # Wait and verify restart
        sleep 30
        if check_container_status "$container_name"; then
            log_info "Container $container_name is running after restart"
            # Reset restart counter on successful restart
            echo "0" > "$restart_file"
            return 0
        else
            log_error "Container $container_name failed to start after restart"
            return 1
        fi
    else
        log_error "Failed to restart container: $container_name"
        echo "$((restart_count + 1))" > "$restart_file"
        return 1
    fi
}

restart_services() {
    log_info "Attempting to restart all services"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY RUN] Would restart all services using: $PROJECT_ROOT/scripts/restart.sh"
        return 0
    fi
    
    if [ -f "$PROJECT_ROOT/scripts/restart.sh" ]; then
        if "$PROJECT_ROOT/scripts/restart.sh"; then
            log_info "Services restarted successfully"
            return 0
        else
            log_error "Failed to restart services"
            return 1
        fi
    else
        log_error "Restart script not found: $PROJECT_ROOT/scripts/restart.sh"
        return 1
    fi
}

cleanup_resources() {
    log_info "Performing resource cleanup"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY RUN] Would perform resource cleanup"
        return 0
    fi
    
    # Clean Docker resources
    docker system prune -f >/dev/null 2>&1 || true
    
    # Clean old logs
    find "$PROJECT_ROOT/logs" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    
    # Clean temporary files
    find /tmp -name "runner_*" -mtime +1 -delete 2>/dev/null || true
    
    log_info "Resource cleanup completed"
}

run_health_check() {
    log_info "Running health check"
    
    if [ -f "$PROJECT_ROOT/scripts/health-check.sh" ]; then
        if "$PROJECT_ROOT/scripts/health-check.sh" --quiet; then
            log_info "Health check passed"
            return 0
        else
            log_warn "Health check failed"
            return 1
        fi
    else
        log_warn "Health check script not found"
        return 1
    fi
}

# Alert handling functions
handle_critical_alert() {
    local message="$1"
    local source="${ALERT_SOURCE:-monitoring}"
    
    log_critical "CRITICAL ALERT: $message (source: $source)"
    
    # Send immediate notifications
    send_slack_notification "🚨 CRITICAL: $message" "critical"
    send_email_notification "Critical Alert - GitHub Actions Runner" "$message" "CRITICAL"
    
    if [ "${NO_ACTION:-false}" = "true" ]; then
        log_info "No action mode - skipping automated remediation"
        return 0
    fi
    
    # Automated response for critical alerts
    case "$message" in
        *"container"*"down"*|*"container"*"stopped"*)
            restart_container "github-runner"
            ;;
        *"service"*"down"*|*"services"*"failed"*)
            restart_services
            ;;
        *"disk"*"full"*|*"storage"*"full"*)
            cleanup_resources
            ;;
        *"memory"*|*"oom"*)
            restart_services
            cleanup_resources
            ;;
        *)
            log_warn "No specific remediation for critical alert: $message"
            run_health_check
            ;;
    esac
    
    # Post-action verification
    sleep 60
    if run_health_check; then
        send_slack_notification "✅ Critical alert resolved: $message" "good"
        log_info "Critical alert appears to be resolved"
    else
        send_slack_notification "❌ Critical alert persists: $message - Manual intervention required" "critical"
        log_error "Critical alert not resolved by automated actions"
    fi
}

handle_high_alert() {
    local message="$1"
    local source="${ALERT_SOURCE:-monitoring}"
    
    log_error "HIGH ALERT: $message (source: $source)"
    
    # Send notifications
    send_slack_notification "⚠️ HIGH: $message" "high"
    
    if [ "${NO_ACTION:-false}" = "true" ]; then
        log_info "No action mode - skipping automated remediation"
        return 0
    fi
    
    # Automated response for high priority alerts
    case "$message" in
        *"high memory"*|*"memory usage"*)
            cleanup_resources
            ;;
        *"high cpu"*|*"cpu usage"*)
            # Check for runaway processes
            docker exec github-runner top -b -n1 | head -20 || true
            ;;
        *"connection"*"failed"*|*"network"*)
            # Test connectivity and restart if needed
            if ! check_network_connectivity; then
                restart_container "github-runner"
            fi
            ;;
        *)
            log_info "Running diagnostic health check for high alert"
            run_health_check
            ;;
    esac
}

handle_warning_alert() {
    local message="$1"
    local source="${ALERT_SOURCE:-monitoring}"
    
    log_warn "WARNING ALERT: $message (source: $source)"
    
    # Send notification for warnings only if configured
    if [ -n "$NOTIFICATION_WEBHOOK" ]; then
        send_slack_notification "⚠️ WARNING: $message" "warning"
    fi
    
    if [ "${NO_ACTION:-false}" = "true" ]; then
        log_info "No action mode - logging only"
        return 0
    fi
    
    # Light automated response for warnings
    case "$message" in
        *"memory"*|*"cpu"*|*"disk"*)
            # Just log resource usage for monitoring
            docker stats --no-stream github-runner 2>/dev/null || true
            df -h / 2>/dev/null || true
            ;;
        *)
            log_info "Warning logged for review: $message"
            ;;
    esac
}

handle_info_alert() {
    local message="$1"
    local source="${ALERT_SOURCE:-monitoring}"
    
    log_info "INFO ALERT: $message (source: $source)"
    
    # Info alerts are typically just logged unless they indicate system events
    case "$message" in
        *"backup"*"completed"*|*"maintenance"*"completed"*)
            # Positive system events - just log
            ;;
        *"started"*|*"stopped"*)
            # Service lifecycle events
            run_health_check
            ;;
        *)
            log_info "Informational alert logged: $message"
            ;;
    esac
}

# Parse command line arguments
if [ $# -lt 2 ]; then
    usage
    exit 1
fi

ALERT_TYPE="$1"
ALERT_MESSAGE="$2"
shift 2

# Parse additional options
while [[ $# -gt 0 ]]; do
    case $1 in
        --source)
            ALERT_SOURCE="$2"
            shift 2
            ;;
        --metric)
            METRIC_NAME="$2"
            shift 2
            ;;
        --value)
            METRIC_VALUE="$2"
            shift 2
            ;;
        --threshold)
            THRESHOLD_VALUE="$2"
            shift 2
            ;;
        --duration)
            ALERT_DURATION="$2"
            shift 2
            ;;
        --no-action)
            NO_ACTION=true
            shift
            ;;
        --force-restart)
            FORCE_RESTART=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate alert type
case "$ALERT_TYPE" in
    critical|high|warning|info)
        ;;
    *)
        log_error "Invalid alert type: $ALERT_TYPE"
        log_error "Valid types: critical, high, warning, info"
        exit 1
        ;;
esac

# Add context to alert message
FULL_MESSAGE="$ALERT_MESSAGE"
if [ -n "${METRIC_NAME:-}" ] && [ -n "${METRIC_VALUE:-}" ]; then
    FULL_MESSAGE="$FULL_MESSAGE (${METRIC_NAME}: ${METRIC_VALUE}"
    if [ -n "${THRESHOLD_VALUE:-}" ]; then
        FULL_MESSAGE="$FULL_MESSAGE, threshold: ${THRESHOLD_VALUE}"
    fi
    FULL_MESSAGE="$FULL_MESSAGE)"
fi

if [ -n "${ALERT_DURATION:-}" ]; then
    FULL_MESSAGE="$FULL_MESSAGE [Duration: ${ALERT_DURATION}]"
fi

# Handle the alert based on type
case "$ALERT_TYPE" in
    critical)
        handle_critical_alert "$FULL_MESSAGE"
        ;;
    high)
        handle_high_alert "$FULL_MESSAGE"
        ;;
    warning)
        handle_warning_alert "$FULL_MESSAGE"
        ;;
    info)
        handle_info_alert "$FULL_MESSAGE"
        ;;
esac

log_info "Alert handling completed for: $ALERT_TYPE - $FULL_MESSAGE"