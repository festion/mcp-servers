#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/common.sh"

ENVIRONMENT="${1:-dev}"

log_info "Running performance tests for environment: $ENVIRONMENT"

test_response_time() {
    log_info "Testing response time"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local services=(
        "github-runner-1:$GITHUB_RUNNER_PORT:/health"
        "github-runner-2:$((GITHUB_RUNNER_PORT + 1)):/health"
        "github-runner-3:$((GITHUB_RUNNER_PORT + 2)):/health"
        "monitoring:$MONITORING_PORT:/api/v1/query"
    )
    
    local response_time_failures=0
    local max_response_time=2000  # 2 seconds in milliseconds
    
    for service in "${services[@]}"; do
        local service_name="${service%%:*}"
        local service_port="${service#*:}"
        service_port="${service_port%%:*}"
        local endpoint="${service##*:}"
        
        local url="http://localhost:$service_port$endpoint"
        
        log_info "Testing response time for: $service_name"
        
        local response_time
        response_time=$(curl -w "%{time_total}\n" -o /dev/null -s "$url" | awk '{print $1*1000}')
        
        if (( $(echo "$response_time < $max_response_time" | bc -l) )); then
            log_success "Response time test passed for $service_name: ${response_time}ms"
        else
            log_error "Response time test failed for $service_name: ${response_time}ms (max: ${max_response_time}ms)"
            ((response_time_failures++))
        fi
    done
    
    return $response_time_failures
}

test_throughput() {
    log_info "Testing throughput"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local test_duration=30  # seconds
    local concurrent_requests=10
    local throughput_failures=0
    
    # Test each runner's throughput
    for ((i=1; i<=GITHUB_RUNNER_COUNT; i++)); do
        local port=$((GITHUB_RUNNER_PORT + i - 1))
        local url="http://localhost:$port/health"
        
        log_info "Testing throughput for runner-$i"
        
        # Use Apache Bench (ab) if available, otherwise use curl in a loop
        if command -v ab &> /dev/null; then
            local ab_result
            ab_result=$(ab -t "$test_duration" -c "$concurrent_requests" "$url" 2>/dev/null | grep "Requests per second" | awk '{print $4}')
            
            local min_rps=5  # Minimum requests per second
            
            if (( $(echo "$ab_result > $min_rps" | bc -l) )); then
                log_success "Throughput test passed for runner-$i: $ab_result RPS"
            else
                log_error "Throughput test failed for runner-$i: $ab_result RPS (min: $min_rps)"
                ((throughput_failures++))
            fi
        else
            # Fallback to curl-based test
            local start_time=$(date +%s)
            local end_time=$((start_time + test_duration))
            local request_count=0
            
            while (( $(date +%s) < end_time )); do
                if curl -s "$url" > /dev/null; then
                    ((request_count++))
                fi
                sleep 0.1
            done
            
            local rps=$(echo "scale=2; $request_count / $test_duration" | bc)
            log_success "Throughput test completed for runner-$i: $rps RPS"
        fi
    done
    
    return $throughput_failures
}

test_resource_utilization() {
    log_info "Testing resource utilization"
    
    local resource_failures=0
    
    # Test CPU utilization
    log_info "Testing CPU utilization"
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | sed 's/%//')
    local max_cpu=80
    
    if (( $(echo "$cpu_usage < $max_cpu" | bc -l) )); then
        log_success "CPU utilization test passed: $cpu_usage% (max: $max_cpu%)"
    else
        log_error "CPU utilization test failed: $cpu_usage% (max: $max_cpu%)"
        ((resource_failures++))
    fi
    
    # Test memory utilization
    log_info "Testing memory utilization"
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    local max_memory=85
    
    if (( $(echo "$memory_usage < $max_memory" | bc -l) )); then
        log_success "Memory utilization test passed: $memory_usage% (max: $max_memory%)"
    else
        log_error "Memory utilization test failed: $memory_usage% (max: $max_memory%)"
        ((resource_failures++))
    fi
    
    # Test disk utilization
    log_info "Testing disk utilization"
    local disk_usage=$(df -h . | awk 'NR==2 {print $5}' | sed 's/%//')
    local max_disk=80
    
    if (( disk_usage < max_disk )); then
        log_success "Disk utilization test passed: $disk_usage% (max: $max_disk%)"
    else
        log_error "Disk utilization test failed: $disk_usage% (max: $max_disk%)"
        ((resource_failures++))
    fi
    
    return $resource_failures
}

test_concurrent_workflows() {
    log_info "Testing concurrent workflow handling"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local concurrent_failures=0
    local max_concurrent=GITHUB_RUNNER_COUNT
    
    # Simulate concurrent workflow requests
    local pids=()
    
    for ((i=1; i<=max_concurrent; i++)); do
        local port=$((GITHUB_RUNNER_PORT + i - 1))
        
        # Start background process to simulate workflow
        (
            for ((j=1; j<=10; j++)); do
                curl -s "http://localhost:$port/health" > /dev/null
                sleep 0.1
            done
        ) &
        
        pids+=($!)
    done
    
    # Wait for all background processes to complete
    for pid in "${pids[@]}"; do
        if wait "$pid"; then
            log_success "Concurrent workflow test passed for PID: $pid"
        else
            log_error "Concurrent workflow test failed for PID: $pid"
            ((concurrent_failures++))
        fi
    done
    
    return $concurrent_failures
}

test_scaling_performance() {
    log_info "Testing scaling performance"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local scaling_failures=0
    
    # Test horizontal scaling (multiple runners)
    local active_runners
    active_runners=$(docker ps --filter "label=github-runner" --filter "status=running" | wc -l)
    
    if (( active_runners >= GITHUB_RUNNER_COUNT )); then
        log_success "Horizontal scaling test passed: $active_runners runners active"
    else
        log_error "Horizontal scaling test failed: only $active_runners runners active"
        ((scaling_failures++))
    fi
    
    # Test load distribution
    local load_distribution_test=true
    
    for ((i=1; i<=GITHUB_RUNNER_COUNT; i++)); do
        local port=$((GITHUB_RUNNER_PORT + i - 1))
        
        if ! curl -s "http://localhost:$port/health" > /dev/null; then
            load_distribution_test=false
            break
        fi
    done
    
    if [[ "$load_distribution_test" == "true" ]]; then
        log_success "Load distribution test passed"
    else
        log_error "Load distribution test failed"
        ((scaling_failures++))
    fi
    
    return $scaling_failures
}

test_database_performance() {
    log_info "Testing database performance"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local db_failures=0
    
    # Test database connection if using PostgreSQL
    if [[ "$DATABASE_URL" == postgresql* ]]; then
        log_info "Testing PostgreSQL performance"
        
        # Test connection time
        local start_time=$(date +%s.%N)
        
        if docker exec postgres psql -U postgres -d github_runner -c "SELECT 1;" > /dev/null 2>&1; then
            local end_time=$(date +%s.%N)
            local connection_time=$(echo "$end_time - $start_time" | bc)
            
            if (( $(echo "$connection_time < 1.0" | bc -l) )); then
                log_success "Database connection test passed: ${connection_time}s"
            else
                log_error "Database connection test failed: ${connection_time}s (max: 1.0s)"
                ((db_failures++))
            fi
        else
            log_error "Database connection test failed: unable to connect"
            ((db_failures++))
        fi
    fi
    
    # Test Redis performance if using Redis
    if [[ "$REDIS_URL" == redis* ]]; then
        log_info "Testing Redis performance"
        
        if docker exec github-runner-redis redis-cli ping | grep -q "PONG"; then
            log_success "Redis performance test passed"
        else
            log_error "Redis performance test failed"
            ((db_failures++))
        fi
    fi
    
    return $db_failures
}

test_network_performance() {
    log_info "Testing network performance"
    
    local network_failures=0
    
    # Test internal network latency
    local containers=(
        "github-runner-1"
        "github-runner-2"
        "github-runner-3"
    )
    
    for container in "${containers[@]}"; do
        log_info "Testing network performance for: $container"
        
        # Test ping to monitoring service
        local ping_result
        ping_result=$(docker exec "$container" ping -c 3 github-runner-prometheus 2>/dev/null | grep "avg" | awk -F'/' '{print $5}')
        
        if [[ -n "$ping_result" ]]; then
            if (( $(echo "$ping_result < 10.0" | bc -l) )); then
                log_success "Network latency test passed for $container: ${ping_result}ms"
            else
                log_error "Network latency test failed for $container: ${ping_result}ms (max: 10.0ms)"
                ((network_failures++))
            fi
        else
            log_error "Network latency test failed for $container: no response"
            ((network_failures++))
        fi
    done
    
    return $network_failures
}

test_monitoring_performance() {
    log_info "Testing monitoring performance"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local monitoring_failures=0
    
    # Test Prometheus query performance
    local start_time=$(date +%s.%N)
    
    if curl -s "http://localhost:$MONITORING_PORT/api/v1/query?query=up" > /dev/null; then
        local end_time=$(date +%s.%N)
        local query_time=$(echo "$end_time - $start_time" | bc)
        
        if (( $(echo "$query_time < 2.0" | bc -l) )); then
            log_success "Monitoring query test passed: ${query_time}s"
        else
            log_error "Monitoring query test failed: ${query_time}s (max: 2.0s)"
            ((monitoring_failures++))
        fi
    else
        log_error "Monitoring query test failed: unable to query"
        ((monitoring_failures++))
    fi
    
    # Test metrics collection rate
    local metrics_count
    metrics_count=$(curl -s "http://localhost:$METRICS_PORT/metrics" | grep "github_runner_" | wc -l)
    
    if (( metrics_count > 0 )); then
        log_success "Metrics collection test passed: $metrics_count metrics"
    else
        log_error "Metrics collection test failed: no metrics found"
        ((monitoring_failures++))
    fi
    
    return $monitoring_failures
}

generate_performance_report() {
    log_info "Generating performance test report"
    
    local report_file="/tmp/performance-test-report-$ENVIRONMENT-$(date +%Y%m%d_%H%M%S).json"
    
    # Get current system metrics
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')
    local disk_usage=$(df -h . | awk 'NR==2 {print $5}')
    
    cat > "$report_file" << EOF
{
    "environment": "$ENVIRONMENT",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "performance_results": {
        "response_time": "$response_time_result",
        "throughput": "$throughput_result",
        "resource_utilization": "$resource_utilization_result",
        "concurrent_workflows": "$concurrent_workflows_result",
        "scaling_performance": "$scaling_performance_result",
        "database_performance": "$database_performance_result",
        "network_performance": "$network_performance_result",
        "monitoring_performance": "$monitoring_performance_result"
    },
    "system_metrics": {
        "cpu_usage": "$cpu_usage",
        "memory_usage": "$memory_usage",
        "disk_usage": "$disk_usage"
    },
    "overall_status": "$overall_status",
    "total_tests": 8,
    "passed_tests": $passed_tests,
    "failed_tests": $failed_tests
}
EOF
    
    log_success "Performance test report generated: $report_file"
}

main() {
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    # Check for required tools
    if ! command -v bc &> /dev/null; then
        log_error "bc (calculator) is required for performance tests"
        exit 1
    fi
    
    local total_failures=0
    local passed_tests=0
    
    # Run all performance tests
    test_response_time
    response_time_result=$?
    total_failures=$((total_failures + response_time_result))
    if (( response_time_result == 0 )); then ((passed_tests++)); fi
    
    test_throughput
    throughput_result=$?
    total_failures=$((total_failures + throughput_result))
    if (( throughput_result == 0 )); then ((passed_tests++)); fi
    
    test_resource_utilization
    resource_utilization_result=$?
    total_failures=$((total_failures + resource_utilization_result))
    if (( resource_utilization_result == 0 )); then ((passed_tests++)); fi
    
    test_concurrent_workflows
    concurrent_workflows_result=$?
    total_failures=$((total_failures + concurrent_workflows_result))
    if (( concurrent_workflows_result == 0 )); then ((passed_tests++)); fi
    
    test_scaling_performance
    scaling_performance_result=$?
    total_failures=$((total_failures + scaling_performance_result))
    if (( scaling_performance_result == 0 )); then ((passed_tests++)); fi
    
    test_database_performance
    database_performance_result=$?
    total_failures=$((total_failures + database_performance_result))
    if (( database_performance_result == 0 )); then ((passed_tests++)); fi
    
    test_network_performance
    network_performance_result=$?
    total_failures=$((total_failures + network_performance_result))
    if (( network_performance_result == 0 )); then ((passed_tests++)); fi
    
    test_monitoring_performance
    monitoring_performance_result=$?
    total_failures=$((total_failures + monitoring_performance_result))
    if (( monitoring_performance_result == 0 )); then ((passed_tests++)); fi
    
    # Calculate results
    local failed_tests=$((8 - passed_tests))
    
    if (( total_failures == 0 )); then
        overall_status="passed"
        log_success "All performance tests passed ($passed_tests/8)"
    else
        overall_status="failed"
        log_error "Performance tests failed: $failed_tests failures"
    fi
    
    generate_performance_report
    
    exit $total_failures
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi