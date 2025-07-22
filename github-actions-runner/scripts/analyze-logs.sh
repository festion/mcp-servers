#!/bin/bash
# GitHub Actions Runner Log Analyzer
# Analyzes logs for patterns, errors, and performance metrics

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default parameters
CONTAINER_NAME="github-runner"
LINES=1000
OUTPUT_FORMAT="summary"
TIME_FILTER=""

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Analyzes GitHub Actions Runner logs for troubleshooting

OPTIONS:
    -c, --container NAME    Container name (default: github-runner)
    -l, --lines NUMBER      Number of log lines to analyze (default: 1000)
    -f, --format FORMAT     Output format: summary|detailed|json (default: summary)
    -t, --time TIMEFRAME    Time filter: 1h|6h|1d|1w (default: all)
    -o, --output FILE       Output file (default: stdout)
    -s, --since TIMESTAMP   Show logs since timestamp (RFC3339)
    -u, --until TIMESTAMP   Show logs until timestamp (RFC3339)
    -e, --errors-only       Show only error and warning messages
    -p, --performance       Focus on performance metrics
    -n, --network           Focus on network-related logs
    -h, --help              Show this help message

EXAMPLES:
    $0                              # Basic log analysis
    $0 -l 500 -f detailed          # Detailed analysis of last 500 lines
    $0 -t 1h -e                     # Errors from last hour
    $0 -p -o performance.txt        # Performance analysis to file
    $0 --since "2024-01-01T10:00:00Z" --until "2024-01-01T11:00:00Z"

EOF
}

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--container)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -l|--lines)
            LINES="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -t|--time)
            TIME_FILTER="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -s|--since)
            SINCE_TIME="$2"
            shift 2
            ;;
        -u|--until)
            UNTIL_TIME="$2"
            shift 2
            ;;
        -e|--errors-only)
            ERRORS_ONLY=true
            shift
            ;;
        -p|--performance)
            PERFORMANCE_FOCUS=true
            shift
            ;;
        -n|--network)
            NETWORK_FOCUS=true
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

# Check if Docker is available
if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker not found. Please install Docker."
    exit 1
fi

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_error "Container '$CONTAINER_NAME' not found."
    log_info "Available containers:"
    docker ps -a --format 'table {{.Names}}\t{{.Status}}'
    exit 1
fi

# Build docker logs command
DOCKER_CMD="docker logs"

# Add time filters
if [ -n "${SINCE_TIME:-}" ]; then
    DOCKER_CMD="$DOCKER_CMD --since '$SINCE_TIME'"
fi

if [ -n "${UNTIL_TIME:-}" ]; then
    DOCKER_CMD="$DOCKER_CMD --until '$UNTIL_TIME'"
fi

if [ -n "$TIME_FILTER" ]; then
    case $TIME_FILTER in
        1h) DOCKER_CMD="$DOCKER_CMD --since '1h'" ;;
        6h) DOCKER_CMD="$DOCKER_CMD --since '6h'" ;;
        1d) DOCKER_CMD="$DOCKER_CMD --since '24h'" ;;
        1w) DOCKER_CMD="$DOCKER_CMD --since '168h'" ;;
        *) log_warn "Invalid time filter: $TIME_FILTER" ;;
    esac
fi

DOCKER_CMD="$DOCKER_CMD --tail $LINES $CONTAINER_NAME"

# Get logs
log_info "Retrieving logs from container: $CONTAINER_NAME"
if ! LOG_DATA=$(eval "$DOCKER_CMD" 2>&1); then
    log_error "Failed to retrieve logs from container: $CONTAINER_NAME"
    exit 1
fi

# Check if logs are empty
if [ -z "$LOG_DATA" ]; then
    log_warn "No logs found for the specified criteria"
    exit 0
fi

# Apply filters
if [ "${ERRORS_ONLY:-false}" = true ]; then
    LOG_DATA=$(echo "$LOG_DATA" | grep -E 'ERROR|FATAL|WARN|Exception|Failed|Error')
fi

if [ "${NETWORK_FOCUS:-false}" = true ]; then
    LOG_DATA=$(echo "$LOG_DATA" | grep -iE 'connection|network|dns|timeout|refused|unreachable|proxy')
fi

# Analysis functions
analyze_errors() {
    echo -e "${RED}=== Error Analysis ===${NC}"
    
    # Error summary
    local error_count=$(echo "$LOG_DATA" | grep -c -E 'ERROR|FATAL' || echo "0")
    local warn_count=$(echo "$LOG_DATA" | grep -c 'WARN' || echo "0")
    local exception_count=$(echo "$LOG_DATA" | grep -c -i 'exception' || echo "0")
    
    echo "Error Count: $error_count"
    echo "Warning Count: $warn_count"
    echo "Exception Count: $exception_count"
    echo ""
    
    if [ "$error_count" -gt 0 ]; then
        echo "Top Error Patterns:"
        echo "$LOG_DATA" | grep -E 'ERROR|FATAL' | \
            sed 's/^.*ERROR/ERROR/' | sed 's/^.*FATAL/FATAL/' | \
            sort | uniq -c | sort -nr | head -10
        echo ""
        
        echo "Recent Errors (last 5):"
        echo "$LOG_DATA" | grep -E 'ERROR|FATAL' | tail -5
        echo ""
    fi
    
    if [ "$warn_count" -gt 0 ]; then
        echo "Top Warning Patterns:"
        echo "$LOG_DATA" | grep 'WARN' | \
            sed 's/^.*WARN/WARN/' | \
            sort | uniq -c | sort -nr | head -5
        echo ""
    fi
}

analyze_performance() {
    echo -e "${BLUE}=== Performance Analysis ===${NC}"
    
    # Look for timing information
    local timing_data=$(echo "$LOG_DATA" | grep -iE 'duration|timing|elapsed|took|ms|seconds')
    
    if [ -n "$timing_data" ]; then
        echo "Performance Metrics Found:"
        echo "$timing_data" | tail -10
        echo ""
    fi
    
    # Memory usage patterns
    local memory_data=$(echo "$LOG_DATA" | grep -iE 'memory|mem|oom|out of memory')
    if [ -n "$memory_data" ]; then
        echo "Memory-related Messages:"
        echo "$memory_data" | tail -5
        echo ""
    fi
    
    # CPU usage patterns
    local cpu_data=$(echo "$LOG_DATA" | grep -iE 'cpu|load|high usage')
    if [ -n "$cpu_data" ]; then
        echo "CPU-related Messages:"
        echo "$cpu_data" | tail -5
        echo ""
    fi
    
    # Job execution times
    local job_data=$(echo "$LOG_DATA" | grep -iE 'job.*started|job.*completed|job.*failed')
    if [ -n "$job_data" ]; then
        echo "Job Execution Events:"
        echo "$job_data" | tail -10
        echo ""
    fi
}

analyze_network() {
    echo -e "${CYAN}=== Network Analysis ===${NC}"
    
    # Connection issues
    local conn_issues=$(echo "$LOG_DATA" | grep -iE 'connection.*failed|connection.*refused|timeout|unreachable')
    if [ -n "$conn_issues" ]; then
        echo "Connection Issues:"
        echo "$conn_issues" | tail -10
        echo ""
    fi
    
    # DNS issues
    local dns_issues=$(echo "$LOG_DATA" | grep -iE 'dns|name resolution|nslookup')
    if [ -n "$dns_issues" ]; then
        echo "DNS-related Messages:"
        echo "$dns_issues" | tail -5
        echo ""
    fi
    
    # GitHub API interactions
    local github_api=$(echo "$LOG_DATA" | grep -iE 'api\.github\.com|github.*api|rate.*limit')
    if [ -n "$github_api" ]; then
        echo "GitHub API Interactions:"
        echo "$github_api" | tail -10
        echo ""
    fi
    
    # Proxy-related messages
    local proxy_data=$(echo "$LOG_DATA" | grep -iE 'proxy|http_proxy|https_proxy')
    if [ -n "$proxy_data" ]; then
        echo "Proxy-related Messages:"
        echo "$proxy_data" | tail -5
        echo ""
    fi
}

analyze_security() {
    echo -e "${YELLOW}=== Security Analysis ===${NC}"
    
    # Authentication issues
    local auth_issues=$(echo "$LOG_DATA" | grep -iE 'auth|token|permission|denied|unauthorized|forbidden')
    if [ -n "$auth_issues" ]; then
        echo "Authentication/Authorization Messages:"
        echo "$auth_issues" | tail -10
        echo ""
    fi
    
    # Registration issues
    local reg_issues=$(echo "$LOG_DATA" | grep -iE 'registration|register')
    if [ -n "$reg_issues" ]; then
        echo "Registration Messages:"
        echo "$reg_issues" | tail -5
        echo ""
    fi
}

analyze_activity() {
    echo -e "${GREEN}=== Activity Analysis ===${NC}"
    
    # Startup/shutdown events
    local lifecycle=$(echo "$LOG_DATA" | grep -iE 'starting|started|stopping|stopped|shutdown|startup')
    if [ -n "$lifecycle" ]; then
        echo "Lifecycle Events:"
        echo "$lifecycle" | tail -10
        echo ""
    fi
    
    # Job activity
    local job_activity=$(echo "$LOG_DATA" | grep -iE 'job.*queued|job.*assigned|workflow')
    if [ -n "$job_activity" ]; then
        echo "Job Activity:"
        echo "$job_activity" | tail -10
        echo ""
    fi
    
    # Recent activity summary
    echo "Recent Activity (last 20 entries):"
    echo "$LOG_DATA" | tail -20
    echo ""
}

# Generate summary statistics
generate_stats() {
    local total_lines=$(echo "$LOG_DATA" | wc -l)
    local error_lines=$(echo "$LOG_DATA" | grep -c -E 'ERROR|FATAL' || echo "0")
    local warn_lines=$(echo "$LOG_DATA" | grep -c 'WARN' || echo "0")
    local info_lines=$(echo "$LOG_DATA" | grep -c 'INFO' || echo "0")
    
    echo -e "${GREEN}=== Log Statistics ===${NC}"
    echo "Total Log Lines: $total_lines"
    echo "Error Lines: $error_lines ($(echo "scale=2; $error_lines * 100 / $total_lines" | bc 2>/dev/null || echo "0")%)"
    echo "Warning Lines: $warn_lines ($(echo "scale=2; $warn_lines * 100 / $total_lines" | bc 2>/dev/null || echo "0")%)"
    echo "Info Lines: $info_lines ($(echo "scale=2; $info_lines * 100 / $total_lines" | bc 2>/dev/null || echo "0")%)"
    echo ""
    
    # Time range analysis
    local first_line=$(echo "$LOG_DATA" | head -1)
    local last_line=$(echo "$LOG_DATA" | tail -1)
    
    echo "Log Time Range:"
    echo "First Entry: $(echo "$first_line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1 || echo "Unknown")"
    echo "Last Entry: $(echo "$last_line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1 || echo "Unknown")"
    echo ""
}

# Generate JSON output
generate_json() {
    local total_lines=$(echo "$LOG_DATA" | wc -l)
    local error_lines=$(echo "$LOG_DATA" | grep -c -E 'ERROR|FATAL' || echo "0")
    local warn_lines=$(echo "$LOG_DATA" | grep -c 'WARN' || echo "0")
    
    cat << EOF
{
    "analysis_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "container_name": "$CONTAINER_NAME",
    "log_lines_analyzed": $total_lines,
    "statistics": {
        "total_lines": $total_lines,
        "error_count": $error_lines,
        "warning_count": $warn_lines,
        "error_percentage": $(echo "scale=2; $error_lines * 100 / $total_lines" | bc 2>/dev/null || echo "0")
    },
    "top_errors": $(echo "$LOG_DATA" | grep -E 'ERROR|FATAL' | sed 's/^.*ERROR/ERROR/' | sed 's/^.*FATAL/FATAL/' | sort | uniq -c | sort -nr | head -5 | jq -R -s 'split("\n")[:-1] | map(split(" ") | {count: .[0], message: (.[1:] | join(" "))})' 2>/dev/null || echo "[]"),
    "recent_errors": $(echo "$LOG_DATA" | grep -E 'ERROR|FATAL' | tail -5 | jq -R -s 'split("\n")[:-1]' 2>/dev/null || echo "[]"),
    "recommendations": []
}
EOF
}

# Main analysis function
perform_analysis() {
    case $OUTPUT_FORMAT in
        "summary")
            echo "=== GitHub Actions Runner Log Analysis Report ==="
            echo "Generated: $(date)"
            echo "Container: $CONTAINER_NAME"
            echo "Lines Analyzed: $(echo "$LOG_DATA" | wc -l)"
            echo ""
            
            generate_stats
            analyze_errors
            
            if [ "${PERFORMANCE_FOCUS:-false}" = true ]; then
                analyze_performance
            fi
            
            if [ "${NETWORK_FOCUS:-false}" = true ]; then
                analyze_network
            fi
            
            analyze_security
            ;;
            
        "detailed")
            echo "=== Detailed GitHub Actions Runner Log Analysis ==="
            echo "Generated: $(date)"
            echo "Container: $CONTAINER_NAME"
            echo ""
            
            generate_stats
            analyze_errors
            analyze_performance
            analyze_network
            analyze_security
            analyze_activity
            ;;
            
        "json")
            generate_json
            ;;
            
        *)
            log_error "Invalid output format: $OUTPUT_FORMAT"
            exit 1
            ;;
    esac
}

# Output redirection
if [ -n "${OUTPUT_FILE:-}" ]; then
    log_info "Writing analysis to: $OUTPUT_FILE"
    perform_analysis > "$OUTPUT_FILE"
    log_info "Analysis complete. Results saved to: $OUTPUT_FILE"
else
    perform_analysis
fi

# Provide recommendations based on analysis
if [ "$OUTPUT_FORMAT" != "json" ] && [ -z "${OUTPUT_FILE:-}" ]; then
    echo ""
    echo -e "${YELLOW}=== Recommendations ===${NC}"
    
    local error_count=$(echo "$LOG_DATA" | grep -c -E 'ERROR|FATAL' || echo "0")
    local warn_count=$(echo "$LOG_DATA" | grep -c 'WARN' || echo "0")
    
    if [ "$error_count" -gt 10 ]; then
        echo "⚠️  High error count detected ($error_count errors). Consider:"
        echo "   - Checking container health: ./scripts/health-check.sh"
        echo "   - Reviewing configuration: ./config/validate-config.sh"
        echo "   - Restarting services: ./scripts/restart.sh"
    fi
    
    if [ "$warn_count" -gt 20 ]; then
        echo "⚠️  High warning count ($warn_count warnings). Review configuration."
    fi
    
    if echo "$LOG_DATA" | grep -q -i "out of memory\|oom"; then
        echo "💾 Memory issues detected. Consider increasing container memory limits."
    fi
    
    if echo "$LOG_DATA" | grep -q -i "connection.*failed\|timeout"; then
        echo "🌐 Network connectivity issues detected. Check:"
        echo "   - Network configuration: ./config/network-config.yml"
        echo "   - Firewall settings"
        echo "   - DNS resolution"
    fi
    
    if echo "$LOG_DATA" | grep -q -i "token\|auth.*fail"; then
        echo "🔐 Authentication issues detected. Verify:"
        echo "   - GitHub token validity: ./config/token-manager.sh verify"
        echo "   - Token permissions"
    fi
    
    echo ""
    echo "For more detailed troubleshooting, see: $PROJECT_ROOT/TROUBLESHOOTING.md"
fi