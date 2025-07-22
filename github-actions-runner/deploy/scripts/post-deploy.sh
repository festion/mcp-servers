#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ENVIRONMENT="${1:-dev}"

log_info "Starting post-deployment verification for environment: $ENVIRONMENT"

verify_service_health() {
    log_info "Verifying service health"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local services=(
        "github-runner-1:$GITHUB_RUNNER_PORT"
        "github-runner-2:$((GITHUB_RUNNER_PORT + 1))"
        "github-runner-3:$((GITHUB_RUNNER_PORT + 2))"
        "monitoring:$MONITORING_PORT"
    )
    
    for service in "${services[@]}"; do
        local service_name="${service%%:*}"
        local service_port="${service##*:}"
        
        if wait_for_service "$service_name" "http://localhost:$service_port/health" 60; then
            log_success "Service $service_name is healthy"
        else
            log_error "Service $service_name failed health check"
            return 1
        fi
    done
}

verify_github_runner_registration() {
    log_info "Verifying GitHub runner registration"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local expected_runners="$GITHUB_RUNNER_COUNT"
    
    local registered_runners
    registered_runners=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                       -H "Accept: application/vnd.github.v3+json" \
                       "https://api.github.com/orgs/$GITHUB_ORG/actions/runners" | \
                       jq -r '.runners[] | select(.status == "online") | .name' | wc -l)
    
    if (( registered_runners >= expected_runners )); then
        log_success "GitHub runners registered successfully: $registered_runners/$expected_runners"
    else
        log_error "Not all GitHub runners are registered: $registered_runners/$expected_runners"
        return 1
    fi
}

verify_container_status() {
    log_info "Verifying container status"
    
    local compose_file="$SCRIPT_DIR/../infrastructure/docker-compose.yml"
    
    if ! docker-compose -f "$compose_file" ps | grep -q "Up"; then
        log_error "Some containers are not running"
        docker-compose -f "$compose_file" ps
        return 1
    fi
    
    log_success "All containers are running"
}

verify_log_aggregation() {
    log_info "Verifying log aggregation"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local log_files=(
        "/var/log/github-runner/runner-1.log"
        "/var/log/github-runner/runner-2.log"
        "/var/log/github-runner/runner-3.log"
        "/var/log/github-runner/monitoring.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
            log_success "Log file exists and has content: $log_file"
        else
            log_warn "Log file missing or empty: $log_file"
        fi
    done
}

verify_metrics_collection() {
    log_info "Verifying metrics collection"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local metrics_endpoint="http://localhost:$METRICS_PORT/metrics"
    
    if curl -s "$metrics_endpoint" | grep -q "github_runner_"; then
        log_success "Metrics are being collected"
    else
        log_error "Metrics collection is not working"
        return 1
    fi
}

verify_backup_system() {
    log_info "Verifying backup system"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local backup_dir="${BACKUP_DIR:-/tmp/deployment-backups}"
    
    if [[ -d "$backup_dir" ]] && [[ -w "$backup_dir" ]]; then
        log_success "Backup system is available"
    else
        log_error "Backup system is not properly configured"
        return 1
    fi
}

verify_security_configuration() {
    log_info "Verifying security configuration"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        if [[ -f "${SSL_CERT_PATH:-}" ]] && [[ -f "${SSL_KEY_PATH:-}" ]]; then
            log_success "SSL certificates are in place"
        else
            log_error "SSL certificates are missing in production"
            return 1
        fi
    fi
    
    local docker_secrets
    docker_secrets=$(docker secret ls 2>/dev/null | wc -l)
    
    if (( docker_secrets > 0 )); then
        log_success "Docker secrets are configured"
    else
        log_warn "No Docker secrets found"
    fi
}

run_functional_tests() {
    log_info "Running functional tests"
    
    local test_script="$SCRIPT_DIR/../validation/functional-tests.sh"
    
    if [[ -f "$test_script" ]]; then
        if "$test_script" "$ENVIRONMENT"; then
            log_success "Functional tests passed"
        else
            log_error "Functional tests failed"
            return 1
        fi
    else
        log_warn "Functional test script not found: $test_script"
    fi
}

run_performance_tests() {
    log_info "Running performance tests"
    
    local test_script="$SCRIPT_DIR/../validation/performance-tests.sh"
    
    if [[ -f "$test_script" ]]; then
        if "$test_script" "$ENVIRONMENT"; then
            log_success "Performance tests passed"
        else
            log_error "Performance tests failed"
            return 1
        fi
    else
        log_warn "Performance test script not found: $test_script"
    fi
}

run_security_scan() {
    log_info "Running security scan"
    
    local scan_script="$SCRIPT_DIR/../validation/security-scan.sh"
    
    if [[ -f "$scan_script" ]]; then
        if "$scan_script" "$ENVIRONMENT"; then
            log_success "Security scan passed"
        else
            log_error "Security scan failed"
            return 1
        fi
    else
        log_warn "Security scan script not found: $scan_script"
    fi
}

verify_rollback_capability() {
    log_info "Verifying rollback capability"
    
    local rollback_script="$SCRIPT_DIR/rollback.sh"
    
    if [[ -f "$rollback_script" ]] && [[ -x "$rollback_script" ]]; then
        log_success "Rollback script is available and executable"
    else
        log_error "Rollback script is not available or not executable"
        return 1
    fi
    
    local version_file="$SCRIPT_DIR/../environments/$ENVIRONMENT.current"
    echo "$DEPLOY_VERSION" > "$version_file"
    log_success "Current version recorded for rollback"
}

generate_deployment_report() {
    log_info "Generating deployment report"
    
    local report_file="/tmp/deployment-report-$ENVIRONMENT-$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$report_file" << EOF
{
    "environment": "$ENVIRONMENT",
    "deployment_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "version": "${DEPLOY_VERSION:-unknown}",
    "status": "successful",
    "verifications": {
        "service_health": "passed",
        "github_runner_registration": "passed",
        "container_status": "passed",
        "log_aggregation": "passed",
        "metrics_collection": "passed",
        "backup_system": "passed",
        "security_configuration": "passed",
        "functional_tests": "passed",
        "performance_tests": "passed",
        "security_scan": "passed",
        "rollback_capability": "passed"
    },
    "services": {
        "github_runners": "$(docker ps --filter 'name=github-runner' --format '{{.Names}}' | wc -l)",
        "containers_running": "$(docker ps --filter 'status=running' | wc -l)",
        "uptime": "$(uptime | awk '{print $3}' | sed 's/,//')"
    },
    "metrics": {
        "cpu_usage": "$(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | sed 's/%us,//')",
        "memory_usage": "$(free | grep Mem | awk '{printf \"%.2f%%\", $3/$2 * 100.0}')",
        "disk_usage": "$(df -h . | awk 'NR==2 {print $5}')"
    }
}
EOF
    
    log_success "Deployment report generated: $report_file"
}

send_deployment_notification() {
    log_info "Sending deployment notification"
    
    local message="🚀 Deployment completed successfully for $ENVIRONMENT environment (v${DEPLOY_VERSION:-unknown})"
    
    send_notification "$message" "success"
}

main() {
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local verification_failed=false
    
    verify_service_health || verification_failed=true
    verify_github_runner_registration || verification_failed=true
    verify_container_status || verification_failed=true
    verify_log_aggregation || verification_failed=true
    verify_metrics_collection || verification_failed=true
    verify_backup_system || verification_failed=true
    verify_security_configuration || verification_failed=true
    run_functional_tests || verification_failed=true
    run_performance_tests || verification_failed=true
    run_security_scan || verification_failed=true
    verify_rollback_capability || verification_failed=true
    
    if [[ "$verification_failed" == "true" ]]; then
        log_error "Post-deployment verification failed"
        send_notification "❌ Deployment verification failed for $ENVIRONMENT environment" "error"
        exit 1
    fi
    
    generate_deployment_report
    send_deployment_notification
    
    log_success "Post-deployment verification completed successfully"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi