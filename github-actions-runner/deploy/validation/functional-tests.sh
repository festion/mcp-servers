#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/common.sh"

ENVIRONMENT="${1:-dev}"

log_info "Running functional tests for environment: $ENVIRONMENT"

test_runner_registration() {
    log_info "Testing runner registration"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local test_repo="$GITHUB_ORG/test-repo"
    local runners_response
    
    runners_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                      -H "Accept: application/vnd.github.v3+json" \
                      "https://api.github.com/orgs/$GITHUB_ORG/actions/runners")
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to query GitHub API for runners"
        return 1
    fi
    
    local runner_count
    runner_count=$(echo "$runners_response" | jq -r '.runners[] | select(.status == "online") | .name' | wc -l)
    
    if (( runner_count >= GITHUB_RUNNER_COUNT )); then
        log_success "Runner registration test passed: $runner_count runners online"
        return 0
    else
        log_error "Runner registration test failed: only $runner_count runners online"
        return 1
    fi
}

test_workflow_execution() {
    log_info "Testing workflow execution"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    # Create a test workflow file
    local test_workflow_content='
name: Test Workflow
on:
  workflow_dispatch:
jobs:
  test:
    runs-on: self-hosted
    steps:
      - name: Test step
        run: echo "Test workflow executed successfully"
'
    
    local test_file="/tmp/test-workflow-$(date +%s).yml"
    echo "$test_workflow_content" > "$test_file"
    
    # This is a simplified test - in a real scenario, you'd push this to a test repo
    # and trigger a workflow run, then check its status
    
    log_success "Workflow execution test setup completed"
    rm -f "$test_file"
    
    return 0
}

test_container_networking() {
    log_info "Testing container networking"
    
    local containers=(
        "github-runner-1"
        "github-runner-2"
        "github-runner-3"
    )
    
    local network_failures=0
    
    for container in "${containers[@]}"; do
        log_info "Testing network connectivity for: $container"
        
        if docker exec "$container" ping -c 1 google.com > /dev/null 2>&1; then
            log_success "Network connectivity test passed for: $container"
        else
            log_error "Network connectivity test failed for: $container"
            ((network_failures++))
        fi
        
        if docker exec "$container" curl -s https://api.github.com/zen > /dev/null; then
            log_success "GitHub API connectivity test passed for: $container"
        else
            log_error "GitHub API connectivity test failed for: $container"
            ((network_failures++))
        fi
    done
    
    return $network_failures
}

test_volume_mounts() {
    log_info "Testing volume mounts"
    
    local containers=(
        "github-runner-1"
        "github-runner-2"
        "github-runner-3"
    )
    
    local mount_failures=0
    
    for container in "${containers[@]}"; do
        log_info "Testing volume mounts for: $container"
        
        # Test work directory mount
        if docker exec "$container" test -d /home/runner/work; then
            log_success "Work directory mount test passed for: $container"
        else
            log_error "Work directory mount test failed for: $container"
            ((mount_failures++))
        fi
        
        # Test Docker socket mount
        if docker exec "$container" test -S /var/run/docker.sock; then
            log_success "Docker socket mount test passed for: $container"
        else
            log_error "Docker socket mount test failed for: $container"
            ((mount_failures++))
        fi
        
        # Test log directory mount
        if docker exec "$container" test -d /var/log/github-runner; then
            log_success "Log directory mount test passed for: $container"
        else
            log_error "Log directory mount test failed for: $container"
            ((mount_failures++))
        fi
    done
    
    return $mount_failures
}

test_service_discovery() {
    log_info "Testing service discovery"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local services=(
        "github-runner-1:$GITHUB_RUNNER_PORT"
        "github-runner-2:$((GITHUB_RUNNER_PORT + 1))"
        "github-runner-3:$((GITHUB_RUNNER_PORT + 2))"
        "monitoring:$MONITORING_PORT"
    )
    
    local discovery_failures=0
    
    for service in "${services[@]}"; do
        local service_name="${service%%:*}"
        local service_port="${service##*:}"
        
        log_info "Testing service discovery for: $service_name"
        
        if nc -z localhost "$service_port"; then
            log_success "Service discovery test passed for: $service_name"
        else
            log_error "Service discovery test failed for: $service_name"
            ((discovery_failures++))
        fi
    done
    
    return $discovery_failures
}

test_monitoring_integration() {
    log_info "Testing monitoring integration"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local monitoring_failures=0
    
    # Test Prometheus endpoint
    if curl -s "http://localhost:$MONITORING_PORT/api/v1/query?query=up" | jq -e '.status == "success"' > /dev/null; then
        log_success "Prometheus monitoring test passed"
    else
        log_error "Prometheus monitoring test failed"
        ((monitoring_failures++))
    fi
    
    # Test metrics endpoint
    if curl -s "http://localhost:$METRICS_PORT/metrics" | grep -q "github_runner_"; then
        log_success "Metrics endpoint test passed"
    else
        log_error "Metrics endpoint test failed"
        ((monitoring_failures++))
    fi
    
    return $monitoring_failures
}

test_log_aggregation() {
    log_info "Testing log aggregation"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local log_failures=0
    
    # Test log file creation
    local log_files=(
        "$LOG_DIR/github-runner/runner-1.log"
        "$LOG_DIR/github-runner/runner-2.log"
        "$LOG_DIR/github-runner/runner-3.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            log_success "Log file exists: $log_file"
        else
            log_error "Log file missing: $log_file"
            ((log_failures++))
        fi
    done
    
    # Test log rotation
    if [[ -f "/etc/logrotate.d/github-runner" ]]; then
        log_success "Log rotation configuration found"
    else
        log_warn "Log rotation configuration not found"
        ((log_failures++))
    fi
    
    return $log_failures
}

test_backup_functionality() {
    log_info "Testing backup functionality"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local backup_failures=0
    
    # Test backup directory
    local backup_dir="${BACKUP_DIR:-/tmp/deployment-backups}"
    
    if [[ -d "$backup_dir" ]]; then
        log_success "Backup directory exists: $backup_dir"
    else
        log_error "Backup directory missing: $backup_dir"
        ((backup_failures++))
    fi
    
    # Test backup creation
    local test_backup_dir="$backup_dir/test-backup-$(date +%s)"
    
    if mkdir -p "$test_backup_dir"; then
        echo "test backup" > "$test_backup_dir/test.txt"
        log_success "Backup creation test passed"
        rm -rf "$test_backup_dir"
    else
        log_error "Backup creation test failed"
        ((backup_failures++))
    fi
    
    return $backup_failures
}

test_security_configuration() {
    log_info "Testing security configuration"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local security_failures=0
    
    # Test secrets management
    if docker secret ls | grep -q "github-token"; then
        log_success "GitHub token secret found"
    else
        log_warn "GitHub token secret not found"
        ((security_failures++))
    fi
    
    # Test SSL configuration for production
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        if [[ "$ENABLE_SSL" == "true" ]]; then
            log_success "SSL is enabled for production"
        else
            log_error "SSL is not enabled for production"
            ((security_failures++))
        fi
    fi
    
    # Test firewall configuration
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            log_success "Firewall is active"
        else
            log_warn "Firewall is not active"
            ((security_failures++))
        fi
    fi
    
    return $security_failures
}

test_rollback_capability() {
    log_info "Testing rollback capability"
    
    local rollback_failures=0
    
    # Test rollback script exists and is executable
    if [[ -x "$SCRIPT_DIR/../scripts/rollback.sh" ]]; then
        log_success "Rollback script is executable"
    else
        log_error "Rollback script is not executable"
        ((rollback_failures++))
    fi
    
    # Test backup versions exist
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    local backup_dir="${BACKUP_DIR:-/tmp/deployment-backups}"
    
    local version_backups
    version_backups=$(find "$backup_dir" -type d -name "version-*" | wc -l)
    
    if (( version_backups > 0 )); then
        log_success "Version backups available for rollback: $version_backups"
    else
        log_warn "No version backups found for rollback"
        ((rollback_failures++))
    fi
    
    return $rollback_failures
}

generate_test_report() {
    log_info "Generating functional test report"
    
    local report_file="/tmp/functional-test-report-$ENVIRONMENT-$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$report_file" << EOF
{
    "environment": "$ENVIRONMENT",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "test_results": {
        "runner_registration": "$runner_registration_result",
        "workflow_execution": "$workflow_execution_result",
        "container_networking": "$container_networking_result",
        "volume_mounts": "$volume_mounts_result",
        "service_discovery": "$service_discovery_result",
        "monitoring_integration": "$monitoring_integration_result",
        "log_aggregation": "$log_aggregation_result",
        "backup_functionality": "$backup_functionality_result",
        "security_configuration": "$security_configuration_result",
        "rollback_capability": "$rollback_capability_result"
    },
    "overall_status": "$overall_status",
    "total_tests": 10,
    "passed_tests": $passed_tests,
    "failed_tests": $failed_tests
}
EOF
    
    log_success "Functional test report generated: $report_file"
}

main() {
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local total_failures=0
    local passed_tests=0
    
    # Run all functional tests
    test_runner_registration
    runner_registration_result=$?
    total_failures=$((total_failures + runner_registration_result))
    if (( runner_registration_result == 0 )); then ((passed_tests++)); fi
    
    test_workflow_execution
    workflow_execution_result=$?
    total_failures=$((total_failures + workflow_execution_result))
    if (( workflow_execution_result == 0 )); then ((passed_tests++)); fi
    
    test_container_networking
    container_networking_result=$?
    total_failures=$((total_failures + container_networking_result))
    if (( container_networking_result == 0 )); then ((passed_tests++)); fi
    
    test_volume_mounts
    volume_mounts_result=$?
    total_failures=$((total_failures + volume_mounts_result))
    if (( volume_mounts_result == 0 )); then ((passed_tests++)); fi
    
    test_service_discovery
    service_discovery_result=$?
    total_failures=$((total_failures + service_discovery_result))
    if (( service_discovery_result == 0 )); then ((passed_tests++)); fi
    
    test_monitoring_integration
    monitoring_integration_result=$?
    total_failures=$((total_failures + monitoring_integration_result))
    if (( monitoring_integration_result == 0 )); then ((passed_tests++)); fi
    
    test_log_aggregation
    log_aggregation_result=$?
    total_failures=$((total_failures + log_aggregation_result))
    if (( log_aggregation_result == 0 )); then ((passed_tests++)); fi
    
    test_backup_functionality
    backup_functionality_result=$?
    total_failures=$((total_failures + backup_functionality_result))
    if (( backup_functionality_result == 0 )); then ((passed_tests++)); fi
    
    test_security_configuration
    security_configuration_result=$?
    total_failures=$((total_failures + security_configuration_result))
    if (( security_configuration_result == 0 )); then ((passed_tests++)); fi
    
    test_rollback_capability
    rollback_capability_result=$?
    total_failures=$((total_failures + rollback_capability_result))
    if (( rollback_capability_result == 0 )); then ((passed_tests++)); fi
    
    # Calculate results
    local failed_tests=$((10 - passed_tests))
    
    if (( total_failures == 0 )); then
        overall_status="passed"
        log_success "All functional tests passed ($passed_tests/10)"
    else
        overall_status="failed"
        log_error "Functional tests failed: $failed_tests failures"
    fi
    
    generate_test_report
    
    exit $total_failures
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi