#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/github-runner-alerts.log"

source "$SCRIPT_DIR/common/logging.sh"
source "$SCRIPT_DIR/common/utils.sh"

setup_logging

usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND

Manage GitHub Actions runner alerts and notifications

COMMANDS:
    check           Check for active alerts
    clear           Clear all alerts
    clear-by-id ID  Clear specific alert by ID
    send            Send test notification
    configure       Configure alert settings
    history         Show alert history
    summary         Show alert summary

OPTIONS:
    -h, --help              Show this help message
    -c, --config FILE       Configuration file path
    --webhook-url URL       Webhook URL for notifications
    --email EMAIL           Email address for alerts
    --severity LEVEL        Filter by severity (info|warning|critical)
    --category TYPE         Filter by category (service|resources|network)
    --since DURATION        Show alerts since duration (1h, 1d, 1w)
    -j, --json              JSON output format
    -v, --verbose           Verbose output

Examples:
    $0 check                                    # Check active alerts
    $0 send --webhook-url https://hooks.slack.com/...  # Test notification
    $0 history --since 24h                     # Show last 24 hours
    $0 clear-by-id disk-space-high             # Clear specific alert
    $0 summary --json                          # JSON summary
EOF
}

COMMAND=""
CONFIG_FILE=""
WEBHOOK_URL=""
EMAIL=""
SEVERITY=""
CATEGORY=""
SINCE=""
JSON_OUTPUT=false
VERBOSE=false

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
        --webhook-url)
            WEBHOOK_URL="$2"
            shift 2
            ;;
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --severity)
            SEVERITY="$2"
            shift 2
            ;;
        --category)
            CATEGORY="$2"
            shift 2
            ;;
        --since)
            SINCE="$2"
            shift 2
            ;;
        -j|--json)
            JSON_OUTPUT=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            LOG_LEVEL="DEBUG"
            shift
            ;;
        check|clear|clear-by-id|send|configure|history|summary)
            COMMAND="$1"
            shift
            # For clear-by-id, the next argument is the alert ID
            if [[ "$COMMAND" == "clear-by-id" ]] && [[ $# -gt 0 ]]; then
                ALERT_ID="$1"
                shift
            fi
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

ALERTS_FILE="/var/lib/github-runner/alerts.json"
ALERT_HISTORY_FILE="/var/lib/github-runner/alert-history.json"
ALERT_CONFIG_FILE="/etc/github-runner/alert-config.json"

load_configuration() {
    local config_file
    if [[ -n "$CONFIG_FILE" ]]; then
        config_file="$CONFIG_FILE"
    else
        config_file="/etc/github-runner/config.env"
        if [[ ! -f "$config_file" ]]; then
            config_file="$PROJECT_ROOT/config/runner.env"
        fi
    fi
    
    if [[ -f "$config_file" ]]; then
        log_debug "Loading configuration from: $config_file"
        set -a
        source "$config_file"
        set +a
    fi
    
    # Override with command line options
    WEBHOOK_URL="${WEBHOOK_URL:-$WEBHOOK_URL}"
    EMAIL="${EMAIL:-${ALERT_EMAIL:-}}"
    
    # Load alert-specific configuration
    if [[ -f "$ALERT_CONFIG_FILE" ]]; then
        local alert_config
        alert_config=$(cat "$ALERT_CONFIG_FILE" 2>/dev/null || echo "{}")
        
        if validate_json "$alert_config"; then
            if [[ -z "$WEBHOOK_URL" ]]; then
                WEBHOOK_URL=$(echo "$alert_config" | jq -r '.webhook_url // ""')
            fi
            if [[ -z "$EMAIL" ]]; then
                EMAIL=$(echo "$alert_config" | jq -r '.email // ""')
            fi
        fi
    fi
}

ensure_directories() {
    mkdir -p "$(dirname "$ALERTS_FILE")"
    mkdir -p "$(dirname "$ALERT_HISTORY_FILE")"
    mkdir -p "$(dirname "$ALERT_CONFIG_FILE")"
}

get_current_alerts() {
    if [[ -f "$ALERTS_FILE" ]]; then
        cat "$ALERTS_FILE"
    else
        echo "[]"
    fi
}

save_alerts() {
    local alerts="$1"
    echo "$alerts" > "$ALERTS_FILE"
}

add_to_history() {
    local alert="$1"
    local action="$2"
    local timestamp=$(date +%s)
    
    local history_entry
    history_entry=$(cat << EOF
{
    "timestamp": $timestamp,
    "action": "$action",
    "alert": $alert
}
EOF
)
    
    local current_history="[]"
    if [[ -f "$ALERT_HISTORY_FILE" ]]; then
        current_history=$(cat "$ALERT_HISTORY_FILE" 2>/dev/null || echo "[]")
    fi
    
    local updated_history
    updated_history=$(echo "$current_history" | jq ". + [$history_entry]")
    
    echo "$updated_history" > "$ALERT_HISTORY_FILE"
}

filter_alerts() {
    local alerts="$1"
    local filtered="$alerts"
    
    if [[ -n "$SEVERITY" ]]; then
        filtered=$(echo "$filtered" | jq --arg severity "$SEVERITY" '[.[] | select(.severity == $severity)]')
    fi
    
    if [[ -n "$CATEGORY" ]]; then
        filtered=$(echo "$filtered" | jq --arg category "$CATEGORY" '[.[] | select(.category == $category)]')
    fi
    
    if [[ -n "$SINCE" ]]; then
        local since_timestamp
        case "$SINCE" in
            *h) since_timestamp=$(date -d "-${SINCE%h} hours" +%s) ;;
            *d) since_timestamp=$(date -d "-${SINCE%d} days" +%s) ;;
            *w) since_timestamp=$(date -d "-${SINCE%w} weeks" +%s) ;;
            *) since_timestamp=$(date -d "-$SINCE" +%s 2>/dev/null || echo "0") ;;
        esac
        
        filtered=$(echo "$filtered" | jq --arg since "$since_timestamp" '[.[] | select(.timestamp >= ($since | tonumber))]')
    fi
    
    echo "$filtered"
}

check_alerts() {
    local alerts
    alerts=$(get_current_alerts)
    
    alerts=$(filter_alerts "$alerts")
    
    local alert_count
    alert_count=$(echo "$alerts" | jq length)
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        echo "$alerts" | jq .
    else
        if [[ "$alert_count" -gt 0 ]]; then
            echo "Active Alerts ($alert_count):"
            echo "===================="
            
            echo "$alerts" | jq -r '.[] | "\(.timestamp | strftime("%Y-%m-%d %H:%M:%S")) [\(.severity | ascii_upcase)] \(.id): \(.message)"'
        else
            echo "No active alerts"
        fi
    fi
}

clear_all_alerts() {
    local current_alerts
    current_alerts=$(get_current_alerts)
    
    local alert_count
    alert_count=$(echo "$current_alerts" | jq length)
    
    if [[ "$alert_count" -gt 0 ]]; then
        # Add all alerts to history as cleared
        echo "$current_alerts" | jq -c '.[]' | while IFS= read -r alert; do
            add_to_history "$alert" "cleared"
        done
        
        save_alerts "[]"
        
        log_success "Cleared $alert_count alert(s)"
        
        if [[ -n "$WEBHOOK_URL" ]]; then
            send_notification "info" "Alerts Cleared" "$alert_count alert(s) manually cleared on $(hostname)"
        fi
    else
        log_info "No alerts to clear"
    fi
}

clear_alert_by_id() {
    local alert_id="$1"
    local current_alerts
    current_alerts=$(get_current_alerts)
    
    local alert_to_clear
    alert_to_clear=$(echo "$current_alerts" | jq --arg id "$alert_id" '.[] | select(.id == $id)')
    
    if [[ "$alert_to_clear" != "" ]]; then
        # Remove the alert from the current alerts
        local updated_alerts
        updated_alerts=$(echo "$current_alerts" | jq --arg id "$alert_id" '[.[] | select(.id != $id)]')
        
        save_alerts "$updated_alerts"
        add_to_history "$alert_to_clear" "cleared"
        
        log_success "Cleared alert: $alert_id"
        
        if [[ -n "$WEBHOOK_URL" ]]; then
            local message
            message=$(echo "$alert_to_clear" | jq -r '.message')
            send_notification "info" "Alert Cleared" "Alert '$alert_id' cleared on $(hostname): $message"
        fi
    else
        log_error "Alert not found: $alert_id"
        exit 1
    fi
}

send_test_notification() {
    local test_message="Test notification from GitHub Actions Runner monitoring on $(hostname)"
    local test_details="This is a test notification to verify alert delivery is working correctly."
    
    if [[ -n "$WEBHOOK_URL" ]]; then
        if send_notification "info" "Test Notification" "$test_details"; then
            log_success "Webhook notification sent successfully"
        else
            log_error "Failed to send webhook notification"
        fi
    else
        log_warn "No webhook URL configured"
    fi
    
    if [[ -n "$EMAIL" ]] && command -v mail >/dev/null 2>&1; then
        local subject="GitHub Actions Runner Test Alert - $(hostname)"
        
        if echo "$test_details" | mail -s "$subject" "$EMAIL" 2>/dev/null; then
            log_success "Email notification sent successfully"
        else
            log_error "Failed to send email notification"
        fi
    else
        if [[ -z "$EMAIL" ]]; then
            log_warn "No email address configured"
        else
            log_warn "Mail command not available"
        fi
    fi
    
    # Add test notification to history
    local test_alert
    test_alert=$(cat << EOF
{
    "id": "test-notification",
    "severity": "info",
    "message": "$test_message",
    "timestamp": $(date +%s),
    "category": "test"
}
EOF
)
    
    add_to_history "$test_alert" "sent"
}

configure_alerts() {
    log_section "Alert Configuration"
    
    echo "Current configuration:"
    echo "  Webhook URL: ${WEBHOOK_URL:-'Not configured'}"
    echo "  Email: ${EMAIL:-'Not configured'}"
    echo
    
    # Interactive configuration if no parameters provided
    if [[ -z "$WEBHOOK_URL" ]] && [[ -z "$EMAIL" ]] && [[ -t 0 ]]; then
        read -p "Enter webhook URL (or press Enter to skip): " webhook_input
        read -p "Enter email address (or press Enter to skip): " email_input
        
        WEBHOOK_URL="$webhook_input"
        EMAIL="$email_input"
    fi
    
    # Save configuration
    local config_data
    config_data=$(cat << EOF
{
    "webhook_url": "${WEBHOOK_URL:-null}",
    "email": "${EMAIL:-null}",
    "configured_at": $(date +%s),
    "configured_by": "$(whoami)"
}
EOF
)
    
    echo "$config_data" > "$ALERT_CONFIG_FILE"
    chmod 640 "$ALERT_CONFIG_FILE"
    
    log_success "Alert configuration saved to: $ALERT_CONFIG_FILE"
    
    # Test configuration if possible
    if [[ -n "$WEBHOOK_URL" ]] || [[ -n "$EMAIL" ]]; then
        echo
        read -p "Send test notification? (y/N): " test_choice
        if [[ "$test_choice" =~ ^[Yy]$ ]]; then
            send_test_notification
        fi
    fi
}

show_alert_history() {
    if [[ ! -f "$ALERT_HISTORY_FILE" ]]; then
        if [[ "$JSON_OUTPUT" == true ]]; then
            echo "[]"
        else
            echo "No alert history found"
        fi
        return 0
    fi
    
    local history
    history=$(cat "$ALERT_HISTORY_FILE")
    
    # Apply filters
    if [[ -n "$SINCE" ]]; then
        local since_timestamp
        case "$SINCE" in
            *h) since_timestamp=$(date -d "-${SINCE%h} hours" +%s) ;;
            *d) since_timestamp=$(date -d "-${SINCE%d} days" +%s) ;;
            *w) since_timestamp=$(date -d "-${SINCE%w} weeks" +%s) ;;
            *) since_timestamp=$(date -d "-$SINCE" +%s 2>/dev/null || echo "0") ;;
        esac
        
        history=$(echo "$history" | jq --arg since "$since_timestamp" '[.[] | select(.timestamp >= ($since | tonumber))]')
    fi
    
    if [[ -n "$SEVERITY" ]]; then
        history=$(echo "$history" | jq --arg severity "$SEVERITY" '[.[] | select(.alert.severity == $severity)]')
    fi
    
    if [[ -n "$CATEGORY" ]]; then
        history=$(echo "$history" | jq --arg category "$CATEGORY" '[.[] | select(.alert.category == $category)]')
    fi
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        echo "$history" | jq .
    else
        local entry_count
        entry_count=$(echo "$history" | jq length)
        
        if [[ "$entry_count" -gt 0 ]]; then
            echo "Alert History ($entry_count entries):"
            echo "============================="
            
            echo "$history" | jq -r '.[] | "\(.timestamp | strftime("%Y-%m-%d %H:%M:%S")) \(.action | ascii_upcase) [\(.alert.severity | ascii_upcase)] \(.alert.id): \(.alert.message)"' | sort -r
        else
            echo "No alert history entries found"
        fi
    fi
}

show_alert_summary() {
    local current_alerts
    current_alerts=$(get_current_alerts)
    
    local history="[]"
    if [[ -f "$ALERT_HISTORY_FILE" ]]; then
        history=$(cat "$ALERT_HISTORY_FILE")
    fi
    
    local current_count
    current_count=$(echo "$current_alerts" | jq length)
    
    local total_history_count
    total_history_count=$(echo "$history" | jq length)
    
    # Count by severity
    local critical_count
    critical_count=$(echo "$current_alerts" | jq '[.[] | select(.severity == "critical")] | length')
    
    local warning_count
    warning_count=$(echo "$current_alerts" | jq '[.[] | select(.severity == "warning")] | length')
    
    local info_count
    info_count=$(echo "$current_alerts" | jq '[.[] | select(.severity == "info")] | length')
    
    # Count by category
    local service_count
    service_count=$(echo "$current_alerts" | jq '[.[] | select(.category == "service")] | length')
    
    local resources_count
    resources_count=$(echo "$current_alerts" | jq '[.[] | select(.category == "resources")] | length')
    
    local network_count
    network_count=$(echo "$current_alerts" | jq '[.[] | select(.category == "network")] | length')
    
    # Recent activity (last 24 hours)
    local yesterday=$(date -d "-1 day" +%s)
    local recent_activity
    recent_activity=$(echo "$history" | jq --arg since "$yesterday" '[.[] | select(.timestamp >= ($since | tonumber))] | length')
    
    local summary_data
    summary_data=$(cat << EOF
{
    "timestamp": $(date +%s),
    "current_alerts": {
        "total": $current_count,
        "by_severity": {
            "critical": $critical_count,
            "warning": $warning_count,
            "info": $info_count
        },
        "by_category": {
            "service": $service_count,
            "resources": $resources_count,
            "network": $network_count
        }
    },
    "history": {
        "total_entries": $total_history_count,
        "last_24h": $recent_activity
    },
    "configuration": {
        "webhook_configured": $(if [[ -n "$WEBHOOK_URL" ]]; then echo "true"; else echo "false"; fi),
        "email_configured": $(if [[ -n "$EMAIL" ]]; then echo "true"; else echo "false"; fi)
    }
}
EOF
)
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        echo "$summary_data" | jq .
    else
        echo "GitHub Actions Runner Alert Summary"
        echo "=================================="
        echo
        echo "Current Alerts: $current_count"
        echo "  Critical: $critical_count"
        echo "  Warning: $warning_count"
        echo "  Info: $info_count"
        echo
        echo "By Category:"
        echo "  Service: $service_count"
        echo "  Resources: $resources_count"
        echo "  Network: $network_count"
        echo
        echo "History:"
        echo "  Total entries: $total_history_count"
        echo "  Last 24 hours: $recent_activity"
        echo
        echo "Configuration:"
        echo "  Webhook: $(if [[ -n "$WEBHOOK_URL" ]]; then echo "Configured"; else echo "Not configured"; fi)"
        echo "  Email: $(if [[ -n "$EMAIL" ]]; then echo "Configured"; else echo "Not configured"; fi)"
        echo
        echo "Generated: $(date)"
    fi
}

main() {
    load_configuration
    ensure_directories
    
    case "$COMMAND" in
        check)
            check_alerts
            ;;
        clear)
            clear_all_alerts
            ;;
        clear-by-id)
            if [[ -z "${ALERT_ID:-}" ]]; then
                log_error "Alert ID is required for clear-by-id command"
                exit 1
            fi
            clear_alert_by_id "$ALERT_ID"
            ;;
        send)
            send_test_notification
            ;;
        configure)
            configure_alerts
            ;;
        history)
            show_alert_history
            ;;
        summary)
            show_alert_summary
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            usage
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi