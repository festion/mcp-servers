#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/common.sh"

ENVIRONMENT="${1:-dev}"

log_info "Running security scan for environment: $ENVIRONMENT"

scan_container_vulnerabilities() {
    log_info "Scanning container vulnerabilities"
    
    local vulnerability_failures=0
    
    # Get list of running containers
    local containers
    containers=$(docker ps --filter "label=github-runner" --format "{{.Names}}")
    
    for container in $containers; do
        log_info "Scanning container: $container"
        
        # Get container image
        local image
        image=$(docker inspect "$container" --format='{{.Config.Image}}')
        
        # Use Docker Scout if available, otherwise use basic security checks
        if command -v docker &> /dev/null && docker scout --help &> /dev/null; then
            if docker scout cves "$image" --format json > /tmp/scout-$container.json 2>/dev/null; then
                local high_cves
                high_cves=$(jq -r '.vulnerabilities[] | select(.severity == "high") | .id' /tmp/scout-$container.json 2>/dev/null | wc -l)
                
                if (( high_cves == 0 )); then
                    log_success "Container vulnerability scan passed: $container"
                else
                    log_error "Container vulnerability scan failed: $container ($high_cves high CVEs)"
                    ((vulnerability_failures++))
                fi
                
                rm -f /tmp/scout-$container.json
            else
                log_warn "Docker Scout scan failed for: $container"
            fi
        else
            # Basic security checks
            if docker exec "$container" which curl &> /dev/null; then
                log_success "Basic security check passed: $container"
            else
                log_warn "Basic security check: missing curl in $container"
            fi
        fi
    done
    
    return $vulnerability_failures
}

scan_secrets_exposure() {
    log_info "Scanning for exposed secrets"
    
    local secrets_failures=0
    
    # Check for exposed environment variables
    local containers
    containers=$(docker ps --filter "label=github-runner" --format "{{.Names}}")
    
    for container in $containers; do
        log_info "Checking secrets exposure in: $container"
        
        # Check for exposed secrets in environment variables
        local env_vars
        env_vars=$(docker exec "$container" env 2>/dev/null || true)
        
        if echo "$env_vars" | grep -i "token\|password\|secret\|key" | grep -v "MASKED\|REDACTED" | grep -q "="; then
            log_error "Potential secret exposure in container: $container"
            ((secrets_failures++))
        else
            log_success "No secret exposure found in: $container"
        fi
    done
    
    # Check for secrets in configuration files
    local config_files=(
        "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
        "$SCRIPT_DIR/../infrastructure/docker-compose.yml"
    )
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            log_info "Checking secrets in: $config_file"
            
            # Look for hardcoded secrets (basic patterns)
            if grep -E "(password|token|secret|key).*=.*[a-zA-Z0-9]{20,}" "$config_file" | grep -v "\${" | grep -v "MASKED\|REDACTED" >/dev/null 2>&1; then
                log_error "Potential hardcoded secret found in: $config_file"
                ((secrets_failures++))
            else
                log_success "No hardcoded secrets found in: $config_file"
            fi
        fi
    done
    
    return $secrets_failures
}

scan_network_security() {
    log_info "Scanning network security"
    
    local network_failures=0
    
    # Check for open ports
    local dangerous_ports=(
        22    # SSH
        23    # Telnet
        21    # FTP
        3389  # RDP
        5432  # PostgreSQL
        6379  # Redis
        3306  # MySQL
    )
    
    for port in "${dangerous_ports[@]}"; do
        if nc -z localhost "$port" 2>/dev/null; then
            log_warn "Potentially dangerous port open: $port"
            ((network_failures++))
        fi
    done
    
    # Check Docker network configuration
    local networks
    networks=$(docker network ls --format "{{.Name}}" | grep -v "bridge\|host\|none")
    
    for network in $networks; do
        log_info "Checking network security: $network"
        
        local network_config
        network_config=$(docker network inspect "$network" --format '{{.Driver}}')
        
        if [[ "$network_config" == "bridge" ]]; then
            log_success "Network security check passed: $network"
        else
            log_warn "Network security check: $network uses $network_config driver"
        fi
    done
    
    return $network_failures
}

scan_file_permissions() {
    log_info "Scanning file permissions"
    
    local permission_failures=0
    
    # Check critical file permissions
    local critical_files=(
        "$SCRIPT_DIR/../deploy.sh"
        "$SCRIPT_DIR/../scripts/pre-deploy.sh"
        "$SCRIPT_DIR/../scripts/post-deploy.sh"
        "$SCRIPT_DIR/../scripts/rollback.sh"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_info "Checking permissions: $file"
            
            local permissions
            permissions=$(stat -c "%a" "$file")
            
            # Check if file is executable by owner but not world-writable
            if [[ "$permissions" == "755" ]] || [[ "$permissions" == "750" ]]; then
                log_success "File permissions OK: $file ($permissions)"
            else
                log_error "File permissions issue: $file ($permissions)"
                ((permission_failures++))
            fi
        fi
    done
    
    # Check directory permissions
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local critical_dirs=(
        "$DATA_DIR"
        "$LOG_DIR"
        "$BACKUP_DIR"
    )
    
    for dir in "${critical_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_info "Checking directory permissions: $dir"
            
            local permissions
            permissions=$(stat -c "%a" "$dir")
            
            # Check if directory is not world-writable
            if [[ "${permissions: -1}" != "7" ]]; then
                log_success "Directory permissions OK: $dir ($permissions)"
            else
                log_error "Directory permissions issue: $dir ($permissions)"
                ((permission_failures++))
            fi
        fi
    done
    
    return $permission_failures
}

scan_ssl_configuration() {
    log_info "Scanning SSL configuration"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local ssl_failures=0
    
    if [[ "$ENABLE_SSL" == "true" ]]; then
        # Check SSL certificate files
        if [[ -f "${SSL_CERT_PATH:-}" ]]; then
            log_info "Checking SSL certificate: $SSL_CERT_PATH"
            
            # Check certificate validity
            if openssl x509 -in "$SSL_CERT_PATH" -noout -dates 2>/dev/null; then
                local expiry_date
                expiry_date=$(openssl x509 -in "$SSL_CERT_PATH" -noout -enddate | cut -d= -f2)
                
                local expiry_timestamp
                expiry_timestamp=$(date -d "$expiry_date" +%s)
                
                local current_timestamp
                current_timestamp=$(date +%s)
                
                local days_until_expiry
                days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
                
                if (( days_until_expiry > 30 )); then
                    log_success "SSL certificate valid: expires in $days_until_expiry days"
                else
                    log_error "SSL certificate expires soon: $days_until_expiry days"
                    ((ssl_failures++))
                fi
            else
                log_error "SSL certificate is invalid: $SSL_CERT_PATH"
                ((ssl_failures++))
            fi
        else
            log_error "SSL certificate file not found: ${SSL_CERT_PATH:-}"
            ((ssl_failures++))
        fi
        
        # Check SSL key file
        if [[ -f "${SSL_KEY_PATH:-}" ]]; then
            log_info "Checking SSL key: $SSL_KEY_PATH"
            
            local key_permissions
            key_permissions=$(stat -c "%a" "$SSL_KEY_PATH")
            
            if [[ "$key_permissions" == "600" ]] || [[ "$key_permissions" == "400" ]]; then
                log_success "SSL key permissions OK: $SSL_KEY_PATH ($key_permissions)"
            else
                log_error "SSL key permissions issue: $SSL_KEY_PATH ($key_permissions)"
                ((ssl_failures++))
            fi
        else
            log_error "SSL key file not found: ${SSL_KEY_PATH:-}"
            ((ssl_failures++))
        fi
    else
        log_info "SSL is disabled for environment: $ENVIRONMENT"
        
        if [[ "$ENVIRONMENT" == "prod" ]]; then
            log_error "SSL should be enabled for production environment"
            ((ssl_failures++))
        fi
    fi
    
    return $ssl_failures
}

scan_docker_security() {
    log_info "Scanning Docker security"
    
    local docker_failures=0
    
    # Check Docker daemon configuration
    if docker info 2>/dev/null | grep -q "Security Options"; then
        log_success "Docker security options are configured"
    else
        log_warn "Docker security options not found"
        ((docker_failures++))
    fi
    
    # Check for privileged containers
    local privileged_containers
    privileged_containers=$(docker ps --filter "label=github-runner" --format "{{.Names}}" | xargs -I {} docker inspect {} --format '{{.Name}}: {{.HostConfig.Privileged}}' | grep "true")
    
    if [[ -n "$privileged_containers" ]]; then
        log_error "Privileged containers found:"
        echo "$privileged_containers"
        ((docker_failures++))
    else
        log_success "No privileged containers found"
    fi
    
    # Check for containers running as root
    local containers
    containers=$(docker ps --filter "label=github-runner" --format "{{.Names}}")
    
    for container in $containers; do
        local user
        user=$(docker exec "$container" whoami 2>/dev/null || echo "unknown")
        
        if [[ "$user" == "root" ]]; then
            log_warn "Container running as root: $container"
            ((docker_failures++))
        else
            log_success "Container not running as root: $container ($user)"
        fi
    done
    
    return $docker_failures
}

scan_github_security() {
    log_info "Scanning GitHub security configuration"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local github_failures=0
    
    # Check GitHub token permissions
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        log_info "Checking GitHub token permissions"
        
        local token_info
        token_info=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                         -H "Accept: application/vnd.github.v3+json" \
                         https://api.github.com/user)
        
        if echo "$token_info" | jq -e '.login' > /dev/null; then
            log_success "GitHub token is valid"
            
            # Check token scopes
            local scopes
            scopes=$(curl -s -I -H "Authorization: token $GITHUB_TOKEN" \
                         -H "Accept: application/vnd.github.v3+json" \
                         https://api.github.com/user | grep -i "x-oauth-scopes" | cut -d: -f2 | tr -d ' ')
            
            if [[ "$scopes" == *"admin:org"* ]]; then
                log_warn "GitHub token has admin:org scope - consider using more restrictive permissions"
                ((github_failures++))
            else
                log_success "GitHub token has appropriate scopes"
            fi
        else
            log_error "GitHub token is invalid"
            ((github_failures++))
        fi
    else
        log_error "GitHub token is not set"
        ((github_failures++))
    fi
    
    return $github_failures
}

scan_backup_security() {
    log_info "Scanning backup security"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local backup_failures=0
    
    local backup_dir="${BACKUP_DIR:-/tmp/deployment-backups}"
    
    if [[ -d "$backup_dir" ]]; then
        log_info "Checking backup directory security: $backup_dir"
        
        # Check directory permissions
        local permissions
        permissions=$(stat -c "%a" "$backup_dir")
        
        if [[ "$permissions" == "700" ]] || [[ "$permissions" == "750" ]]; then
            log_success "Backup directory permissions OK: $backup_dir ($permissions)"
        else
            log_error "Backup directory permissions issue: $backup_dir ($permissions)"
            ((backup_failures++))
        fi
        
        # Check for sensitive files in backups
        local sensitive_files
        sensitive_files=$(find "$backup_dir" -name "*.env" -o -name "*.key" -o -name "*.pem" | wc -l)
        
        if (( sensitive_files > 0 )); then
            log_warn "Sensitive files found in backups: $sensitive_files files"
            ((backup_failures++))
        else
            log_success "No sensitive files found in backups"
        fi
    else
        log_error "Backup directory not found: $backup_dir"
        ((backup_failures++))
    fi
    
    return $backup_failures
}

generate_security_report() {
    log_info "Generating security scan report"
    
    local report_file="/tmp/security-scan-report-$ENVIRONMENT-$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$report_file" << EOF
{
    "environment": "$ENVIRONMENT",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "security_results": {
        "container_vulnerabilities": "$vulnerability_result",
        "secrets_exposure": "$secrets_result",
        "network_security": "$network_result",
        "file_permissions": "$permissions_result",
        "ssl_configuration": "$ssl_result",
        "docker_security": "$docker_result",
        "github_security": "$github_result",
        "backup_security": "$backup_result"
    },
    "overall_status": "$overall_status",
    "total_tests": 8,
    "passed_tests": $passed_tests,
    "failed_tests": $failed_tests,
    "recommendations": [
        "Regularly update container images to patch vulnerabilities",
        "Use Docker secrets for sensitive data",
        "Enable SSL/TLS for production environments",
        "Implement network segmentation",
        "Use least privilege principle for GitHub tokens",
        "Regularly rotate secrets and tokens",
        "Monitor for security events and anomalies"
    ]
}
EOF
    
    log_success "Security scan report generated: $report_file"
}

main() {
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local total_failures=0
    local passed_tests=0
    
    # Run all security scans
    scan_container_vulnerabilities
    vulnerability_result=$?
    total_failures=$((total_failures + vulnerability_result))
    if (( vulnerability_result == 0 )); then ((passed_tests++)); fi
    
    scan_secrets_exposure
    secrets_result=$?
    total_failures=$((total_failures + secrets_result))
    if (( secrets_result == 0 )); then ((passed_tests++)); fi
    
    scan_network_security
    network_result=$?
    total_failures=$((total_failures + network_result))
    if (( network_result == 0 )); then ((passed_tests++)); fi
    
    scan_file_permissions
    permissions_result=$?
    total_failures=$((total_failures + permissions_result))
    if (( permissions_result == 0 )); then ((passed_tests++)); fi
    
    scan_ssl_configuration
    ssl_result=$?
    total_failures=$((total_failures + ssl_result))
    if (( ssl_result == 0 )); then ((passed_tests++)); fi
    
    scan_docker_security
    docker_result=$?
    total_failures=$((total_failures + docker_result))
    if (( docker_result == 0 )); then ((passed_tests++)); fi
    
    scan_github_security
    github_result=$?
    total_failures=$((total_failures + github_result))
    if (( github_result == 0 )); then ((passed_tests++)); fi
    
    scan_backup_security
    backup_result=$?
    total_failures=$((total_failures + backup_result))
    if (( backup_result == 0 )); then ((passed_tests++)); fi
    
    # Calculate results
    local failed_tests=$((8 - passed_tests))
    
    if (( total_failures == 0 )); then
        overall_status="passed"
        log_success "All security scans passed ($passed_tests/8)"
    else
        overall_status="failed"
        log_error "Security scans failed: $failed_tests failures"
    fi
    
    generate_security_report
    
    exit $total_failures
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi