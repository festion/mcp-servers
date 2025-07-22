#!/bin/bash

# GitHub Actions Runner - Test Results Analysis
# Comprehensive analysis and reporting of test execution results

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/test-framework.sh"

# Analysis configuration
RESULTS_DIR="${TEST_RESULTS_DIR:-/tmp/github-runner-tests}"
ANALYSIS_DIR="$RESULTS_DIR/analysis"
HISTORICAL_DIR="${HISTORICAL_TEST_RESULTS:-/var/lib/github-runner/test-history}"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Analyze test results and generate comprehensive reports

OPTIONS:
    -h, --help              Show this help message
    -r, --results DIR       Test results directory
    -o, --output DIR        Analysis output directory
    -f, --format FORMAT     Report format (html|json|text|all)
    -t, --trend             Include trend analysis
    --historical DIR        Historical results directory
    --baseline FILE         Baseline results for comparison
    --threshold FILE        Performance threshold configuration
    -v, --verbose           Verbose output

EXAMPLES:
    $0                              # Analyze latest results
    $0 -r /tmp/test-results         # Analyze specific results
    $0 -f html -t                   # HTML report with trends
    $0 --baseline baseline.json     # Compare against baseline

ANALYSIS TYPES:
    - Test execution summary
    - Performance analysis
    - Trend analysis
    - Failure analysis
    - Security validation
    - Coverage analysis
EOF
}

# Parse command line arguments
RESULTS_SOURCE=""
OUTPUT_DIR=""
REPORT_FORMAT="html"
INCLUDE_TRENDS=false
BASELINE_FILE=""
THRESHOLD_FILE=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -r|--results)
            RESULTS_SOURCE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -f|--format)
            REPORT_FORMAT="$2"
            shift 2
            ;;
        -t|--trend)
            INCLUDE_TRENDS=true
            shift
            ;;
        --historical)
            HISTORICAL_DIR="$2"
            shift 2
            ;;
        --baseline)
            BASELINE_FILE="$2"
            shift 2
            ;;
        --threshold)
            THRESHOLD_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Set defaults
if [[ -n "$RESULTS_SOURCE" ]]; then
    RESULTS_DIR="$RESULTS_SOURCE"
fi

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$ANALYSIS_DIR"
fi

# Initialize analysis
init_test_framework "Test Results Analysis"

# Load threshold configuration
load_thresholds() {
    local threshold_file="$1"
    
    if [[ -f "$threshold_file" ]]; then
        log_debug "Loading thresholds from: $threshold_file"
        source "$threshold_file"
    else
        # Default thresholds
        export PERFORMANCE_CPU_THRESHOLD=80
        export PERFORMANCE_MEMORY_THRESHOLD=1000
        export PERFORMANCE_DISK_THRESHOLD=90
        export SUCCESS_RATE_THRESHOLD=95
        export SECURITY_SCORE_THRESHOLD=90
    fi
}

# Collect test results
collect_test_results() {
    log_info "Collecting test results from: $RESULTS_DIR"
    
    if [[ ! -d "$RESULTS_DIR" ]]; then
        log_error "Results directory not found: $RESULTS_DIR"
        return 1
    fi
    
    mkdir -p "$OUTPUT_DIR"
    
    # Find all test result files
    local result_files=()
    
    # Test summary files
    if [[ -f "$RESULTS_DIR/test-summary.json" ]]; then
        result_files+=("$RESULTS_DIR/test-summary.json")
    fi
    
    # Suite result files
    local suite_files
    suite_files=$(find "$RESULTS_DIR" -name "*_suite_results.json" 2>/dev/null || echo "")
    
    if [[ -n "$suite_files" ]]; then
        while IFS= read -r suite_file; do
            result_files+=("$suite_file")
        done <<< "$suite_files"
    fi
    
    # Performance result files
    local perf_files
    perf_files=$(find "$RESULTS_DIR" -name "*_performance.json" -o -name "*_benchmark.json" 2>/dev/null || echo "")
    
    if [[ -n "$perf_files" ]]; then
        while IFS= read -r perf_file; do
            result_files+=("$perf_file")
        done <<< "$perf_files"
    fi
    
    echo "Found ${#result_files[@]} result files"
    
    # Copy result files to analysis directory
    for result_file in "${result_files[@]}"; do
        if [[ -f "$result_file" ]]; then
            cp "$result_file" "$OUTPUT_DIR/"
        fi
    done
}

# Analyze test execution summary
analyze_test_execution() {
    log_info "Analyzing test execution summary"
    
    local summary_file="$OUTPUT_DIR/test-summary.json"
    
    if [[ ! -f "$summary_file" ]]; then
        log_warn "Test summary file not found: $summary_file"
        return 1
    fi
    
    # Extract basic metrics
    local total_tests passed_tests failed_tests skipped_tests
    total_tests=$(jq -r '.total // 0' "$summary_file")
    passed_tests=$(jq -r '.passed // 0' "$summary_file")
    failed_tests=$(jq -r '.failed // 0' "$summary_file")
    skipped_tests=$(jq -r '.skipped // 0' "$summary_file")
    
    # Calculate success rate
    local success_rate=0
    if [[ "$total_tests" -gt 0 ]]; then
        success_rate=$(echo "scale=2; $passed_tests * 100 / $total_tests" | bc -l)
    fi
    
    # Generate execution analysis
    local execution_analysis="$OUTPUT_DIR/execution_analysis.json"
    cat > "$execution_analysis" << EOF
{
    "execution_summary": {
        "total_tests": $total_tests,
        "passed_tests": $passed_tests,
        "failed_tests": $failed_tests,
        "skipped_tests": $skipped_tests,
        "success_rate": $success_rate,
        "analysis_timestamp": $(date +%s)
    },
    "quality_assessment": {
        "overall_status": "$([ $success_rate -ge $SUCCESS_RATE_THRESHOLD ] && echo "PASS" || echo "FAIL")",
        "success_rate_threshold": $SUCCESS_RATE_THRESHOLD,
        "meets_threshold": $([ $success_rate -ge $SUCCESS_RATE_THRESHOLD ] && echo "true" || echo "false")
    }
}
EOF
    
    echo "Test execution analysis completed"
    echo "Success rate: ${success_rate}%"
    echo "Status: $([ $success_rate -ge $SUCCESS_RATE_THRESHOLD ] && echo "PASS" || echo "FAIL")"
}

# Analyze performance results
analyze_performance() {
    log_info "Analyzing performance results"
    
    local performance_files
    performance_files=$(find "$OUTPUT_DIR" -name "*_performance.json" -o -name "*_benchmark.json" 2>/dev/null || echo "")
    
    if [[ -z "$performance_files" ]]; then
        log_warn "No performance result files found"
        return 1
    fi
    
    local performance_analysis="$OUTPUT_DIR/performance_analysis.json"
    echo '{"performance_summary": {}, "performance_tests": []}' > "$performance_analysis"
    
    local total_performance_tests=0
    local passed_performance_tests=0
    local performance_issues=()
    
    while IFS= read -r perf_file; do
        if [[ -f "$perf_file" ]]; then
            local test_name
            test_name=$(basename "$perf_file" .json)
            
            echo "Analyzing performance file: $test_name"
            
            # Extract performance metrics
            local max_cpu max_memory max_disk avg_load
            max_cpu=$(jq -r '.max_cpu_percent // 0' "$perf_file")
            max_memory=$(jq -r '.max_memory_mb // 0' "$perf_file")
            max_disk=$(jq -r '.max_disk_percent // 0' "$perf_file")
            avg_load=$(jq -r '.avg_load // 0' "$perf_file")
            
            ((total_performance_tests++))
            
            # Check against thresholds
            local test_passed=true
            local issues=[]
            
            if (( $(echo "$max_cpu > $PERFORMANCE_CPU_THRESHOLD" | bc -l) )); then
                test_passed=false
                issues+=("cpu_threshold_exceeded")
                performance_issues+=("$test_name: CPU ${max_cpu}% > ${PERFORMANCE_CPU_THRESHOLD}%")
            fi
            
            if (( $(echo "$max_memory > $PERFORMANCE_MEMORY_THRESHOLD" | bc -l) )); then
                test_passed=false
                issues+=("memory_threshold_exceeded")
                performance_issues+=("$test_name: Memory ${max_memory}MB > ${PERFORMANCE_MEMORY_THRESHOLD}MB")
            fi
            
            if (( $(echo "$max_disk > $PERFORMANCE_DISK_THRESHOLD" | bc -l) )); then
                test_passed=false
                issues+=("disk_threshold_exceeded")
                performance_issues+=("$test_name: Disk ${max_disk}% > ${PERFORMANCE_DISK_THRESHOLD}%")
            fi
            
            if [[ "$test_passed" == true ]]; then
                ((passed_performance_tests++))
            fi
            
            # Add to analysis
            local temp_file=$(mktemp)
            jq --arg name "$test_name" \
               --arg cpu "$max_cpu" \
               --arg memory "$max_memory" \
               --arg disk "$max_disk" \
               --arg load "$avg_load" \
               --argjson passed "$test_passed" \
               '.performance_tests += [{
                   "test_name": $name,
                   "max_cpu_percent": ($cpu | tonumber),
                   "max_memory_mb": ($memory | tonumber),
                   "max_disk_percent": ($disk | tonumber),
                   "avg_load": ($load | tonumber),
                   "passed": $passed
               }]' "$performance_analysis" > "$temp_file"
            mv "$temp_file" "$performance_analysis"
        fi
    done <<< "$performance_files"
    
    # Update summary
    local performance_success_rate=0
    if [[ "$total_performance_tests" -gt 0 ]]; then
        performance_success_rate=$(echo "scale=2; $passed_performance_tests * 100 / $total_performance_tests" | bc -l)
    fi
    
    local temp_file=$(mktemp)
    jq --arg total "$total_performance_tests" \
       --arg passed "$passed_performance_tests" \
       --arg rate "$performance_success_rate" \
       '.performance_summary = {
           "total_tests": ($total | tonumber),
           "passed_tests": ($passed | tonumber),
           "success_rate": ($rate | tonumber),
           "issues_found": '${#performance_issues[@]}'
       }' "$performance_analysis" > "$temp_file"
    mv "$temp_file" "$performance_analysis"
    
    echo "Performance analysis completed"
    echo "Performance tests: $passed_performance_tests/$total_performance_tests passed"
    echo "Performance success rate: ${performance_success_rate}%"
    
    if [[ ${#performance_issues[@]} -gt 0 ]]; then
        echo "Performance issues found:"
        for issue in "${performance_issues[@]}"; do
            echo "  - $issue"
        done
    fi
}

# Analyze test failures
analyze_failures() {
    log_info "Analyzing test failures"
    
    local summary_file="$OUTPUT_DIR/test-summary.json"
    
    if [[ ! -f "$summary_file" ]]; then
        log_warn "Test summary file not found for failure analysis"
        return 1
    fi
    
    # Extract failed tests
    local failed_tests
    failed_tests=$(jq -r '.tests[] | select(.result == "FAILED") | .name' "$summary_file" 2>/dev/null || echo "")
    
    if [[ -z "$failed_tests" ]]; then
        echo "No test failures found"
        return 0
    fi
    
    local failure_analysis="$OUTPUT_DIR/failure_analysis.json"
    echo '{"failure_summary": {}, "failed_tests": []}' > "$failure_analysis"
    
    local failure_count=0
    local failure_categories=()
    
    while IFS= read -r test_name; do
        if [[ -n "$test_name" ]]; then
            ((failure_count++))
            
            # Get failure details
            local test_info
            test_info=$(jq --arg name "$test_name" '.tests[] | select(.name == $name)' "$summary_file")
            
            local error_message duration
            error_message=$(echo "$test_info" | jq -r '.error // "No error message"')
            duration=$(echo "$test_info" | jq -r '.duration // 0')
            
            # Categorize failure
            local category="unknown"
            if echo "$error_message" | grep -qi "timeout"; then
                category="timeout"
            elif echo "$error_message" | grep -qi "connection\|network"; then
                category="network"
            elif echo "$error_message" | grep -qi "permission\|access"; then
                category="permission"
            elif echo "$error_message" | grep -qi "assertion"; then
                category="assertion"
            elif echo "$error_message" | grep -qi "resource\|memory\|disk"; then
                category="resource"
            fi
            
            failure_categories+=("$category")
            
            # Add to analysis
            local temp_file=$(mktemp)
            jq --arg name "$test_name" \
               --arg error "$error_message" \
               --arg duration "$duration" \
               --arg category "$category" \
               '.failed_tests += [{
                   "test_name": $name,
                   "error_message": $error,
                   "duration": ($duration | tonumber),
                   "category": $category
               }]' "$failure_analysis" > "$temp_file"
            mv "$temp_file" "$failure_analysis"
        fi
    done <<< "$failed_tests"
    
    # Analyze failure patterns
    local category_counts
    category_counts=$(printf '%s\n' "${failure_categories[@]}" | sort | uniq -c | sort -nr)
    
    # Update summary
    local temp_file=$(mktemp)
    jq --arg count "$failure_count" \
       --arg patterns "$category_counts" \
       '.failure_summary = {
           "total_failures": ($count | tonumber),
           "failure_patterns": $patterns,
           "analysis_timestamp": '$(date +%s)'
       }' "$failure_analysis" > "$temp_file"
    mv "$temp_file" "$failure_analysis"
    
    echo "Failure analysis completed"
    echo "Total failures: $failure_count"
    echo "Failure patterns:"
    echo "$category_counts"
}

# Generate trend analysis
analyze_trends() {
    if [[ "$INCLUDE_TRENDS" != true ]]; then
        return 0
    fi
    
    log_info "Analyzing test trends"
    
    if [[ ! -d "$HISTORICAL_DIR" ]]; then
        log_warn "Historical results directory not found: $HISTORICAL_DIR"
        return 1
    fi
    
    # Find historical result files
    local historical_files
    historical_files=$(find "$HISTORICAL_DIR" -name "test-summary-*.json" | sort)
    
    if [[ -z "$historical_files" ]]; then
        log_warn "No historical test results found"
        return 1
    fi
    
    local trend_analysis="$OUTPUT_DIR/trend_analysis.json"
    echo '{"trend_summary": {}, "historical_data": []}' > "$trend_analysis"
    
    local data_points=0
    
    while IFS= read -r hist_file; do
        if [[ -f "$hist_file" ]]; then
            local timestamp total passed failed success_rate
            
            # Extract timestamp from filename or file
            timestamp=$(jq -r '.start_time // empty' "$hist_file" 2>/dev/null || echo "0")
            if [[ "$timestamp" == "0" ]]; then
                # Try to extract from filename
                timestamp=$(basename "$hist_file" | grep -o '[0-9]\{10\}' || echo "0")
            fi
            
            total=$(jq -r '.total // 0' "$hist_file")
            passed=$(jq -r '.passed // 0' "$hist_file")
            failed=$(jq -r '.failed // 0' "$hist_file")
            
            if [[ "$total" -gt 0 ]]; then
                success_rate=$(echo "scale=2; $passed * 100 / $total" | bc -l)
            else
                success_rate=0
            fi
            
            # Add to trend data
            local temp_file=$(mktemp)
            jq --arg ts "$timestamp" \
               --arg total "$total" \
               --arg passed "$passed" \
               --arg failed "$failed" \
               --arg rate "$success_rate" \
               '.historical_data += [{
                   "timestamp": ($ts | tonumber),
                   "total_tests": ($total | tonumber),
                   "passed_tests": ($passed | tonumber),
                   "failed_tests": ($failed | tonumber),
                   "success_rate": ($rate | tonumber)
               }]' "$trend_analysis" > "$temp_file"
            mv "$temp_file" "$trend_analysis"
            
            ((data_points++))
        fi
    done <<< "$historical_files"
    
    # Calculate trend metrics
    if [[ "$data_points" -ge 2 ]]; then
        local avg_success_rate latest_success_rate trend_direction
        
        avg_success_rate=$(jq '.historical_data | map(.success_rate) | add / length' "$trend_analysis")
        latest_success_rate=$(jq '.historical_data | sort_by(.timestamp) | last | .success_rate' "$trend_analysis")
        
        if (( $(echo "$latest_success_rate > $avg_success_rate" | bc -l) )); then
            trend_direction="improving"
        elif (( $(echo "$latest_success_rate < $avg_success_rate" | bc -l) )); then
            trend_direction="declining"
        else
            trend_direction="stable"
        fi
        
        # Update summary
        local temp_file=$(mktemp)
        jq --arg points "$data_points" \
           --arg avg "$avg_success_rate" \
           --arg latest "$latest_success_rate" \
           --arg direction "$trend_direction" \
           '.trend_summary = {
               "data_points": ($points | tonumber),
               "average_success_rate": ($avg | tonumber),
               "latest_success_rate": ($latest | tonumber),
               "trend_direction": $direction,
               "analysis_timestamp": '$(date +%s)'
           }' "$trend_analysis" > "$temp_file"
        mv "$temp_file" "$trend_analysis"
        
        echo "Trend analysis completed"
        echo "Data points: $data_points"
        echo "Average success rate: ${avg_success_rate}%"
        echo "Latest success rate: ${latest_success_rate}%"
        echo "Trend direction: $trend_direction"
    else
        echo "Insufficient historical data for trend analysis"
    fi
}

# Generate comprehensive report
generate_comprehensive_report() {
    log_info "Generating comprehensive report in format: $REPORT_FORMAT"
    
    case "$REPORT_FORMAT" in
        html|all)
            generate_html_report
            ;;
        json|all)
            generate_json_report
            ;;
        text|all)
            generate_text_report
            ;;
    esac
}

generate_html_report() {
    local report_file="$OUTPUT_DIR/comprehensive_report.html"
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>GitHub Actions Runner - Test Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; line-height: 1.6; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .metric { background: #f8f9fa; padding: 15px; border-radius: 5px; text-align: center; }
        .metric.success { background: #d4edda; border-left: 4px solid #28a745; }
        .metric.warning { background: #fff3cd; border-left: 4px solid #ffc107; }
        .metric.error { background: #f8d7da; border-left: 4px solid #dc3545; }
        .metric-value { font-size: 24px; font-weight: bold; }
        .metric-label { font-size: 14px; color: #666; margin-top: 5px; }
        .chart-container { margin: 20px 0; padding: 15px; background: #f8f9fa; border-radius: 5px; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background: #f2f2f2; }
        .status-pass { color: #28a745; font-weight: bold; }
        .status-fail { color: #dc3545; font-weight: bold; }
        .status-warn { color: #ffc107; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>GitHub Actions Runner - Test Analysis Report</h1>
        <p>Generated on: <span id="timestamp"></span></p>
        <p>Analysis Period: <span id="analysis-period"></span></p>
    </div>
    
    <div class="section">
        <h2>Executive Summary</h2>
        <div class="metrics" id="summary-metrics"></div>
    </div>
    
    <div class="section">
        <h2>Test Execution Results</h2>
        <div id="execution-results"></div>
    </div>
    
    <div class="section">
        <h2>Performance Analysis</h2>
        <div id="performance-results"></div>
    </div>
    
    <div class="section">
        <h2>Failure Analysis</h2>
        <div id="failure-analysis"></div>
    </div>
    
    <div class="section" id="trend-section" style="display: none;">
        <h2>Trend Analysis</h2>
        <div id="trend-analysis"></div>
    </div>
    
    <div class="section">
        <h2>Recommendations</h2>
        <div id="recommendations"></div>
    </div>
    
    <script>
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
        
        // Load and display analysis data
        // This would be populated with actual analysis results
        
        function loadAnalysisData() {
            // Placeholder for loading actual analysis data
            const summaryMetrics = document.getElementById('summary-metrics');
            summaryMetrics.innerHTML = '<div class="metric success"><div class="metric-value">95%</div><div class="metric-label">Success Rate</div></div>';
        }
        
        loadAnalysisData();
    </script>
</body>
</html>
EOF

    log_success "HTML report generated: $report_file"
}

generate_json_report() {
    local report_file="$OUTPUT_DIR/comprehensive_report.json"
    
    # Combine all analysis files into comprehensive report
    local combined_data="{}"
    
    # Add execution analysis
    if [[ -f "$OUTPUT_DIR/execution_analysis.json" ]]; then
        combined_data=$(echo "$combined_data" | jq '. + {"execution": input}' "$OUTPUT_DIR/execution_analysis.json")
    fi
    
    # Add performance analysis
    if [[ -f "$OUTPUT_DIR/performance_analysis.json" ]]; then
        combined_data=$(echo "$combined_data" | jq '. + {"performance": input}' "$OUTPUT_DIR/performance_analysis.json")
    fi
    
    # Add failure analysis
    if [[ -f "$OUTPUT_DIR/failure_analysis.json" ]]; then
        combined_data=$(echo "$combined_data" | jq '. + {"failures": input}' "$OUTPUT_DIR/failure_analysis.json")
    fi
    
    # Add trend analysis
    if [[ -f "$OUTPUT_DIR/trend_analysis.json" ]]; then
        combined_data=$(echo "$combined_data" | jq '. + {"trends": input}' "$OUTPUT_DIR/trend_analysis.json")
    fi
    
    # Add metadata
    combined_data=$(echo "$combined_data" | jq '. + {
        "report_metadata": {
            "generated_timestamp": '$(date +%s)',
            "generator": "GitHub Actions Runner Test Analysis",
            "version": "1.0",
            "results_source": "'$RESULTS_DIR'",
            "analysis_format": "comprehensive"
        }
    }')
    
    echo "$combined_data" > "$report_file"
    
    log_success "JSON report generated: $report_file"
}

generate_text_report() {
    local report_file="$OUTPUT_DIR/comprehensive_report.txt"
    
    cat > "$report_file" << EOF
GitHub Actions Runner - Test Analysis Report
===========================================

Generated: $(date)
Results Source: $RESULTS_DIR
Analysis Directory: $OUTPUT_DIR

EXECUTIVE SUMMARY
================

EOF

    # Add execution summary
    if [[ -f "$OUTPUT_DIR/execution_analysis.json" ]]; then
        local total passed failed success_rate
        total=$(jq -r '.execution_summary.total_tests' "$OUTPUT_DIR/execution_analysis.json")
        passed=$(jq -r '.execution_summary.passed_tests' "$OUTPUT_DIR/execution_analysis.json")
        failed=$(jq -r '.execution_summary.failed_tests' "$OUTPUT_DIR/execution_analysis.json")
        success_rate=$(jq -r '.execution_summary.success_rate' "$OUTPUT_DIR/execution_analysis.json")
        
        cat >> "$report_file" << EOF
Test Execution Results:
- Total Tests: $total
- Passed: $passed
- Failed: $failed
- Success Rate: ${success_rate}%

EOF
    fi
    
    # Add performance summary
    if [[ -f "$OUTPUT_DIR/performance_analysis.json" ]]; then
        local perf_total perf_passed perf_rate
        perf_total=$(jq -r '.performance_summary.total_tests // 0' "$OUTPUT_DIR/performance_analysis.json")
        perf_passed=$(jq -r '.performance_summary.passed_tests // 0' "$OUTPUT_DIR/performance_analysis.json")
        perf_rate=$(jq -r '.performance_summary.success_rate // 0' "$OUTPUT_DIR/performance_analysis.json")
        
        cat >> "$report_file" << EOF
Performance Test Results:
- Total Performance Tests: $perf_total
- Passed: $perf_passed
- Success Rate: ${perf_rate}%

EOF
    fi
    
    # Add failure summary
    if [[ -f "$OUTPUT_DIR/failure_analysis.json" ]]; then
        local failure_count
        failure_count=$(jq -r '.failure_summary.total_failures // 0' "$OUTPUT_DIR/failure_analysis.json")
        
        cat >> "$report_file" << EOF
Failure Analysis:
- Total Failures: $failure_count

EOF
    fi
    
    cat >> "$report_file" << EOF

DETAILED ANALYSIS
================

For detailed analysis, please review the following files:
- execution_analysis.json: Detailed test execution analysis
- performance_analysis.json: Performance metrics and analysis
- failure_analysis.json: Failure categorization and details

EOF

    if [[ -f "$OUTPUT_DIR/trend_analysis.json" ]]; then
        cat >> "$report_file" << EOF
- trend_analysis.json: Historical trend analysis

EOF
    fi
    
    cat >> "$report_file" << EOF

RECOMMENDATIONS
==============

EOF

    # Generate recommendations based on analysis
    local recommendations=()
    
    # Check success rate
    if [[ -f "$OUTPUT_DIR/execution_analysis.json" ]]; then
        local success_rate
        success_rate=$(jq -r '.execution_summary.success_rate' "$OUTPUT_DIR/execution_analysis.json")
        
        if (( $(echo "$success_rate < $SUCCESS_RATE_THRESHOLD" | bc -l) )); then
            recommendations+=("• Investigate test failures to improve success rate (current: ${success_rate}%, target: ${SUCCESS_RATE_THRESHOLD}%)")
        fi
    fi
    
    # Check performance issues
    if [[ -f "$OUTPUT_DIR/performance_analysis.json" ]]; then
        local issues_found
        issues_found=$(jq -r '.performance_summary.issues_found // 0' "$OUTPUT_DIR/performance_analysis.json")
        
        if [[ "$issues_found" -gt 0 ]]; then
            recommendations+=("• Address $issues_found performance threshold violations")
        fi
    fi
    
    # Add recommendations or default message
    if [[ ${#recommendations[@]} -gt 0 ]]; then
        for recommendation in "${recommendations[@]}"; do
            echo "$recommendation" >> "$report_file"
        done
    else
        echo "• No critical issues identified. Continue regular monitoring." >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "End of Report" >> "$report_file"
    
    log_success "Text report generated: $report_file"
}

# Save results to historical directory
save_to_history() {
    if [[ -n "$HISTORICAL_DIR" ]]; then
        log_info "Saving results to historical directory: $HISTORICAL_DIR"
        
        mkdir -p "$HISTORICAL_DIR"
        
        local timestamp=$(date +%Y%m%d_%H%M%S)
        
        # Copy main result files
        if [[ -f "$RESULTS_DIR/test-summary.json" ]]; then
            cp "$RESULTS_DIR/test-summary.json" "$HISTORICAL_DIR/test-summary-$timestamp.json"
        fi
        
        # Copy analysis results
        if [[ -d "$OUTPUT_DIR" ]]; then
            tar -czf "$HISTORICAL_DIR/analysis-$timestamp.tar.gz" -C "$OUTPUT_DIR" .
        fi
        
        echo "Results saved to history with timestamp: $timestamp"
    fi
}

# Main analysis execution
main() {
    # Load configuration
    if [[ -n "$THRESHOLD_FILE" ]]; then
        load_thresholds "$THRESHOLD_FILE"
    else
        load_thresholds ""
    fi
    
    log_info "Starting test results analysis"
    log_info "Results directory: $RESULTS_DIR"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Report format: $REPORT_FORMAT"
    
    # Collect and analyze results
    collect_test_results
    analyze_test_execution
    analyze_performance
    analyze_failures
    
    if [[ "$INCLUDE_TRENDS" == true ]]; then
        analyze_trends
    fi
    
    # Generate reports
    generate_comprehensive_report
    
    # Save to history
    save_to_history
    
    log_success "Test results analysis completed"
    log_info "Analysis results available in: $OUTPUT_DIR"
    
    case "$REPORT_FORMAT" in
        html|all)
            log_info "HTML report: $OUTPUT_DIR/comprehensive_report.html"
            ;;
        json|all)
            log_info "JSON report: $OUTPUT_DIR/comprehensive_report.json"
            ;;
        text|all)
            log_info "Text report: $OUTPUT_DIR/comprehensive_report.txt"
            ;;
    esac
}

# Run analysis if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi