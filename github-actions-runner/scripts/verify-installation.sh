#!/bin/bash

# GitHub Actions Runner Installation Verification Script
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
tests_passed=0
tests_failed=0
tests_total=0

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_test() {
    echo -n "Testing: $1... "
    ((tests_total++))
}

print_pass() {
    echo -e "${GREEN}PASS${NC}"
    ((tests_passed++))
}

print_fail() {
    echo -e "${RED}FAIL${NC}"
    ((tests_failed++))
    if [[ -n "$1" ]]; then
        echo -e "${RED}  Error: $1${NC}"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠ Warning: $1${NC}"
}

# Test Docker installation
test_docker() {
    print_header "Docker Installation"
    
    print_test "Docker command availability"
    if command -v docker &> /dev/null; then
        print_pass
    else
        print_fail "Docker not found in PATH"
        return 1
    fi
    
    print_test "Docker service status"
    if systemctl is-active --quiet docker; then
        print_pass
    else
        print_fail "Docker service not running"
        return 1
    fi
    
    print_test "Docker permissions"
    if docker ps &> /dev/null; then
        print_pass
    else
        print_fail "Cannot access Docker daemon"
        return 1
    fi
    
    print_test "Docker Compose availability"
    if command -v docker-compose &> /dev/null; then
        print_pass
    else
        print_fail "Docker Compose not found"
        return 1
    fi
}

# Test environment configuration
test_environment() {
    print_header "Environment Configuration"
    
    print_test "Environment file exists"
    if [[ -f ".env" ]]; then
        print_pass
    else
        print_fail ".env file not found"
        return 1
    fi
    
    # Source environment file
    source .env
    
    print_test "GitHub token configured"
    if [[ -n "$GITHUB_TOKEN" && "$GITHUB_TOKEN" != "your-personal-access-token" ]]; then
        print_pass
    else
        print_fail "GitHub token not configured"
        return 1
    fi
    
    print_test "Repository configuration"
    if [[ -n "$GITHUB_OWNER" && -n "$GITHUB_REPOSITORY" ]]; then
        print_pass
    else
        print_fail "Repository not configured"
        return 1
    fi
    
    print_test "Runner name configured"
    if [[ -n "$RUNNER_NAME" ]]; then
        print_pass
    else
        print_fail "Runner name not configured"
        return 1
    fi
}

# Test network connectivity
test_connectivity() {
    print_header "Network Connectivity"
    
    print_test "GitHub API access"
    if curl -s --max-time 10 https://api.github.com/zen &> /dev/null; then
        print_pass
    else
        print_fail "Cannot reach GitHub API"
    fi
    
    print_test "Docker Hub access"
    if curl -s --max-time 10 https://registry-1.docker.io &> /dev/null; then
        print_pass
    else
        print_fail "Cannot reach Docker Hub"
    fi
    
    print_test "Home Assistant connectivity"
    if ping -c 1 -W 5 192.168.1.155 &> /dev/null; then
        print_pass
    else
        print_fail "Cannot reach Home Assistant (192.168.1.155)"
    fi
    
    # Test GitHub token validity
    print_test "GitHub token validity"
    source .env
    if curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | grep -q "login"; then
        print_pass
    else
        print_fail "Invalid GitHub token"
    fi
}

# Test SSH configuration
test_ssh() {
    print_header "SSH Configuration"
    
    print_test "SSH private key exists"
    if [[ -f "config/homeassistant_key" ]]; then
        print_pass
    else
        print_fail "SSH private key not found"
        return 1
    fi
    
    print_test "SSH key permissions"
    if [[ "$(stat -c %a config/homeassistant_key)" == "600" ]]; then
        print_pass
    else
        print_fail "SSH key has incorrect permissions"
    fi
    
    print_test "SSH public key exists"
    if [[ -f "config/homeassistant_key.pub" ]]; then
        print_pass
    else
        print_fail "SSH public key not found"
    fi
    
    print_test "SSH connectivity to Home Assistant"
    if timeout 10 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i config/homeassistant_key homeassistant@192.168.1.155 "echo 'SSH test successful'" &> /dev/null; then
        print_pass
    else
        print_fail "SSH connection failed"
        print_warning "Ensure public key is added to Home Assistant ~/.ssh/authorized_keys"
    fi
}

# Test runner registration
test_runner_registration() {
    print_header "Runner Registration"
    
    print_test "Runner configuration exists"
    if [[ -f "config/.runner" ]]; then
        print_pass
    else
        print_fail "Runner not registered"
        echo -e "${YELLOW}Run: ./scripts/register-runner.sh${NC}"
        return 1
    fi
    
    print_test "Runner credentials exist"
    if [[ -f "config/.credentials" ]]; then
        print_pass
    else
        print_fail "Runner credentials missing"
        return 1
    fi
}

# Test container services
test_containers() {
    print_header "Container Services"
    
    print_test "Docker Compose file exists"
    if [[ -f "docker-compose.yml" ]]; then
        print_pass
    else
        print_fail "docker-compose.yml not found"
        return 1
    fi
    
    print_test "Runner container running"
    if docker-compose ps github-runner | grep -q "Up"; then
        print_pass
    else
        print_fail "Runner container not running"
        echo -e "${YELLOW}Run: docker-compose up -d${NC}"
    fi
    
    print_test "Runner container health"
    if docker inspect github-actions-runner --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
        print_pass
    else
        print_fail "Runner container unhealthy"
        echo -e "${YELLOW}Check: docker-compose logs github-runner${NC}"
    fi
    
    print_test "Runner process status"
    if docker exec github-actions-runner pgrep -f "Runner.Listener" &> /dev/null; then
        print_pass
    else
        print_fail "Runner process not running"
    fi
}

# Test GitHub integration
test_github_integration() {
    print_header "GitHub Integration"
    
    source .env
    
    print_test "Repository API access"
    if curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPOSITORY" | grep -q "full_name"; then
        print_pass
    else
        print_fail "Cannot access repository via API"
    fi
    
    print_test "Runner visible in GitHub"
    if curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPOSITORY/actions/runners" | grep -q "$RUNNER_NAME"; then
        print_pass
    else
        print_fail "Runner not visible in GitHub"
        print_warning "Check repository settings and runner registration"
    fi
    
    print_test "Actions enabled"
    if curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPOSITORY" | grep -q '"has_actions": true'; then
        print_pass
    else
        print_fail "Actions not enabled for repository"
    fi
}

# Test workspace configuration
test_workspace() {
    print_header "Workspace Configuration"
    
    print_test "Workspace directory exists"
    if [[ -d "workspace" ]]; then
        print_pass
    else
        print_fail "Workspace directory missing"
    fi
    
    print_test "Config directory exists"
    if [[ -d "config" ]]; then
        print_pass
    else
        print_fail "Config directory missing"
    fi
    
    print_test "Logs directory exists"
    if [[ -d "logs" ]]; then
        print_pass
    else
        print_fail "Logs directory missing"
    fi
    
    print_test "Scripts directory exists"
    if [[ -d "scripts" ]]; then
        print_pass
    else
        print_fail "Scripts directory missing"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}GitHub Actions Runner Installation Verification${NC}"
    echo -e "${BLUE}===============================================${NC}"
    echo
    
    # Change to script directory
    cd "$(dirname "$0")/.."
    
    # Run all tests
    test_docker
    echo
    test_environment
    echo
    test_connectivity
    echo
    test_ssh
    echo
    test_runner_registration
    echo
    test_containers
    echo
    test_github_integration
    echo
    test_workspace
    echo
    
    # Print summary
    print_header "Verification Summary"
    echo -e "Tests passed: ${GREEN}$tests_passed${NC}/$tests_total"
    echo -e "Tests failed: ${RED}$tests_failed${NC}/$tests_total"
    
    if [[ $tests_failed -eq 0 ]]; then
        echo -e "${GREEN}✓ All verification tests passed!${NC}"
        echo -e "${GREEN}Your GitHub Actions runner is properly installed and configured.${NC}"
        echo
        echo "Next steps:"
        echo "1. Create a test workflow in your repository"
        echo "2. Run a test job with 'runs-on: self-hosted'"
        echo "3. Monitor the runner logs: docker-compose logs -f github-runner"
        exit 0
    else
        echo -e "${RED}✗ Some verification tests failed.${NC}"
        echo -e "${RED}Please resolve the issues above before using the runner.${NC}"
        exit 1
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi