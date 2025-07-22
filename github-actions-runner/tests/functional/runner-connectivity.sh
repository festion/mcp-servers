#!/bin/bash

# GitHub Actions Runner - Connectivity Tests
# Tests for runner registration, GitHub API connectivity, and network access

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/test-framework.sh"

# Test configuration
RUNNER_DIR="${RUNNER_DIR:-/opt/github-actions-runner}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
TEST_REPO="${TEST_REPO:-}"

# Initialize test framework
init_test_framework "Runner Connectivity Tests"

# Test: GitHub API connectivity
test_github_api_connectivity() {
    log_info "Testing GitHub API connectivity"
    
    if [[ -z "$GITHUB_TOKEN" ]]; then
        echo "GITHUB_TOKEN not set, skipping API connectivity test"
        return 1
    fi
    
    local response
    response=$(github_api_request "/user" "GET")
    
    assert_contains "$response" "login" "GitHub API response should contain login field"
    assert_not_contains "$response" "message" "GitHub API response should not contain error message"
    
    echo "GitHub API connectivity: OK"
}

# Test: GitHub API rate limits
test_github_api_rate_limits() {
    log_info "Testing GitHub API rate limits"
    
    if [[ -z "$GITHUB_TOKEN" ]]; then
        echo "GITHUB_TOKEN not set, skipping rate limit test"
        return 1
    fi
    
    local response
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                    -H "Accept: application/vnd.github.v3+json" \
                    -I "https://api.github.com/rate_limit")
    
    assert_contains "$response" "X-RateLimit-Limit" "Response should contain rate limit header"
    assert_contains "$response" "X-RateLimit-Remaining" "Response should contain remaining requests header"
    
    local remaining
    remaining=$(echo "$response" | grep -i "X-RateLimit-Remaining" | cut -d' ' -f2 | tr -d '\r')
    
    if [[ "$remaining" -lt 100 ]]; then
        log_warn "Low API rate limit remaining: $remaining"
    fi
    
    echo "GitHub API rate limits: OK (remaining: $remaining)"
}

# Test: Runner service status
test_runner_service_status() {
    log_info "Testing runner service status"
    
    assert_command_success "systemctl is-active github-runner.service" \
        "GitHub runner service should be active"
    
    assert_command_success "systemctl is-enabled github-runner.service" \
        "GitHub runner service should be enabled"
    
    echo "Runner service status: OK"
}

# Test: Runner registration status
test_runner_registration() {
    log_info "Testing runner registration status"
    
    assert_directory_exists "$RUNNER_DIR" "Runner directory should exist"
    assert_file_exists "$RUNNER_DIR/.runner" "Runner configuration file should exist"
    assert_file_exists "$RUNNER_DIR/.credentials" "Runner credentials file should exist"
    
    # Check if runner is online (if we have repo access)
    if [[ -n "$GITHUB_TOKEN" ]] && [[ -n "$TEST_REPO" ]]; then
        local runners_response
        runners_response=$(github_api_request "/repos/$TEST_REPO/actions/runners" "GET")
        
        local runner_name
        runner_name=$(hostname)
        
        if echo "$runners_response" | jq -r '.runners[].name' | grep -q "$runner_name"; then
            echo "Runner is registered and visible in GitHub: $runner_name"
        else
            log_warn "Runner not found in GitHub runners list"
        fi
    fi
    
    echo "Runner registration: OK"
}

# Test: Network connectivity to GitHub
test_github_network_connectivity() {
    log_info "Testing network connectivity to GitHub"
    
    # Test DNS resolution
    assert_command_success "nslookup github.com" "Should be able to resolve github.com"
    assert_command_success "nslookup api.github.com" "Should be able to resolve api.github.com"
    
    # Test HTTPS connectivity
    assert_port_open "github.com" "443" "HTTPS port should be accessible on github.com"
    assert_port_open "api.github.com" "443" "HTTPS port should be accessible on api.github.com"
    
    # Test HTTP response
    assert_url_accessible "https://github.com" "200" "GitHub main site should be accessible"
    assert_url_accessible "https://api.github.com" "200" "GitHub API should be accessible"
    
    echo "GitHub network connectivity: OK"
}

# Test: Runner configuration validation
test_runner_configuration() {
    log_info "Testing runner configuration"
    
    if [[ -f "$RUNNER_DIR/.runner" ]]; then
        local config
        config=$(cat "$RUNNER_DIR/.runner")
        
        assert_contains "$config" "gitHubUrl" "Runner config should contain GitHub URL"
        assert_contains "$config" "agentId" "Runner config should contain agent ID"
        assert_contains "$config" "agentName" "Runner config should contain agent name"
        
        # Validate JSON format
        assert_command_success "jq . '$RUNNER_DIR/.runner'" "Runner config should be valid JSON"
    else
        echo "Runner configuration file not found, skipping validation"
        return 1
    fi
    
    echo "Runner configuration: OK"
}

# Test: Private network access (homelab specific)
test_private_network_access() {
    log_info "Testing private network access"
    
    # Test access to homelab services
    local homelab_services=(
        "192.168.1.155:8123"  # Home Assistant
        "192.168.1.137:8006"  # Proxmox
        "192.168.1.90:3000"   # WikiJS
    )
    
    for service in "${homelab_services[@]}"; do
        local host port
        IFS=':' read -r host port <<< "$service"
        
        if wait_for_port "$host" "$port" 5; then
            echo "Private network access to $service: OK"
        else
            log_warn "Cannot access private service: $service"
        fi
    done
    
    echo "Private network access tests completed"
}

# Test: Runner working directory permissions
test_runner_permissions() {
    log_info "Testing runner permissions"
    
    local runner_user="${RUNNER_USER:-github-runner}"
    
    # Check ownership
    if [[ -d "$RUNNER_DIR" ]]; then
        local owner
        owner=$(stat -c %U "$RUNNER_DIR")
        assert_equals "$runner_user" "$owner" "Runner directory should be owned by $runner_user"
    fi
    
    # Check working directory
    local work_dir="$RUNNER_DIR/_work"
    if [[ -d "$work_dir" ]]; then
        assert_command_success "sudo -u $runner_user test -w '$work_dir'" \
            "Runner user should have write access to work directory"
    fi
    
    # Check script permissions
    if [[ -f "$RUNNER_DIR/run.sh" ]]; then
        assert_command_success "test -x '$RUNNER_DIR/run.sh'" \
            "Runner script should be executable"
    fi
    
    echo "Runner permissions: OK"
}

# Test: Runner logs accessibility
test_runner_logs() {
    log_info "Testing runner logs"
    
    # Check systemd logs
    assert_command_success "journalctl -u github-runner.service --no-pager -n 10" \
        "Should be able to access runner service logs"
    
    # Check application logs
    local log_file="/var/log/github-runner/runner.log"
    if [[ -f "$log_file" ]]; then
        assert_file_exists "$log_file" "Runner log file should exist"
        assert_command_success "tail -n 5 '$log_file'" "Should be able to read runner logs"
    fi
    
    echo "Runner logs: OK"
}

# Test: Container runtime (if using Docker)
test_container_runtime() {
    log_info "Testing container runtime"
    
    if command -v docker >/dev/null 2>&1; then
        assert_command_success "docker --version" "Docker should be installed and accessible"
        assert_command_success "docker info" "Docker daemon should be running"
        
        # Test if runner user can access Docker
        local runner_user="${RUNNER_USER:-github-runner}"
        if getent group docker | grep -q "$runner_user"; then
            assert_command_success "sudo -u $runner_user docker ps" \
                "Runner user should be able to access Docker"
        else
            log_warn "Runner user is not in docker group"
        fi
        
        echo "Container runtime: OK"
    else
        echo "Docker not installed, skipping container runtime tests"
        return 0
    fi
}

# Test: Resource availability
test_resource_availability() {
    log_info "Testing resource availability"
    
    # Check available memory
    local memory_kb
    memory_kb=$(free | awk 'NR==2{print $7}')
    local memory_mb=$((memory_kb / 1024))
    
    if [[ $memory_mb -lt 500 ]]; then
        log_warn "Low available memory: ${memory_mb}MB"
    else
        echo "Available memory: ${memory_mb}MB"
    fi
    
    # Check disk space
    local disk_usage
    disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ $disk_usage -gt 90 ]]; then
        log_warn "High disk usage: ${disk_usage}%"
    else
        echo "Disk usage: ${disk_usage}%"
    fi
    
    # Check CPU load
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | xargs)
    echo "CPU load average: $load_avg"
    
    echo "Resource availability: OK"
}

# Main test execution
main() {
    setup_test_environment
    
    # Run connectivity tests
    run_test "github_api_connectivity" "test_github_api_connectivity" \
        "Test GitHub API connectivity and authentication"
    
    run_test "github_api_rate_limits" "test_github_api_rate_limits" \
        "Check GitHub API rate limit status"
    
    run_test "runner_service_status" "test_runner_service_status" \
        "Verify runner service is active and enabled"
    
    run_test "runner_registration" "test_runner_registration" \
        "Validate runner registration and configuration"
    
    run_test "github_network_connectivity" "test_github_network_connectivity" \
        "Test network connectivity to GitHub services"
    
    run_test "runner_configuration" "test_runner_configuration" \
        "Validate runner configuration file"
    
    run_test "private_network_access" "test_private_network_access" \
        "Test access to private homelab services"
    
    run_test "runner_permissions" "test_runner_permissions" \
        "Verify runner directory and file permissions"
    
    run_test "runner_logs" "test_runner_logs" \
        "Check runner log accessibility"
    
    run_test "container_runtime" "test_container_runtime" \
        "Test container runtime availability"
    
    run_test "resource_availability" "test_resource_availability" \
        "Check system resource availability"
    
    cleanup_test_environment
    finalize_test_framework
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi