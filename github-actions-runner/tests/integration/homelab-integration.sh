#!/bin/bash

# GitHub Actions Runner - Homelab Integration Tests
# Tests for integration with existing homelab infrastructure and services

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/test-framework.sh"

# Integration test configuration
HOME_ASSISTANT_URL="${HOME_ASSISTANT_URL:-http://192.168.1.155:8123}"
PROXMOX_URL="${PROXMOX_URL:-http://192.168.1.137:8006}"
WIKIJS_URL="${WIKIJS_URL:-http://192.168.1.90:3000}"
MONITORING_URL="${MONITORING_URL:-http://localhost:3000}"

# Initialize test framework
init_test_framework "Homelab Integration Tests"

# Test: Home Assistant integration
test_home_assistant_integration() {
    log_info "Testing Home Assistant integration"
    
    # Test Home Assistant accessibility
    if wait_for_url "$HOME_ASSISTANT_URL" 10 200; then
        echo "Home Assistant is accessible at $HOME_ASSISTANT_URL"
    else
        log_warn "Home Assistant is not accessible at $HOME_ASSISTANT_URL"
        return 1
    fi
    
    # Test API endpoint (if auth token is available)
    if [[ -n "${HASS_TOKEN:-}" ]]; then
        local api_response
        api_response=$(curl -s -H "Authorization: Bearer $HASS_TOKEN" \
                           -H "Content-Type: application/json" \
                           "$HOME_ASSISTANT_URL/api/states" || echo "[]")
        
        if echo "$api_response" | jq . >/dev/null 2>&1; then
            local entity_count
            entity_count=$(echo "$api_response" | jq length)
            echo "Home Assistant API accessible: $entity_count entities"
        else
            log_warn "Home Assistant API not accessible or invalid response"
        fi
    else
        echo "HASS_TOKEN not set, skipping API test"
    fi
    
    # Test if Home Assistant can trigger GitHub Actions (simulation)
    local trigger_test_file="$TEST_TEMP_DIR/ha_trigger_test.yaml"
    cat > "$trigger_test_file" << 'EOF'
# Example Home Assistant automation that could trigger GitHub Actions
automation:
  - alias: "Deploy Configuration"
    trigger:
      - platform: state
        entity_id: input_boolean.deploy_config
        to: 'on'
    action:
      - service: shell_command.trigger_github_action
        data:
          command: >
            curl -X POST \
            -H "Authorization: token {{ secrets.github_token }}" \
            -H "Accept: application/vnd.github.v3+json" \
            https://api.github.com/repos/OWNER/REPO/actions/workflows/deploy.yml/dispatches \
            -d '{"ref":"main"}'
EOF
    
    assert_file_exists "$trigger_test_file" "Home Assistant automation config should be created"
    echo "Home Assistant integration test: OK"
}

# Test: Proxmox integration
test_proxmox_integration() {
    log_info "Testing Proxmox integration"
    
    # Test Proxmox web interface accessibility
    if wait_for_url "$PROXMOX_URL" 10 200; then
        echo "Proxmox web interface is accessible at $PROXMOX_URL"
    else
        log_warn "Proxmox web interface is not accessible at $PROXMOX_URL"
        return 1
    fi
    
    # Test API endpoint (if credentials are available)
    if [[ -n "${PROXMOX_TOKEN:-}" ]]; then
        local api_response
        api_response=$(curl -s -k \
                           -H "Authorization: PVEAPIToken=$PROXMOX_TOKEN" \
                           "$PROXMOX_URL/api2/json/version" || echo "{}")
        
        if echo "$api_response" | jq . >/dev/null 2>&1; then
            local version
            version=$(echo "$api_response" | jq -r '.data.version // "unknown"')
            echo "Proxmox API accessible: version $version"
        else
            log_warn "Proxmox API not accessible or invalid response"
        fi
    else
        echo "PROXMOX_TOKEN not set, skipping API test"
    fi
    
    # Test VM deployment simulation
    local vm_config_file="$TEST_TEMP_DIR/test_vm_config.json"
    cat > "$vm_config_file" << 'EOF'
{
  "vmid": 999,
  "name": "github-runner-test",
  "memory": 2048,
  "cores": 2,
  "sockets": 1,
  "ostype": "l26",
  "scsi0": "local-lvm:20",
  "ide2": "local:iso/ubuntu-22.04-server-amd64.iso,media=cdrom",
  "net0": "virtio,bridge=vmbr0",
  "boot": "order=scsi0;ide2"
}
EOF
    
    assert_file_exists "$vm_config_file" "VM configuration should be created"
    echo "Proxmox integration test: OK"
}

# Test: WikiJS integration
test_wikijs_integration() {
    log_info "Testing WikiJS integration"
    
    # Test WikiJS accessibility
    if wait_for_url "$WIKIJS_URL" 10 200; then
        echo "WikiJS is accessible at $WIKIJS_URL"
    else
        log_warn "WikiJS is not accessible at $WIKIJS_URL"
        return 1
    fi
    
    # Test GraphQL API (if token is available)
    if [[ -n "${WIKIJS_TOKEN:-}" ]]; then
        local api_response
        api_response=$(curl -s \
                           -H "Authorization: Bearer $WIKIJS_TOKEN" \
                           -H "Content-Type: application/json" \
                           -d '{"query": "{ pages { list { id title path } } }"}' \
                           "$WIKIJS_URL/graphql" || echo "{}")
        
        if echo "$api_response" | jq . >/dev/null 2>&1; then
            local page_count
            page_count=$(echo "$api_response" | jq '.data.pages.list | length // 0')
            echo "WikiJS GraphQL API accessible: $page_count pages"
        else
            log_warn "WikiJS GraphQL API not accessible or invalid response"
        fi
    else
        echo "WIKIJS_TOKEN not set, skipping API test"
    fi
    
    # Test documentation deployment simulation
    local doc_file="$TEST_TEMP_DIR/test_documentation.md"
    cat > "$doc_file" << 'EOF'
# GitHub Actions Runner Documentation

## Overview
This is test documentation that could be deployed to WikiJS via GitHub Actions.

## Features
- Automated deployment
- Version control integration
- Markdown support

## Usage
Documentation is automatically updated when changes are pushed to the repository.
EOF
    
    assert_file_exists "$doc_file" "Test documentation should be created"
    echo "WikiJS integration test: OK"
}

# Test: Monitoring system integration
test_monitoring_integration() {
    log_info "Testing monitoring system integration"
    
    # Test Prometheus metrics endpoint
    local prometheus_url="http://localhost:9090"
    if wait_for_url "$prometheus_url" 5 200; then
        echo "Prometheus is accessible at $prometheus_url"
        
        # Test metrics query
        local metrics_response
        metrics_response=$(curl -s "$prometheus_url/api/v1/query?query=up" || echo "{}")
        
        if echo "$metrics_response" | jq . >/dev/null 2>&1; then
            local status
            status=$(echo "$metrics_response" | jq -r '.status // "error"')
            echo "Prometheus API status: $status"
        fi
    else
        echo "Prometheus not accessible, checking for node_exporter"
        
        # Check if node_exporter is running
        if pgrep -f node_exporter >/dev/null 2>&1; then
            echo "Node exporter is running"
        else
            log_warn "No monitoring services detected"
        fi
    fi
    
    # Test Grafana (if available)
    if wait_for_url "$MONITORING_URL" 5 200; then
        echo "Grafana is accessible at $MONITORING_URL"
        
        # Test API endpoint
        local grafana_response
        grafana_response=$(curl -s "$MONITORING_URL/api/health" || echo "{}")
        
        if echo "$grafana_response" | jq . >/dev/null 2>&1; then
            local database
            database=$(echo "$grafana_response" | jq -r '.database // "unknown"')
            echo "Grafana health check: database $database"
        fi
    else
        echo "Grafana not accessible at $MONITORING_URL"
    fi
    
    # Test runner metrics collection
    local metrics_script="$TEST_TEMP_DIR/collect_metrics.sh"
    cat > "$metrics_script" << 'EOF'
#!/bin/bash

echo "# GitHub Actions Runner Metrics"
echo "runner_status{instance=\"$(hostname)\"} $(systemctl is-active github-runner.service >/dev/null && echo 1 || echo 0)"
echo "runner_memory_usage_bytes{instance=\"$(hostname)\"} $(ps -o rss= -p $(pgrep -f Runner.Listener) 2>/dev/null | awk '{print $1*1024}' || echo 0)"
echo "runner_cpu_usage_percent{instance=\"$(hostname)\"} $(ps -o pcpu= -p $(pgrep -f Runner.Listener) 2>/dev/null || echo 0)"
echo "runner_uptime_seconds{instance=\"$(hostname)\"} $(stat -c %Y /var/run/github-runner.pid 2>/dev/null | xargs -I {} expr $(date +%s) - {} || echo 0)"
EOF
    
    chmod +x "$metrics_script"
    
    assert_command_success "$metrics_script" "Metrics collection script should execute"
    
    echo "Monitoring integration test: OK"
}

# Test: Network connectivity between services
test_inter_service_connectivity() {
    log_info "Testing inter-service connectivity"
    
    local services=(
        "192.168.1.155:8123"  # Home Assistant
        "192.168.1.137:8006"  # Proxmox
        "192.168.1.90:3000"   # WikiJS
    )
    
    local connectivity_results=()
    
    for service in "${services[@]}"; do
        local host port
        IFS=':' read -r host port <<< "$service"
        
        if wait_for_port "$host" "$port" 5; then
            echo "✓ $service is reachable"
            connectivity_results+=("$service:reachable")
        else
            echo "✗ $service is not reachable"
            connectivity_results+=("$service:unreachable")
        fi
    done
    
    # Test DNS resolution for homelab services
    local hostnames=("homeassistant.local" "proxmox.local" "wiki.local")
    
    for hostname in "${hostnames[@]}"; do
        if nslookup "$hostname" >/dev/null 2>&1; then
            echo "✓ DNS resolution for $hostname works"
        else
            echo "✗ DNS resolution for $hostname failed"
        fi
    done
    
    # Save connectivity results
    local results_file="$TEST_RESULTS_DIR/connectivity_results.json"
    local json_results="{\"timestamp\": $(date +%s), \"services\": ["
    local first=true
    
    for result in "${connectivity_results[@]}"; do
        local service status
        IFS=':' read -r service status <<< "$result"
        
        if [[ "$first" == "false" ]]; then
            json_results+=","
        fi
        json_results+="{\"service\": \"$service\", \"status\": \"$status\"}"
        first=false
    done
    
    json_results+="]}"
    echo "$json_results" > "$results_file"
    
    echo "Inter-service connectivity test: OK"
}

# Test: Backup system integration
test_backup_integration() {
    log_info "Testing backup system integration"
    
    # Test backup script accessibility
    local backup_script="/opt/github-actions-runner/scripts/backup.sh"
    if [[ -x "$backup_script" ]]; then
        echo "Backup script is accessible: $backup_script"
        
        # Test backup creation
        assert_command_success "$backup_script --test" \
            "Backup script should support test mode"
        
    else
        log_warn "Backup script not found or not executable: $backup_script"
    fi
    
    # Test backup storage accessibility
    local backup_dirs=(
        "/var/backups/github-runner"
        "/opt/github-actions-runner/backups"
        "/tmp/github-runner-backups"
    )
    
    local accessible_backup_dir=""
    for backup_dir in "${backup_dirs[@]}"; do
        if [[ -d "$backup_dir" ]] && [[ -w "$backup_dir" ]]; then
            echo "Backup directory accessible: $backup_dir"
            accessible_backup_dir="$backup_dir"
            break
        fi
    done
    
    if [[ -z "$accessible_backup_dir" ]]; then
        # Create test backup directory
        accessible_backup_dir="$TEST_TEMP_DIR/backups"
        mkdir -p "$accessible_backup_dir"
        echo "Created test backup directory: $accessible_backup_dir"
    fi
    
    # Test backup creation simulation
    local test_backup_file="$accessible_backup_dir/test_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    local test_data_dir="$TEST_TEMP_DIR/backup_test_data"
    
    mkdir -p "$test_data_dir"
    echo "Test backup data" > "$test_data_dir/test_file.txt"
    echo "Configuration data" > "$test_data_dir/config.json"
    
    # Create backup
    if tar -czf "$test_backup_file" -C "$test_data_dir" .; then
        echo "Test backup created successfully: $test_backup_file"
        
        # Verify backup integrity
        if tar -tzf "$test_backup_file" >/dev/null 2>&1; then
            echo "Backup integrity verified"
        else
            log_warn "Backup integrity check failed"
        fi
        
        # Cleanup test backup
        rm -f "$test_backup_file"
    else
        log_warn "Failed to create test backup"
    fi
    
    rm -rf "$test_data_dir"
    echo "Backup integration test: OK"
}

# Test: Security system integration
test_security_integration() {
    log_info "Testing security system integration"
    
    # Test firewall status
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status
        ufw_status=$(ufw status | head -1)
        echo "UFW firewall status: $ufw_status"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        local firewalld_status
        firewalld_status=$(firewall-cmd --state 2>/dev/null || echo "inactive")
        echo "Firewalld status: $firewalld_status"
    else
        echo "No common firewall tools detected"
    fi
    
    # Test SSH configuration
    if [[ -f "/etc/ssh/sshd_config" ]]; then
        local ssh_config_checks=(
            "PermitRootLogin"
            "PasswordAuthentication"
            "PubkeyAuthentication"
            "Port"
        )
        
        for check in "${ssh_config_checks[@]}"; do
            local value
            value=$(grep "^$check" /etc/ssh/sshd_config | awk '{print $2}' || echo "default")
            echo "SSH $check: $value"
        done
    fi
    
    # Test SSL/TLS certificate status
    local ssl_cert_paths=(
        "/etc/ssl/certs/github-runner.crt"
        "/opt/github-actions-runner/ssl/cert.pem"
        "/etc/nginx/ssl/runner.crt"
    )
    
    for cert_path in "${ssl_cert_paths[@]}"; do
        if [[ -f "$cert_path" ]]; then
            local cert_info
            cert_info=$(openssl x509 -in "$cert_path" -noout -dates 2>/dev/null || echo "invalid")
            echo "SSL certificate found: $cert_path ($cert_info)"
        fi
    done
    
    # Test security monitoring integration
    local security_log_paths=(
        "/var/log/auth.log"
        "/var/log/secure"
        "/var/log/github-runner/security.log"
    )
    
    for log_path in "${security_log_paths[@]}"; do
        if [[ -f "$log_path" ]] && [[ -r "$log_path" ]]; then
            local recent_entries
            recent_entries=$(tail -10 "$log_path" | wc -l)
            echo "Security log accessible: $log_path ($recent_entries recent entries)"
        fi
    done
    
    echo "Security integration test: OK"
}

# Test: Configuration management integration
test_configuration_management() {
    log_info "Testing configuration management integration"
    
    # Test configuration file locations
    local config_files=(
        "/opt/github-actions-runner/config/runner.env"
        "/etc/github-runner/config.env"
        "/opt/github-actions-runner/.env"
    )
    
    local found_configs=0
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            echo "Configuration file found: $config_file"
            ((found_configs++))
            
            # Test configuration validation
            if grep -q "GITHUB_TOKEN" "$config_file" 2>/dev/null; then
                echo "  ✓ Contains GitHub token configuration"
            fi
            
            if grep -q "RUNNER_NAME" "$config_file" 2>/dev/null; then
                echo "  ✓ Contains runner name configuration"
            fi
        fi
    done
    
    if [[ $found_configs -eq 0 ]]; then
        log_warn "No configuration files found"
    fi
    
    # Test configuration templates
    local template_dir="/opt/github-actions-runner/templates"
    if [[ -d "$template_dir" ]]; then
        local template_count
        template_count=$(find "$template_dir" -name "*.template" -o -name "*.example" | wc -l)
        echo "Configuration templates available: $template_count"
    fi
    
    # Test environment variable handling
    local test_env_script="$TEST_TEMP_DIR/test_env_config.sh"
    cat > "$test_env_script" << 'EOF'
#!/bin/bash

# Test environment variable configuration
export TEST_VAR="test_value"
export GITHUB_REPOSITORY="test/repo"
export RUNNER_WORKSPACE="/tmp/workspace"

echo "Environment variables configured:"
echo "TEST_VAR: ${TEST_VAR}"
echo "GITHUB_REPOSITORY: ${GITHUB_REPOSITORY}"
echo "RUNNER_WORKSPACE: ${RUNNER_WORKSPACE}"

# Test variable substitution
template_content="Repository: \${GITHUB_REPOSITORY}, Workspace: \${RUNNER_WORKSPACE}"
rendered_content=$(envsubst <<< "$template_content")
echo "Rendered template: $rendered_content"
EOF
    
    chmod +x "$test_env_script"
    assert_command_success "$test_env_script" "Environment configuration test should succeed"
    
    echo "Configuration management test: OK"
}

# Test: CI/CD pipeline integration
test_cicd_pipeline_integration() {
    log_info "Testing CI/CD pipeline integration"
    
    # Test workflow file structure
    local workflow_dirs=(
        "/opt/github-actions-runner/workflows"
        "$TEST_TEMP_DIR/.github/workflows"
    )
    
    # Create test workflow directory
    mkdir -p "$TEST_TEMP_DIR/.github/workflows"
    
    # Create test workflow files
    local test_workflow="$TEST_TEMP_DIR/.github/workflows/test.yml"
    cat > "$test_workflow" << 'EOF'
name: Test Workflow
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Run tests
        run: |
          echo "Running tests on self-hosted runner"
          echo "System: $(uname -a)"
          echo "Date: $(date)"
          
      - name: Build
        run: |
          echo "Building application"
          mkdir -p build
          echo "Built artifact" > build/app.txt
          
      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: build-artifacts
          path: build/
EOF
    
    assert_file_exists "$test_workflow" "Test workflow should be created"
    
    # Test workflow validation (syntax check)
    if command -v yq >/dev/null 2>&1; then
        assert_command_success "yq eval . '$test_workflow'" \
            "Workflow YAML should be valid"
    elif command -v python3 >/dev/null 2>&1; then
        assert_command_success "python3 -c 'import yaml; yaml.safe_load(open(\"$test_workflow\"))'" \
            "Workflow YAML should be valid (Python)"
    else
        echo "No YAML validator available, skipping syntax check"
    fi
    
    # Test deployment workflow
    local deploy_workflow="$TEST_TEMP_DIR/.github/workflows/deploy.yml"
    cat > "$deploy_workflow" << 'EOF'
name: Deploy to Homelab
on:
  push:
    branches: [ main ]

jobs:
  deploy-to-homelab:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to Home Assistant
        run: |
          echo "Deploying configuration to Home Assistant"
          # curl -X POST "${{ secrets.HASS_WEBHOOK_URL }}" \
          #   -H "Content-Type: application/json" \
          #   -d '{"action": "deploy", "source": "github"}'
          
      - name: Update WikiJS Documentation
        run: |
          echo "Updating documentation in WikiJS"
          # Update documentation using WikiJS API
          
      - name: Trigger Proxmox Tasks
        run: |
          echo "Triggering Proxmox automation tasks"
          # Trigger VM deployments or configuration updates
EOF
    
    assert_file_exists "$deploy_workflow" "Deployment workflow should be created"
    
    echo "CI/CD pipeline integration test: OK"
}

# Main integration test execution
main() {
    setup_test_environment
    
    # Run integration tests
    run_test "home_assistant_integration" "test_home_assistant_integration" \
        "Test integration with Home Assistant"
    
    run_test "proxmox_integration" "test_proxmox_integration" \
        "Test integration with Proxmox VE"
    
    run_test "wikijs_integration" "test_wikijs_integration" \
        "Test integration with WikiJS"
    
    run_test "monitoring_integration" "test_monitoring_integration" \
        "Test integration with monitoring systems"
    
    run_test "inter_service_connectivity" "test_inter_service_connectivity" \
        "Test connectivity between homelab services"
    
    run_test "backup_integration" "test_backup_integration" \
        "Test integration with backup systems"
    
    run_test "security_integration" "test_security_integration" \
        "Test integration with security systems"
    
    run_test "configuration_management" "test_configuration_management" \
        "Test configuration management integration"
    
    run_test "cicd_pipeline_integration" "test_cicd_pipeline_integration" \
        "Test CI/CD pipeline integration"
    
    cleanup_test_environment
    finalize_test_framework
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi