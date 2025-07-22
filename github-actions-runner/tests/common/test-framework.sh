#!/bin/bash

# GitHub Actions Runner - Test Framework Core
# Common testing utilities and framework functions

set -euo pipefail

# Test framework configuration
TEST_FRAMEWORK_VERSION="1.0.0"
TEST_START_TIME=""
TEST_END_TIME=""
TEST_RESULTS_DIR="${TEST_RESULTS_DIR:-/tmp/github-runner-tests}"
TEST_VERBOSE="${TEST_VERBOSE:-false}"
TEST_PARALLEL="${TEST_PARALLEL:-false}"
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    if [[ "$TEST_VERBOSE" == "true" ]]; then
        echo -e "[DEBUG] $*"
    fi
}

# Test framework initialization
init_test_framework() {
    local test_name="$1"
    
    TEST_START_TIME=$(date +%s)
    
    # Create results directory
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Initialize test report
    cat > "$TEST_RESULTS_DIR/test-summary.json" << EOF
{
    "test_name": "$test_name",
    "framework_version": "$TEST_FRAMEWORK_VERSION",
    "start_time": "$TEST_START_TIME",
    "hostname": "$(hostname)",
    "total": 0,
    "passed": 0,
    "failed": 0,
    "skipped": 0,
    "tests": []
}
EOF

    log_info "Test framework initialized: $test_name"
    log_info "Results directory: $TEST_RESULTS_DIR"
}

# Test execution wrapper
run_test() {
    local test_name="$1"
    local test_function="$2"
    local test_description="${3:-}"
    local test_timeout="${4:-$TEST_TIMEOUT}"
    
    ((TESTS_TOTAL++))
    
    log_info "Running test: $test_name"
    if [[ -n "$test_description" ]]; then
        log_debug "Description: $test_description"
    fi
    
    local test_start=$(date +%s)
    local test_result="UNKNOWN"
    local test_output=""
    local test_error=""
    
    # Create test-specific log file
    local test_log="$TEST_RESULTS_DIR/${test_name}.log"
    
    # Run test with timeout
    if timeout "$test_timeout" bash -c "$test_function" > "$test_log" 2>&1; then
        test_result="PASSED"
        ((TESTS_PASSED++))
        log_success "✓ $test_name"
    else
        local exit_code=$?
        test_result="FAILED"
        ((TESTS_FAILED++))
        
        if [[ $exit_code -eq 124 ]]; then
            test_error="Test timed out after ${test_timeout}s"
            log_error "✗ $test_name (TIMEOUT)"
        else
            test_error="Test failed with exit code $exit_code"
            log_error "✗ $test_name (FAILED)"
        fi
        
        # Show error output if verbose
        if [[ "$TEST_VERBOSE" == "true" ]] && [[ -f "$test_log" ]]; then
            echo "--- Test Output ---"
            cat "$test_log"
            echo "--- End Output ---"
        fi
    fi
    
    local test_end=$(date +%s)
    local test_duration=$((test_end - test_start))
    
    # Update test results
    update_test_results "$test_name" "$test_result" "$test_duration" "$test_description" "$test_error"
    
    return $([ "$test_result" = "PASSED" ] && echo 0 || echo 1)
}

# Skip a test
skip_test() {
    local test_name="$1"
    local reason="${2:-No reason provided}"
    
    ((TESTS_TOTAL++))
    ((TESTS_SKIPPED++))
    
    log_warn "⊘ $test_name (SKIPPED: $reason)"
    
    update_test_results "$test_name" "SKIPPED" "0" "$reason" ""
}

# Update test results JSON
update_test_results() {
    local test_name="$1"
    local result="$2"
    local duration="$3"
    local description="$4"
    local error="$5"
    
    local temp_file=$(mktemp)
    
    jq --arg name "$test_name" \
       --arg result "$result" \
       --arg duration "$duration" \
       --arg desc "$description" \
       --arg error "$error" \
       '.tests += [{
           "name": $name,
           "result": $result,
           "duration": ($duration | tonumber),
           "description": $desc,
           "error": $error,
           "timestamp": now
       }] | 
       .total = (.tests | length) |
       .passed = (.tests | map(select(.result == "PASSED")) | length) |
       .failed = (.tests | map(select(.result == "FAILED")) | length) |
       .skipped = (.tests | map(select(.result == "SKIPPED")) | length)' \
       "$TEST_RESULTS_DIR/test-summary.json" > "$temp_file"
    
    mv "$temp_file" "$TEST_RESULTS_DIR/test-summary.json"
}

# Finalize test framework
finalize_test_framework() {
    TEST_END_TIME=$(date +%s)
    local total_duration=$((TEST_END_TIME - TEST_START_TIME))
    
    # Update final summary
    local temp_file=$(mktemp)
    jq --arg end_time "$TEST_END_TIME" \
       --arg duration "$total_duration" \
       '. + {
           "end_time": $end_time,
           "total_duration": ($duration | tonumber)
       }' "$TEST_RESULTS_DIR/test-summary.json" > "$temp_file"
    mv "$temp_file" "$TEST_RESULTS_DIR/test-summary.json"
    
    # Print summary
    echo ""
    echo "==============================================="
    echo "TEST SUMMARY"
    echo "==============================================="
    echo "Total Tests:   $TESTS_TOTAL"
    echo "Passed:        $TESTS_PASSED"
    echo "Failed:        $TESTS_FAILED"
    echo "Skipped:       $TESTS_SKIPPED"
    echo "Duration:      ${total_duration}s"
    echo "Success Rate:  $(( TESTS_TOTAL > 0 ? (TESTS_PASSED * 100) / TESTS_TOTAL : 0 ))%"
    echo "==============================================="
    
    # Generate detailed report
    generate_test_report
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Generate detailed test report
generate_test_report() {
    local report_file="$TEST_RESULTS_DIR/test-report.html"
    local json_file="$TEST_RESULTS_DIR/test-summary.json"
    
    if [[ ! -f "$json_file" ]]; then
        log_warn "No test results found, skipping report generation"
        return
    fi
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>GitHub Actions Runner - Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f8f9fa; padding: 20px; border-radius: 5px; }
        .summary { display: flex; gap: 20px; margin: 20px 0; }
        .metric { background-color: #e9ecef; padding: 15px; border-radius: 5px; text-align: center; }
        .metric.passed { background-color: #d4edda; }
        .metric.failed { background-color: #f8d7da; }
        .metric.skipped { background-color: #fff3cd; }
        .test-list { margin-top: 20px; }
        .test-item { padding: 10px; margin: 5px 0; border-radius: 3px; }
        .test-item.passed { background-color: #d4edda; }
        .test-item.failed { background-color: #f8d7da; }
        .test-item.skipped { background-color: #fff3cd; }
        .test-name { font-weight: bold; }
        .test-duration { float: right; color: #666; }
        .test-error { color: #721c24; font-style: italic; margin-top: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>GitHub Actions Runner - Test Report</h1>
        <p>Generated on: <span id="timestamp"></span></p>
        <p>Framework Version: <span id="framework-version"></span></p>
        <p>Total Duration: <span id="total-duration"></span>s</p>
    </div>
    
    <div class="summary">
        <div class="metric">
            <h3>Total Tests</h3>
            <div id="total-tests">0</div>
        </div>
        <div class="metric passed">
            <h3>Passed</h3>
            <div id="passed-tests">0</div>
        </div>
        <div class="metric failed">
            <h3>Failed</h3>
            <div id="failed-tests">0</div>
        </div>
        <div class="metric skipped">
            <h3>Skipped</h3>
            <div id="skipped-tests">0</div>
        </div>
    </div>
    
    <div class="test-list">
        <h2>Test Results</h2>
        <div id="test-results"></div>
    </div>
    
    <script>
EOF

    # Embed JSON data and JavaScript
    echo "const testData = " >> "$report_file"
    cat "$json_file" >> "$report_file"
    echo ";" >> "$report_file"
    
    cat >> "$report_file" << 'EOF'
        
        // Populate report with data
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
        document.getElementById('framework-version').textContent = testData.framework_version;
        document.getElementById('total-duration').textContent = testData.total_duration || 0;
        document.getElementById('total-tests').textContent = testData.total;
        document.getElementById('passed-tests').textContent = testData.passed;
        document.getElementById('failed-tests').textContent = testData.failed;
        document.getElementById('skipped-tests').textContent = testData.skipped;
        
        // Generate test list
        const testResults = document.getElementById('test-results');
        testData.tests.forEach(test => {
            const div = document.createElement('div');
            div.className = `test-item ${test.result.toLowerCase()}`;
            
            const html = `
                <div class="test-name">${test.name}</div>
                <div class="test-duration">${test.duration}s</div>
                ${test.description ? `<div>${test.description}</div>` : ''}
                ${test.error ? `<div class="test-error">Error: ${test.error}</div>` : ''}
            `;
            
            div.innerHTML = html;
            testResults.appendChild(div);
        });
    </script>
</body>
</html>
EOF

    log_info "Test report generated: $report_file"
}

# Assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$expected" != "$actual" ]]; then
        echo "ASSERTION FAILED: $message"
        echo "Expected: $expected"
        echo "Actual: $actual"
        return 1
    fi
    return 0
}

assert_not_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$expected" == "$actual" ]]; then
        echo "ASSERTION FAILED: $message"
        echo "Expected NOT: $expected"
        echo "Actual: $actual"
        return 1
    fi
    return 0
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$haystack" != *"$needle"* ]]; then
        echo "ASSERTION FAILED: $message"
        echo "String: $haystack"
        echo "Should contain: $needle"
        return 1
    fi
    return 0
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "ASSERTION FAILED: $message"
        echo "String: $haystack"
        echo "Should NOT contain: $needle"
        return 1
    fi
    return 0
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File does not exist}"
    
    if [[ ! -f "$file" ]]; then
        echo "ASSERTION FAILED: $message"
        echo "File: $file"
        return 1
    fi
    return 0
}

assert_directory_exists() {
    local dir="$1"
    local message="${2:-Directory does not exist}"
    
    if [[ ! -d "$dir" ]]; then
        echo "ASSERTION FAILED: $message"
        echo "Directory: $dir"
        return 1
    fi
    return 0
}

assert_command_success() {
    local cmd="$1"
    local message="${2:-Command failed}"
    
    if ! eval "$cmd" >/dev/null 2>&1; then
        echo "ASSERTION FAILED: $message"
        echo "Command: $cmd"
        return 1
    fi
    return 0
}

assert_command_failure() {
    local cmd="$1"
    local message="${2:-Command should have failed}"
    
    if eval "$cmd" >/dev/null 2>&1; then
        echo "ASSERTION FAILED: $message"
        echo "Command: $cmd"
        return 1
    fi
    return 0
}

assert_service_running() {
    local service="$1"
    local message="${2:-Service is not running}"
    
    if ! systemctl is-active "$service" >/dev/null 2>&1; then
        echo "ASSERTION FAILED: $message"
        echo "Service: $service"
        return 1
    fi
    return 0
}

assert_port_open() {
    local host="$1"
    local port="$2"
    local message="${3:-Port is not open}"
    
    if ! timeout 5 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        echo "ASSERTION FAILED: $message"
        echo "Host: $host"
        echo "Port: $port"
        return 1
    fi
    return 0
}

assert_url_accessible() {
    local url="$1"
    local expected_code="${2:-200}"
    local message="${3:-URL is not accessible}"
    
    local actual_code
    actual_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [[ "$actual_code" != "$expected_code" ]]; then
        echo "ASSERTION FAILED: $message"
        echo "URL: $url"
        echo "Expected code: $expected_code"
        echo "Actual code: $actual_code"
        return 1
    fi
    return 0
}

# Test environment helpers
setup_test_environment() {
    log_debug "Setting up test environment"
    
    # Create temporary directories
    export TEST_TEMP_DIR=$(mktemp -d)
    export TEST_CONFIG_DIR="$TEST_TEMP_DIR/config"
    export TEST_DATA_DIR="$TEST_TEMP_DIR/data"
    
    mkdir -p "$TEST_CONFIG_DIR" "$TEST_DATA_DIR"
    
    log_debug "Test temp dir: $TEST_TEMP_DIR"
}

cleanup_test_environment() {
    log_debug "Cleaning up test environment"
    
    if [[ -n "${TEST_TEMP_DIR:-}" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Test data helpers
create_test_file() {
    local file="$1"
    local content="${2:-test content}"
    
    mkdir -p "$(dirname "$file")"
    echo "$content" > "$file"
}

create_test_config() {
    local config_file="$1"
    local config_data="$2"
    
    mkdir -p "$(dirname "$config_file")"
    echo "$config_data" > "$config_file"
}

# Network testing helpers
wait_for_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-30}"
    
    local count=0
    while [[ $count -lt $timeout ]]; do
        if timeout 1 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
            return 0
        fi
        ((count++))
        sleep 1
    done
    
    return 1
}

wait_for_url() {
    local url="$1"
    local timeout="${2:-30}"
    local expected_code="${3:-200}"
    
    local count=0
    while [[ $count -lt $timeout ]]; do
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
        
        if [[ "$code" == "$expected_code" ]]; then
            return 0
        fi
        
        ((count++))
        sleep 1
    done
    
    return 1
}

# GitHub API helpers
github_api_request() {
    local endpoint="$1"
    local method="${2:-GET}"
    local token="${GITHUB_TOKEN:-}"
    
    if [[ -z "$token" ]]; then
        echo "ERROR: GITHUB_TOKEN not set"
        return 1
    fi
    
    curl -s \
        -X "$method" \
        -H "Authorization: token $token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com$endpoint"
}

# Docker helpers
docker_container_running() {
    local container="$1"
    docker ps --format "{{.Names}}" | grep -q "^${container}$"
}

docker_image_exists() {
    local image="$1"
    docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image}$"
}

# Performance measurement helpers
measure_execution_time() {
    local cmd="$1"
    local start_time end_time duration
    
    start_time=$(date +%s.%N)
    eval "$cmd"
    local result=$?
    end_time=$(date +%s.%N)
    
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    echo "$duration"
    return $result
}

measure_memory_usage() {
    local pid="$1"
    
    if [[ -f "/proc/$pid/status" ]]; then
        grep VmRSS "/proc/$pid/status" | awk '{print $2}'
    else
        echo "0"
    fi
}

# Load testing helpers
run_concurrent_tests() {
    local test_function="$1"
    local concurrency="${2:-5}"
    local iterations="${3:-10}"
    
    local pids=()
    local results_dir="$TEST_TEMP_DIR/concurrent"
    mkdir -p "$results_dir"
    
    for ((i=1; i<=concurrency; i++)); do
        (
            for ((j=1; j<=iterations; j++)); do
                if eval "$test_function" > "$results_dir/worker_${i}_${j}.log" 2>&1; then
                    echo "PASS" > "$results_dir/worker_${i}_${j}.result"
                else
                    echo "FAIL" > "$results_dir/worker_${i}_${j}.result"
                fi
            done
        ) &
        pids+=($!)
    done
    
    # Wait for all workers to complete
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # Count results
    local total_tests=$((concurrency * iterations))
    local passed_tests
    passed_tests=$(find "$results_dir" -name "*.result" -exec grep -l "PASS" {} \; | wc -l)
    local failed_tests=$((total_tests - passed_tests))
    
    echo "Concurrent test results: $passed_tests passed, $failed_tests failed out of $total_tests"
    
    return $([[ $failed_tests -eq 0 ]] && echo 0 || echo 1)
}

# Export all functions for use in test scripts
export -f log_info log_success log_warn log_error log_debug
export -f init_test_framework run_test skip_test finalize_test_framework
export -f assert_equals assert_not_equals assert_contains assert_not_contains
export -f assert_file_exists assert_directory_exists
export -f assert_command_success assert_command_failure
export -f assert_service_running assert_port_open assert_url_accessible
export -f setup_test_environment cleanup_test_environment
export -f create_test_file create_test_config
export -f wait_for_port wait_for_url github_api_request
export -f docker_container_running docker_image_exists
export -f measure_execution_time measure_memory_usage run_concurrent_tests