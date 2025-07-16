#!/bin/bash

# GitHub Actions Runner - Performance Benchmarks
# Benchmark tests for establishing performance baselines and regression testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/test-framework.sh"

# Benchmark configuration
BENCHMARK_ITERATIONS="${BENCHMARK_ITERATIONS:-5}"
BENCHMARK_RESULTS_DIR="$TEST_RESULTS_DIR/benchmarks"

# Initialize test framework
init_test_framework "Performance Benchmarks"

# Benchmark data collection
save_benchmark_result() {
    local test_name="$1"
    local metric_name="$2"
    local value="$3"
    local unit="$4"
    local iteration="${5:-1}"
    
    local results_file="$BENCHMARK_RESULTS_DIR/${test_name}_benchmark.json"
    mkdir -p "$BENCHMARK_RESULTS_DIR"
    
    # Initialize file if it doesn't exist
    if [[ ! -f "$results_file" ]]; then
        echo '{"test_name": "'$test_name'", "metrics": {}}' > "$results_file"
    fi
    
    # Add metric data
    local temp_file=$(mktemp)
    jq --arg metric "$metric_name" \
       --arg value "$value" \
       --arg unit "$unit" \
       --arg iteration "$iteration" \
       '.metrics[$metric] //= {"values": [], "unit": ""} |
        .metrics[$metric].values += [{"value": ($value | tonumber), "iteration": ($iteration | tonumber)}] |
        .metrics[$metric].unit = $unit' \
       "$results_file" > "$temp_file"
    mv "$temp_file" "$results_file"
}

calculate_benchmark_stats() {
    local test_name="$1"
    local results_file="$BENCHMARK_RESULTS_DIR/${test_name}_benchmark.json"
    
    if [[ ! -f "$results_file" ]]; then
        return 1
    fi
    
    local temp_file=$(mktemp)
    jq '.metrics | to_entries[] | 
        {
            metric: .key,
            unit: .value.unit,
            values: .value.values | map(.value),
            min: (.value.values | map(.value) | min),
            max: (.value.values | map(.value) | max),
            avg: (.value.values | map(.value) | add / length),
            count: (.value.values | length)
        }' "$results_file" > "$temp_file"
    
    echo "=== Benchmark Statistics: $test_name ==="
    while IFS= read -r stat; do
        local metric unit min max avg count
        metric=$(echo "$stat" | jq -r '.metric')
        unit=$(echo "$stat" | jq -r '.unit')
        min=$(echo "$stat" | jq -r '.min')
        max=$(echo "$stat" | jq -r '.max')
        avg=$(echo "$stat" | jq -r '.avg')
        count=$(echo "$stat" | jq -r '.count')
        
        printf "%-20s: min=%.2f %s, max=%.2f %s, avg=%.2f %s (n=%d)\n" \
               "$metric" "$min" "$unit" "$max" "$unit" "$avg" "$unit" "$count"
    done < "$temp_file"
    
    rm -f "$temp_file"
}

# Benchmark: System boot time
benchmark_system_boot_time() {
    log_info "Benchmarking system boot time"
    
    # Get system uptime (proxy for boot performance)
    local uptime_seconds
    uptime_seconds=$(awk '{print $1}' /proc/uptime)
    
    # Get systemd boot time if available
    if command -v systemd-analyze >/dev/null 2>&1; then
        local boot_time
        boot_time=$(systemd-analyze | grep "Startup finished" | awk '{print $(NF-1)}' | sed 's/min//' || echo "0")
        
        if [[ "$boot_time" != "0" ]]; then
            # Convert to seconds if in minutes
            if [[ "$boot_time" == *"min"* ]]; then
                boot_time=$(echo "$boot_time" | sed 's/min//' | awk '{print $1 * 60}')
            fi
            
            save_benchmark_result "system_boot" "boot_time" "$boot_time" "seconds" "1"
            echo "System boot time: ${boot_time}s"
        fi
    fi
    
    save_benchmark_result "system_boot" "uptime" "$uptime_seconds" "seconds" "1"
    echo "Current uptime: ${uptime_seconds}s"
}

# Benchmark: Service startup time
benchmark_service_startup() {
    log_info "Benchmarking service startup time"
    
    local service_name="github-runner.service"
    
    for ((i=1; i<=BENCHMARK_ITERATIONS; i++)); do
        log_debug "Service startup benchmark iteration $i"
        
        # Stop service
        local stop_start_time
        stop_start_time=$(date +%s.%N)
        systemctl stop "$service_name" 2>/dev/null || true
        
        # Wait for service to stop
        while systemctl is-active "$service_name" >/dev/null 2>&1; do
            sleep 0.1
        done
        
        local stop_end_time
        stop_end_time=$(date +%s.%N)
        local stop_duration
        stop_duration=$(echo "$stop_end_time - $stop_start_time" | bc -l)
        
        # Start service
        local start_start_time
        start_start_time=$(date +%s.%N)
        systemctl start "$service_name"
        
        # Wait for service to be active
        while ! systemctl is-active "$service_name" >/dev/null 2>&1; do
            sleep 0.1
        done
        
        local start_end_time
        start_end_time=$(date +%s.%N)
        local start_duration
        start_duration=$(echo "$start_end_time - $start_start_time" | bc -l)
        
        save_benchmark_result "service_startup" "stop_time" "$stop_duration" "seconds" "$i"
        save_benchmark_result "service_startup" "start_time" "$start_duration" "seconds" "$i"
        
        echo "Iteration $i: Stop=${stop_duration}s, Start=${start_duration}s"
        
        # Brief pause between iterations
        sleep 2
    done
    
    calculate_benchmark_stats "service_startup"
}

# Benchmark: File I/O performance
benchmark_file_io() {
    log_info "Benchmarking file I/O performance"
    
    local test_dir="$TEST_TEMP_DIR/io_benchmark"
    mkdir -p "$test_dir"
    
    for ((i=1; i<=BENCHMARK_ITERATIONS; i++)); do
        log_debug "File I/O benchmark iteration $i"
        
        # Sequential write test
        local write_start_time
        write_start_time=$(date +%s.%N)
        dd if=/dev/zero of="$test_dir/write_test_$i.dat" bs=1M count=100 2>/dev/null
        local write_end_time
        write_end_time=$(date +%s.%N)
        local write_duration
        write_duration=$(echo "$write_end_time - $write_start_time" | bc -l)
        local write_speed
        write_speed=$(echo "100 / $write_duration" | bc -l)
        
        # Sequential read test
        local read_start_time
        read_start_time=$(date +%s.%N)
        dd if="$test_dir/write_test_$i.dat" of=/dev/null bs=1M 2>/dev/null
        local read_end_time
        read_end_time=$(date +%s.%N)
        local read_duration
        read_duration=$(echo "$read_end_time - $read_start_time" | bc -l)
        local read_speed
        read_speed=$(echo "100 / $read_duration" | bc -l)
        
        # Random I/O test
        local random_start_time
        random_start_time=$(date +%s.%N)
        dd if="$test_dir/write_test_$i.dat" of=/dev/null bs=4k skip=100 count=1000 2>/dev/null
        local random_end_time
        random_end_time=$(date +%s.%N)
        local random_duration
        random_duration=$(echo "$random_end_time - $random_start_time" | bc -l)
        
        save_benchmark_result "file_io" "write_speed" "$write_speed" "MB/s" "$i"
        save_benchmark_result "file_io" "read_speed" "$read_speed" "MB/s" "$i"
        save_benchmark_result "file_io" "random_access_time" "$random_duration" "seconds" "$i"
        
        echo "Iteration $i: Write=${write_speed}MB/s, Read=${read_speed}MB/s, Random=${random_duration}s"
        
        # Clean up test file
        rm -f "$test_dir/write_test_$i.dat"
    done
    
    calculate_benchmark_stats "file_io"
    rm -rf "$test_dir"
}

# Benchmark: Network performance
benchmark_network() {
    log_info "Benchmarking network performance"
    
    for ((i=1; i<=BENCHMARK_ITERATIONS; i++)); do
        log_debug "Network benchmark iteration $i"
        
        # DNS resolution time
        local dns_start_time
        dns_start_time=$(date +%s.%N)
        nslookup github.com >/dev/null 2>&1
        local dns_end_time
        dns_end_time=$(date +%s.%N)
        local dns_duration
        dns_duration=$(echo "$dns_end_time - $dns_start_time" | bc -l)
        
        # HTTP connection time
        local http_start_time
        http_start_time=$(date +%s.%N)
        curl -s -o /dev/null -w "%{time_total}" https://api.github.com/zen >/dev/null 2>&1
        local http_end_time
        http_end_time=$(date +%s.%N)
        local http_duration
        http_duration=$(echo "$http_end_time - $http_start_time" | bc -l)
        
        # Download speed test (small file)
        local download_start_time
        download_start_time=$(date +%s.%N)
        curl -s -o /dev/null https://httpbin.org/bytes/1048576  # 1MB
        local download_end_time
        download_end_time=$(date +%s.%N)
        local download_duration
        download_duration=$(echo "$download_end_time - $download_start_time" | bc -l)
        local download_speed
        download_speed=$(echo "1 / $download_duration" | bc -l)
        
        save_benchmark_result "network" "dns_resolution" "$dns_duration" "seconds" "$i"
        save_benchmark_result "network" "http_connection" "$http_duration" "seconds" "$i"
        save_benchmark_result "network" "download_speed" "$download_speed" "MB/s" "$i"
        
        echo "Iteration $i: DNS=${dns_duration}s, HTTP=${http_duration}s, Download=${download_speed}MB/s"
        
        # Brief pause between iterations
        sleep 1
    done
    
    calculate_benchmark_stats "network"
}

# Benchmark: CPU performance
benchmark_cpu() {
    log_info "Benchmarking CPU performance"
    
    for ((i=1; i<=BENCHMARK_ITERATIONS; i++)); do
        log_debug "CPU benchmark iteration $i"
        
        # Integer calculation benchmark
        local int_start_time
        int_start_time=$(date +%s.%N)
        local result=0
        for ((j=1; j<=1000000; j++)); do
            result=$((result + j))
        done
        local int_end_time
        int_end_time=$(date +%s.%N)
        local int_duration
        int_duration=$(echo "$int_end_time - $int_start_time" | bc -l)
        local int_rate
        int_rate=$(echo "1000000 / $int_duration" | bc -l)
        
        # Floating point benchmark (if bc is available)
        local float_duration=0
        if command -v bc >/dev/null 2>&1; then
            local float_start_time
            float_start_time=$(date +%s.%N)
            echo "scale=10; for(i=1;i<=10000;i++) { sqrt(i) }" | bc -l >/dev/null 2>&1
            local float_end_time
            float_end_time=$(date +%s.%N)
            float_duration=$(echo "$float_end_time - $float_start_time" | bc -l)
        fi
        
        # String processing benchmark
        local string_start_time
        string_start_time=$(date +%s.%N)
        local test_string=""
        for ((k=1; k<=1000; k++)); do
            test_string="${test_string}test_$k"
        done
        local string_end_time
        string_end_time=$(date +%s.%N)
        local string_duration
        string_duration=$(echo "$string_end_time - $string_start_time" | bc -l)
        
        save_benchmark_result "cpu" "integer_ops" "$int_rate" "ops/sec" "$i"
        save_benchmark_result "cpu" "string_processing" "$string_duration" "seconds" "$i"
        
        if (( $(echo "$float_duration > 0" | bc -l) )); then
            save_benchmark_result "cpu" "floating_point" "$float_duration" "seconds" "$i"
        fi
        
        echo "Iteration $i: Int=${int_rate}ops/s, String=${string_duration}s, Float=${float_duration}s"
    done
    
    calculate_benchmark_stats "cpu"
}

# Benchmark: Memory performance
benchmark_memory() {
    log_info "Benchmarking memory performance"
    
    for ((i=1; i<=BENCHMARK_ITERATIONS; i++)); do
        log_debug "Memory benchmark iteration $i"
        
        # Memory allocation speed
        local alloc_start_time
        alloc_start_time=$(date +%s.%N)
        declare -a test_array
        for ((j=1; j<=10000; j++)); do
            test_array[$j]="memory_test_data_$j"
        done
        local alloc_end_time
        alloc_end_time=$(date +%s.%N)
        local alloc_duration
        alloc_duration=$(echo "$alloc_end_time - $alloc_start_time" | bc -l)
        
        # Memory access speed
        local access_start_time
        access_start_time=$(date +%s.%N)
        local access_count=0
        for ((k=1; k<=1000; k++)); do
            local index=$((RANDOM % 10000 + 1))
            if [[ -n "${test_array[$index]:-}" ]]; then
                ((access_count++))
            fi
        done
        local access_end_time
        access_end_time=$(date +%s.%N)
        local access_duration
        access_duration=$(echo "$access_end_time - $access_start_time" | bc -l)
        
        # Memory deallocation speed
        local dealloc_start_time
        dealloc_start_time=$(date +%s.%N)
        unset test_array
        local dealloc_end_time
        dealloc_end_time=$(date +%s.%N)
        local dealloc_duration
        dealloc_duration=$(echo "$dealloc_end_time - $dealloc_start_time" | bc -l)
        
        save_benchmark_result "memory" "allocation_time" "$alloc_duration" "seconds" "$i"
        save_benchmark_result "memory" "access_time" "$access_duration" "seconds" "$i"
        save_benchmark_result "memory" "deallocation_time" "$dealloc_duration" "seconds" "$i"
        
        echo "Iteration $i: Alloc=${alloc_duration}s, Access=${access_duration}s, Dealloc=${dealloc_duration}s"
    done
    
    calculate_benchmark_stats "memory"
}

# Benchmark: Container operations (if Docker available)
benchmark_container_operations() {
    log_info "Benchmarking container operations"
    
    if ! command -v docker >/dev/null 2>&1; then
        echo "Docker not available, skipping container benchmarks"
        return 0
    fi
    
    # Ensure test image is available
    docker pull alpine:latest >/dev/null 2>&1 || return 0
    
    for ((i=1; i<=BENCHMARK_ITERATIONS; i++)); do
        log_debug "Container benchmark iteration $i"
        
        # Container startup time
        local start_time
        start_time=$(date +%s.%N)
        local container_id
        container_id=$(docker run -d alpine:latest sleep 10)
        # Wait for container to be running
        while [[ "$(docker inspect -f '{{.State.Status}}' "$container_id")" != "running" ]]; do
            sleep 0.01
        done
        local start_end_time
        start_end_time=$(date +%s.%N)
        local start_duration
        start_duration=$(echo "$start_end_time - $start_time" | bc -l)
        
        # Container execution time
        local exec_start_time
        exec_start_time=$(date +%s.%N)
        docker exec "$container_id" echo "test" >/dev/null 2>&1
        local exec_end_time
        exec_end_time=$(date +%s.%N)
        local exec_duration
        exec_duration=$(echo "$exec_end_time - $exec_start_time" | bc -l)
        
        # Container stop time
        local stop_start_time
        stop_start_time=$(date +%s.%N)
        docker stop "$container_id" >/dev/null 2>&1
        local stop_end_time
        stop_end_time=$(date +%s.%N)
        local stop_duration
        stop_duration=$(echo "$stop_end_time - $stop_start_time" | bc -l)
        
        # Cleanup
        docker rm "$container_id" >/dev/null 2>&1
        
        save_benchmark_result "container" "startup_time" "$start_duration" "seconds" "$i"
        save_benchmark_result "container" "exec_time" "$exec_duration" "seconds" "$i"
        save_benchmark_result "container" "stop_time" "$stop_duration" "seconds" "$i"
        
        echo "Iteration $i: Start=${start_duration}s, Exec=${exec_duration}s, Stop=${stop_duration}s"
    done
    
    calculate_benchmark_stats "container"
}

# Generate comprehensive benchmark report
generate_benchmark_report() {
    log_info "Generating comprehensive benchmark report"
    
    local report_file="$BENCHMARK_RESULTS_DIR/benchmark_report.html"
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>GitHub Actions Runner - Performance Benchmarks</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f8f9fa; padding: 20px; border-radius: 5px; }
        .benchmark-section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background-color: #e9ecef; border-radius: 3px; }
        .metric-name { font-weight: bold; }
        .metric-value { color: #007bff; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>GitHub Actions Runner - Performance Benchmarks</h1>
        <p>Generated on: <span id="timestamp"></span></p>
        <p>System: <span id="hostname"></span></p>
    </div>
    
    <div id="benchmark-results"></div>
    
    <script>
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
        document.getElementById('hostname').textContent = window.location.hostname || 'localhost';
        
        // Benchmark data will be inserted here
    </script>
</body>
</html>
EOF

    # Add benchmark data to report
    local benchmark_files
    benchmark_files=$(find "$BENCHMARK_RESULTS_DIR" -name "*_benchmark.json" 2>/dev/null || echo "")
    
    if [[ -n "$benchmark_files" ]]; then
        echo "<script>" >> "$report_file"
        echo "const benchmarkData = [" >> "$report_file"
        
        local first_file=true
        while IFS= read -r benchmark_file; do
            if [[ "$first_file" == "false" ]]; then
                echo "," >> "$report_file"
            fi
            cat "$benchmark_file" >> "$report_file"
            first_file=false
        done <<< "$benchmark_files"
        
        echo "];" >> "$report_file"
        
        cat >> "$report_file" << 'EOF'
        
        // Generate benchmark sections
        const resultsDiv = document.getElementById('benchmark-results');
        
        benchmarkData.forEach(benchmark => {
            const section = document.createElement('div');
            section.className = 'benchmark-section';
            
            const title = document.createElement('h2');
            title.textContent = benchmark.test_name.replace('_', ' ').toUpperCase();
            section.appendChild(title);
            
            Object.entries(benchmark.metrics).forEach(([metricName, metricData]) => {
                const metric = document.createElement('div');
                metric.className = 'metric';
                
                const values = metricData.values.map(v => v.value);
                const min = Math.min(...values);
                const max = Math.max(...values);
                const avg = values.reduce((a, b) => a + b, 0) / values.length;
                
                metric.innerHTML = `
                    <div class="metric-name">${metricName.replace('_', ' ')}</div>
                    <div class="metric-value">
                        Avg: ${avg.toFixed(2)} ${metricData.unit}<br>
                        Min: ${min.toFixed(2)} ${metricData.unit}<br>
                        Max: ${max.toFixed(2)} ${metricData.unit}
                    </div>
                `;
                
                section.appendChild(metric);
            });
            
            resultsDiv.appendChild(section);
        });
    </script>
</body>
</html>
EOF

        log_success "Benchmark report generated: $report_file"
    else
        log_warn "No benchmark data found for report generation"
    fi
}

# Main benchmark execution
main() {
    setup_test_environment
    
    log_info "Running performance benchmarks with $BENCHMARK_ITERATIONS iterations each"
    
    # Run all benchmarks
    run_test "system_boot_benchmark" "benchmark_system_boot_time" \
        "Benchmark system boot time"
    
    run_test "service_startup_benchmark" "benchmark_service_startup" \
        "Benchmark service startup/shutdown time"
    
    run_test "file_io_benchmark" "benchmark_file_io" \
        "Benchmark file I/O performance"
    
    run_test "network_benchmark" "benchmark_network" \
        "Benchmark network performance"
    
    run_test "cpu_benchmark" "benchmark_cpu" \
        "Benchmark CPU performance"
    
    run_test "memory_benchmark" "benchmark_memory" \
        "Benchmark memory performance"
    
    run_test "container_benchmark" "benchmark_container_operations" \
        "Benchmark container operations"
    
    # Generate comprehensive report
    generate_benchmark_report
    
    cleanup_test_environment
    finalize_test_framework
}

# Run benchmarks if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi