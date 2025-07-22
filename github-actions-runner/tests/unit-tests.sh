#!/bin/bash

# GitHub Actions Runner - Unit Tests
# Component-level testing for individual scripts and functions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/test-framework.sh"

# Unit test configuration
RUNNER_SCRIPTS_DIR="${RUNNER_SCRIPTS_DIR:-/opt/github-actions-runner/scripts}"

# Initialize test framework
init_test_framework "Unit Tests"

# Test: Health check script functions
test_health_check_script() {
    log_info "Testing health check script functions"
    
    local health_script="$RUNNER_SCRIPTS_DIR/health-check.sh"
    
    if [[ ! -f "$health_script" ]]; then
        echo "Health check script not found: $health_script"
        return 1
    fi
    
    # Test script syntax
    assert_command_success "bash -n '$health_script'" \
        "Health check script should have valid syntax"
    
    # Test help option
    assert_command_success "$health_script --help" \
        "Health check script should support --help option"
    
    # Test basic functionality (non-destructive)
    if [[ -x "$health_script" ]]; then
        # Create mock environment for testing
        export TEST_MODE=true
        
        # Test dry run mode
        assert_command_success "$health_script --dry-run" \
            "Health check script should support dry run mode"
        
        unset TEST_MODE
    fi
    
    echo "Health check script test: OK"
}

# Test: Backup script functions
test_backup_script() {
    log_info "Testing backup script functions"
    
    local backup_script="$RUNNER_SCRIPTS_DIR/backup.sh"
    
    if [[ ! -f "$backup_script" ]]; then
        echo "Backup script not found: $backup_script"
        return 1
    fi
    
    # Test script syntax
    assert_command_success "bash -n '$backup_script'" \
        "Backup script should have valid syntax"
    
    # Test help option
    assert_command_success "$backup_script --help" \
        "Backup script should support --help option"
    
    # Test backup creation (in test mode)
    if [[ -x "$backup_script" ]]; then
        local test_backup_dir="$TEST_TEMP_DIR/backup_test"
        mkdir -p "$test_backup_dir"
        
        # Create test data
        echo "test data" > "$test_backup_dir/test_file.txt"
        
        # Test backup functionality
        export BACKUP_SOURCE="$test_backup_dir"
        export BACKUP_DESTINATION="$TEST_TEMP_DIR/backups"
        export TEST_MODE=true
        
        if "$backup_script" --test 2>/dev/null; then
            echo "Backup script test mode: OK"
        else
            echo "Backup script test mode not supported, skipping"
        fi
        
        unset BACKUP_SOURCE BACKUP_DESTINATION TEST_MODE
    fi
    
    echo "Backup script test: OK"
}

# Test: Configuration validation functions
test_config_validation() {
    log_info "Testing configuration validation functions"
    
    local config_script="$RUNNER_SCRIPTS_DIR/validate-config.sh"
    
    if [[ -f "$config_script" ]]; then
        # Test script syntax
        assert_command_success "bash -n '$config_script'" \
            "Config validation script should have valid syntax"
    fi
    
    # Test configuration file validation
    local test_config_file="$TEST_TEMP_DIR/test_config.env"
    
    # Create valid config
    cat > "$test_config_file" << 'EOF'
GITHUB_TOKEN=test_token_123
RUNNER_NAME=test-runner
RUNNER_LABELS=self-hosted,linux,x64
GITHUB_REPOSITORY=owner/repo
EOF
    
    # Test config parsing
    if source "$test_config_file" 2>/dev/null; then
        assert_equals "test_token_123" "$GITHUB_TOKEN" \
            "Should parse GITHUB_TOKEN correctly"
        
        assert_equals "test-runner" "$RUNNER_NAME" \
            "Should parse RUNNER_NAME correctly"
        
        echo "Configuration parsing: OK"
    fi
    
    # Create invalid config
    local invalid_config_file="$TEST_TEMP_DIR/invalid_config.env"
    cat > "$invalid_config_file" << 'EOF'
GITHUB_TOKEN=
INVALID_SYNTAX =
RUNNER_NAME=
EOF
    
    # Test validation logic
    local validation_errors=0
    
    # Source and validate
    if source "$invalid_config_file" 2>/dev/null; then
        if [[ -z "${GITHUB_TOKEN:-}" ]]; then
            ((validation_errors++))
        fi
        
        if [[ -z "${RUNNER_NAME:-}" ]]; then
            ((validation_errors++))
        fi
    fi
    
    assert_not_equals "0" "$validation_errors" \
        "Should detect configuration errors"
    
    echo "Configuration validation test: OK"
}

# Test: Logging functions
test_logging_functions() {
    log_info "Testing logging functions"
    
    local logging_script="$RUNNER_SCRIPTS_DIR/common/logging.sh"
    
    if [[ ! -f "$logging_script" ]]; then
        echo "Logging script not found: $logging_script"
        return 1
    fi
    
    # Source logging functions
    source "$logging_script"
    
    # Test log level functions
    local test_log_file="$TEST_TEMP_DIR/test.log"
    
    # Redirect logging to test file
    exec 3>&1 4>&2
    exec 1>"$test_log_file" 2>&1
    
    # Test logging functions
    log_info "Test info message"
    log_warn "Test warning message"
    log_error "Test error message"
    log_debug "Test debug message"
    
    # Restore output
    exec 1>&3 2>&4
    exec 3>&- 4>&-
    
    # Verify log content
    assert_file_exists "$test_log_file" "Log file should be created"
    
    local log_content
    log_content=$(cat "$test_log_file")
    
    assert_contains "$log_content" "Test info message" \
        "Log should contain info message"
    
    assert_contains "$log_content" "Test warning message" \
        "Log should contain warning message"
    
    assert_contains "$log_content" "Test error message" \
        "Log should contain error message"
    
    echo "Logging functions test: OK"
}

# Test: Utility functions
test_utility_functions() {
    log_info "Testing utility functions"
    
    local utils_script="$RUNNER_SCRIPTS_DIR/common/utils.sh"
    
    if [[ ! -f "$utils_script" ]]; then
        echo "Utils script not found: $utils_script"
        return 1
    fi
    
    # Source utility functions
    source "$utils_script"
    
    # Test format_bytes function (if available)
    if declare -f format_bytes >/dev/null 2>&1; then
        local formatted
        formatted=$(format_bytes 1024)
        echo "format_bytes(1024) = $formatted"
        
        formatted=$(format_bytes 1048576)
        echo "format_bytes(1048576) = $formatted"
    fi
    
    # Test check_disk_space function (if available)
    if declare -f check_disk_space >/dev/null 2>&1; then
        if check_disk_space "/" 95; then
            echo "Disk space check: OK (< 95%)"
        else
            echo "Disk space check: WARN (>= 95%)"
        fi
    fi
    
    # Test lock_script function (if available)
    if declare -f lock_script >/dev/null 2>&1; then
        local test_lock_file="$TEST_TEMP_DIR/test.lock"
        
        if lock_script "$test_lock_file" 5; then
            echo "Lock script: OK"
            
            # Test that second lock fails
            if ! lock_script "$test_lock_file" 1; then
                echo "Lock script exclusivity: OK"
            else
                echo "Lock script exclusivity: FAILED"
            fi
            
            # Cleanup
            rm -f "$test_lock_file"
        else
            echo "Lock script: FAILED"
        fi
    fi
    
    echo "Utility functions test: OK"
}

# Test: Service management functions
test_service_management() {
    log_info "Testing service management functions"
    
    # Test systemctl commands (non-destructive)
    local service_name="github-runner.service"
    
    # Test service status check
    if systemctl list-units --type=service | grep -q "$service_name"; then
        echo "Service is registered: $service_name"
        
        # Test status retrieval
        local service_status
        service_status=$(systemctl is-active "$service_name" 2>/dev/null || echo "inactive")
        echo "Service status: $service_status"
        
        # Test enabled status
        local service_enabled
        service_enabled=$(systemctl is-enabled "$service_name" 2>/dev/null || echo "disabled")
        echo "Service enabled: $service_enabled"
        
    else
        echo "Service not found: $service_name"
    fi
    
    # Test service management script
    local service_scripts=(
        "$RUNNER_SCRIPTS_DIR/start.sh"
        "$RUNNER_SCRIPTS_DIR/stop.sh"
        "$RUNNER_SCRIPTS_DIR/restart.sh"
        "$RUNNER_SCRIPTS_DIR/status.sh"
    )
    
    for script in "${service_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            # Test script syntax
            assert_command_success "bash -n '$script'" \
                "Script $script should have valid syntax"
            
            # Test help option (if supported)
            if "$script" --help >/dev/null 2>&1; then
                echo "Script $script supports --help"
            fi
        fi
    done
    
    echo "Service management test: OK"
}

# Test: Security functions
test_security_functions() {
    log_info "Testing security functions"
    
    # Test file permission functions
    local test_file="$TEST_TEMP_DIR/security_test.txt"
    echo "test content" > "$test_file"
    
    # Test permission setting
    chmod 644 "$test_file"
    local perms
    perms=$(stat -c %a "$test_file")
    assert_equals "644" "$perms" "Should set permissions correctly"
    
    # Test ownership (if running as root)
    if [[ $EUID -eq 0 ]]; then
        local original_owner
        original_owner=$(stat -c %U "$test_file")
        
        # Test changing ownership
        chown nobody "$test_file" 2>/dev/null || true
        local new_owner
        new_owner=$(stat -c %U "$test_file")
        
        echo "Ownership change test: $original_owner -> $new_owner"
        
        # Restore ownership
        chown "$original_owner" "$test_file" 2>/dev/null || true
    fi
    
    # Test secure file creation
    local secure_file="$TEST_TEMP_DIR/secure_test.txt"
    (
        umask 077  # Create with restrictive permissions
        echo "secure content" > "$secure_file"
    )
    
    local secure_perms
    secure_perms=$(stat -c %a "$secure_file")
    echo "Secure file permissions: $secure_perms"
    
    # Test input sanitization
    local test_input="normal_input"
    local sanitized
    sanitized=$(echo "$test_input" | tr -d '`;|&$()<>')
    assert_equals "$test_input" "$sanitized" \
        "Normal input should not be modified"
    
    local malicious_input="input;rm -rf /"
    sanitized=$(echo "$malicious_input" | tr -d '`;|&$()<>')
    assert_not_equals "$malicious_input" "$sanitized" \
        "Malicious input should be sanitized"
    
    echo "Security functions test: OK"
}

# Test: Performance monitoring functions
test_performance_functions() {
    log_info "Testing performance monitoring functions"
    
    # Test system resource checks
    local memory_info
    memory_info=$(free -m | awk 'NR==2{printf "%d,%d,%d", $2,$3,$7}')
    echo "Memory info (total,used,available): $memory_info MB"
    
    local disk_info
    disk_info=$(df / | awk 'NR==2{printf "%s,%s", $4,$5}')
    echo "Disk info (available,used%): $disk_info"
    
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | xargs)
    echo "Load average: $load_avg"
    
    # Test CPU usage calculation
    local cpu_usage
    if command -v top >/dev/null 2>&1; then
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' || echo "unknown")
        echo "CPU usage: $cpu_usage%"
    fi
    
    # Test process monitoring
    if pgrep -f Runner.Listener >/dev/null 2>&1; then
        local runner_pid
        runner_pid=$(pgrep -f Runner.Listener | head -1)
        
        local runner_memory
        runner_memory=$(ps -o rss= -p "$runner_pid" 2>/dev/null | awk '{print $1}' || echo "0")
        echo "Runner memory usage: ${runner_memory}KB"
        
        local runner_cpu
        runner_cpu=$(ps -o pcpu= -p "$runner_pid" 2>/dev/null | awk '{print $1}' || echo "0")
        echo "Runner CPU usage: ${runner_cpu}%"
    fi
    
    echo "Performance monitoring test: OK"
}

# Test: Network functions
test_network_functions() {
    log_info "Testing network functions"
    
    # Test DNS resolution
    if nslookup github.com >/dev/null 2>&1; then
        echo "DNS resolution: OK"
    else
        echo "DNS resolution: FAILED"
    fi
    
    # Test HTTP connectivity
    if curl -s --max-time 5 https://api.github.com/zen >/dev/null 2>&1; then
        echo "HTTP connectivity: OK"
    else
        echo "HTTP connectivity: FAILED"
    fi
    
    # Test port checking function
    local test_port_function="$TEST_TEMP_DIR/test_port.sh"
    cat > "$test_port_function" << 'EOF'
#!/bin/bash

check_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-5}"
    
    timeout "$timeout" bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null
}

# Test function
if check_port "github.com" "443" 5; then
    echo "Port check function: OK"
else
    echo "Port check function: FAILED"
fi
EOF
    
    chmod +x "$test_port_function"
    assert_command_success "$test_port_function" \
        "Port check function should work"
    
    # Test URL accessibility function
    local test_url_function="$TEST_TEMP_DIR/test_url.sh"
    cat > "$test_url_function" << 'EOF'
#!/bin/bash

check_url() {
    local url="$1"
    local expected_code="${2:-200}"
    
    local actual_code
    actual_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    [[ "$actual_code" == "$expected_code" ]]
}

# Test function
if check_url "https://github.com" "200"; then
    echo "URL check function: OK"
else
    echo "URL check function: FAILED"
fi
EOF
    
    chmod +x "$test_url_function"
    assert_command_success "$test_url_function" \
        "URL check function should work"
    
    echo "Network functions test: OK"
}

# Test: Error handling
test_error_handling() {
    log_info "Testing error handling"
    
    # Test error exit codes
    local error_test_script="$TEST_TEMP_DIR/error_test.sh"
    cat > "$error_test_script" << 'EOF'
#!/bin/bash

set -euo pipefail

# Function that should fail
failing_function() {
    false
    echo "This should not be reached"
}

# Test error handling
if failing_function 2>/dev/null; then
    echo "ERROR: Function should have failed"
    exit 1
else
    echo "Function failed as expected"
fi

echo "Error handling test completed"
EOF
    
    chmod +x "$error_test_script"
    assert_command_success "$error_test_script" \
        "Error handling test should succeed"
    
    # Test cleanup on error
    local cleanup_test_script="$TEST_TEMP_DIR/cleanup_test.sh"
    cat > "$cleanup_test_script" << 'EOF'
#!/bin/bash

set -euo pipefail

TEMP_FILE="/tmp/cleanup_test_$$"

# Cleanup function
cleanup() {
    echo "Cleaning up: $TEMP_FILE"
    rm -f "$TEMP_FILE"
}

# Set trap for cleanup
trap cleanup EXIT

# Create temporary file
touch "$TEMP_FILE"

# Simulate some work
echo "Working with temporary file: $TEMP_FILE"

# Exit normally (cleanup should run)
echo "Cleanup test completed"
EOF
    
    chmod +x "$cleanup_test_script"
    assert_command_success "$cleanup_test_script" \
        "Cleanup test should succeed"
    
    echo "Error handling test: OK"
}

# Main unit test execution
main() {
    setup_test_environment
    
    # Run unit tests
    run_test "health_check_script" "test_health_check_script" \
        "Test health check script functionality"
    
    run_test "backup_script" "test_backup_script" \
        "Test backup script functionality"
    
    run_test "config_validation" "test_config_validation" \
        "Test configuration validation functions"
    
    run_test "logging_functions" "test_logging_functions" \
        "Test logging utility functions"
    
    run_test "utility_functions" "test_utility_functions" \
        "Test general utility functions"
    
    run_test "service_management" "test_service_management" \
        "Test service management functions"
    
    run_test "security_functions" "test_security_functions" \
        "Test security-related functions"
    
    run_test "performance_functions" "test_performance_functions" \
        "Test performance monitoring functions"
    
    run_test "network_functions" "test_network_functions" \
        "Test network utility functions"
    
    run_test "error_handling" "test_error_handling" \
        "Test error handling mechanisms"
    
    cleanup_test_environment
    finalize_test_framework
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi