#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$BACKUP_ROOT")"

source "$BACKUP_ROOT/scripts/common/backup-functions.sh"
source "$PROJECT_ROOT/scripts/common/logging.sh"
source "$PROJECT_ROOT/scripts/common/utils.sh"

setup_logging "/var/log/github-runner-backup-storage.log"

usage() {
    cat << 'EOF'
Usage: storage-manager.sh [OPTIONS] COMMAND

Manage backup storage for GitHub Actions runner

COMMANDS:
    setup               Set up backup storage configuration
    test                Test storage connectivity and performance
    sync                Sync backups to remote storage
    cleanup             Clean up old backups based on retention policy
    monitor             Monitor storage usage and health
    migrate             Migrate backups between storage systems
    encrypt             Encrypt existing backup files
    decrypt             Decrypt backup files
    list                List available backups across all storage
    verify              Verify backup integrity across storage systems

OPTIONS:
    -h, --help              Show this help message
    -c, --config FILE       Backup configuration file
    -s, --storage TYPE      Storage type (local, s3, rsync, scp)
    -d, --destination PATH  Storage destination
    --dry-run               Show what would be done without making changes
    --force                 Force operations without confirmation
    -v, --verbose           Verbose output

Examples:
    ./storage-manager.sh setup --storage s3 --destination s3://my-bucket/backups
    ./storage-manager.sh test                               # Test all configured storage
    ./storage-manager.sh sync --storage rsync              # Sync to rsync destination
    ./storage-manager.sh cleanup --dry-run                 # Preview cleanup operations
    ./storage-manager.sh monitor                           # Show storage status
EOF
}

COMMAND=""
CONFIG_FILE="$BACKUP_ROOT/config/backup.conf"
STORAGE_TYPE=""
DESTINATION=""
DRY_RUN=false
FORCE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -s|--storage)
            STORAGE_TYPE="$2"
            shift 2
            ;;
        -d|--destination)
            DESTINATION="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            LOG_LEVEL="DEBUG"
            shift
            ;;
        setup|test|sync|cleanup|monitor|migrate|encrypt|decrypt|list|verify)
            COMMAND="$1"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$COMMAND" ]]; then
    log_error "Command is required"
    usage
    exit 1
fi

main() {
    log_section "GitHub Actions Runner - Storage Manager"
    
    load_backup_config "$CONFIG_FILE"
    
    case "$COMMAND" in
        setup)
            setup_storage
            ;;
        test)
            test_storage
            ;;
        sync)
            sync_storage
            ;;
        cleanup)
            cleanup_storage
            ;;
        monitor)
            monitor_storage
            ;;
        migrate)
            migrate_storage
            ;;
        encrypt)
            encrypt_storage
            ;;
        decrypt)
            decrypt_storage
            ;;
        list)
            list_storage
            ;;
        verify)
            verify_storage
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            usage
            exit 1
            ;;
    esac
}

setup_storage() {
    log_info "Setting up backup storage configuration..."
    
    if [[ -z "$STORAGE_TYPE" ]]; then
        STORAGE_TYPE="${BACKUP_REMOTE_TYPE:-local}"
    fi
    
    if [[ -z "$DESTINATION" ]]; then
        DESTINATION="${BACKUP_REMOTE_DESTINATION:-$BACKUP_DESTINATION}"
    fi
    
    log_info "Storage type: $STORAGE_TYPE"
    log_info "Destination: $DESTINATION"
    
    case "$STORAGE_TYPE" in
        "local")
            setup_local_storage
            ;;
        "s3")
            setup_s3_storage
            ;;
        "rsync")
            setup_rsync_storage
            ;;
        "scp")
            setup_scp_storage
            ;;
        "ftp")
            setup_ftp_storage
            ;;
        *)
            log_error "Unsupported storage type: $STORAGE_TYPE"
            exit 1
            ;;
    esac
    
    # Test the configuration
    log_info "Testing storage configuration..."
    if test_storage_connectivity "$STORAGE_TYPE" "$DESTINATION"; then
        log_success "Storage setup completed successfully"
        
        # Update configuration file
        update_storage_config "$STORAGE_TYPE" "$DESTINATION"
    else
        log_error "Storage setup failed - connectivity test failed"
        exit 1
    fi
}

setup_local_storage() {
    log_info "Setting up local storage..."
    
    local storage_dir="$DESTINATION"
    
    # Create storage directory structure
    if [[ ! -d "$storage_dir" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$storage_dir"
            mkdir -p "$storage_dir"/{archives,manifests,logs,temp}
        fi
        log_info "Created storage directory: $storage_dir"
    fi
    
    # Set appropriate permissions
    if [[ "$DRY_RUN" == false ]]; then
        chmod 750 "$storage_dir"
        chown "${BACKUP_USER:-root}:${BACKUP_USER:-root}" "$storage_dir" 2>/dev/null || true
    fi
    
    # Check available space
    local available_gb
    available_gb=$(df -BG "$storage_dir" | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [[ "$available_gb" -lt 10 ]]; then
        log_warn "Low available space: ${available_gb}GB (recommended: 10GB+)"
    else
        log_info "Available space: ${available_gb}GB"
    fi
    
    # Create storage configuration
    cat > "$storage_dir/.storage-config" << EOF
{
    "storage_type": "local",
    "destination": "$storage_dir",
    "created": "$(date -Iseconds)",
    "created_by": "$(whoami)"
}
EOF
    
    log_success "Local storage configured"
}

setup_s3_storage() {
    log_info "Setting up AWS S3 storage..."
    
    # Check AWS CLI availability
    if ! command -v aws >/dev/null 2>&1; then
        log_error "AWS CLI not found. Please install AWS CLI first."
        exit 1
    fi
    
    # Parse S3 destination
    local s3_bucket
    local s3_prefix
    if [[ "$DESTINATION" =~ ^s3://([^/]+)/?(.*)$ ]]; then
        s3_bucket="${BASH_REMATCH[1]}"
        s3_prefix="${BASH_REMATCH[2]}"
    else
        log_error "Invalid S3 destination format. Use: s3://bucket-name/prefix"
        exit 1
    fi
    
    log_info "S3 Bucket: $s3_bucket"
    log_info "S3 Prefix: $s3_prefix"
    
    # Test AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    # Check if bucket exists and is accessible
    if aws s3 ls "s3://$s3_bucket" >/dev/null 2>&1; then
        log_info "S3 bucket is accessible"
    else
        log_error "S3 bucket not accessible: $s3_bucket"
        exit 1
    fi
    
    # Test write access
    local test_file="/tmp/s3-test-$$"
    echo "S3 connectivity test" > "$test_file"
    
    if [[ "$DRY_RUN" == false ]]; then
        if aws s3 cp "$test_file" "$DESTINATION/test-file" >/dev/null 2>&1; then
            aws s3 rm "$DESTINATION/test-file" >/dev/null 2>&1
            log_success "S3 write access verified"
        else
            log_error "S3 write access test failed"
            rm -f "$test_file"
            exit 1
        fi
    fi
    
    rm -f "$test_file"
    
    # Configure S3 sync options
    create_s3_sync_script "$s3_bucket" "$s3_prefix"
    
    log_success "S3 storage configured"
}

setup_rsync_storage() {
    log_info "Setting up rsync storage..."
    
    # Check rsync availability
    if ! command -v rsync >/dev/null 2>&1; then
        log_error "rsync command not found"
        exit 1
    fi
    
    # Parse rsync destination
    local rsync_host=""
    local rsync_path=""
    
    if [[ "$DESTINATION" =~ ^rsync://([^/]+)/(.*)$ ]]; then
        rsync_host="${BASH_REMATCH[1]}"
        rsync_path="${BASH_REMATCH[2]}"
    elif [[ "$DESTINATION" =~ ^([^:]+):(.*)$ ]]; then
        rsync_host="${BASH_REMATCH[1]}"
        rsync_path="${BASH_REMATCH[2]}"
    else
        rsync_path="$DESTINATION"
    fi
    
    # Test rsync connectivity
    if [[ -n "$rsync_host" ]]; then
        log_info "Testing rsync connectivity to: $rsync_host"
        
        local test_file="/tmp/rsync-test-$$"
        echo "Rsync connectivity test" > "$test_file"
        
        if [[ "$DRY_RUN" == false ]]; then
            if rsync "$test_file" "$DESTINATION/test-file" >/dev/null 2>&1; then
                rsync --delete "$test_file" "$DESTINATION/test-file" >/dev/null 2>&1
                log_success "Rsync connectivity verified"
            else
                log_error "Rsync connectivity test failed"
                rm -f "$test_file"
                exit 1
            fi
        fi
        
        rm -f "$test_file"
    else
        # Local rsync destination
        if [[ ! -d "$rsync_path" ]]; then
            if [[ "$DRY_RUN" == false ]]; then
                mkdir -p "$rsync_path"
            fi
            log_info "Created rsync destination: $rsync_path"
        fi
    fi
    
    # Create rsync configuration
    create_rsync_sync_script "$DESTINATION"
    
    log_success "Rsync storage configured"
}

setup_scp_storage() {
    log_info "Setting up SCP storage..."
    
    # Check scp availability
    if ! command -v scp >/dev/null 2>&1; then
        log_error "scp command not found"
        exit 1
    fi
    
    # Parse SCP destination
    local scp_host=""
    local scp_path=""
    
    if [[ "$DESTINATION" =~ ^([^:]+):(.*)$ ]]; then
        scp_host="${BASH_REMATCH[1]}"
        scp_path="${BASH_REMATCH[2]}"
    else
        log_error "Invalid SCP destination format. Use: user@host:/path"
        exit 1
    fi
    
    log_info "SCP Host: $scp_host"
    log_info "SCP Path: $scp_path"
    
    # Test SCP connectivity
    local test_file="/tmp/scp-test-$$"
    echo "SCP connectivity test" > "$test_file"
    
    if [[ "$DRY_RUN" == false ]]; then
        if scp "$test_file" "$DESTINATION/test-file" >/dev/null 2>&1; then
            ssh "$scp_host" "rm -f $scp_path/test-file" >/dev/null 2>&1
            log_success "SCP connectivity verified"
        else
            log_error "SCP connectivity test failed"
            rm -f "$test_file"
            exit 1
        fi
    fi
    
    rm -f "$test_file"
    
    # Create SCP sync script
    create_scp_sync_script "$scp_host" "$scp_path"
    
    log_success "SCP storage configured"
}

setup_ftp_storage() {
    log_info "Setting up FTP storage..."
    
    # Check FTP client availability
    if ! command -v lftp >/dev/null 2>&1 && ! command -v ftp >/dev/null 2>&1; then
        log_error "No FTP client found (lftp or ftp required)"
        exit 1
    fi
    
    log_warn "FTP storage setup requires manual configuration"
    log_info "Please configure FTP credentials in: $BACKUP_ROOT/config/ftp-credentials"
    
    # Create FTP credentials template
    if [[ ! -f "$BACKUP_ROOT/config/ftp-credentials" ]]; then
        cat > "$BACKUP_ROOT/config/ftp-credentials" << 'EOF'
# FTP Credentials Configuration
FTP_HOST=""
FTP_PORT=21
FTP_USERNAME=""
FTP_PASSWORD=""
FTP_PASSIVE=true
FTP_SSL=false
EOF
        chmod 600 "$BACKUP_ROOT/config/ftp-credentials"
        log_info "Created FTP credentials template"
    fi
    
    log_success "FTP storage configuration template created"
}

test_storage() {
    log_info "Testing storage connectivity and performance..."
    
    local storage_type="${STORAGE_TYPE:-$BACKUP_REMOTE_TYPE}"
    local destination="${DESTINATION:-$BACKUP_REMOTE_DESTINATION}"
    
    if [[ -z "$storage_type" || "$storage_type" == "local" ]]; then
        test_local_storage
    fi
    
    if [[ "$storage_type" != "local" && -n "$destination" ]]; then
        test_remote_storage "$storage_type" "$destination"
    fi
    
    # Performance test
    perform_storage_benchmark
}

test_local_storage() {
    log_info "Testing local storage..."
    
    local storage_dir="${BACKUP_DESTINATION}"
    
    # Check directory existence and permissions
    if [[ ! -d "$storage_dir" ]]; then
        log_error "Local storage directory not found: $storage_dir"
        return 1
    fi
    
    if [[ ! -w "$storage_dir" ]]; then
        log_error "Local storage directory not writable: $storage_dir"
        return 1
    fi
    
    # Check available space
    local available_gb
    available_gb=$(df -BG "$storage_dir" | awk 'NR==2 {print $4}' | sed 's/G//')
    log_info "Available space: ${available_gb}GB"
    
    if [[ "$available_gb" -lt 5 ]]; then
        log_warn "Low available space: ${available_gb}GB"
    fi
    
    # Test file operations
    local test_file="$storage_dir/.storage-test-$$"
    
    if echo "Storage test" > "$test_file" 2>/dev/null; then
        if [[ -f "$test_file" ]]; then
            rm -f "$test_file"
            log_success "Local storage test passed"
            return 0
        fi
    fi
    
    log_error "Local storage test failed"
    return 1
}

test_remote_storage() {
    local storage_type="$1"
    local destination="$2"
    
    log_info "Testing remote storage: $storage_type"
    
    case "$storage_type" in
        "s3")
            test_s3_storage "$destination"
            ;;
        "rsync")
            test_rsync_storage "$destination"
            ;;
        "scp")
            test_scp_storage "$destination"
            ;;
        "ftp")
            test_ftp_storage "$destination"
            ;;
        *)
            log_error "Unsupported storage type for testing: $storage_type"
            return 1
            ;;
    esac
}

test_s3_storage() {
    local s3_destination="$1"
    
    log_info "Testing S3 storage connectivity..."
    
    # Test AWS CLI
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials test failed"
        return 1
    fi
    
    # Test bucket access
    local bucket
    bucket=$(echo "$s3_destination" | sed 's|s3://||' | cut -d'/' -f1)
    
    if ! aws s3 ls "s3://$bucket" >/dev/null 2>&1; then
        log_error "S3 bucket access test failed: $bucket"
        return 1
    fi
    
    # Test upload/download
    local test_file="/tmp/s3-test-$$"
    echo "S3 test data" > "$test_file"
    
    if aws s3 cp "$test_file" "$s3_destination/test-file" >/dev/null 2>&1; then
        if aws s3 cp "$s3_destination/test-file" "/tmp/s3-download-$$" >/dev/null 2>&1; then
            aws s3 rm "$s3_destination/test-file" >/dev/null 2>&1
            rm -f "$test_file" "/tmp/s3-download-$$"
            log_success "S3 storage test passed"
            return 0
        fi
    fi
    
    rm -f "$test_file"
    log_error "S3 storage test failed"
    return 1
}

test_rsync_storage() {
    local rsync_destination="$1"
    
    log_info "Testing rsync storage connectivity..."
    
    local test_file="/tmp/rsync-test-$$"
    echo "Rsync test data" > "$test_file"
    
    if rsync "$test_file" "$rsync_destination/test-file" >/dev/null 2>&1; then
        # Try to remove the test file
        if [[ "$rsync_destination" =~ : ]]; then
            # Remote destination
            local host
            host=$(echo "$rsync_destination" | cut -d':' -f1)
            local path
            path=$(echo "$rsync_destination" | cut -d':' -f2)
            ssh "$host" "rm -f $path/test-file" >/dev/null 2>&1
        else
            # Local destination
            rm -f "$rsync_destination/test-file" 2>/dev/null
        fi
        
        rm -f "$test_file"
        log_success "Rsync storage test passed"
        return 0
    fi
    
    rm -f "$test_file"
    log_error "Rsync storage test failed"
    return 1
}

test_scp_storage() {
    local scp_destination="$1"
    
    log_info "Testing SCP storage connectivity..."
    
    local test_file="/tmp/scp-test-$$"
    echo "SCP test data" > "$test_file"
    
    if scp "$test_file" "$scp_destination/test-file" >/dev/null 2>&1; then
        # Try to remove the test file
        local host
        host=$(echo "$scp_destination" | cut -d':' -f1)
        local path
        path=$(echo "$scp_destination" | cut -d':' -f2)
        ssh "$host" "rm -f $path/test-file" >/dev/null 2>&1
        
        rm -f "$test_file"
        log_success "SCP storage test passed"
        return 0
    fi
    
    rm -f "$test_file"
    log_error "SCP storage test failed"
    return 1
}

test_ftp_storage() {
    local ftp_destination="$1"
    
    log_info "Testing FTP storage connectivity..."
    
    # Check if credentials are configured
    local credentials_file="$BACKUP_ROOT/config/ftp-credentials"
    
    if [[ ! -f "$credentials_file" ]]; then
        log_error "FTP credentials not configured: $credentials_file"
        return 1
    fi
    
    source "$credentials_file"
    
    if [[ -z "$FTP_HOST" || -z "$FTP_USERNAME" ]]; then
        log_error "FTP credentials incomplete"
        return 1
    fi
    
    # Test FTP connection
    if command -v lftp >/dev/null 2>&1; then
        if lftp -u "$FTP_USERNAME,$FTP_PASSWORD" "$FTP_HOST" -e "ls; quit" >/dev/null 2>&1; then
            log_success "FTP storage test passed"
            return 0
        fi
    fi
    
    log_error "FTP storage test failed"
    return 1
}

perform_storage_benchmark() {
    log_info "Performing storage benchmark..."
    
    local storage_dir="${BACKUP_DESTINATION}"
    local test_file="$storage_dir/.benchmark-$$"
    local test_size_mb=100
    
    # Create test file
    log_info "Creating ${test_size_mb}MB test file..."
    local start_time=$(date +%s.%N)
    
    dd if=/dev/zero of="$test_file" bs=1M count=$test_size_mb >/dev/null 2>&1
    
    local write_time=$(date +%s.%N)
    local write_duration=$(echo "$write_time - $start_time" | bc 2>/dev/null || echo "0")
    local write_speed
    
    if [[ "$write_duration" != "0" ]]; then
        write_speed=$(echo "scale=2; $test_size_mb / $write_duration" | bc 2>/dev/null || echo "0")
        log_info "Write speed: ${write_speed} MB/s"
    fi
    
    # Read test
    log_info "Reading test file..."
    local read_start=$(date +%s.%N)
    
    dd if="$test_file" of=/dev/null bs=1M >/dev/null 2>&1
    
    local read_time=$(date +%s.%N)
    local read_duration=$(echo "$read_time - $read_start" | bc 2>/dev/null || echo "0")
    local read_speed
    
    if [[ "$read_duration" != "0" ]]; then
        read_speed=$(echo "scale=2; $test_size_mb / $read_duration" | bc 2>/dev/null || echo "0")
        log_info "Read speed: ${read_speed} MB/s"
    fi
    
    # Cleanup
    rm -f "$test_file"
    
    # Store benchmark results
    cat > "$storage_dir/.benchmark-results" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "test_size_mb": $test_size_mb,
    "write_speed_mbps": "${write_speed:-0}",
    "read_speed_mbps": "${read_speed:-0}",
    "write_duration": "${write_duration:-0}",
    "read_duration": "${read_duration:-0}"
}
EOF
    
    log_success "Storage benchmark completed"
}

test_storage_connectivity() {
    local storage_type="$1"
    local destination="$2"
    
    case "$storage_type" in
        "local")
            test_local_storage
            ;;
        "s3")
            test_s3_storage "$destination"
            ;;
        "rsync")
            test_rsync_storage "$destination"
            ;;
        "scp")
            test_scp_storage "$destination"
            ;;
        "ftp")
            test_ftp_storage "$destination"
            ;;
        *)
            log_error "Unknown storage type: $storage_type"
            return 1
            ;;
    esac
}

sync_storage() {
    log_info "Syncing backups to remote storage..."
    
    local storage_type="${STORAGE_TYPE:-$BACKUP_REMOTE_TYPE}"
    local destination="${DESTINATION:-$BACKUP_REMOTE_DESTINATION}"
    
    if [[ "$storage_type" == "local" ]]; then
        log_info "Local storage selected - no sync needed"
        return 0
    fi
    
    case "$storage_type" in
        "s3")
            sync_to_s3 "$destination"
            ;;
        "rsync")
            sync_to_rsync "$destination"
            ;;
        "scp")
            sync_to_scp "$destination"
            ;;
        *)
            log_error "Sync not implemented for storage type: $storage_type"
            return 1
            ;;
    esac
}

sync_to_s3() {
    local s3_destination="$1"
    
    log_info "Syncing to S3: $s3_destination"
    
    local sync_options="--delete"
    
    # Add storage class if specified
    if [[ -n "${BACKUP_S3_STORAGE_CLASS:-}" ]]; then
        sync_options="$sync_options --storage-class $BACKUP_S3_STORAGE_CLASS"
    fi
    
    # Add encryption if specified
    if [[ -n "${BACKUP_S3_ENCRYPTION:-}" ]]; then
        sync_options="$sync_options --sse $BACKUP_S3_ENCRYPTION"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        sync_options="$sync_options --dryrun"
        log_info "DRY RUN MODE - No actual sync will be performed"
    fi
    
    # Perform sync
    if aws s3 sync "$BACKUP_DESTINATION" "$s3_destination" $sync_options; then
        log_success "S3 sync completed"
        return 0
    else
        log_error "S3 sync failed"
        return 1
    fi
}

sync_to_rsync() {
    local rsync_destination="$1"
    
    log_info "Syncing to rsync: $rsync_destination"
    
    local rsync_options="${BACKUP_REMOTE_SYNC_OPTIONS:---archive --compress --delete}"
    
    if [[ "$DRY_RUN" == true ]]; then
        rsync_options="$rsync_options --dry-run"
        log_info "DRY RUN MODE - No actual sync will be performed"
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        rsync_options="$rsync_options --verbose --progress"
    fi
    
    # Perform sync
    if rsync $rsync_options "$BACKUP_DESTINATION/" "$rsync_destination/"; then
        log_success "Rsync sync completed"
        return 0
    else
        log_error "Rsync sync failed"
        return 1
    fi
}

sync_to_scp() {
    local scp_destination="$1"
    
    log_info "Syncing to SCP: $scp_destination"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN MODE - Would sync files to: $scp_destination"
        find "$BACKUP_DESTINATION" -type f -name "*.tar.gz" -o -name "*.manifest.json" | head -10
        return 0
    fi
    
    # Use rsync over SSH for efficient transfer
    local host
    host=$(echo "$scp_destination" | cut -d':' -f1)
    local path
    path=$(echo "$scp_destination" | cut -d':' -f2)
    
    if rsync -avz -e ssh "$BACKUP_DESTINATION/" "$host:$path/"; then
        log_success "SCP sync completed"
        return 0
    else
        log_error "SCP sync failed"
        return 1
    fi
}

cleanup_storage() {
    log_info "Cleaning up old backups..."
    
    # Local cleanup
    cleanup_local_storage
    
    # Remote cleanup if enabled
    local storage_type="${STORAGE_TYPE:-$BACKUP_REMOTE_TYPE}"
    
    if [[ "$storage_type" != "local" && "${BACKUP_REMOTE_ENABLED:-false}" == "true" ]]; then
        cleanup_remote_storage "$storage_type"
    fi
}

cleanup_local_storage() {
    log_info "Cleaning up local storage..."
    
    local retention_days="${BACKUP_RETENTION_DAYS}"
    cleanup_old_backups "$retention_days"
}

cleanup_remote_storage() {
    local storage_type="$1"
    
    log_info "Cleaning up remote storage: $storage_type"
    
    case "$storage_type" in
        "s3")
            cleanup_s3_storage
            ;;
        "rsync")
            cleanup_rsync_storage
            ;;
        *)
            log_warn "Remote cleanup not implemented for: $storage_type"
            ;;
    esac
}

cleanup_s3_storage() {
    log_info "Cleaning up S3 storage..."
    
    local s3_destination="${BACKUP_REMOTE_DESTINATION}"
    local retention_days="${BACKUP_REMOTE_RETENTION_DAYS:-180}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN MODE - Would clean up S3 objects older than $retention_days days"
        return 0
    fi
    
    # Use S3 lifecycle policies for efficient cleanup
    log_info "Note: Consider configuring S3 lifecycle policies for automated cleanup"
    
    # Manual cleanup (for demonstration)
    local cutoff_date
    cutoff_date=$(date -d "-$retention_days days" +%Y-%m-%d)
    
    aws s3api list-objects-v2 --bucket "$(echo "$s3_destination" | sed 's|s3://||' | cut -d'/' -f1)" \
        --prefix "$(echo "$s3_destination" | sed 's|s3://[^/]*/||')" \
        --query "Contents[?LastModified<='$cutoff_date'].Key" --output text | \
    while read -r key; do
        if [[ -n "$key" ]]; then
            log_info "Deleting old S3 object: $key"
            aws s3api delete-object --bucket "$(echo "$s3_destination" | sed 's|s3://||' | cut -d'/' -f1)" --key "$key"
        fi
    done
}

cleanup_rsync_storage() {
    log_info "Cleaning up rsync storage..."
    
    local rsync_destination="${BACKUP_REMOTE_DESTINATION}"
    local retention_days="${BACKUP_REMOTE_RETENTION_DAYS:-180}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN MODE - Would clean up files older than $retention_days days"
        return 0
    fi
    
    # Remote cleanup via SSH
    if [[ "$rsync_destination" =~ : ]]; then
        local host
        host=$(echo "$rsync_destination" | cut -d':' -f1)
        local path
        path=$(echo "$rsync_destination" | cut -d':' -f2)
        
        ssh "$host" "find $path -name '*.tar.gz' -o -name '*.manifest.json' -mtime +$retention_days -delete"
        log_info "Remote cleanup completed via SSH"
    else
        # Local rsync destination
        find "$rsync_destination" -name "*.tar.gz" -o -name "*.manifest.json" -mtime +"$retention_days" -delete
        log_info "Local rsync destination cleanup completed"
    fi
}

monitor_storage() {
    log_section "Storage Monitor Report"
    
    monitor_local_storage
    
    local storage_type="${BACKUP_REMOTE_TYPE:-}"
    if [[ -n "$storage_type" && "$storage_type" != "local" ]]; then
        monitor_remote_storage "$storage_type"
    fi
}

monitor_local_storage() {
    log_info "Local Storage Status:"
    echo "======================"
    
    local storage_dir="${BACKUP_DESTINATION}"
    
    # Directory status
    if [[ -d "$storage_dir" ]]; then
        echo "✓ Storage directory exists: $storage_dir"
        
        # Permissions
        local perms
        perms=$(stat -c %a "$storage_dir" 2>/dev/null || echo "unknown")
        echo "  Permissions: $perms"
        
        # Ownership
        local owner
        owner=$(stat -c "%U:%G" "$storage_dir" 2>/dev/null || echo "unknown")
        echo "  Owner: $owner"
        
        # Disk usage
        echo "  Disk Usage:"
        df -h "$storage_dir" | tail -n 1 | awk '{print "    Total: " $2 ", Used: " $3 ", Available: " $4 ", Use%: " $5}'
        
        # Backup count and size
        local backup_count
        backup_count=$(find "$storage_dir" -name "*.tar.gz" 2>/dev/null | wc -l)
        echo "  Backup Archives: $backup_count"
        
        local total_size
        total_size=$(du -sh "$storage_dir" 2>/dev/null | cut -f1)
        echo "  Total Size: $total_size"
        
        # Latest backup
        local latest_backup
        latest_backup=$(find "$storage_dir" -name "*.manifest.json" -printf "%T@ %p\n" 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
        if [[ -n "$latest_backup" ]]; then
            local backup_id
            backup_id=$(basename "$latest_backup" .manifest.json)
            local backup_date
            backup_date=$(jq -r '.iso_timestamp // "unknown"' "$latest_backup" 2>/dev/null)
            echo "  Latest Backup: $backup_id ($backup_date)"
        fi
        
    else
        echo "✗ Storage directory not found: $storage_dir"
    fi
    
    echo
}

monitor_remote_storage() {
    local storage_type="$1"
    
    log_info "Remote Storage Status ($storage_type):"
    echo "=================================="
    
    case "$storage_type" in
        "s3")
            monitor_s3_storage
            ;;
        "rsync")
            monitor_rsync_storage
            ;;
        *)
            echo "Monitoring not implemented for: $storage_type"
            ;;
    esac
    
    echo
}

monitor_s3_storage() {
    local s3_destination="${BACKUP_REMOTE_DESTINATION}"
    
    if [[ -z "$s3_destination" ]]; then
        echo "S3 destination not configured"
        return
    fi
    
    local bucket
    bucket=$(echo "$s3_destination" | sed 's|s3://||' | cut -d'/' -f1)
    local prefix
    prefix=$(echo "$s3_destination" | sed 's|s3://[^/]*/||')
    
    echo "S3 Bucket: $bucket"
    echo "Prefix: $prefix"
    
    # Object count
    local object_count
    object_count=$(aws s3api list-objects-v2 --bucket "$bucket" --prefix "$prefix" --query 'KeyCount' --output text 2>/dev/null || echo "0")
    echo "Objects: $object_count"
    
    # Total size
    local total_size
    total_size=$(aws s3api list-objects-v2 --bucket "$bucket" --prefix "$prefix" --query 'sum(Contents[].Size)' --output text 2>/dev/null || echo "0")
    if [[ "$total_size" != "null" && "$total_size" -gt 0 ]]; then
        local size_mb=$((total_size / 1024 / 1024))
        echo "Total Size: ${size_mb}MB"
    fi
}

monitor_rsync_storage() {
    local rsync_destination="${BACKUP_REMOTE_DESTINATION}"
    
    if [[ -z "$rsync_destination" ]]; then
        echo "Rsync destination not configured"
        return
    fi
    
    echo "Destination: $rsync_destination"
    
    if [[ "$rsync_destination" =~ : ]]; then
        local host
        host=$(echo "$rsync_destination" | cut -d':' -f1)
        local path
        path=$(echo "$rsync_destination" | cut -d':' -f2)
        
        echo "Remote Host: $host"
        echo "Remote Path: $path"
        
        # Remote directory status
        if ssh "$host" "test -d $path" 2>/dev/null; then
            echo "✓ Remote directory exists"
            
            local file_count
            file_count=$(ssh "$host" "find $path -name '*.tar.gz' | wc -l" 2>/dev/null || echo "0")
            echo "Remote Files: $file_count"
            
            local total_size
            total_size=$(ssh "$host" "du -sh $path 2>/dev/null | cut -f1" || echo "unknown")
            echo "Remote Size: $total_size"
        else
            echo "✗ Remote directory not accessible"
        fi
    else
        echo "Local Path: $rsync_destination"
        
        if [[ -d "$rsync_destination" ]]; then
            echo "✓ Directory exists"
            
            local file_count
            file_count=$(find "$rsync_destination" -name "*.tar.gz" 2>/dev/null | wc -l)
            echo "Files: $file_count"
            
            local total_size
            total_size=$(du -sh "$rsync_destination" 2>/dev/null | cut -f1)
            echo "Size: $total_size"
        else
            echo "✗ Directory not found"
        fi
    fi
}

create_s3_sync_script() {
    local bucket="$1"
    local prefix="$2"
    
    local sync_script="$BACKUP_ROOT/storage/s3-sync.sh"
    
    cat > "$sync_script" << EOF
#!/bin/bash
# Auto-generated S3 sync script

set -euo pipefail

S3_BUCKET="$bucket"
S3_PREFIX="$prefix"
LOCAL_DIR="\${BACKUP_DESTINATION:-/var/backups/github-runner}"

sync_to_s3() {
    aws s3 sync "\$LOCAL_DIR" "s3://\$S3_BUCKET/\$S3_PREFIX" \\
        --storage-class "${BACKUP_S3_STORAGE_CLASS:-STANDARD_IA}" \\
        --sse "${BACKUP_S3_ENCRYPTION:-AES256}" \\
        --delete
}

sync_from_s3() {
    aws s3 sync "s3://\$S3_BUCKET/\$S3_PREFIX" "\$LOCAL_DIR" \\
        --delete
}

case "\${1:-sync}" in
    sync|to-s3)
        sync_to_s3
        ;;
    from-s3)
        sync_from_s3
        ;;
    *)
        echo "Usage: \$0 {sync|to-s3|from-s3}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$sync_script"
    log_info "Created S3 sync script: $sync_script"
}

create_rsync_sync_script() {
    local destination="$1"
    
    local sync_script="$BACKUP_ROOT/storage/rsync-sync.sh"
    
    cat > "$sync_script" << EOF
#!/bin/bash
# Auto-generated rsync sync script

set -euo pipefail

RSYNC_DEST="$destination"
LOCAL_DIR="\${BACKUP_DESTINATION:-/var/backups/github-runner}"
RSYNC_OPTIONS="${BACKUP_REMOTE_SYNC_OPTIONS:---archive --compress --delete}"

sync_to_remote() {
    rsync \$RSYNC_OPTIONS "\$LOCAL_DIR/" "\$RSYNC_DEST/"
}

sync_from_remote() {
    rsync \$RSYNC_OPTIONS "\$RSYNC_DEST/" "\$LOCAL_DIR/"
}

case "\${1:-sync}" in
    sync|to-remote)
        sync_to_remote
        ;;
    from-remote)
        sync_from_remote
        ;;
    *)
        echo "Usage: \$0 {sync|to-remote|from-remote}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$sync_script"
    log_info "Created rsync sync script: $sync_script"
}

create_scp_sync_script() {
    local host="$1"
    local path="$2"
    
    local sync_script="$BACKUP_ROOT/storage/scp-sync.sh"
    
    cat > "$sync_script" << EOF
#!/bin/bash
# Auto-generated SCP sync script

set -euo pipefail

SCP_HOST="$host"
SCP_PATH="$path"
LOCAL_DIR="\${BACKUP_DESTINATION:-/var/backups/github-runner}"

sync_to_remote() {
    # Use rsync over SSH for efficient transfer
    rsync -avz -e ssh "\$LOCAL_DIR/" "\$SCP_HOST:\$SCP_PATH/"
}

sync_from_remote() {
    rsync -avz -e ssh "\$SCP_HOST:\$SCP_PATH/" "\$LOCAL_DIR/"
}

case "\${1:-sync}" in
    sync|to-remote)
        sync_to_remote
        ;;
    from-remote)
        sync_from_remote
        ;;
    *)
        echo "Usage: \$0 {sync|to-remote|from-remote}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$sync_script"
    log_info "Created SCP sync script: $sync_script"
}

update_storage_config() {
    local storage_type="$1"
    local destination="$2"
    
    local config_file="$CONFIG_FILE"
    local temp_config="/tmp/backup-config-update-$$"
    
    # Update configuration
    sed -E "s|^BACKUP_REMOTE_TYPE=.*|BACKUP_REMOTE_TYPE=\"$storage_type\"|" "$config_file" > "$temp_config"
    sed -i -E "s|^BACKUP_REMOTE_DESTINATION=.*|BACKUP_REMOTE_DESTINATION=\"$destination\"|" "$temp_config"
    sed -i -E "s|^BACKUP_REMOTE_ENABLED=.*|BACKUP_REMOTE_ENABLED=true|" "$temp_config"
    
    if [[ "$DRY_RUN" == false ]]; then
        mv "$temp_config" "$config_file"
        log_info "Updated backup configuration: $config_file"
    else
        rm -f "$temp_config"
        log_info "DRY RUN - Configuration would be updated"
    fi
}

# Additional commands implementation
list_storage() {
    log_section "Backup Storage Listing"
    
    # List local backups
    list_local_backups
    
    # List remote backups if configured
    local storage_type="${BACKUP_REMOTE_TYPE:-}"
    if [[ -n "$storage_type" && "$storage_type" != "local" ]]; then
        list_remote_backups "$storage_type"
    fi
}

list_local_backups() {
    log_info "Local Backups:"
    echo "=============="
    
    local storage_dir="${BACKUP_DESTINATION}"
    
    if [[ ! -d "$storage_dir" ]]; then
        echo "No local storage directory found"
        return
    fi
    
    local backup_count=0
    
    while IFS= read -r -d '' manifest_file; do
        if [[ -f "$manifest_file" ]]; then
            local backup_id
            backup_id=$(jq -r '.backup_id // "unknown"' "$manifest_file" 2>/dev/null)
            
            local backup_type
            backup_type=$(jq -r '.backup_type // "unknown"' "$manifest_file" 2>/dev/null)
            
            local timestamp
            timestamp=$(jq -r '.iso_timestamp // "unknown"' "$manifest_file" 2>/dev/null)
            
            local size
            size=$(jq -r '.statistics.archive_size // 0' "$manifest_file" 2>/dev/null)
            local size_mb=$((size / 1024 / 1024))
            
            printf "%-30s %-12s %-20s %6dMB\n" "$backup_id" "$backup_type" "$timestamp" "$size_mb"
            ((backup_count++))
        fi
    done < <(find "$storage_dir" -name "*.manifest.json" -print0 2>/dev/null | sort -z)
    
    echo "Total: $backup_count backups"
    echo
}

list_remote_backups() {
    local storage_type="$1"
    
    log_info "Remote Backups ($storage_type):"
    echo "=========================="
    
    case "$storage_type" in
        "s3")
            list_s3_backups
            ;;
        "rsync")
            list_rsync_backups
            ;;
        *)
            echo "Remote listing not implemented for: $storage_type"
            ;;
    esac
    
    echo
}

list_s3_backups() {
    local s3_destination="${BACKUP_REMOTE_DESTINATION}"
    
    if [[ -z "$s3_destination" ]]; then
        echo "S3 destination not configured"
        return
    fi
    
    local bucket
    bucket=$(echo "$s3_destination" | sed 's|s3://||' | cut -d'/' -f1)
    local prefix
    prefix=$(echo "$s3_destination" | sed 's|s3://[^/]*/||')
    
    aws s3api list-objects-v2 --bucket "$bucket" --prefix "$prefix" \
        --query 'Contents[?ends_with(Key, `.tar.gz`)].{Key:Key,Size:Size,LastModified:LastModified}' \
        --output table 2>/dev/null || echo "Failed to list S3 objects"
}

list_rsync_backups() {
    local rsync_destination="${BACKUP_REMOTE_DESTINATION}"
    
    if [[ -z "$rsync_destination" ]]; then
        echo "Rsync destination not configured"
        return
    fi
    
    if [[ "$rsync_destination" =~ : ]]; then
        local host
        host=$(echo "$rsync_destination" | cut -d':' -f1)
        local path
        path=$(echo "$rsync_destination" | cut -d':' -f2)
        
        ssh "$host" "find $path -name '*.tar.gz' -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' | sort" 2>/dev/null || echo "Failed to list remote files"
    else
        find "$rsync_destination" -name "*.tar.gz" -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' | sort 2>/dev/null || echo "No files found"
    fi
}

verify_storage() {
    log_info "Verifying backup storage integrity..."
    
    # Verify local storage
    verify_local_storage
    
    # Verify remote storage if configured
    local storage_type="${BACKUP_REMOTE_TYPE:-}"
    if [[ -n "$storage_type" && "$storage_type" != "local" ]]; then
        verify_remote_storage "$storage_type"
    fi
}

verify_local_storage() {
    log_info "Verifying local storage..."
    
    local storage_dir="${BACKUP_DESTINATION}"
    local verification_errors=0
    
    # Check each backup
    while IFS= read -r -d '' manifest_file; do
        if [[ -f "$manifest_file" ]]; then
            local backup_id
            backup_id=$(jq -r '.backup_id // "unknown"' "$manifest_file" 2>/dev/null)
            
            # Check if archive exists
            local archive_found=false
            for ext in ".tar.gz" ".tar" ".zip" ".gpg"; do
                if [[ -f "$storage_dir/$backup_id$ext" ]]; then
                    archive_found=true
                    
                    # Verify checksum if available
                    if [[ -f "$storage_dir/$backup_id$ext.sha256" ]]; then
                        local stored_checksum
                        stored_checksum=$(cat "$storage_dir/$backup_id$ext.sha256")
                        local actual_checksum
                        actual_checksum=$(sha256sum "$storage_dir/$backup_id$ext" | cut -d' ' -f1)
                        
                        if [[ "$stored_checksum" == "$actual_checksum" ]]; then
                            log_debug "Checksum verified: $backup_id"
                        else
                            log_error "Checksum mismatch: $backup_id"
                            ((verification_errors++))
                        fi
                    else
                        log_warn "No checksum file for: $backup_id"
                    fi
                    
                    break
                fi
            done
            
            if [[ "$archive_found" != true ]]; then
                log_error "Archive missing for backup: $backup_id"
                ((verification_errors++))
            fi
        fi
    done < <(find "$storage_dir" -name "*.manifest.json" -print0 2>/dev/null)
    
    if [[ "$verification_errors" -eq 0 ]]; then
        log_success "Local storage verification passed"
    else
        log_error "Local storage verification found $verification_errors error(s)"
    fi
}

verify_remote_storage() {
    local storage_type="$1"
    
    log_info "Verifying remote storage: $storage_type"
    
    # Remote verification is complex and storage-specific
    # For now, just test connectivity
    test_remote_storage "$storage_type" "${BACKUP_REMOTE_DESTINATION}"
}

# Stubs for additional commands (to be implemented)
migrate_storage() {
    log_error "Storage migration not yet implemented"
    exit 1
}

encrypt_storage() {
    log_error "Storage encryption not yet implemented"
    exit 1
}

decrypt_storage() {
    log_error "Storage decryption not yet implemented"
    exit 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi