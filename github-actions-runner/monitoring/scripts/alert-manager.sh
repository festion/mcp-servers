#!/bin/bash

# GitHub Actions Runner Alert Management System
# Processes alerts and routes them to appropriate channels

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_DIR="$(dirname "$SCRIPT_DIR")"
BASE_DIR="$(dirname "$MONITORING_DIR")"
CONFIG_FILE="$MONITORING_DIR/health-checks.yml"
ALERTS_DIR="$MONITORING_DIR/alerts"
LOG_FILE="$BASE_DIR/logs/alert-manager.log"

# Alert configuration
ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
HOMELAB_AUDITOR_PATH="/home/dev/workspace/homelab-gitops-auditor"

# Alert levels
declare -A ALERT_LEVELS=(
    ["critical"]="🔴"
    ["warning"]="🟡"
    ["info"]="🔵"
    ["resolved"]="✅"
)

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Load configuration from YAML
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Extract webhook URLs from YAML (simplified parsing)
        ALERT_WEBHOOK_URL=$(grep "webhook_url:" "$CONFIG_FILE" | cut -d'"' -f2 || echo "")
        ALERT_EMAIL=$(grep "email:" "$CONFIG_FILE" | cut -d'"' -f2 || echo "")
        SLACK_WEBHOOK_URL=$(grep "slack_webhook:" "$CONFIG_FILE" | cut -d'"' -f2 || echo "")
    fi
}

# Create alert record
create_alert_record() {
    local alert_id="$1"
    local severity="$2"
    local title="$3"
    local message="$4"
    local source="${5:-github-runner}"
    
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    local alert_file="$ALERTS_DIR/${alert_id}.json"
    
    cat > "$alert_file" << EOF
{
    "id": "$alert_id",
    "timestamp": "$timestamp",
    "severity": "$severity",
    "title": "$title",
    "message": "$message",
    "source": "$source",
    "status": "active",
    "created_at": "$timestamp",
    "resolved_at": null,
    "notification_sent": false,
    "escalation_level": 0
}
EOF

    log "Alert created: $alert_id ($severity) - $title"
}

# Resolve alert
resolve_alert() {
    local alert_id="$1"
    local resolution_message="${2:-Alert resolved automatically}"
    
    local alert_file="$ALERTS_DIR/${alert_id}.json"
    
    if [[ -f "$alert_file" ]]; then
        local timestamp
        timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        
        # Update alert status
        local temp_file
        temp_file=$(mktemp)
        jq --arg timestamp "$timestamp" --arg message "$resolution_message" \
           '.status = "resolved" | .resolved_at = $timestamp | .resolution_message = $message' \
           "$alert_file" > "$temp_file"
        mv "$temp_file" "$alert_file"
        
        log "Alert resolved: $alert_id - $resolution_message"
        
        # Send resolution notification
        send_notification "$alert_id" "resolved" "Alert Resolved: $(jq -r '.title' "$alert_file")" "$resolution_message"
    fi
}

# Send Slack notification
send_slack_notification() {
    local severity="$1"
    local title="$2"
    local message="$3"
    local alert_id="$4"
    
    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        return 0
    fi
    
    local color="#808080"
    case $severity in
        "critical") color="#FF0000" ;;
        "warning") color="#FFA500" ;;
        "info") color="#0000FF" ;;
        "resolved") color="#00FF00" ;;
    esac
    
    local payload
    payload=$(cat << EOF
{
    "attachments": [
        {
            "color": "$color",
            "title": "${ALERT_LEVELS[$severity]} $title",
            "text": "$message",
            "fields": [
                {
                    "title": "Source",
                    "value": "GitHub Actions Runner",
                    "short": true
                },
                {
                    "title": "Alert ID",
                    "value": "$alert_id",
                    "short": true
                },
                {
                    "title": "Timestamp",
                    "value": "$(date)",
                    "short": true
                }
            ],
            "footer": "GitHub Runner Monitoring"
        }
    ]
}
EOF
)

    curl -X POST -H 'Content-type: application/json' \
         --data "$payload" \
         "$SLACK_WEBHOOK_URL" || log "Failed to send Slack notification"
}

# Send email notification
send_email_notification() {
    local severity="$1"
    local title="$2"
    local message="$3"
    local alert_id="$4"
    
    if [[ -z "$ALERT_EMAIL" ]] || ! command -v mail &> /dev/null; then
        return 0
    fi
    
    local subject="${ALERT_LEVELS[$severity]} GitHub Runner Alert: $title"
    local body
    body=$(cat << EOF
GitHub Actions Runner Alert

Alert ID: $alert_id
Severity: $severity
Title: $title
Message: $message
Timestamp: $(date)
Source: GitHub Actions Runner

This is an automated alert from your GitHub Actions runner monitoring system.
EOF
)

    echo "$body" | mail -s "$subject" "$ALERT_EMAIL" || log "Failed to send email notification"
}

# Send webhook notification
send_webhook_notification() {
    local severity="$1"
    local title="$2"
    local message="$3"
    local alert_id="$4"
    
    if [[ -z "$ALERT_WEBHOOK_URL" ]]; then
        return 0
    fi
    
    local payload
    payload=$(cat << EOF
{
    "alert_id": "$alert_id",
    "severity": "$severity",
    "title": "$title",
    "message": "$message",
    "source": "github-actions-runner",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)

    curl -X POST -H 'Content-type: application/json' \
         --data "$payload" \
         "$ALERT_WEBHOOK_URL" || log "Failed to send webhook notification"
}

# Integration with homelab-gitops-auditor
send_homelab_notification() {
    local severity="$1"
    local title="$2"
    local message="$3"
    
    if [[ -f "$HOMELAB_AUDITOR_PATH/scripts/send-alert.sh" ]]; then
        "$HOMELAB_AUDITOR_PATH/scripts/send-alert.sh" \
            "$title" \
            "$message" \
            "$severity" || log "Failed to send homelab auditor notification"
    fi
}

# Send notification to all configured channels
send_notification() {
    local alert_id="$1"
    local severity="$2"
    local title="$3"
    local message="$4"
    
    log "Sending $severity notification: $title"
    
    # Send to all configured channels
    send_slack_notification "$severity" "$title" "$message" "$alert_id"
    send_email_notification "$severity" "$title" "$message" "$alert_id"
    send_webhook_notification "$severity" "$title" "$message" "$alert_id"
    send_homelab_notification "$severity" "$title" "$message"
    
    # Mark notification as sent
    local alert_file="$ALERTS_DIR/${alert_id}.json"
    if [[ -f "$alert_file" ]]; then
        local temp_file
        temp_file=$(mktemp)
        jq '.notification_sent = true' "$alert_file" > "$temp_file"
        mv "$temp_file" "$alert_file"
    fi
}

# Process health check results
process_health_check() {
    local health_report="$1"
    
    if [[ ! -f "$health_report" ]]; then
        log "Health report not found: $health_report"
        return 1
    fi
    
    local overall_status
    overall_status=$(jq -r '.overall_status' "$health_report")
    local critical_failures
    critical_failures=$(jq -r '.critical_failures' "$health_report")
    local warning_count
    warning_count=$(jq -r '.warning_count' "$health_report")
    
    # Generate alert for critical status
    if [[ "$overall_status" == "CRITICAL" ]]; then
        local alert_id="health-critical-$(date +%s)"
        create_alert_record "$alert_id" "critical" \
            "GitHub Runner Critical Health Status" \
            "Health check detected $critical_failures critical failure(s). Immediate attention required."
        send_notification "$alert_id" "critical" \
            "GitHub Runner Critical Health Status" \
            "Health check detected $critical_failures critical failure(s). Immediate attention required."
    
    # Generate alert for warning status
    elif [[ "$overall_status" == "WARNING" ]]; then
        local alert_id="health-warning-$(date +%s)"
        create_alert_record "$alert_id" "warning" \
            "GitHub Runner Health Warning" \
            "Health check detected $warning_count warning(s). Monitoring recommended."
        send_notification "$alert_id" "warning" \
            "GitHub Runner Health Warning" \
            "Health check detected $warning_count warning(s). Monitoring recommended."
    fi
}

# Monitor for new alerts from metrics
monitor_metrics_alerts() {
    log "Monitoring metrics for alert conditions..."
    
    local metrics_file="$BASE_DIR/data/metrics/custom_metrics.prom"
    
    if [[ ! -f "$metrics_file" ]]; then
        return 0
    fi
    
    # Check CPU usage
    local cpu_usage
    cpu_usage=$(grep "github_runner_system_cpu_usage" "$metrics_file" | awk '{print $2}' || echo "0")
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        local alert_id="cpu-high-$(date +%s)"
        create_alert_record "$alert_id" "warning" \
            "High CPU Usage" \
            "CPU usage is at ${cpu_usage}%. Consider investigating workload."
        send_notification "$alert_id" "warning" \
            "High CPU Usage" \
            "CPU usage is at ${cpu_usage}%. Consider investigating workload."
    fi
    
    # Check memory usage
    local memory_usage
    memory_usage=$(grep "github_runner_system_memory_usage" "$metrics_file" | awk '{print $2}' || echo "0")
    if (( $(echo "$memory_usage > 85" | bc -l) )); then
        local alert_id="memory-high-$(date +%s)"
        create_alert_record "$alert_id" "critical" \
            "High Memory Usage" \
            "Memory usage is at ${memory_usage}%. System may become unstable."
        send_notification "$alert_id" "critical" \
            "High Memory Usage" \
            "Memory usage is at ${memory_usage}%. System may become unstable."
    fi
    
    # Check GitHub connection
    local connection_status
    connection_status=$(grep "github_runner_connection_status" "$metrics_file" | awk '{print $2}' || echo "1")
    if [[ "$connection_status" == "0" ]]; then
        local alert_id="github-disconnected-$(date +%s)"
        create_alert_record "$alert_id" "critical" \
            "GitHub Connection Lost" \
            "Runner has lost connection to GitHub. Jobs cannot be processed."
        send_notification "$alert_id" "critical" \
            "GitHub Connection Lost" \
            "Runner has lost connection to GitHub. Jobs cannot be processed."
    fi
}

# Escalate unresolved alerts
escalate_alerts() {
    log "Checking for alerts requiring escalation..."
    
    local escalation_threshold=3600  # 1 hour
    local current_time
    current_time=$(date +%s)
    
    for alert_file in "$ALERTS_DIR"/*.json; do
        if [[ ! -f "$alert_file" ]]; then
            continue
        fi
        
        local status
        status=$(jq -r '.status' "$alert_file")
        if [[ "$status" != "active" ]]; then
            continue
        fi
        
        local created_at
        created_at=$(jq -r '.created_at' "$alert_file")
        local created_timestamp
        created_timestamp=$(date -d "$created_at" +%s 2>/dev/null || echo "$current_time")
        local age=$((current_time - created_timestamp))
        
        if [[ $age -gt $escalation_threshold ]]; then
            local alert_id
            alert_id=$(jq -r '.id' "$alert_file")
            local title
            title=$(jq -r '.title' "$alert_file")
            local escalation_level
            escalation_level=$(jq -r '.escalation_level' "$alert_file")
            
            # Escalate alert
            local temp_file
            temp_file=$(mktemp)
            jq '.escalation_level += 1' "$alert_file" > "$temp_file"
            mv "$temp_file" "$alert_file"
            
            log "Escalating alert: $alert_id (level $((escalation_level + 1)))"
            send_notification "$alert_id" "critical" \
                "ESCALATED: $title" \
                "Alert has been unresolved for over 1 hour. Escalation level: $((escalation_level + 1))"
        fi
    done
}

# Clean up old resolved alerts
cleanup_old_alerts() {
    log "Cleaning up old resolved alerts..."
    
    local retention_days=7
    find "$ALERTS_DIR" -name "*.json" -mtime +$retention_days -exec rm -f {} \;
}

# List active alerts
list_alerts() {
    local status_filter="${1:-active}"
    
    echo "=== GitHub Runner Alerts ($status_filter) ==="
    
    for alert_file in "$ALERTS_DIR"/*.json; do
        if [[ ! -f "$alert_file" ]]; then
            echo "No alerts found."
            return 0
        fi
        
        local status
        status=$(jq -r '.status' "$alert_file")
        
        if [[ "$status_filter" != "all" && "$status" != "$status_filter" ]]; then
            continue
        fi
        
        local alert_id title severity timestamp
        alert_id=$(jq -r '.id' "$alert_file")
        title=$(jq -r '.title' "$alert_file")
        severity=$(jq -r '.severity' "$alert_file")
        timestamp=$(jq -r '.timestamp' "$alert_file")
        
        echo "${ALERT_LEVELS[$severity]} [$severity] $title"
        echo "   ID: $alert_id"
        echo "   Time: $timestamp"
        echo "   Status: $status"
        echo
    done
}

# Get alert statistics
get_alert_stats() {
    local total_alerts=0
    local active_alerts=0
    local critical_alerts=0
    local warning_alerts=0
    
    for alert_file in "$ALERTS_DIR"/*.json; do
        if [[ ! -f "$alert_file" ]]; then
            break
        fi
        
        total_alerts=$((total_alerts + 1))
        
        local status severity
        status=$(jq -r '.status' "$alert_file")
        severity=$(jq -r '.severity' "$alert_file")
        
        if [[ "$status" == "active" ]]; then
            active_alerts=$((active_alerts + 1))
            
            case $severity in
                "critical") critical_alerts=$((critical_alerts + 1)) ;;
                "warning") warning_alerts=$((warning_alerts + 1)) ;;
            esac
        fi
    done
    
    cat << EOF
{
    "total_alerts": $total_alerts,
    "active_alerts": $active_alerts,
    "critical_alerts": $critical_alerts,
    "warning_alerts": $warning_alerts
}
EOF
}

# Main execution
main() {
    case "${1:-monitor}" in
        "send")
            shift
            local severity="$1"
            local title="$2"
            local message="$3"
            local alert_id="manual-$(date +%s)"
            
            create_alert_record "$alert_id" "$severity" "$title" "$message"
            send_notification "$alert_id" "$severity" "$title" "$message"
            ;;
        "resolve")
            resolve_alert "$2" "${3:-Manual resolution}"
            ;;
        "list")
            list_alerts "${2:-active}"
            ;;
        "stats")
            get_alert_stats
            ;;
        "monitor")
            monitor_metrics_alerts
            escalate_alerts
            cleanup_old_alerts
            ;;
        "process-health")
            process_health_check "$2"
            ;;
        *)
            echo "Usage: $0 {send|resolve|list|stats|monitor|process-health}"
            echo "  send <severity> <title> <message> - Send manual alert"
            echo "  resolve <alert_id> [message]       - Resolve alert"
            echo "  list [status]                      - List alerts (active/resolved/all)"
            echo "  stats                              - Show alert statistics"
            echo "  monitor                            - Check metrics and escalate alerts"
            echo "  process-health <report_file>       - Process health check report"
            exit 1
            ;;
    esac
}

# Ensure directories exist
mkdir -p "$ALERTS_DIR" "$(dirname "$LOG_FILE")"

# Load configuration
load_config

# Handle script execution
main "$@"