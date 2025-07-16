#!/bin/bash

# GitHub Actions Runner - Job Execution Tests
# Tests for workflow execution, job completion, and error handling

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/test-framework.sh"

# Test configuration
RUNNER_DIR="${RUNNER_DIR:-/opt/github-actions-runner}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
TEST_REPO="${TEST_REPO:-}"
WORKFLOW_TIMEOUT="${WORKFLOW_TIMEOUT:-300}"

# Initialize test framework
init_test_framework "Job Execution Tests"

# Test: Basic workflow execution
test_basic_workflow_execution() {
    log_info "Testing basic workflow execution"
    
    if [[ -z "$GITHUB_TOKEN" ]] || [[ -z "$TEST_REPO" ]]; then
        echo "GITHUB_TOKEN or TEST_REPO not set, skipping workflow execution tests"
        return 1
    fi
    
    # Create a simple test workflow
    local workflow_content
    workflow_content=$(cat << 'EOF'
name: Test Workflow
on:
  workflow_dispatch:
    inputs:
      test_id:
        description: 'Test ID'
        required: true

jobs:
  test:
    runs-on: self-hosted
    steps:
      - name: Echo test
        run: echo "Test ID: ${{ github.event.inputs.test_id }}"
      
      - name: System info
        run: |
          echo "Hostname: $(hostname)"
          echo "Date: $(date)"
          echo "User: $(whoami)"
          
      - name: Create test file
        run: |
          echo "Test execution successful" > /tmp/test_execution_${{ github.event.inputs.test_id }}.txt
          cat /tmp/test_execution_${{ github.event.inputs.test_id }}.txt
EOF
)
    
    # Generate unique test ID
    local test_id
    test_id="test_$(date +%s)"
    
    echo "Created test workflow for execution test"
    echo "Test ID: $test_id"
    
    # Note: In a real test, you would trigger the workflow via GitHub API
    # For this test, we'll simulate the expected behavior
    
    # Check if runner can access the work directory
    local work_dir="$RUNNER_DIR/_work"
    assert_directory_exists "$work_dir" "Runner work directory should exist"
    
    # Simulate workflow execution environment
    local test_work_dir="$work_dir/test_$test_id"
    mkdir -p "$test_work_dir"
    
    # Test basic commands that workflows would use
    assert_command_success "cd '$test_work_dir' && echo 'test' > test.txt" \
        "Should be able to create files in work directory"
    
    assert_command_success "cd '$test_work_dir' && ls -la" \
        "Should be able to list files in work directory"
    
    # Cleanup
    rm -rf "$test_work_dir"
    
    echo "Basic workflow execution test: OK"
}

# Test: Environment variable handling
test_environment_variables() {
    log_info "Testing environment variable handling"
    
    # Test standard GitHub Actions environment variables
    local test_env_script="$TEST_TEMP_DIR/test_env.sh"
    cat > "$test_env_script" << 'EOF'
#!/bin/bash
echo "Testing environment variables..."

# Standard variables that should be available in GitHub Actions
echo "HOME: ${HOME:-not_set}"
echo "USER: ${USER:-not_set}"
echo "PATH: ${PATH:-not_set}"

# Test setting and reading custom variables
export TEST_VAR="test_value"
echo "TEST_VAR: ${TEST_VAR}"

# Test multi-line variables
export MULTI_LINE_VAR="line1
line2
line3"
echo "MULTI_LINE_VAR: ${MULTI_LINE_VAR}"

# Test special characters
export SPECIAL_VAR="test with spaces and symbols: !@#$%"
echo "SPECIAL_VAR: ${SPECIAL_VAR}"

echo "Environment variable test completed successfully"
EOF

    chmod +x "$test_env_script"
    
    assert_command_success "$test_env_script" \
        "Environment variable test script should execute successfully"
    
    echo "Environment variable handling: OK"
}

# Test: Secrets handling simulation
test_secrets_handling() {
    log_info "Testing secrets handling simulation"
    
    # Test that sensitive information is not logged
    local test_script="$TEST_TEMP_DIR/test_secrets.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash

# Simulate secret handling
SECRET_VALUE="super_secret_password_123"

# Test that we can use secrets without exposing them
echo "Using secret in command..."
if [[ "$SECRET_VALUE" == "super_secret_password_123" ]]; then
    echo "Secret validation: OK"
else
    echo "Secret validation: FAILED"
    exit 1
fi

# Test that secrets are not accidentally logged
echo "This line should not contain the secret"

# Cleanup - ensure secret is not left in environment
unset SECRET_VALUE

echo "Secrets handling test completed"
EOF

    chmod +x "$test_script"
    
    local output
    output=$("$test_script" 2>&1)
    
    assert_contains "$output" "Secret validation: OK" \
        "Secret validation should pass"
    
    assert_not_contains "$output" "super_secret_password_123" \
        "Secret value should not appear in output"
    
    echo "Secrets handling: OK"
}

# Test: Container execution (if Docker is available)
test_container_execution() {
    log_info "Testing container execution"
    
    if ! command -v docker >/dev/null 2>&1; then
        echo "Docker not available, skipping container execution tests"
        return 0
    fi
    
    # Test pulling and running a simple container
    assert_command_success "docker pull alpine:latest" \
        "Should be able to pull Docker images"
    
    assert_command_success "docker run --rm alpine:latest echo 'Container test successful'" \
        "Should be able to run simple containers"
    
    # Test container with volume mounts
    local test_volume_dir="$TEST_TEMP_DIR/volume_test"
    mkdir -p "$test_volume_dir"
    echo "test content" > "$test_volume_dir/test.txt"
    
    assert_command_success "docker run --rm -v '$test_volume_dir:/workspace' alpine:latest cat /workspace/test.txt" \
        "Should be able to mount volumes in containers"
    
    # Test container networking
    assert_command_success "docker run --rm alpine:latest ping -c 1 8.8.8.8" \
        "Container should have network access"
    
    echo "Container execution: OK"
}

# Test: Artifact handling simulation
test_artifact_handling() {
    log_info "Testing artifact handling simulation"
    
    local artifacts_dir="$TEST_TEMP_DIR/artifacts"
    mkdir -p "$artifacts_dir"
    
    # Create test artifacts
    echo "Build artifact content" > "$artifacts_dir/build.txt"
    echo "Test results content" > "$artifacts_dir/results.xml"
    
    # Create archive
    local archive_file="$artifacts_dir/artifacts.tar.gz"
    tar -czf "$archive_file" -C "$artifacts_dir" build.txt results.xml
    
    assert_file_exists "$archive_file" "Artifact archive should be created"
    
    # Test archive extraction
    local extract_dir="$TEST_TEMP_DIR/extract"
    mkdir -p "$extract_dir"
    tar -xzf "$archive_file" -C "$extract_dir"
    
    assert_file_exists "$extract_dir/build.txt" "Extracted artifact should exist"
    assert_file_exists "$extract_dir/results.xml" "Extracted test results should exist"
    
    echo "Artifact handling: OK"
}

# Test: Workspace management
test_workspace_management() {
    log_info "Testing workspace management"
    
    local workspace_dir="$TEST_TEMP_DIR/workspace"
    mkdir -p "$workspace_dir"
    
    # Test workspace initialization
    cd "$workspace_dir"
    
    # Simulate git repository setup
    assert_command_success "git init" "Should be able to initialize git repository"
    assert_command_success "git config user.name 'Test User'" "Should be able to configure git"
    assert_command_success "git config user.email 'test@example.com'" "Should be able to configure git email"
    
    # Test file operations
    echo "test content" > "test_file.txt"
    assert_command_success "git add test_file.txt" "Should be able to add files to git"
    assert_command_success "git commit -m 'Test commit'" "Should be able to commit changes"
    
    # Test directory operations
    mkdir -p "subdir/nested"
    echo "nested content" > "subdir/nested/file.txt"
    
    assert_file_exists "subdir/nested/file.txt" "Nested file should exist"
    
    # Test permissions
    chmod +x "test_file.txt"
    assert_command_success "test -x test_file.txt" "Should be able to change file permissions"
    
    echo "Workspace management: OK"
}

# Test: Error handling and recovery
test_error_handling() {
    log_info "Testing error handling and recovery"
    
    # Test script that fails
    local failing_script="$TEST_TEMP_DIR/failing_script.sh"
    cat > "$failing_script" << 'EOF'
#!/bin/bash
set -e

echo "Starting test script..."
echo "This should work fine"

# This command should fail
false

echo "This should not be reached"
EOF

    chmod +x "$failing_script"
    
    # Test that the script fails as expected
    assert_command_failure "$failing_script" \
        "Failing script should exit with non-zero code"
    
    # Test recovery script
    local recovery_script="$TEST_TEMP_DIR/recovery_script.sh"
    cat > "$recovery_script" << 'EOF'
#!/bin/bash

echo "Testing error recovery..."

# Test command that might fail
if ! false; then
    echo "Command failed as expected, continuing with recovery"
else
    echo "Unexpected success"
fi

# Test recovery logic
cleanup_temp_files() {
    echo "Cleaning up temporary files..."
    # Cleanup logic here
}

# Simulate error handling
trap cleanup_temp_files EXIT

echo "Recovery test completed successfully"
EOF

    chmod +x "$recovery_script"
    
    assert_command_success "$recovery_script" \
        "Recovery script should handle errors gracefully"
    
    echo "Error handling and recovery: OK"
}

# Test: Resource usage during execution
test_resource_usage() {
    log_info "Testing resource usage during execution"
    
    # Test memory-intensive task
    local memory_test_script="$TEST_TEMP_DIR/memory_test.sh"
    cat > "$memory_test_script" << 'EOF'
#!/bin/bash

echo "Testing memory usage..."

# Create array to consume some memory
declare -a test_array

for i in {1..1000}; do
    test_array[$i]="This is test data for memory testing iteration $i"
done

echo "Memory test array created with ${#test_array[@]} elements"

# Monitor memory usage
memory_usage=$(ps -o pid,pmem,rss,comm -p $$ | tail -1)
echo "Current process memory: $memory_usage"

# Cleanup
unset test_array

echo "Memory test completed"
EOF

    chmod +x "$memory_test_script"
    
    # Measure execution time and memory
    local start_time end_time
    start_time=$(date +%s)
    
    assert_command_success "$memory_test_script" \
        "Memory test script should execute successfully"
    
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "Memory test execution time: ${duration}s"
    
    # Test CPU-intensive task
    local cpu_test_script="$TEST_TEMP_DIR/cpu_test.sh"
    cat > "$cpu_test_script" << 'EOF'
#!/bin/bash

echo "Testing CPU usage..."

# Perform some CPU-intensive calculations
result=0
for i in {1..10000}; do
    result=$((result + i * 2))
done

echo "CPU test completed, result: $result"
EOF

    chmod +x "$cpu_test_script"
    
    start_time=$(date +%s.%N)
    assert_command_success "$cpu_test_script" \
        "CPU test script should execute successfully"
    end_time=$(date +%s.%N)
    
    local cpu_duration
    cpu_duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    echo "CPU test execution time: ${cpu_duration}s"
    
    echo "Resource usage testing: OK"
}

# Test: Concurrent job simulation
test_concurrent_jobs() {
    log_info "Testing concurrent job simulation"
    
    # Create multiple test scripts to simulate concurrent jobs
    local job_scripts=()
    local num_jobs=3
    
    for ((i=1; i<=num_jobs; i++)); do
        local job_script="$TEST_TEMP_DIR/job_$i.sh"
        cat > "$job_script" << EOF
#!/bin/bash
echo "Job $i starting at \$(date)"
sleep 2
echo "Job $i working..."
echo "Job $i result: \$((RANDOM % 100))"
echo "Job $i completed at \$(date)"
EOF
        chmod +x "$job_script"
        job_scripts+=("$job_script")
    done
    
    # Run jobs concurrently
    local pids=()
    local start_time
    start_time=$(date +%s)
    
    for script in "${job_scripts[@]}"; do
        "$script" > "${script}.output" 2>&1 &
        pids+=($!)
    done
    
    # Wait for all jobs to complete
    local failed_jobs=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            ((failed_jobs++))
        fi
    done
    
    local end_time
    end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    echo "Concurrent jobs completed in ${total_duration}s"
    echo "Failed jobs: $failed_jobs"
    
    # Verify all job outputs
    for script in "${job_scripts[@]}"; do
        assert_file_exists "${script}.output" "Job output file should exist"
    done
    
    assert_equals "0" "$failed_jobs" "No jobs should fail"
    
    echo "Concurrent job simulation: OK"
}

# Test: Cleanup after job completion
test_job_cleanup() {
    log_info "Testing job cleanup"
    
    local job_workspace="$TEST_TEMP_DIR/job_workspace"
    mkdir -p "$job_workspace"
    
    # Simulate job execution that creates files
    cd "$job_workspace"
    
    # Create various types of files
    echo "build output" > build.out
    echo "test log" > test.log
    echo "temporary data" > temp.tmp
    mkdir -p cache/data
    echo "cached data" > cache/data/cache.dat
    
    # Create large file to test cleanup
    dd if=/dev/zero of=large_file.dat bs=1M count=10 2>/dev/null
    
    assert_file_exists "build.out" "Build output should exist"
    assert_file_exists "large_file.dat" "Large file should exist"
    
    # Test selective cleanup (keep important files, remove temporary ones)
    rm -f *.tmp
    rm -rf cache/
    
    assert_file_exists "build.out" "Build output should still exist after cleanup"
    assert_command_failure "test -f temp.tmp" "Temporary file should be removed"
    assert_command_failure "test -d cache" "Cache directory should be removed"
    
    # Test complete cleanup
    cd "$TEST_TEMP_DIR"
    rm -rf "$job_workspace"
    
    assert_command_failure "test -d '$job_workspace'" "Job workspace should be completely removed"
    
    echo "Job cleanup: OK"
}

# Main test execution
main() {
    setup_test_environment
    
    # Run job execution tests
    run_test "basic_workflow_execution" "test_basic_workflow_execution" \
        "Test basic workflow execution capabilities"
    
    run_test "environment_variables" "test_environment_variables" \
        "Test environment variable handling"
    
    run_test "secrets_handling" "test_secrets_handling" \
        "Test secrets handling simulation"
    
    run_test "container_execution" "test_container_execution" \
        "Test container execution capabilities"
    
    run_test "artifact_handling" "test_artifact_handling" \
        "Test artifact creation and handling"
    
    run_test "workspace_management" "test_workspace_management" \
        "Test workspace setup and management"
    
    run_test "error_handling" "test_error_handling" \
        "Test error handling and recovery"
    
    run_test "resource_usage" "test_resource_usage" \
        "Test resource usage during execution"
    
    run_test "concurrent_jobs" "test_concurrent_jobs" \
        "Test concurrent job execution simulation"
    
    run_test "job_cleanup" "test_job_cleanup" \
        "Test cleanup after job completion"
    
    cleanup_test_environment
    finalize_test_framework
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi