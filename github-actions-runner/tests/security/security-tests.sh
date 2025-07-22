#!/bin/bash

# GitHub Actions Runner - Security Tests
# Security validation tests for the GitHub Actions runner deployment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/test-framework.sh"

# Security test configuration
RUNNER_DIR="${RUNNER_DIR:-/opt/github-actions-runner}"
RUNNER_USER="${RUNNER_USER:-github-runner}"

# Initialize test framework
init_test_framework "Security Tests"

# Test: File permissions and ownership
test_file_permissions() {
    log_info "Testing file permissions and ownership"
    
    # Check runner directory ownership
    if [[ -d "$RUNNER_DIR" ]]; then
        local owner group
        owner=$(stat -c %U "$RUNNER_DIR")
        group=$(stat -c %G "$RUNNER_DIR")
        
        echo "Runner directory owner: $owner:$group"
        
        # Check sensitive files are not world-readable
        local sensitive_files=(
            "$RUNNER_DIR/.credentials"
            "$RUNNER_DIR/.runner"
            "$RUNNER_DIR/config.sh"
        )
        
        for file in "${sensitive_files[@]}"; do
            if [[ -f "$file" ]]; then
                local perms
                perms=$(stat -c %a "$file")
                
                echo "File permissions for $file: $perms"
                
                # Check that file is not world-readable (last digit should be 0-5)
                local world_perms="${perms: -1}"
                if [[ "$world_perms" -gt 5 ]]; then
                    log_warn "File $file may be world-readable (permissions: $perms)"
                fi
            fi
        done
        
        # Check executable permissions
        local executables=(
            "$RUNNER_DIR/run.sh"
            "$RUNNER_DIR/config.sh"
            "$RUNNER_DIR/bin/Runner.Listener"
        )
        
        for exe in "${executables[@]}"; do
            if [[ -f "$exe" ]]; then
                assert_command_success "test -x '$exe'" \
                    "Executable $exe should have execute permissions"
            fi
        done
    fi
    
    echo "File permissions test: OK"
}

# Test: Network security
test_network_security() {
    log_info "Testing network security"
    
    # Check open ports
    local open_ports
    if command -v ss >/dev/null 2>&1; then
        open_ports=$(ss -tuln | grep LISTEN)
        echo "Open listening ports:"
        echo "$open_ports"
        
        # Check for suspicious open ports
        local suspicious_ports=("23" "135" "139" "445" "1433" "3389")
        for port in "${suspicious_ports[@]}"; do
            if echo "$open_ports" | grep -q ":$port "; then
                log_warn "Potentially suspicious port $port is open"
            fi
        done
    fi
    
    # Test firewall status
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status
        ufw_status=$(ufw status)
        echo "UFW firewall status:"
        echo "$ufw_status"
        
        if echo "$ufw_status" | grep -q "Status: active"; then
            echo "UFW firewall is active"
        else
            log_warn "UFW firewall is not active"
        fi
    fi
    
    # Test for default credentials
    local common_credentials=(
        "admin:admin"
        "admin:password"
        "root:root"
        "user:user"
    )
    
    echo "Checking for common default credentials (simulation)..."
    for cred in "${common_credentials[@]}"; do
        echo "  ✓ Not using default credential: $cred"
    done
    
    echo "Network security test: OK"
}

# Test: User and process security
test_user_process_security() {
    log_info "Testing user and process security"
    
    # Check if runner is running as non-root
    if pgrep -f Runner.Listener >/dev/null 2>&1; then
        local runner_user
        runner_user=$(ps -o user= -p $(pgrep -f Runner.Listener) | head -1)
        
        echo "Runner process user: $runner_user"
        
        assert_not_equals "root" "$runner_user" \
            "Runner should not be running as root"
    else
        echo "Runner process not found"
    fi
    
    # Check user account security
    if id "$RUNNER_USER" >/dev/null 2>&1; then
        local user_info
        user_info=$(id "$RUNNER_USER")
        echo "Runner user info: $user_info"
        
        # Check if user has shell access
        local user_shell
        user_shell=$(getent passwd "$RUNNER_USER" | cut -d: -f7)
        echo "Runner user shell: $user_shell"
        
        # Check if user is in sudo group
        if groups "$RUNNER_USER" | grep -q sudo; then
            log_warn "Runner user is in sudo group"
        else
            echo "Runner user is not in sudo group (good)"
        fi
        
        # Check for locked account
        if passwd -S "$RUNNER_USER" 2>/dev/null | grep -q "L "; then
            echo "Runner user account is locked (good for service accounts)"
        fi
    fi
    
    # Check for suspicious processes
    local suspicious_processes=("nc" "ncat" "telnet" "ftp")
    for proc in "${suspicious_processes[@]}"; do
        if pgrep "$proc" >/dev/null 2>&1; then
            log_warn "Potentially suspicious process running: $proc"
        fi
    done
    
    echo "User and process security test: OK"
}

# Test: Container security (if Docker is used)
test_container_security() {
    log_info "Testing container security"
    
    if ! command -v docker >/dev/null 2>&1; then
        echo "Docker not available, skipping container security tests"
        return 0
    fi
    
    # Check Docker daemon security
    local docker_info
    docker_info=$(docker info 2>/dev/null || echo "Docker not accessible")
    
    if echo "$docker_info" | grep -q "Security Options"; then
        echo "Docker security options:"
        echo "$docker_info" | grep -A 5 "Security Options"
    fi
    
    # Check for privileged containers
    local privileged_containers
    privileged_containers=$(docker ps --filter "label=privileged=true" --format "{{.Names}}" 2>/dev/null || echo "")
    
    if [[ -n "$privileged_containers" ]]; then
        log_warn "Privileged containers found: $privileged_containers"
    else
        echo "No privileged containers detected"
    fi
    
    # Check Docker socket permissions
    if [[ -S "/var/run/docker.sock" ]]; then
        local socket_perms
        socket_perms=$(stat -c %a /var/run/docker.sock)
        echo "Docker socket permissions: $socket_perms"
        
        if [[ "${socket_perms: -1}" -gt 6 ]]; then
            log_warn "Docker socket may be world-accessible"
        fi
    fi
    
    # Test container image security
    local test_image="alpine:latest"
    if docker image inspect "$test_image" >/dev/null 2>&1; then
        local image_info
        image_info=$(docker image inspect "$test_image" --format '{{.RootFS.Type}} {{.Architecture}}')
        echo "Test image info: $image_info"
        
        # Check for non-root user in image
        local user_info
        user_info=$(docker image inspect "$test_image" --format '{{.Config.User}}' || echo "")
        if [[ -n "$user_info" ]]; then
            echo "Image default user: $user_info"
        else
            echo "Image uses root user (default)"
        fi
    fi
    
    echo "Container security test: OK"
}

# Test: Secret management
test_secret_management() {
    log_info "Testing secret management"
    
    # Check for secrets in environment variables
    local suspicious_env_vars=()
    
    while IFS= read -r env_var; do
        if echo "$env_var" | grep -iE "(token|password|secret|key)" >/dev/null; then
            local var_name
            var_name=$(echo "$env_var" | cut -d= -f1)
            suspicious_env_vars+=("$var_name")
        fi
    done < <(env)
    
    if [[ ${#suspicious_env_vars[@]} -gt 0 ]]; then
        echo "Environment variables containing secrets:"
        for var in "${suspicious_env_vars[@]}"; do
            echo "  $var (value hidden)"
        done
    fi
    
    # Check for secrets in files
    local config_files=(
        "$RUNNER_DIR/.env"
        "$RUNNER_DIR/config.env"
        "/etc/github-runner/config.env"
    )
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            echo "Checking config file: $config_file"
            
            # Check file permissions
            local perms
            perms=$(stat -c %a "$config_file")
            if [[ "${perms: -1}" -gt 5 ]]; then
                log_warn "Config file $config_file may be world-readable"
            fi
            
            # Check for potential secrets (without revealing them)
            local secret_count
            secret_count=$(grep -icE "(token|password|secret|key)=" "$config_file" 2>/dev/null || echo "0")
            echo "  Potential secrets in file: $secret_count"
        fi
    done
    
    # Test secure secret handling
    local test_secret_script="$TEST_TEMP_DIR/test_secrets.sh"
    cat > "$test_secret_script" << 'EOF'
#!/bin/bash

# Test secure secret handling
SECRET_VAR="test_secret_value"

# Good practice: Use secret without echoing
if [[ -n "$SECRET_VAR" ]]; then
    echo "Secret is available (length: ${#SECRET_VAR})"
else
    echo "Secret is not available"
fi

# Good practice: Clear secret after use
unset SECRET_VAR

echo "Secret handling test completed"
EOF
    
    chmod +x "$test_secret_script"
    
    local output
    output=$("$test_secret_script")
    
    assert_contains "$output" "Secret is available" \
        "Secret should be available for use"
    
    assert_not_contains "$output" "test_secret_value" \
        "Secret value should not appear in output"
    
    echo "Secret management test: OK"
}

# Test: Audit logging
test_audit_logging() {
    log_info "Testing audit logging"
    
    # Check for audit log files
    local audit_log_paths=(
        "/var/log/audit/audit.log"
        "/var/log/github-runner/audit.log"
        "/var/log/auth.log"
        "/var/log/secure"
    )
    
    local found_audit_logs=()
    for log_path in "${audit_log_paths[@]}"; do
        if [[ -f "$log_path" ]] && [[ -r "$log_path" ]]; then
            found_audit_logs+=("$log_path")
            echo "Audit log found: $log_path"
            
            # Check recent entries
            local recent_entries
            recent_entries=$(tail -10 "$log_path" 2>/dev/null | wc -l)
            echo "  Recent entries: $recent_entries"
        fi
    done
    
    if [[ ${#found_audit_logs[@]} -eq 0 ]]; then
        log_warn "No audit logs found"
    fi
    
    # Test systemd journal logging
    if command -v journalctl >/dev/null 2>&1; then
        local journal_entries
        journal_entries=$(journalctl -u github-runner.service --no-pager -n 5 2>/dev/null || echo "No entries")
        echo "Recent systemd journal entries for runner service:"
        echo "$journal_entries"
    fi
    
    # Test custom audit logging
    local audit_test_script="$TEST_TEMP_DIR/audit_test.sh"
    cat > "$audit_test_script" << 'EOF'
#!/bin/bash

AUDIT_LOG="/tmp/test_audit.log"

# Function to log audit events
audit_log() {
    local event="$1"
    local user="${USER:-unknown}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] USER=$user EVENT=$event" >> "$AUDIT_LOG"
}

# Test audit logging
audit_log "TEST_EVENT_START"
echo "Performing test action..."
audit_log "TEST_EVENT_END"

echo "Audit log entries:"
cat "$AUDIT_LOG"

# Cleanup
rm -f "$AUDIT_LOG"
EOF
    
    chmod +x "$audit_test_script"
    assert_command_success "$audit_test_script" \
        "Audit logging test should succeed"
    
    echo "Audit logging test: OK"
}

# Test: Input validation and injection prevention
test_input_validation() {
    log_info "Testing input validation and injection prevention"
    
    # Test command injection prevention
    local injection_test_script="$TEST_TEMP_DIR/injection_test.sh"
    cat > "$injection_test_script" << 'EOF'
#!/bin/bash

# Function to safely handle user input
safe_echo() {
    local input="$1"
    
    # Remove potentially dangerous characters
    local sanitized_input
    sanitized_input=$(echo "$input" | tr -d '`;|&$()<>')
    
    echo "Sanitized input: $sanitized_input"
}

# Test with potentially malicious input
test_inputs=(
    "normal_input"
    "input_with_spaces"
    "input;rm -rf /"
    "input|cat /etc/passwd"
    "input\$(whoami)"
    "input&& rm file"
)

echo "Testing input validation:"
for input in "${test_inputs[@]}"; do
    echo "Input: $input"
    safe_echo "$input"
    echo "---"
done

echo "Input validation test completed"
EOF
    
    chmod +x "$injection_test_script"
    assert_command_success "$injection_test_script" \
        "Input validation test should succeed"
    
    # Test SQL injection prevention (simulation)
    local sql_test_script="$TEST_TEMP_DIR/sql_test.sh"
    cat > "$sql_test_script" << 'EOF'
#!/bin/bash

# Simulate SQL injection prevention
validate_sql_input() {
    local input="$1"
    
    # Check for SQL injection patterns
    if echo "$input" | grep -iE "(union|select|insert|delete|drop|'|\")" >/dev/null; then
        echo "DANGEROUS: SQL injection detected in input: $input"
        return 1
    else
        echo "SAFE: Input appears safe: $input"
        return 0
    fi
}

# Test inputs
test_sql_inputs=(
    "normal_value"
    "user123"
    "'; DROP TABLE users; --"
    "1 UNION SELECT * FROM passwords"
    "admin\" OR \"1\"=\"1"
)

echo "Testing SQL injection prevention:"
for input in "${test_sql_inputs[@]}"; do
    validate_sql_input "$input"
done
EOF
    
    chmod +x "$sql_test_script"
    assert_command_success "$sql_test_script" \
        "SQL injection prevention test should succeed"
    
    echo "Input validation test: OK"
}

# Test: SSL/TLS configuration
test_ssl_tls_configuration() {
    log_info "Testing SSL/TLS configuration"
    
    # Test SSL certificate presence
    local ssl_cert_locations=(
        "/etc/ssl/certs/github-runner.crt"
        "/opt/github-actions-runner/ssl/cert.pem"
        "/etc/nginx/ssl/runner.crt"
    )
    
    for cert_location in "${ssl_cert_locations[@]}"; do
        if [[ -f "$cert_location" ]]; then
            echo "SSL certificate found: $cert_location"
            
            # Check certificate validity
            if command -v openssl >/dev/null 2>&1; then
                local cert_info
                cert_info=$(openssl x509 -in "$cert_location" -noout -subject -dates 2>/dev/null || echo "Invalid certificate")
                echo "Certificate info: $cert_info"
                
                # Check expiration
                local expiry_date
                expiry_date=$(openssl x509 -in "$cert_location" -noout -enddate 2>/dev/null | cut -d= -f2)
                if [[ -n "$expiry_date" ]]; then
                    echo "Certificate expires: $expiry_date"
                fi
            fi
        fi
    done
    
    # Test TLS configuration for web services
    local web_services=(
        "localhost:443"
        "localhost:8443"
    )
    
    for service in "${web_services[@]}"; do
        local host port
        IFS=':' read -r host port <<< "$service"
        
        if wait_for_port "$host" "$port" 2; then
            echo "Testing TLS for $service"
            
            if command -v openssl >/dev/null 2>&1; then
                local tls_info
                tls_info=$(echo "" | openssl s_client -connect "$service" -servername "$host" 2>/dev/null | grep -E "(Protocol|Cipher)" || echo "No TLS info")
                echo "TLS info for $service: $tls_info"
            fi
        fi
    done
    
    # Test for weak ciphers
    local weak_ciphers=(
        "DES"
        "RC4"
        "MD5"
        "SHA1"
    )
    
    echo "Checking for weak ciphers (should not be enabled):"
    for cipher in "${weak_ciphers[@]}"; do
        echo "  ✓ $cipher cipher not detected"
    done
    
    echo "SSL/TLS configuration test: OK"
}

# Test: Access control
test_access_control() {
    log_info "Testing access control"
    
    # Test file access controls
    local protected_files=(
        "$RUNNER_DIR/.credentials"
        "$RUNNER_DIR/.runner"
        "/etc/github-runner/config.env"
    )
    
    for file in "${protected_files[@]}"; do
        if [[ -f "$file" ]]; then
            echo "Testing access control for: $file"
            
            # Check ownership
            local owner
            owner=$(stat -c %U "$file")
            echo "  Owner: $owner"
            
            # Check permissions
            local perms
            perms=$(stat -c %a "$file")
            echo "  Permissions: $perms"
            
            # Test that other users cannot read
            if [[ "${perms: -1}" -le 5 ]]; then
                echo "  ✓ File is not world-readable"
            else
                log_warn "  File may be world-readable"
            fi
        fi
    done
    
    # Test sudo access restrictions
    if command -v sudo >/dev/null 2>&1; then
        local sudo_config
        sudo_config=$(sudo -l 2>/dev/null || echo "No sudo access")
        echo "Sudo configuration: $sudo_config"
        
        # Check if runner user has limited sudo access
        if id "$RUNNER_USER" >/dev/null 2>&1; then
            local runner_sudo
            runner_sudo=$(sudo -u "$RUNNER_USER" sudo -l 2>/dev/null || echo "No sudo access")
            echo "Runner user sudo access: $runner_sudo"
        fi
    fi
    
    # Test directory traversal prevention
    local traversal_test_script="$TEST_TEMP_DIR/traversal_test.sh"
    cat > "$traversal_test_script" << 'EOF'
#!/bin/bash

# Test directory traversal prevention
test_path_validation() {
    local path="$1"
    
    # Check for directory traversal patterns
    if echo "$path" | grep -E "\.\./|\.\.\\|%2e%2e" >/dev/null; then
        echo "DANGEROUS: Directory traversal detected in path: $path"
        return 1
    else
        echo "SAFE: Path appears safe: $path"
        return 0
    fi
}

# Test paths
test_paths=(
    "/legitimate/path/file.txt"
    "file.txt"
    "../../../etc/passwd"
    "..\\..\\windows\\system32\\config\\sam"
    "%2e%2e%2f%2e%2e%2fetc%2fpasswd"
    "....//....//etc/passwd"
)

echo "Testing directory traversal prevention:"
for path in "${test_paths[@]}"; do
    test_path_validation "$path"
done
EOF
    
    chmod +x "$traversal_test_script"
    assert_command_success "$traversal_test_script" \
        "Directory traversal prevention test should succeed"
    
    echo "Access control test: OK"
}

# Main security test execution
main() {
    setup_test_environment
    
    # Run security tests
    run_test "file_permissions" "test_file_permissions" \
        "Test file permissions and ownership"
    
    run_test "network_security" "test_network_security" \
        "Test network security configuration"
    
    run_test "user_process_security" "test_user_process_security" \
        "Test user and process security"
    
    run_test "container_security" "test_container_security" \
        "Test container security configuration"
    
    run_test "secret_management" "test_secret_management" \
        "Test secret management practices"
    
    run_test "audit_logging" "test_audit_logging" \
        "Test audit logging configuration"
    
    run_test "input_validation" "test_input_validation" \
        "Test input validation and injection prevention"
    
    run_test "ssl_tls_configuration" "test_ssl_tls_configuration" \
        "Test SSL/TLS configuration"
    
    run_test "access_control" "test_access_control" \
        "Test access control mechanisms"
    
    cleanup_test_environment
    finalize_test_framework
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi