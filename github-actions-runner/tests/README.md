# GitHub Actions Runner - Integration Testing Framework

## Overview

This comprehensive testing framework validates the functionality, performance, security, and integration capabilities of the GitHub Actions runner deployment within the homelab environment.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Test Suites](#test-suites)
3. [Test Execution](#test-execution)
4. [Configuration](#configuration)
5. [Test Results](#test-results)
6. [Continuous Integration](#continuous-integration)
7. [Troubleshooting](#troubleshooting)
8. [Contributing](#contributing)

## Quick Start

### Prerequisites

- GitHub Actions runner installed and configured
- Required tools: `curl`, `jq`, `tar`, `gzip`, `bc`
- Environment variables configured (see [Configuration](#configuration))
- Sufficient system resources (>500MB RAM, <90% disk usage)

### Running All Tests

```bash
# Run all test suites
./tests/run-tests.sh

# Run specific test suites
./tests/run-tests.sh --suites functional,security

# Run tests in parallel
./tests/run-tests.sh --parallel

# Quick smoke test
./tests/run-tests.sh --smoke
```

### Running Individual Test Suites

```bash
# Functional tests
./tests/functional/runner-connectivity.sh
./tests/functional/job-execution.sh

# Performance tests
./tests/performance/load-testing.sh
./tests/performance/benchmarks.sh

# Integration tests
./tests/integration/homelab-integration.sh

# Security tests
./tests/security/security-tests.sh

# Unit tests
./tests/unit-tests.sh
```

## Test Suites

### 1. Functional Testing

**Location**: `tests/functional/`

**Purpose**: Validates core GitHub Actions runner functionality

#### Tests Included:

- **Runner Connectivity** (`runner-connectivity.sh`)
  - GitHub API connectivity and authentication
  - Runner registration and configuration
  - Network connectivity to GitHub services
  - Private network access to homelab services
  - File permissions and ownership
  - Resource availability

- **Job Execution** (`job-execution.sh`)
  - Basic workflow execution simulation
  - Environment variable handling
  - Container execution (if Docker available)
  - Artifact handling simulation
  - Workspace management
  - Error handling and recovery
  - Concurrent job simulation
  - Job cleanup procedures

#### Running Functional Tests:

```bash
# All functional tests
./tests/run-tests.sh --suites functional

# Individual test files
./tests/functional/runner-connectivity.sh
./tests/functional/job-execution.sh
```

### 2. Performance Testing

**Location**: `tests/performance/`

**Purpose**: Validates system performance under various load conditions

#### Tests Included:

- **Load Testing** (`load-testing.sh`)
  - Baseline performance measurement
  - CPU stress testing
  - Memory stress testing
  - Disk I/O stress testing
  - Concurrent job performance
  - Network performance testing
  - Resource limits testing
  - Scalability testing

- **Benchmarks** (`benchmarks.sh`)
  - System boot time benchmarking
  - Service startup time benchmarking
  - File I/O performance benchmarking
  - Network performance benchmarking
  - CPU performance benchmarking
  - Memory performance benchmarking
  - Container operations benchmarking

#### Running Performance Tests:

```bash
# All performance tests
./tests/run-tests.sh --suites performance

# Quick performance tests (reduced duration/iterations)
./tests/run-tests.sh --suites performance --quick

# Individual test files
./tests/performance/load-testing.sh
./tests/performance/benchmarks.sh
```

#### Performance Configuration:

```bash
# Environment variables for performance tuning
export LOAD_TEST_DURATION=60          # Load test duration in seconds
export MAX_CONCURRENT_JOBS=5          # Maximum concurrent jobs for testing
export BENCHMARK_ITERATIONS=5         # Number of benchmark iterations
export MEMORY_THRESHOLD_MB=1000       # Memory usage threshold
export CPU_THRESHOLD_PERCENT=80       # CPU usage threshold
export DISK_THRESHOLD_PERCENT=90      # Disk usage threshold
```

### 3. Integration Testing

**Location**: `tests/integration/`

**Purpose**: Validates integration with existing homelab infrastructure

#### Tests Included:

- **Homelab Integration** (`homelab-integration.sh`)
  - Home Assistant integration
  - Proxmox VE integration
  - WikiJS integration
  - Monitoring system integration
  - Inter-service connectivity
  - Backup system integration
  - Security system integration
  - Configuration management integration
  - CI/CD pipeline integration

#### Running Integration Tests:

```bash
# All integration tests
./tests/run-tests.sh --suites integration

# Individual test file
./tests/integration/homelab-integration.sh
```

#### Integration Configuration:

```bash
# Environment variables for integration testing
export HOME_ASSISTANT_URL="http://192.168.1.155:8123"
export HASS_TOKEN="your_home_assistant_token"
export PROXMOX_URL="http://192.168.1.137:8006"
export PROXMOX_TOKEN="your_proxmox_token"
export WIKIJS_URL="http://192.168.1.90:3000"
export WIKIJS_TOKEN="your_wikijs_token"
export MONITORING_URL="http://localhost:3000"
```

### 4. Security Testing

**Location**: `tests/security/`

**Purpose**: Validates security configuration and best practices

#### Tests Included:

- **Security Tests** (`security-tests.sh`)
  - File permissions and ownership
  - Network security configuration
  - User and process security
  - Container security (if Docker available)
  - Secret management
  - Audit logging
  - Input validation and injection prevention
  - SSL/TLS configuration
  - Access control mechanisms

#### Running Security Tests:

```bash
# All security tests
./tests/run-tests.sh --suites security

# Individual test file
./tests/security/security-tests.sh
```

### 5. Unit Testing

**Location**: `tests/unit-tests.sh`

**Purpose**: Component-level testing for individual scripts and functions

#### Tests Included:

- Health check script functions
- Backup script functions
- Configuration validation
- Logging functions
- Utility functions
- Service management functions
- Security functions
- Performance monitoring functions
- Network functions
- Error handling mechanisms

#### Running Unit Tests:

```bash
# Unit tests
./tests/unit-tests.sh
```

## Test Execution

### Test Orchestration

The main test orchestration script `run-tests.sh` provides comprehensive test execution with the following features:

#### Basic Usage:

```bash
./tests/run-tests.sh [OPTIONS]
```

#### Options:

- `-s, --suites SUITES`: Specify test suites (comma-separated)
- `-p, --parallel`: Run test suites in parallel
- `-c, --continue`: Continue on test failures
- `-f, --format FORMAT`: Output format (text|json|html)
- `-o, --output DIR`: Output directory for test results
- `-v, --verbose`: Verbose output
- `--quick`: Run quick tests only (skip long-running tests)
- `--smoke`: Run smoke tests only
- `--ci`: CI mode (optimized for continuous integration)

#### Examples:

```bash
# Run all test suites
./tests/run-tests.sh

# Run specific suites in parallel
./tests/run-tests.sh --suites functional,security --parallel

# CI mode with JSON output
./tests/run-tests.sh --ci --format json --output /tmp/test-results

# Quick smoke test
./tests/run-tests.sh --smoke

# Verbose execution with continued on failure
./tests/run-tests.sh --verbose --continue
```

### Parallel Execution

Tests can be executed in parallel for faster completion:

```bash
# Parallel test suite execution
./tests/run-tests.sh --parallel

# Parallel execution with specific suites
./tests/run-tests.sh --suites functional,performance,security --parallel
```

### Test Modes

#### Smoke Testing

Quick validation of core functionality:

```bash
./tests/run-tests.sh --smoke
```

#### Quick Testing

Reduced duration/iterations for faster execution:

```bash
./tests/run-tests.sh --quick
```

#### CI Mode

Optimized for continuous integration:

```bash
./tests/run-tests.sh --ci
```

## Configuration

### Environment Variables

#### Required for Integration Tests:

```bash
export GITHUB_TOKEN="ghp_your_github_token"
export TEST_REPO="owner/repository"
```

#### Optional for Enhanced Testing:

```bash
# Home Assistant
export HOME_ASSISTANT_URL="http://192.168.1.155:8123"
export HASS_TOKEN="your_home_assistant_token"

# Proxmox
export PROXMOX_URL="http://192.168.1.137:8006"
export PROXMOX_TOKEN="your_proxmox_token"

# WikiJS
export WIKIJS_URL="http://192.168.1.90:3000"
export WIKIJS_TOKEN="your_wikijs_token"

# Monitoring
export MONITORING_URL="http://localhost:3000"

# Test Configuration
export TEST_VERBOSE="true"
export TEST_PARALLEL="true"
export TEST_CONTINUE_ON_FAILURE="false"
export TEST_RESULTS_DIR="/tmp/github-runner-tests"
```

#### Performance Test Configuration:

```bash
export LOAD_TEST_DURATION=60
export MAX_CONCURRENT_JOBS=5
export BENCHMARK_ITERATIONS=5
export MEMORY_THRESHOLD_MB=1000
export CPU_THRESHOLD_PERCENT=80
export DISK_THRESHOLD_PERCENT=90
```

### Configuration Files

Create a test configuration file at `tests/config/test.env`:

```bash
# tests/config/test.env
GITHUB_TOKEN=your_github_token
TEST_REPO=owner/repository
HOME_ASSISTANT_URL=http://192.168.1.155:8123
PROXMOX_URL=http://192.168.1.137:8006
WIKIJS_URL=http://192.168.1.90:3000
TEST_VERBOSE=true
```

Load configuration before running tests:

```bash
source tests/config/test.env
./tests/run-tests.sh
```

## Test Results

### Result Directory Structure

```
/tmp/github-runner-tests/
├── test-summary.json           # Overall test summary
├── test-report.html           # HTML test report
├── functional/
│   ├── runner-connectivity.log
│   └── job-execution.log
├── performance/
│   ├── load-testing.log
│   ├── benchmarks.log
│   └── benchmarks/
│       ├── cpu_benchmark.json
│       ├── memory_benchmark.json
│       └── benchmark_report.html
├── integration/
│   └── homelab-integration.log
├── security/
│   └── security-tests.log
└── reports/
    ├── test_report.text
    ├── test_report.json
    └── test_report.html
```

### Output Formats

#### Text Format (Default)

Human-readable text output with test results and summaries.

#### JSON Format

Machine-readable JSON output for integration with CI/CD systems:

```bash
./tests/run-tests.sh --format json
```

#### HTML Format

Web-based HTML report with interactive elements:

```bash
./tests/run-tests.sh --format html
```

### Performance Benchmarks

Performance test results include:

- **Baseline Metrics**: System performance without load
- **Stress Test Results**: Performance under various stress conditions
- **Benchmark Data**: Comparative performance measurements
- **Trend Analysis**: Performance over time (if run repeatedly)

### Test Artifacts

Tests generate various artifacts:

- **Log Files**: Detailed execution logs for each test
- **Performance Data**: CSV files with performance metrics
- **Configuration Snapshots**: System configuration at test time
- **Error Reports**: Detailed error information for failed tests

## Continuous Integration

### GitHub Actions Integration

Create `.github/workflows/test.yml`:

```yaml
name: Integration Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM

jobs:
  test:
    runs-on: self-hosted
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup test environment
        run: |
          sudo apt-get update
          sudo apt-get install -y jq bc curl
          
      - name: Run smoke tests
        run: |
          export GITHUB_TOKEN="${{ secrets.GITHUB_TOKEN }}"
          export TEST_REPO="${{ github.repository }}"
          ./tests/run-tests.sh --smoke --ci --format json
          
      - name: Run full test suite
        if: github.event_name == 'schedule'
        run: |
          export GITHUB_TOKEN="${{ secrets.GITHUB_TOKEN }}"
          export TEST_REPO="${{ github.repository }}"
          ./tests/run-tests.sh --ci --format json --parallel
          
      - name: Upload test results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: test-results
          path: /tmp/github-runner-tests/
```

### Scheduled Testing

Set up regular test execution:

```bash
# Add to crontab for daily testing
0 6 * * * cd /opt/github-actions-runner && ./tests/run-tests.sh --smoke --ci > /var/log/github-runner/daily-tests.log 2>&1

# Weekly comprehensive testing
0 2 * * 0 cd /opt/github-actions-runner && ./tests/run-tests.sh --ci --parallel > /var/log/github-runner/weekly-tests.log 2>&1
```

### CI/CD Integration Scripts

Create integration scripts for various CI/CD systems:

#### Jenkins Integration

```bash
#!/bin/bash
# jenkins-test.sh

set -euo pipefail

# Jenkins environment
export TEST_RESULTS_DIR="$WORKSPACE/test-results"
export TEST_VERBOSE="true"

# Run tests
./tests/run-tests.sh --ci --format json --output "$TEST_RESULTS_DIR"

# Archive results
tar -czf test-results.tar.gz -C "$TEST_RESULTS_DIR" .
```

#### GitLab CI Integration

```yaml
# .gitlab-ci.yml
test:
  stage: test
  script:
    - export GITHUB_TOKEN="$GITHUB_TOKEN"
    - export TEST_REPO="$CI_PROJECT_PATH"
    - ./tests/run-tests.sh --ci --format json
  artifacts:
    reports:
      junit: /tmp/github-runner-tests/junit.xml
    paths:
      - /tmp/github-runner-tests/
    expire_in: 1 week
```

## Troubleshooting

### Common Issues

#### 1. Missing Dependencies

**Error**: Command not found (jq, bc, curl, etc.)

**Solution**:
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y jq bc curl tar gzip

# CentOS/RHEL
sudo yum install -y jq bc curl tar gzip

# Or use package manager of your distribution
```

#### 2. Permission Issues

**Error**: Permission denied when accessing files

**Solution**:
```bash
# Ensure test scripts are executable
chmod +x tests/*.sh tests/*/*.sh

# Check file ownership
sudo chown -R $(whoami):$(whoami) tests/

# Verify runner permissions
sudo chown -R github-runner:github-runner /opt/github-actions-runner/
```

#### 3. Network Connectivity Issues

**Error**: Cannot connect to GitHub API or homelab services

**Solution**:
```bash
# Test basic connectivity
curl -I https://api.github.com
ping 192.168.1.155

# Check firewall settings
sudo ufw status
sudo iptables -L

# Verify DNS resolution
nslookup github.com
nslookup homeassistant.local
```

#### 4. Insufficient Resources

**Error**: Tests fail due to low memory or disk space

**Solution**:
```bash
# Check system resources
free -h
df -h

# Clean up temporary files
sudo rm -rf /tmp/github-runner-tests-*
docker system prune -f

# Adjust test parameters
export LOAD_TEST_DURATION=30
export BENCHMARK_ITERATIONS=2
./tests/run-tests.sh --quick
```

#### 5. Test Environment Issues

**Error**: Tests fail due to incorrect configuration

**Solution**:
```bash
# Verify environment variables
env | grep -E "(GITHUB|TEST|HASS|PROXMOX|WIKIJS)"

# Check runner service status
systemctl status github-runner.service

# Validate configuration files
./tests/unit-tests.sh
```

### Debug Mode

Enable verbose debugging:

```bash
# Enable debug output
export TEST_VERBOSE=true

# Run with maximum verbosity
./tests/run-tests.sh --verbose

# Check individual test logs
tail -f /tmp/github-runner-tests/functional/runner-connectivity.log
```

### Log Analysis

Analyze test logs for issues:

```bash
# Search for errors in all logs
grep -r "ERROR\|FAILED\|ASSERTION FAILED" /tmp/github-runner-tests/

# Check test summary
cat /tmp/github-runner-tests/test-summary.json | jq .

# Review failed tests
jq '.tests[] | select(.result == "FAILED")' /tmp/github-runner-tests/test-summary.json
```

### Performance Issues

Investigate performance problems:

```bash
# Check system performance during tests
top -p $(pgrep -f run-tests.sh)
iostat 1
vmstat 1

# Review performance test results
cat /tmp/github-runner-tests/performance/load-testing.log

# Check benchmark results
cat /tmp/github-runner-tests/performance/benchmarks/benchmark_report.html
```

## Contributing

### Adding New Tests

1. **Create test script** in appropriate directory:
   ```bash
   # For functional tests
   cp tests/functional/runner-connectivity.sh tests/functional/new-test.sh
   
   # For integration tests
   cp tests/integration/homelab-integration.sh tests/integration/new-integration.sh
   ```

2. **Follow test framework patterns**:
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/../common/test-framework.sh"
   
   init_test_framework "New Test Suite"
   
   test_new_functionality() {
       log_info "Testing new functionality"
       # Test implementation
       echo "New functionality test: OK"
   }
   
   main() {
       setup_test_environment
       
       run_test "new_functionality" "test_new_functionality" \
           "Test description"
       
       cleanup_test_environment
       finalize_test_framework
   }
   
   if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
       main "$@"
   fi
   ```

3. **Update test orchestration**:
   - Add new test to `run-tests.sh` suite definitions
   - Update documentation

4. **Test your additions**:
   ```bash
   # Test new script individually
   ./tests/functional/new-test.sh
   
   # Test with orchestration
   ./tests/run-tests.sh --suites functional
   ```

### Code Style Guidelines

- Use bash strict mode: `set -euo pipefail`
- Follow existing naming conventions
- Include comprehensive error handling
- Add descriptive log messages
- Use assertion functions for validation
- Clean up resources in test cleanup

### Testing Best Practices

- **Idempotent**: Tests should be repeatable
- **Isolated**: Tests should not depend on each other
- **Fast**: Optimize for quick execution
- **Reliable**: Minimize flaky tests
- **Informative**: Provide clear error messages

### Documentation

When adding new tests:

1. Update this README.md
2. Add inline documentation to test scripts
3. Include usage examples
4. Document configuration requirements
5. Add troubleshooting information

---

## Support

For questions, issues, or contributions:

1. **Check existing documentation** in this README
2. **Review test logs** for specific error information
3. **Run diagnostic tests** to identify issues
4. **Create detailed issue reports** with logs and configuration

## License

This testing framework is part of the GitHub Actions runner deployment and follows the same licensing terms as the main project.