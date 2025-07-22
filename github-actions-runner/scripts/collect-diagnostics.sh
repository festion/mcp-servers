#!/bin/bash
# GitHub Actions Runner Diagnostic Information Collector
# Collects comprehensive diagnostic information for troubleshooting

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DIAG_DIR="$PROJECT_ROOT/diagnostics/$(date +%Y%m%d_%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create diagnostics directory
mkdir -p "$DIAG_DIR"

log_info "Collecting diagnostic information to: $DIAG_DIR"

# System information
log_info "Collecting system information..."
{
    echo "=== System Information ==="
    uname -a
    echo ""
    echo "=== Date/Time ==="
    date
    echo ""
    echo "=== Uptime ==="
    uptime
    echo ""
    echo "=== Disk Usage ==="
    df -h
    echo ""
    echo "=== Memory Usage ==="
    free -h
    echo ""
    echo "=== CPU Information ==="
    lscpu 2>/dev/null || echo "lscpu not available"
    echo ""
    echo "=== Network Interfaces ==="
    ip addr show 2>/dev/null || ifconfig 2>/dev/null || echo "Network info not available"
} > "$DIAG_DIR/system-info.txt" 2>&1

# Docker information
log_info "Collecting Docker information..."
if command -v docker >/dev/null 2>&1; then
    {
        echo "=== Docker Version ==="
        docker version
        echo ""
        echo "=== Docker Info ==="
        docker info
        echo ""
        echo "=== Docker Containers ==="
        docker ps -a
        echo ""
        echo "=== Docker Images ==="
        docker images
        echo ""
        echo "=== Docker Networks ==="
        docker network ls
        echo ""
        echo "=== Docker Volumes ==="
        docker volume ls
        echo ""
        echo "=== Docker System Usage ==="
        docker system df
    } > "$DIAG_DIR/docker-info.txt" 2>&1
else
    echo "Docker not available" > "$DIAG_DIR/docker-info.txt"
fi

# Docker Compose information
log_info "Collecting Docker Compose information..."
if command -v docker-compose >/dev/null 2>&1; then
    {
        echo "=== Docker Compose Version ==="
        docker-compose version
        echo ""
        echo "=== Docker Compose Services ==="
        cd "$PROJECT_ROOT"
        docker-compose ps
        echo ""
        echo "=== Docker Compose Configuration ==="
        docker-compose config
    } > "$DIAG_DIR/docker-compose-info.txt" 2>&1
else
    echo "Docker Compose not available" > "$DIAG_DIR/docker-compose-info.txt"
fi

# Resource usage
log_info "Collecting resource usage..."
if command -v docker >/dev/null 2>&1; then
    {
        echo "=== Container Resource Usage ==="
        docker stats --no-stream
        echo ""
        echo "=== Process List ==="
        ps aux | head -20
    } > "$DIAG_DIR/resources.txt" 2>&1
fi

# Container logs
log_info "Collecting container logs..."
if command -v docker >/dev/null 2>&1; then
    # GitHub Runner logs
    if docker ps | grep -q github-runner; then
        docker logs github-runner > "$DIAG_DIR/runner-logs.txt" 2>&1 || echo "Failed to collect runner logs" > "$DIAG_DIR/runner-logs.txt"
    else
        echo "GitHub runner container not running" > "$DIAG_DIR/runner-logs.txt"
    fi
    
    # Nginx logs
    if docker ps | grep -q nginx; then
        docker logs github-runner-nginx > "$DIAG_DIR/nginx-logs.txt" 2>&1 || echo "Failed to collect nginx logs" > "$DIAG_DIR/nginx-logs.txt"
    else
        echo "Nginx container not running" > "$DIAG_DIR/nginx-logs.txt"
    fi
    
    # Prometheus logs
    if docker ps | grep -q prometheus; then
        docker logs github-runner-prometheus > "$DIAG_DIR/prometheus-logs.txt" 2>&1 || echo "Failed to collect prometheus logs" > "$DIAG_DIR/prometheus-logs.txt"
    else
        echo "Prometheus container not running" > "$DIAG_DIR/prometheus-logs.txt"
    fi
fi

# Configuration files
log_info "Collecting configuration files..."
if [ -d "$PROJECT_ROOT/config" ]; then
    cp -r "$PROJECT_ROOT/config" "$DIAG_DIR/" 2>/dev/null || log_warn "Failed to copy config directory"
    
    # Sanitize sensitive information
    if [ -f "$DIAG_DIR/config/runner.env" ]; then
        sed -i 's/GITHUB_TOKEN=.*/GITHUB_TOKEN=***REDACTED***/g' "$DIAG_DIR/config/runner.env"
        sed -i 's/REGISTRATION_TOKEN=.*/REGISTRATION_TOKEN=***REDACTED***/g' "$DIAG_DIR/config/runner.env"
    fi
fi

# Copy docker-compose files
if [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
    cp "$PROJECT_ROOT/docker-compose.yml" "$DIAG_DIR/"
fi

if [ -f "$PROJECT_ROOT/.env" ]; then
    cp "$PROJECT_ROOT/.env" "$DIAG_DIR/"
    # Sanitize sensitive information
    sed -i 's/.*TOKEN=.*/&***REDACTED***/g' "$DIAG_DIR/.env"
    sed -i 's/.*PASSWORD=.*/&***REDACTED***/g' "$DIAG_DIR/.env"
fi

# Network diagnostics
log_info "Collecting network diagnostics..."
{
    echo "=== Network Connectivity Test ==="
    echo "Testing GitHub connectivity..."
    curl -I https://github.com --connect-timeout 10 2>&1 || echo "GitHub connection failed"
    echo ""
    echo "Testing GitHub API connectivity..."
    curl -I https://api.github.com --connect-timeout 10 2>&1 || echo "GitHub API connection failed"
    echo ""
    echo "=== DNS Resolution ==="
    nslookup github.com 2>&1 || echo "DNS resolution failed"
    echo ""
    nslookup api.github.com 2>&1 || echo "DNS resolution failed"
    echo ""
    echo "=== Network Routes ==="
    ip route show 2>/dev/null || route -n 2>/dev/null || echo "Route info not available"
    echo ""
    echo "=== Active Connections ==="
    netstat -tlnp 2>/dev/null | head -20 || ss -tlnp 2>/dev/null | head -20 || echo "Connection info not available"
} > "$DIAG_DIR/network-diagnostics.txt" 2>&1

# Application logs
log_info "Collecting application logs..."
if [ -d "$PROJECT_ROOT/logs" ]; then
    mkdir -p "$DIAG_DIR/logs"
    cp -r "$PROJECT_ROOT/logs"/* "$DIAG_DIR/logs/" 2>/dev/null || log_warn "Failed to copy application logs"
fi

# Security information
log_info "Collecting security information..."
{
    echo "=== File Permissions ==="
    ls -la "$PROJECT_ROOT" 2>/dev/null || echo "Permission listing failed"
    echo ""
    echo "=== Running Processes ==="
    ps aux | grep -E '(docker|runner|nginx)' | grep -v grep
    echo ""
    echo "=== Open Files ==="
    lsof -i :80 -i :443 -i :9090 2>/dev/null || echo "lsof not available"
} > "$DIAG_DIR/security-info.txt" 2>&1

# Environment information
log_info "Collecting environment information..."
{
    echo "=== Environment Variables ==="
    env | grep -E '^(DOCKER|COMPOSE|GITHUB|PATH|HOME|USER)' | sort
    echo ""
    echo "=== Shell Information ==="
    echo "Shell: $SHELL"
    echo "User: $(whoami)"
    echo "Working Directory: $(pwd)"
} > "$DIAG_DIR/environment.txt" 2>&1

# Health check results
log_info "Running health checks..."
if [ -f "$PROJECT_ROOT/scripts/health-check.sh" ]; then
    "$PROJECT_ROOT/scripts/health-check.sh" > "$DIAG_DIR/health-check.txt" 2>&1 || echo "Health check failed" > "$DIAG_DIR/health-check.txt"
else
    echo "Health check script not found" > "$DIAG_DIR/health-check.txt"
fi

# Configuration validation
log_info "Validating configuration..."
if [ -f "$PROJECT_ROOT/config/validate-config.sh" ]; then
    "$PROJECT_ROOT/config/validate-config.sh" > "$DIAG_DIR/config-validation.txt" 2>&1 || echo "Config validation failed" > "$DIAG_DIR/config-validation.txt"
else
    echo "Config validation script not found" > "$DIAG_DIR/config-validation.txt"
fi

# Create summary report
log_info "Creating summary report..."
{
    echo "=== GitHub Actions Runner Diagnostic Summary ==="
    echo "Generated: $(date)"
    echo "Hostname: $(hostname)"
    echo "User: $(whoami)"
    echo ""
    echo "=== System Status ==="
    echo "Uptime: $(uptime | awk '{print $3,$4}' | sed 's/,//')"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    echo "Memory Usage: $(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
    echo "Disk Usage: $(df / | awk 'NR==2{print $5}')"
    echo ""
    echo "=== Docker Status ==="
    if command -v docker >/dev/null 2>&1; then
        echo "Docker Version: $(docker --version)"
        echo "Running Containers: $(docker ps --format 'table {{.Names}}\t{{.Status}}' | tail -n +2 | wc -l)"
        echo "Container Status:"
        docker ps --format 'table {{.Names}}\t{{.Status}}' | tail -n +2 || echo "No containers running"
    else
        echo "Docker not available"
    fi
    echo ""
    echo "=== Recent Errors ==="
    if [ -f "$DIAG_DIR/runner-logs.txt" ]; then
        echo "Recent Runner Errors:"
        grep -E 'ERROR|FATAL' "$DIAG_DIR/runner-logs.txt" | tail -5 || echo "No recent errors found"
    fi
    echo ""
    echo "=== Recommendations ==="
    # Basic recommendations based on collected data
    memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ "$memory_usage" -gt 90 ]; then
        echo "⚠️  High memory usage detected ($memory_usage%). Consider restarting services."
    fi
    
    disk_usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        echo "⚠️  High disk usage detected ($disk_usage%). Clean up disk space."
    fi
    
    if ! command -v docker >/dev/null 2>&1; then
        echo "❌ Docker not available. Check Docker installation."
    fi
    
    echo ""
    echo "=== Files Collected ==="
    find "$DIAG_DIR" -type f -exec basename {} \; | sort
} > "$DIAG_DIR/summary.txt"

# Create archive
log_info "Creating diagnostic archive..."
cd "$(dirname "$DIAG_DIR")"
ARCHIVE_NAME="$(basename "$DIAG_DIR").tar.gz"
tar czf "$ARCHIVE_NAME" "$(basename "$DIAG_DIR")" 2>/dev/null

if [ $? -eq 0 ]; then
    log_info "Diagnostic archive created: $(dirname "$DIAG_DIR")/$ARCHIVE_NAME"
    log_info "Archive size: $(du -h "$(dirname "$DIAG_DIR")/$ARCHIVE_NAME" | cut -f1)"
else
    log_error "Failed to create diagnostic archive"
fi

# Cleanup option
echo ""
read -p "Remove uncompressed diagnostic directory? [y/N]: " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$DIAG_DIR"
    log_info "Uncompressed directory removed"
fi

log_info "Diagnostic collection complete!"
echo ""
echo "Next steps:"
echo "1. Review the summary: cat $DIAG_DIR/summary.txt"
echo "2. Share the archive with support team: $ARCHIVE_NAME"
echo "3. Check the troubleshooting guide: $PROJECT_ROOT/TROUBLESHOOTING.md"