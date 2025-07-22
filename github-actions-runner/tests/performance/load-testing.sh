#!/bin/bash

# GitHub Actions Runner - Load Testing
# Performance tests for resource utilization, concurrent jobs, and scalability

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/test-framework.sh"

# Performance test configuration
LOAD_TEST_DURATION="${LOAD_TEST_DURATION:-60}"
MAX_CONCURRENT_JOBS="${MAX_CONCURRENT_JOBS:-5}"
MEMORY_THRESHOLD_MB="${MEMORY_THRESHOLD_MB:-1000}"
CPU_THRESHOLD_PERCENT="${CPU_THRESHOLD_PERCENT:-80}"
DISK_THRESHOLD_PERCENT="${DISK_THRESHOLD_PERCENT:-90}"

# Initialize test framework
init_test_framework "Load Testing"

# Performance monitoring functions
start_performance_monitoring() {
    local monitor_file="$1"
    local duration="$2"
    
    (
        echo "timestamp,cpu_percent,memory_mb,disk_percent,load_avg"
        for ((i=0; i<duration; i++)); do
            local timestamp=$(date +%s)
            local cpu_percent=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
            local memory_mb=$(free -m | awk 'NR==2{printf "%.0f", $3}')
            local disk_percent=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
            local load_avg=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | xargs)
            
            echo "$timestamp,$cpu_percent,$memory_mb,$disk_percent,$load_avg"
            sleep 1
        done
    ) > "$monitor_file" &
    
    echo $!
}

stop_performance_monitoring() {
    local monitor_pid="$1"
    
    if kill -0 "$monitor_pid" 2>/dev/null; then
        kill "$monitor_pid" 2>/dev/null || true
        wait "$monitor_pid" 2>/dev/null || true
    fi
}

analyze_performance_data() {
    local monitor_file="$1"
    local test_name="$2"
    
    if [[ ! -f "$monitor_file" ]]; then
        log_warn "Performance monitor file not found: $monitor_file"
        return 1
    fi
    
    local max_cpu max_memory max_disk avg_load
    max_cpu=$(tail -n +2 "$monitor_file" | cut -d',' -f2 | sort -n | tail -1)
    max_memory=$(tail -n +2 "$monitor_file" | cut -d',' -f3 | sort -n | tail -1)
    max_disk=$(tail -n +2 "$monitor_file" | cut -d',' -f4 | sort -n | tail -1)
    avg_load=$(tail -n +2 "$monitor_file" | cut -d',' -f5 | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
    
    echo "=== Performance Analysis: $test_name ==="
    echo "Max CPU Usage: ${max_cpu}%"
    echo "Max Memory Usage: ${max_memory}MB"
    echo "Max Disk Usage: ${max_disk}%"
    echo "Average Load: $avg_load"
    
    # Save detailed results
    local results_file="$TEST_RESULTS_DIR/${test_name}_performance.json"
    cat > "$results_file" << EOF
{
    "test_name": "$test_name",
    "max_cpu_percent": $max_cpu,
    "max_memory_mb": $max_memory,
    "max_disk_percent": $max_disk,
    "avg_load": $avg_load,
    "timestamp": $(date +%s)
}
EOF
    
    # Check against thresholds
    local threshold_failures=0
    
    if (( $(echo "$max_memory > $MEMORY_THRESHOLD_MB" | bc -l) )); then
        log_warn "Memory usage exceeded threshold: ${max_memory}MB > ${MEMORY_THRESHOLD_MB}MB"
        ((threshold_failures++))
    fi
    
    if (( $(echo "$max_cpu > $CPU_THRESHOLD_PERCENT" | bc -l) )); then
        log_warn "CPU usage exceeded threshold: ${max_cpu}% > ${CPU_THRESHOLD_PERCENT}%"
        ((threshold_failures++))
    fi
    
    if (( $(echo "$max_disk > $DISK_THRESHOLD_PERCENT" | bc -l) )); then
        log_warn "Disk usage exceeded threshold: ${max_disk}% > ${DISK_THRESHOLD_PERCENT}%"
        ((threshold_failures++))
    fi
    
    return $threshold_failures
}

# Test: Baseline performance measurement
test_baseline_performance() {
    log_info "Measuring baseline performance"
    
    local monitor_file="$TEST_RESULTS_DIR/baseline_performance.csv"
    local monitor_pid
    
    # Start monitoring
    monitor_pid=$(start_performance_monitoring "$monitor_file" 30)
    
    # Wait for baseline measurement
    sleep 30
    
    # Stop monitoring
    stop_performance_monitoring "$monitor_pid"
    
    # Analyze results
    analyze_performance_data "$monitor_file" "baseline"
    
    echo "Baseline performance measurement: OK"
}

# Test: CPU stress testing
test_cpu_stress() {
    log_info "Testing CPU stress performance"
    
    local monitor_file="$TEST_RESULTS_DIR/cpu_stress_performance.csv"
    local monitor_pid
    
    # Start monitoring
    monitor_pid=$(start_performance_monitoring "$monitor_file" "$LOAD_TEST_DURATION")
    
    # Create CPU intensive tasks
    local stress_pids=()
    local num_cores
    num_cores=$(nproc)
    
    for ((i=0; i<num_cores; i++)); do
        (
            # CPU intensive calculation
            local result=0
            local iterations=100000
            for ((j=0; j<iterations; j++)); do
                result=$((result + j * j / (j + 1)))
            done
            echo "CPU stress worker $i completed: $result"
        ) &
        stress_pids+=($!)
    done
    
    # Wait for stress test to complete
    sleep "$LOAD_TEST_DURATION"
    
    # Stop stress processes
    for pid in "${stress_pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    
    # Stop monitoring
    stop_performance_monitoring "$monitor_pid"
    
    # Analyze results
    if analyze_performance_data "$monitor_file" "cpu_stress"; then
        echo "CPU stress test: OK"
    else
        log_warn "CPU stress test exceeded thresholds"
    fi
}

# Test: Memory stress testing
test_memory_stress() {
    log_info "Testing memory stress performance"
    
    local monitor_file="$TEST_RESULTS_DIR/memory_stress_performance.csv"
    local monitor_pid
    
    # Start monitoring
    monitor_pid=$(start_performance_monitoring "$monitor_file" "$LOAD_TEST_DURATION")
    
    # Create memory intensive task
    local stress_script="$TEST_TEMP_DIR/memory_stress.sh"
    cat > "$stress_script" << 'EOF'
#!/bin/bash

echo "Starting memory stress test..."

# Create large arrays to consume memory
declare -a memory_arrays

# Allocate memory in chunks
for i in {1..100}; do
    # Create array with 10000 elements
    declare -a "array_$i"
    eval "array_$i=($(seq 1 10000))"
    memory_arrays+=("array_$i")
    
    # Add some delay to make it observable
    sleep 0.5
done

echo "Memory stress test arrays created: ${#memory_arrays[@]}"

# Hold memory for a while
sleep 30

# Cleanup
for array_name in "${memory_arrays[@]}"; do
    unset "$array_name"
done

echo "Memory stress test completed"
EOF

    chmod +x "$stress_script"
    
    # Run memory stress test
    "$stress_script" &
    local stress_pid=$!
    
    # Wait for test completion
    wait "$stress_pid"
    
    # Stop monitoring
    stop_performance_monitoring "$monitor_pid"
    
    # Analyze results
    if analyze_performance_data "$monitor_file" "memory_stress"; then
        echo "Memory stress test: OK"
    else
        log_warn "Memory stress test exceeded thresholds"
    fi
}

# Test: Disk I/O stress testing
test_disk_io_stress() {
    log_info "Testing disk I/O stress performance"
    
    local monitor_file="$TEST_RESULTS_DIR/disk_io_stress_performance.csv"
    local monitor_pid
    
    # Start monitoring
    monitor_pid=$(start_performance_monitoring "$monitor_file" "$LOAD_TEST_DURATION")
    
    local test_dir="$TEST_TEMP_DIR/disk_stress"
    mkdir -p "$test_dir"
    
    # Create disk I/O intensive tasks
    local io_pids=()
    
    # Write test
    (
        for i in {1..50}; do
            dd if=/dev/zero of="$test_dir/test_file_$i.dat" bs=1M count=10 2>/dev/null
        done
        echo "Write test completed"
    ) &
    io_pids+=($!)
    
    # Read test
    (
        sleep 5  # Start after some files are created
        for i in {1..100}; do
            if [[ -f "$test_dir/test_file_$((i % 50 + 1)).dat" ]]; then
                cat "$test_dir/test_file_$((i % 50 + 1)).dat" > /dev/null
            fi
            sleep 0.1
        done
        echo "Read test completed"
    ) &
    io_pids+=($!)
    
    # Random access test
    (
        sleep 10  # Start after files are available
        for i in {1..50}; do
            local file_num=$((RANDOM % 50 + 1))
            if [[ -f "$test_dir/test_file_$file_num.dat" ]]; then
                dd if="$test_dir/test_file_$file_num.dat" of=/dev/null bs=4k count=100 2>/dev/null
            fi
            sleep 0.2
        done
        echo "Random access test completed"
    ) &
    io_pids+=($!)
    
    # Wait for I/O tests to complete
    for pid in "${io_pids[@]}"; do
        wait "$pid"
    done
    
    # Cleanup test files
    rm -rf "$test_dir"
    
    # Stop monitoring
    stop_performance_monitoring "$monitor_pid"
    
    # Analyze results
    if analyze_performance_data "$monitor_file" "disk_io_stress"; then
        echo "Disk I/O stress test: OK"
    else
        log_warn "Disk I/O stress test exceeded thresholds"
    fi
}

# Test: Concurrent job simulation
test_concurrent_job_performance() {
    log_info "Testing concurrent job performance"
    
    local monitor_file="$TEST_RESULTS_DIR/concurrent_jobs_performance.csv"
    local monitor_pid
    
    # Start monitoring
    monitor_pid=$(start_performance_monitoring "$monitor_file" "$LOAD_TEST_DURATION")
    
    # Create multiple simulated jobs
    local job_pids=()
    local jobs_completed=0
    local jobs_failed=0
    
    for ((i=1; i<=MAX_CONCURRENT_JOBS; i++)); do
        (
            local job_id="job_$i"
            local job_dir="$TEST_TEMP_DIR/$job_id"
            mkdir -p "$job_dir"
            cd "$job_dir"
            
            echo "Starting $job_id at $(date)"
            
            # Simulate typical CI/CD job activities
            
            # 1. Code checkout simulation
            git init > /dev/null 2>&1
            echo "Mock repository content" > README.md
            git add README.md > /dev/null 2>&1
            git commit -m "Initial commit" > /dev/null 2>&1
            
            # 2. Dependency installation simulation
            mkdir -p node_modules
            for dep in {1..20}; do
                echo "Mock dependency $dep" > "node_modules/dep_$dep.js"
            done
            
            # 3. Build simulation
            mkdir -p build
            for file in {1..10}; do
                echo "Built file $file content" > "build/built_$file.js"
                sleep 0.1
            done
            
            # 4. Test simulation
            mkdir -p test_results
            for test in {1..5}; do
                echo "Test $test: PASSED" > "test_results/test_$test.xml"
                # Simulate test execution time
                sleep $((RANDOM % 3 + 1))
            done
            
            # 5. Artifact creation
            tar -czf "${job_id}_artifacts.tar.gz" build/ test_results/ > /dev/null 2>&1
            
            echo "Completed $job_id at $(date)"
            echo "$job_id" > "$job_dir/success"
            
        ) &
        job_pids+=($!)
    done
    
    # Monitor job completion
    local start_time
    start_time=$(date +%s)
    
    for pid in "${job_pids[@]}"; do
        if wait "$pid"; then
            ((jobs_completed++))
        else
            ((jobs_failed++))
        fi
    done
    
    local end_time
    end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Stop monitoring
    stop_performance_monitoring "$monitor_pid"
    
    echo "Concurrent jobs completed: $jobs_completed"
    echo "Concurrent jobs failed: $jobs_failed"
    echo "Total execution time: ${total_duration}s"
    
    # Analyze performance
    if analyze_performance_data "$monitor_file" "concurrent_jobs"; then
        echo "Concurrent job performance test: OK"
    else
        log_warn "Concurrent job performance test exceeded thresholds"
    fi
    
    # Verify all jobs completed successfully
    assert_equals "$MAX_CONCURRENT_JOBS" "$jobs_completed" \
        "All concurrent jobs should complete successfully"
}

# Test: Network performance
test_network_performance() {
    log_info "Testing network performance"
    
    local monitor_file="$TEST_RESULTS_DIR/network_performance.csv"
    local monitor_pid
    
    # Start monitoring
    monitor_pid=$(start_performance_monitoring "$monitor_file" 60)
    
    # Test download performance (GitHub API calls)
    local api_start_time api_end_time
    api_start_time=$(date +%s.%N)
    
    for i in {1..10}; do
        curl -s -o /dev/null "https://api.github.com/zen" || true
        sleep 1
    done
    
    api_end_time=$(date +%s.%N)
    local api_duration
    api_duration=$(echo "$api_end_time - $api_start_time" | bc -l)
    
    echo "GitHub API calls completed in: ${api_duration}s"
    
    # Test concurrent network connections
    local concurrent_pids=()
    local concurrent_start_time
    concurrent_start_time=$(date +%s)
    
    for i in {1..5}; do
        (
            for j in {1..5}; do
                curl -s -o /dev/null "https://httpbin.org/delay/1" || true
            done
        ) &
        concurrent_pids+=($!)
    done
    
    # Wait for concurrent tests
    for pid in "${concurrent_pids[@]}"; do
        wait "$pid"
    done
    
    local concurrent_end_time
    concurrent_end_time=$(date +%s)
    local concurrent_duration=$((concurrent_end_time - concurrent_start_time))
    
    echo "Concurrent network tests completed in: ${concurrent_duration}s"
    
    # Stop monitoring
    stop_performance_monitoring "$monitor_pid"
    
    # Analyze results
    if analyze_performance_data "$monitor_file" "network_performance"; then
        echo "Network performance test: OK"
    else
        log_warn "Network performance test exceeded thresholds"
    fi
}

# Test: Resource limits testing
test_resource_limits() {
    log_info "Testing resource limits"
    
    # Test maximum file descriptors
    local max_fd
    max_fd=$(ulimit -n)
    echo "Maximum file descriptors: $max_fd"
    
    # Test maximum processes
    local max_proc
    max_proc=$(ulimit -u)
    echo "Maximum processes: $max_proc"
    
    # Test memory limits
    local max_mem
    max_mem=$(ulimit -v)
    if [[ "$max_mem" == "unlimited" ]]; then
        echo "Memory limit: unlimited"
    else
        echo "Memory limit: ${max_mem}KB"
    fi
    
    # Test file size limits
    local max_file_size
    max_file_size=$(ulimit -f)
    if [[ "$max_file_size" == "unlimited" ]]; then
        echo "File size limit: unlimited"
    else
        echo "File size limit: ${max_file_size} blocks"
    fi
    
    # Test creating many files (within limits)
    local test_files_dir="$TEST_TEMP_DIR/many_files"
    mkdir -p "$test_files_dir"
    
    local files_created=0
    for ((i=1; i<=1000; i++)); do
        if echo "test content $i" > "$test_files_dir/file_$i.txt"; then
            ((files_created++))
        else
            break
        fi
    done
    
    echo "Successfully created $files_created test files"
    
    # Cleanup
    rm -rf "$test_files_dir"
    
    echo "Resource limits test: OK"
}

# Test: Scalability testing
test_scalability() {
    log_info "Testing scalability"
    
    local scalability_results="$TEST_RESULTS_DIR/scalability_results.json"
    echo '{"test_name": "scalability", "results": []}' > "$scalability_results"
    
    # Test different load levels
    local load_levels=(1 2 3 5)
    
    for load_level in "${load_levels[@]}"; do
        echo "Testing scalability with $load_level concurrent jobs..."
        
        local monitor_file="$TEST_RESULTS_DIR/scalability_${load_level}_jobs.csv"
        local monitor_pid
        
        # Start monitoring
        monitor_pid=$(start_performance_monitoring "$monitor_file" 30)
        
        # Run concurrent jobs
        local job_pids=()
        local start_time
        start_time=$(date +%s)
        
        for ((i=1; i<=load_level; i++)); do
            (
                # Simulate a standard job workload
                local work_dir="$TEST_TEMP_DIR/scale_job_${load_level}_$i"
                mkdir -p "$work_dir"
                cd "$work_dir"
                
                # CPU work
                local result=0
                for ((j=1; j<=10000; j++)); do
                    result=$((result + j))
                done
                
                # Memory work
                declare -a test_array
                for ((k=1; k<=1000; k++)); do
                    test_array[$k]="data_$k"
                done
                
                # I/O work
                echo "Job output" > output.txt
                for ((l=1; l<=100; l++)); do
                    echo "Line $l" >> output.txt
                done
                
                echo "$result" > result.txt
                
            ) &
            job_pids+=($!)
        done
        
        # Wait for jobs to complete
        for pid in "${job_pids[@]}"; do
            wait "$pid"
        done
        
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Stop monitoring
        stop_performance_monitoring "$monitor_pid"
        
        # Analyze performance for this load level
        local max_cpu max_memory max_disk avg_load
        if [[ -f "$monitor_file" ]]; then
            max_cpu=$(tail -n +2 "$monitor_file" | cut -d',' -f2 | sort -n | tail -1)
            max_memory=$(tail -n +2 "$monitor_file" | cut -d',' -f3 | sort -n | tail -1)
            max_disk=$(tail -n +2 "$monitor_file" | cut -d',' -f4 | sort -n | tail -1)
            avg_load=$(tail -n +2 "$monitor_file" | cut -d',' -f5 | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
        else
            max_cpu=0; max_memory=0; max_disk=0; avg_load=0
        fi
        
        echo "Load level $load_level: Duration=${duration}s, CPU=${max_cpu}%, Memory=${max_memory}MB, Load=${avg_load}"
        
        # Add results to scalability report
        local temp_file=$(mktemp)
        jq --arg level "$load_level" \
           --arg duration "$duration" \
           --arg cpu "$max_cpu" \
           --arg memory "$max_memory" \
           --arg load "$avg_load" \
           '.results += [{
               "load_level": ($level | tonumber),
               "duration": ($duration | tonumber),
               "max_cpu": ($cpu | tonumber),
               "max_memory": ($memory | tonumber),
               "avg_load": ($load | tonumber)
           }]' "$scalability_results" > "$temp_file"
        mv "$temp_file" "$scalability_results"
    done
    
    echo "Scalability testing completed"
    echo "Results saved to: $scalability_results"
}

# Main test execution
main() {
    setup_test_environment
    
    # Ensure required tools are available
    if ! command -v bc >/dev/null 2>&1; then
        log_warn "bc (calculator) not available, some calculations may fail"
    fi
    
    # Run performance tests
    run_test "baseline_performance" "test_baseline_performance" \
        "Measure baseline system performance" 60
    
    run_test "cpu_stress" "test_cpu_stress" \
        "Test system performance under CPU stress" 120
    
    run_test "memory_stress" "test_memory_stress" \
        "Test system performance under memory stress" 120
    
    run_test "disk_io_stress" "test_disk_io_stress" \
        "Test system performance under disk I/O stress" 120
    
    run_test "concurrent_job_performance" "test_concurrent_job_performance" \
        "Test performance with multiple concurrent jobs" 180
    
    run_test "network_performance" "test_network_performance" \
        "Test network performance and latency" 120
    
    run_test "resource_limits" "test_resource_limits" \
        "Test system resource limits"
    
    run_test "scalability" "test_scalability" \
        "Test system scalability with increasing load" 300
    
    cleanup_test_environment
    finalize_test_framework
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi