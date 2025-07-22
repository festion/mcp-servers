#!/bin/bash

# GitHub Actions Runner - Test Orchestration
# Main test execution script that coordinates all test suites

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/test-framework.sh"

# Test orchestration configuration
TEST_SUITES="${TEST_SUITES:-functional,performance,integration,security}"
TEST_PARALLEL="${TEST_PARALLEL:-false}"
TEST_CONTINUE_ON_FAILURE="${TEST_CONTINUE_ON_FAILURE:-false}"
TEST_OUTPUT_FORMAT="${TEST_OUTPUT_FORMAT:-text}"
TEST_RESULTS_DIR="${TEST_RESULTS_DIR:-/tmp/github-runner-tests}"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run comprehensive test suite for GitHub Actions runner

OPTIONS:
    -h, --help              Show this help message
    -s, --suites SUITES     Test suites to run (comma-separated)
                           Available: functional,performance,integration,security
                           Default: all suites
    -p, --parallel          Run test suites in parallel
    -c, --continue          Continue on test failures
    -f, --format FORMAT     Output format (text|json|html)
    -o, --output DIR        Output directory for test results
    -v, --verbose           Verbose output
    --quick                 Run quick tests only (skip long-running tests)
    --smoke                 Run smoke tests only
    --ci                    CI mode (optimized for continuous integration)

EXAMPLES:
    $0                                    # Run all test suites
    $0 -s functional,security             # Run specific suites
    $0 --parallel --continue              # Parallel execution, continue on failures
    $0 --smoke                            # Quick smoke tests
    $0 --ci -f json                       # CI mode with JSON output

ENVIRONMENT VARIABLES:
    GITHUB_TOKEN           GitHub API token for integration tests
    TEST_REPO             GitHub repository for testing (owner/repo)
    HOME_ASSISTANT_URL    Home Assistant URL for integration tests
    PROXMOX_URL           Proxmox URL for integration tests
    WIKIJS_URL            WikiJS URL for integration tests
    TEST_VERBOSE          Enable verbose output (true/false)
    TEST_PARALLEL         Enable parallel execution (true/false)
EOF
}

# Parse command line arguments
SUITES=""
PARALLEL=false
CONTINUE_ON_FAILURE=false
OUTPUT_FORMAT="text"
OUTPUT_DIR=""
VERBOSE=false
QUICK_MODE=false
SMOKE_MODE=false
CI_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -s|--suites)
            SUITES="$2"
            shift 2
            ;;
        -p|--parallel)
            PARALLEL=true
            shift
            ;;
        -c|--continue)
            CONTINUE_ON_FAILURE=true
            shift
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --smoke)
            SMOKE_MODE=true
            shift
            ;;
        --ci)
            CI_MODE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Set configuration based on arguments
if [[ -n "$SUITES" ]]; then
    TEST_SUITES="$SUITES"
fi

if [[ "$PARALLEL" == true ]]; then
    TEST_PARALLEL=true
fi

if [[ "$CONTINUE_ON_FAILURE" == true ]]; then
    TEST_CONTINUE_ON_FAILURE=true
fi

if [[ "$VERBOSE" == true ]]; then
    TEST_VERBOSE=true
fi

if [[ -n "$OUTPUT_DIR" ]]; then
    TEST_RESULTS_DIR="$OUTPUT_DIR"
fi

# CI mode optimizations
if [[ "$CI_MODE" == true ]]; then
    TEST_PARALLEL=true
    TEST_CONTINUE_ON_FAILURE=true
    OUTPUT_FORMAT="json"
    QUICK_MODE=true
fi

# Smoke mode configuration
if [[ "$SMOKE_MODE" == true ]]; then
    TEST_SUITES="functional"
    QUICK_MODE=true
fi

# Initialize test orchestration
init_test_framework "GitHub Actions Runner Test Suite"

# Test suite definitions
declare -A TEST_SUITE_INFO
TEST_SUITE_INFO[functional]="$SCRIPT_DIR/functional/runner-connectivity.sh,$SCRIPT_DIR/functional/job-execution.sh"
TEST_SUITE_INFO[performance]="$SCRIPT_DIR/performance/load-testing.sh,$SCRIPT_DIR/performance/benchmarks.sh"
TEST_SUITE_INFO[integration]="$SCRIPT_DIR/integration/homelab-integration.sh"
TEST_SUITE_INFO[security]="$SCRIPT_DIR/security/security-tests.sh"

# Function to run a single test suite
run_test_suite() {
    local suite_name="$1"
    local suite_scripts="${TEST_SUITE_INFO[$suite_name]:-}"
    
    if [[ -z "$suite_scripts" ]]; then
        log_error "Unknown test suite: $suite_name"
        return 1
    fi
    
    log_info "Running test suite: $suite_name"
    
    local suite_start_time
    suite_start_time=$(date +%s)
    
    local suite_passed=0
    local suite_failed=0
    
    IFS=',' read -ra SCRIPTS <<< "$suite_scripts"
    for script in "${SCRIPTS[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_warn "Test script not found: $script"
            ((suite_failed++))
            continue
        fi
        
        if [[ ! -x "$script" ]]; then
            log_warn "Test script not executable: $script"
            ((suite_failed++))
            continue
        fi
        
        local script_name
        script_name=$(basename "$script" .sh)
        
        log_info "Executing test script: $script_name"
        
        # Set environment variables for test scripts
        export TEST_RESULTS_DIR="$TEST_RESULTS_DIR/$suite_name"
        export TEST_VERBOSE="$TEST_VERBOSE"
        export TEST_PARALLEL="$TEST_PARALLEL"
        
        if [[ "$QUICK_MODE" == true ]]; then
            export QUICK_MODE=true
            export LOAD_TEST_DURATION=30
            export BENCHMARK_ITERATIONS=2
        fi
        
        # Run test script
        local script_start_time script_end_time script_duration
        script_start_time=$(date +%s)
        
        if "$script" > "$TEST_RESULTS_DIR/${suite_name}_${script_name}.log" 2>&1; then
            ((suite_passed++))
            log_success "✓ $script_name completed successfully"
        else
            ((suite_failed++))
            log_error "✗ $script_name failed"
            
            if [[ "$TEST_VERBOSE" == true ]]; then
                echo "--- Test Script Output ---"
                tail -20 "$TEST_RESULTS_DIR/${suite_name}_${script_name}.log"
                echo "--- End Output ---"
            fi
            
            if [[ "$TEST_CONTINUE_ON_FAILURE" != true ]]; then
                log_error "Stopping test suite execution due to failure"
                return 1
            fi
        fi
        
        script_end_time=$(date +%s)
        script_duration=$((script_end_time - script_start_time))
        
        log_info "Script $script_name completed in ${script_duration}s"
    done
    
    local suite_end_time
    suite_end_time=$(date +%s)
    local suite_duration=$((suite_end_time - suite_start_time))
    
    log_info "Test suite $suite_name summary: $suite_passed passed, $suite_failed failed (${suite_duration}s)"
    
    # Save suite results
    local suite_results_file="$TEST_RESULTS_DIR/${suite_name}_suite_results.json"
    cat > "$suite_results_file" << EOF
{
    "suite_name": "$suite_name",
    "start_time": $suite_start_time,
    "end_time": $suite_end_time,
    "duration": $suite_duration,
    "scripts_passed": $suite_passed,
    "scripts_failed": $suite_failed,
    "total_scripts": $((suite_passed + suite_failed))
}
EOF
    
    return $([[ $suite_failed -eq 0 ]] && echo 0 || echo 1)
}

# Function to run test suites in parallel
run_suites_parallel() {
    local suites=("$@")
    local pids=()
    local results=()
    
    log_info "Running test suites in parallel: ${suites[*]}"
    
    # Start all test suites in background
    for suite in "${suites[@]}"; do
        (
            mkdir -p "$TEST_RESULTS_DIR/$suite"
            run_test_suite "$suite"
            echo $? > "$TEST_RESULTS_DIR/${suite}_exit_code"
        ) &
        pids+=($!)
    done
    
    # Wait for all suites to complete
    for i in "${!pids[@]}"; do
        local pid=${pids[$i]}
        local suite=${suites[$i]}
        
        log_info "Waiting for test suite: $suite (PID: $pid)"
        
        if wait "$pid"; then
            results+=("$suite:PASSED")
            log_success "✓ Test suite $suite completed successfully"
        else
            results+=("$suite:FAILED")
            log_error "✗ Test suite $suite failed"
        fi
    done
    
    # Report parallel execution results
    log_info "Parallel execution results:"
    for result in "${results[@]}"; do
        local suite status
        IFS=':' read -r suite status <<< "$result"
        echo "  $suite: $status"
    done
    
    # Check if any suite failed
    local failed_count=0
    for result in "${results[@]}"; do
        if [[ "$result" == *":FAILED" ]]; then
            ((failed_count++))
        fi
    done
    
    return $([[ $failed_count -eq 0 ]] && echo 0 || echo 1)
}

# Function to run test suites sequentially
run_suites_sequential() {
    local suites=("$@")
    local failed_suites=()
    
    log_info "Running test suites sequentially: ${suites[*]}"
    
    for suite in "${suites[@]}"; do
        mkdir -p "$TEST_RESULTS_DIR/$suite"
        
        if run_test_suite "$suite"; then
            log_success "✓ Test suite $suite completed successfully"
        else
            failed_suites+=("$suite")
            log_error "✗ Test suite $suite failed"
            
            if [[ "$TEST_CONTINUE_ON_FAILURE" != true ]]; then
                log_error "Stopping execution due to test suite failure"
                break
            fi
        fi
    done
    
    if [[ ${#failed_suites[@]} -gt 0 ]]; then
        log_error "Failed test suites: ${failed_suites[*]}"
        return 1
    fi
    
    return 0
}

# Function to validate test environment
validate_test_environment() {
    log_info "Validating test environment"
    
    # Check required tools
    local required_tools=("curl" "jq" "tar" "gzip")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_warn "Missing tools: ${missing_tools[*]}"
        log_warn "Some tests may fail or be skipped"
    fi
    
    # Check test environment variables
    if [[ -z "${GITHUB_TOKEN:-}" ]] && [[ "$TEST_SUITES" == *"integration"* ]]; then
        log_warn "GITHUB_TOKEN not set - some integration tests will be skipped"
    fi
    
    if [[ -z "${TEST_REPO:-}" ]] && [[ "$TEST_SUITES" == *"integration"* ]]; then
        log_warn "TEST_REPO not set - some integration tests will be skipped"
    fi
    
    # Check system resources
    local available_memory
    available_memory=$(free -m | awk 'NR==2{print $7}')
    if [[ "$available_memory" -lt 500 ]]; then
        log_warn "Low available memory: ${available_memory}MB - performance tests may be affected"
    fi
    
    local disk_usage
    disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ "$disk_usage" -gt 90 ]]; then
        log_warn "High disk usage: ${disk_usage}% - tests may fail due to insufficient space"
    fi
    
    echo "Test environment validation completed"
}

# Function to generate test report
generate_test_report() {
    log_info "Generating test report"
    
    local report_file="$TEST_RESULTS_DIR/test_report.$OUTPUT_FORMAT"
    
    case "$OUTPUT_FORMAT" in
        json)
            generate_json_report "$report_file"
            ;;
        html)
            generate_html_report "$report_file"
            ;;
        text|*)
            generate_text_report "$report_file"
            ;;
    esac
    
    log_success "Test report generated: $report_file"
}

generate_json_report() {
    local report_file="$1"
    
    local report_data="{
        \"test_run\": {
            \"timestamp\": $(date +%s),
            \"iso_timestamp\": \"$(date -Iseconds)\",
            \"hostname\": \"$(hostname)\",
            \"test_suites\": \"$TEST_SUITES\",
            \"parallel\": $TEST_PARALLEL,
            \"quick_mode\": $QUICK_MODE,
            \"smoke_mode\": $SMOKE_MODE,
            \"ci_mode\": $CI_MODE
        },
        \"suites\": []
    }"
    
    # Collect suite results
    local suite_files
    suite_files=$(find "$TEST_RESULTS_DIR" -name "*_suite_results.json" 2>/dev/null || echo "")
    
    if [[ -n "$suite_files" ]]; then
        local temp_file=$(mktemp)
        echo "$report_data" > "$temp_file"
        
        while IFS= read -r suite_file; do
            local suite_data
            suite_data=$(cat "$suite_file")
            
            local updated_report
            updated_report=$(jq --argjson suite "$suite_data" '.suites += [$suite]' "$temp_file")
            echo "$updated_report" > "$temp_file"
        done <<< "$suite_files"
        
        mv "$temp_file" "$report_file"
    else
        echo "$report_data" > "$report_file"
    fi
}

generate_html_report() {
    local report_file="$1"
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>GitHub Actions Runner - Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f8f9fa; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .suite { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .suite.passed { border-left: 5px solid #28a745; }
        .suite.failed { border-left: 5px solid #dc3545; }
        .metrics { display: flex; gap: 20px; margin: 20px 0; }
        .metric { background-color: #e9ecef; padding: 15px; border-radius: 5px; text-align: center; min-width: 100px; }
        .metric.passed { background-color: #d4edda; }
        .metric.failed { background-color: #f8d7da; }
        .metric-value { font-size: 24px; font-weight: bold; }
        .metric-label { font-size: 14px; color: #666; }
    </style>
</head>
<body>
    <div class="header">
        <h1>GitHub Actions Runner - Test Report</h1>
        <p><strong>Generated:</strong> <span id="timestamp"></span></p>
        <p><strong>Hostname:</strong> <span id="hostname"></span></p>
        <p><strong>Test Suites:</strong> <span id="test-suites"></span></p>
    </div>
    
    <div class="metrics" id="metrics"></div>
    <div id="suite-results"></div>
    
    <script>
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
        document.getElementById('hostname').textContent = window.location.hostname || 'localhost';
        document.getElementById('test-suites').textContent = 'Loading...';
        
        // Load and display test results
        // (This would be populated with actual test data)
    </script>
</body>
</html>
EOF

    log_info "HTML report template generated (data population requires test results)"
}

generate_text_report() {
    local report_file="$1"
    
    cat > "$report_file" << EOF
GitHub Actions Runner - Test Report
=====================================

Generated: $(date)
Hostname: $(hostname)
Test Suites: $TEST_SUITES
Parallel Execution: $TEST_PARALLEL
Quick Mode: $QUICK_MODE
CI Mode: $CI_MODE

EOF

    # Add suite summaries
    local suite_files
    suite_files=$(find "$TEST_RESULTS_DIR" -name "*_suite_results.json" 2>/dev/null || echo "")
    
    if [[ -n "$suite_files" ]]; then
        echo "Test Suite Results:" >> "$report_file"
        echo "==================" >> "$report_file"
        echo "" >> "$report_file"
        
        while IFS= read -r suite_file; do
            local suite_name scripts_passed scripts_failed duration
            suite_name=$(jq -r '.suite_name' "$suite_file")
            scripts_passed=$(jq -r '.scripts_passed' "$suite_file")
            scripts_failed=$(jq -r '.scripts_failed' "$suite_file")
            duration=$(jq -r '.duration' "$suite_file")
            
            echo "Suite: $suite_name" >> "$report_file"
            echo "  Passed: $scripts_passed" >> "$report_file"
            echo "  Failed: $scripts_failed" >> "$report_file"
            echo "  Duration: ${duration}s" >> "$report_file"
            echo "" >> "$report_file"
        done <<< "$suite_files"
    else
        echo "No test suite results found." >> "$report_file"
    fi
}

# Main test orchestration
main() {
    # Create results directory
    mkdir -p "$TEST_RESULTS_DIR"
    
    log_info "GitHub Actions Runner Test Orchestration"
    log_info "Test suites: $TEST_SUITES"
    log_info "Parallel execution: $TEST_PARALLEL"
    log_info "Output format: $OUTPUT_FORMAT"
    log_info "Results directory: $TEST_RESULTS_DIR"
    
    # Validate environment
    validate_test_environment
    
    # Parse test suites
    IFS=',' read -ra SUITES_ARRAY <<< "$TEST_SUITES"
    
    # Validate suite names
    local valid_suites=()
    for suite in "${SUITES_ARRAY[@]}"; do
        if [[ -n "${TEST_SUITE_INFO[$suite]:-}" ]]; then
            valid_suites+=("$suite")
        else
            log_warn "Unknown test suite: $suite"
        fi
    done
    
    if [[ ${#valid_suites[@]} -eq 0 ]]; then
        log_error "No valid test suites specified"
        exit 1
    fi
    
    # Execute test suites
    local execution_start_time execution_end_time
    execution_start_time=$(date +%s)
    
    if [[ "$TEST_PARALLEL" == true ]] && [[ ${#valid_suites[@]} -gt 1 ]]; then
        run_suites_parallel "${valid_suites[@]}"
    else
        run_suites_sequential "${valid_suites[@]}"
    fi
    
    local test_result=$?
    
    execution_end_time=$(date +%s)
    local total_duration=$((execution_end_time - execution_start_time))
    
    # Generate final report
    generate_test_report
    
    # Print summary
    echo ""
    echo "==============================================="
    echo "TEST EXECUTION SUMMARY"
    echo "==============================================="
    echo "Total Duration: ${total_duration}s"
    echo "Test Suites: ${valid_suites[*]}"
    echo "Results Directory: $TEST_RESULTS_DIR"
    
    if [[ $test_result -eq 0 ]]; then
        log_success "All test suites completed successfully"
    else
        log_error "Some test suites failed"
    fi
    
    echo "==============================================="
    
    exit $test_result
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi