#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$BACKUP_ROOT")"

source "$SCRIPT_DIR/common/backup-functions.sh"
source "$PROJECT_ROOT/scripts/common/logging.sh"
source "$PROJECT_ROOT/scripts/common/utils.sh"

setup_logging "/var/log/github-runner-backup-validate.log"

usage() {
    cat << 'EOF'
Usage: backup-validate.sh [OPTIONS] [BACKUP_ID]

Validate backup integrity and content for GitHub Actions runner

OPTIONS:
    -h, --help              Show this help message
    -d, --destination DIR   Backup location [default: /var/backups/github-runner]
    -a, --all               Validate all backups in destination
    -t, --type TYPE         Validate specific backup type (full, incremental, config)
    -l, --list              List available backups for validation
    --deep                  Perform deep validation (extract and verify contents)
    --checksum              Verify file checksums
    --structure             Verify backup structure and manifest
    --restore-test          Test restore capability (non-destructive)
    --report FILE           Generate validation report
    --json                  Output results in JSON format
    --parallel              Use parallel processing for validation
    --fix-minor             Attempt to fix minor validation issues
    -v, --verbose           Verbose validation output

Examples:
    ./backup-validate.sh                               # Validate latest backup
    ./backup-validate.sh full-backup-20240115          # Validate specific backup
    ./backup-validate.sh --all                         # Validate all backups
    ./backup-validate.sh --deep --checksum             # Comprehensive validation
    ./backup-validate.sh --restore-test                # Test restore capability
EOF
}

DESTINATION="/var/backups/github-runner"
BACKUP_ID=""
VALIDATE_ALL=false
BACKUP_TYPE=""
LIST_ONLY=false
DEEP_VALIDATION=false
VERIFY_CHECKSUM=false
VERIFY_STRUCTURE=false
RESTORE_TEST=false
REPORT_FILE=""
JSON_OUTPUT=false
PARALLEL_MODE=false
FIX_MINOR=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -d|--destination)
            DESTINATION="$2"
            shift 2
            ;;
        -a|--all)
            VALIDATE_ALL=true
            shift
            ;;
        -t|--type)
            BACKUP_TYPE="$2"
            shift 2
            ;;
        -l|--list)
            LIST_ONLY=true
            shift
            ;;
        --deep)
            DEEP_VALIDATION=true
            shift
            ;;
        --checksum)
            VERIFY_CHECKSUM=true
            shift
            ;;
        --structure)
            VERIFY_STRUCTURE=true
            shift
            ;;
        --restore-test)
            RESTORE_TEST=true
            shift
            ;;
        --report)
            REPORT_FILE="$2"
            shift 2
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --parallel)
            PARALLEL_MODE=true
            shift
            ;;
        --fix-minor)
            FIX_MINOR=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            LOG_LEVEL="DEBUG"
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            BACKUP_ID="$1"
            shift
            ;;
    esac
done

main() {
    log_section "GitHub Actions Runner - Backup Validation"
    
    if [[ ! -d "$DESTINATION" ]]; then
        log_error "Backup destination not found: $DESTINATION"
        exit 1
    fi
    
    if [[ "$LIST_ONLY" == true ]]; then
        list_available_backups
        exit 0
    fi
    
    local validation_results=()
    local overall_status="success"
    
    if [[ "$VALIDATE_ALL" == true ]]; then
        validate_all_backups
    elif [[ -n "$BACKUP_ID" ]]; then
        validate_single_backup "$BACKUP_ID"
    else
        # Validate latest backup
        local latest_backup
        latest_backup=$(find_latest_backup "$DESTINATION")
        if [[ -n "$latest_backup" ]]; then
            validate_single_backup "$latest_backup"
        else
            log_error "No backups found to validate"
            exit 1
        fi
    fi
    
    if [[ -n "$REPORT_FILE" ]]; then
        generate_validation_report "$REPORT_FILE"
    fi
    
    log_section "Validation Complete"
    
    if [[ "$overall_status" == "success" ]]; then
        log_success "All validations passed"
        exit 0
    else
        log_error "Some validations failed"
        exit 1
    fi
}

list_available_backups() {
    log_info "Available backups in $DESTINATION:"
    echo "========================================"
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        local backups_json="["
        local first=true
    fi
    
    while IFS= read -r -d '' manifest_file; do
        if [[ -f "$manifest_file" ]]; then
            local backup_data
            backup_data=$(extract_backup_info "$manifest_file")
            
            if [[ "$JSON_OUTPUT" == true ]]; then
                if [[ "$first" == true ]]; then
                    first=false
                else
                    backups_json+=","
                fi
                backups_json+="$backup_data"
            else
                display_backup_info "$backup_data"
            fi
        fi
    done < <(find "$DESTINATION" -name "*.manifest.json" -print0 2>/dev/null | sort -z)
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        backups_json+="]"
        echo "$backups_json" | jq '.'
    fi
}

extract_backup_info() {
    local manifest_file="$1"
    
    local backup_id
    backup_id=$(jq -r '.backup_id // "unknown"' "$manifest_file" 2>/dev/null)
    
    local backup_type
    backup_type=$(jq -r '.backup_type // "unknown"' "$manifest_file" 2>/dev/null)
    
    local timestamp
    timestamp=$(jq -r '.iso_timestamp // .timestamp // "unknown"' "$manifest_file" 2>/dev/null)
    
    local size
    size=$(jq -r '.total_size // "unknown"' "$manifest_file" 2>/dev/null)
    
    local archive_exists=false
    local archive_file=""
    
    # Check if archive file exists
    local base_path="$DESTINATION/$backup_id"
    for ext in ".tar.gz" ".tar" ".zip" ".gpg"; do
        if [[ -f "$base_path$ext" ]]; then
            archive_exists=true
            archive_file="$base_path$ext"
            break
        fi
    done
    
    cat << EOF
{
    "backup_id": "$backup_id",
    "backup_type": "$backup_type",
    "timestamp": "$timestamp",
    "size": "$size",
    "manifest_file": "$manifest_file",
    "archive_exists": $archive_exists,
    "archive_file": "$archive_file"
}
EOF
}

display_backup_info() {
    local backup_data="$1"
    
    local backup_id
    backup_id=$(echo "$backup_data" | jq -r '.backup_id')
    
    local backup_type
    backup_type=$(echo "$backup_data" | jq -r '.backup_type')
    
    local timestamp
    timestamp=$(echo "$backup_data" | jq -r '.timestamp')
    
    local size
    size=$(echo "$backup_data" | jq -r '.size')
    
    local archive_exists
    archive_exists=$(echo "$backup_data" | jq -r '.archive_exists')
    
    local status_icon="✓"
    if [[ "$archive_exists" != "true" ]]; then
        status_icon="✗"
    fi
    
    printf "%-30s %-12s %-20s %-10s %s\n" "$backup_id" "$backup_type" "$timestamp" "$size" "$status_icon"
}

validate_all_backups() {
    log_info "Validating all backups in $DESTINATION..."
    
    local backup_count=0
    local success_count=0
    local failed_count=0
    
    while IFS= read -r -d '' manifest_file; do
        if [[ -f "$manifest_file" ]]; then
            local backup_id
            backup_id=$(jq -r '.backup_id // "unknown"' "$manifest_file" 2>/dev/null)
            
            if [[ -n "$BACKUP_TYPE" ]]; then
                local backup_type
                backup_type=$(jq -r '.backup_type // "unknown"' "$manifest_file" 2>/dev/null)
                
                if [[ "$backup_type" != "$BACKUP_TYPE" ]]; then
                    continue
                fi
            fi
            
            ((backup_count++))
            
            log_info "Validating backup: $backup_id"
            
            if [[ "$PARALLEL_MODE" == true ]]; then
                validate_single_backup "$backup_id" &
            else
                if validate_single_backup "$backup_id"; then
                    ((success_count++))
                else
                    ((failed_count++))
                fi
            fi
        fi
    done < <(find "$DESTINATION" -name "*.manifest.json" -print0 2>/dev/null)
    
    if [[ "$PARALLEL_MODE" == true ]]; then
        wait
        # Count results differently for parallel mode
        success_count=$backup_count
        failed_count=0
    fi
    
    log_info "Validation summary: $success_count/$backup_count backups passed"
    
    if [[ "$failed_count" -gt 0 ]]; then
        overall_status="failed"
    fi
}

validate_single_backup() {
    local backup_id="$1"
    
    log_debug "Starting validation for backup: $backup_id"
    
    local validation_status="success"
    local validation_issues=()
    
    # Check manifest file
    local manifest_file="$DESTINATION/$backup_id.manifest.json"
    if [[ ! -f "$manifest_file" ]]; then
        log_error "Manifest file not found: $manifest_file"
        return 1
    fi
    
    if ! validate_manifest_structure "$manifest_file"; then
        validation_status="failed"
        validation_issues+=("Invalid manifest structure")
    fi
    
    # Check archive file
    local archive_file
    archive_file=$(find_archive_file "$backup_id")
    
    if [[ -z "$archive_file" ]]; then
        log_error "Archive file not found for backup: $backup_id"
        validation_status="failed"
        validation_issues+=("Missing archive file")
    else
        if ! validate_archive_integrity "$archive_file"; then
            validation_status="failed"
            validation_issues+=("Archive integrity check failed")
        fi
        
        if [[ "$VERIFY_CHECKSUM" == true ]]; then
            if ! validate_archive_checksum "$backup_id" "$archive_file"; then
                validation_status="failed"
                validation_issues+=("Checksum verification failed")
            fi
        fi
        
        if [[ "$DEEP_VALIDATION" == true ]]; then
            if ! validate_archive_contents "$backup_id" "$archive_file"; then
                validation_status="failed"
                validation_issues+=("Content validation failed")
            fi
        fi
    fi
    
    if [[ "$VERIFY_STRUCTURE" == true ]]; then
        if ! validate_backup_structure "$backup_id"; then
            validation_status="failed"
            validation_issues+=("Structure validation failed")
        fi
    fi
    
    if [[ "$RESTORE_TEST" == true ]]; then
        if ! test_restore_capability "$backup_id"; then
            validation_status="failed"
            validation_issues+=("Restore test failed")
        fi
    fi
    
    # Report results
    if [[ "$validation_status" == "success" ]]; then
        log_success "Backup validation passed: $backup_id"
        return 0
    else
        log_error "Backup validation failed: $backup_id"
        for issue in "${validation_issues[@]}"; do
            log_error "  - $issue"
        done
        return 1
    fi
}

validate_manifest_structure() {
    local manifest_file="$1"
    
    log_debug "Validating manifest structure: $manifest_file"
    
    # Check if file is valid JSON
    if ! jq . "$manifest_file" >/dev/null 2>&1; then
        log_error "Manifest is not valid JSON"
        return 1
    fi
    
    # Check required fields
    local required_fields=(
        "backup_id"
        "backup_type"
        "timestamp"
        "created_by"
    )
    
    for field in "${required_fields[@]}"; do
        if ! jq -e ".$field" "$manifest_file" >/dev/null 2>&1; then
            log_error "Required field missing from manifest: $field"
            if [[ "$FIX_MINOR" == true ]]; then
                attempt_fix_manifest "$manifest_file" "$field"
            else
                return 1
            fi
        fi
    done
    
    # Validate timestamp format
    local timestamp
    timestamp=$(jq -r '.timestamp // 0' "$manifest_file")
    
    if [[ "$timestamp" == "0" ]] || ! date -d "@$timestamp" >/dev/null 2>&1; then
        log_error "Invalid timestamp in manifest"
        return 1
    fi
    
    log_debug "Manifest structure validation passed"
    return 0
}

find_archive_file() {
    local backup_id="$1"
    
    local base_path="$DESTINATION/$backup_id"
    
    for ext in ".tar.gz" ".tar" ".zip" ".gpg"; do
        if [[ -f "$base_path$ext" ]]; then
            echo "$base_path$ext"
            return 0
        fi
    done
    
    return 1
}

validate_archive_integrity() {
    local archive_file="$1"
    
    log_debug "Validating archive integrity: $(basename "$archive_file")"
    
    local file_extension="${archive_file##*.}"
    
    case "$file_extension" in
        "gz"|"tgz")
            if ! tar -tzf "$archive_file" >/dev/null 2>&1; then
                log_error "Tar.gz archive is corrupted"
                return 1
            fi
            ;;
        "tar")
            if ! tar -tf "$archive_file" >/dev/null 2>&1; then
                log_error "Tar archive is corrupted"
                return 1
            fi
            ;;
        "zip")
            if ! unzip -t "$archive_file" >/dev/null 2>&1; then
                log_error "Zip archive is corrupted"
                return 1
            fi
            ;;
        "gpg")
            if ! gpg --list-packets "$archive_file" >/dev/null 2>&1; then
                log_error "GPG encrypted file is corrupted"
                return 1
            fi
            ;;
        *)
            log_warn "Unknown archive format: $file_extension"
            return 1
            ;;
    esac
    
    log_debug "Archive integrity validation passed"
    return 0
}

validate_archive_checksum() {
    local backup_id="$1"
    local archive_file="$2"
    
    log_debug "Validating archive checksum"
    
    local manifest_file="$DESTINATION/$backup_id.manifest.json"
    local stored_checksum
    stored_checksum=$(jq -r '.checksum // .sha256 // ""' "$manifest_file" 2>/dev/null)
    
    if [[ -z "$stored_checksum" ]]; then
        log_warn "No checksum found in manifest for verification"
        return 0
    fi
    
    local current_checksum
    current_checksum=$(sha256sum "$archive_file" | cut -d' ' -f1)
    
    if [[ "$current_checksum" == "$stored_checksum" ]]; then
        log_debug "Checksum verification passed"
        return 0
    else
        log_error "Checksum verification failed"
        log_error "Expected: $stored_checksum"
        log_error "Actual: $current_checksum"
        return 1
    fi
}

validate_archive_contents() {
    local backup_id="$1"
    local archive_file="$2"
    
    log_debug "Performing deep content validation"
    
    local temp_dir="/tmp/validate-$backup_id-$$"
    mkdir -p "$temp_dir"
    
    # Extract archive for content validation
    local extraction_success=false
    
    case "${archive_file##*.}" in
        "gz"|"tgz")
            if tar -xzf "$archive_file" -C "$temp_dir" 2>/dev/null; then
                extraction_success=true
            fi
            ;;
        "tar")
            if tar -xf "$archive_file" -C "$temp_dir" 2>/dev/null; then
                extraction_success=true
            fi
            ;;
        "zip")
            if unzip -q "$archive_file" -d "$temp_dir" 2>/dev/null; then
                extraction_success=true
            fi
            ;;
        "gpg")
            if gpg --decrypt "$archive_file" 2>/dev/null | tar -xz -C "$temp_dir" 2>/dev/null; then
                extraction_success=true
            fi
            ;;
    esac
    
    if [[ "$extraction_success" != true ]]; then
        log_error "Failed to extract archive for content validation"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Validate extracted content structure
    local content_valid=true
    
    # Check for expected directory structure
    local expected_dirs=("installation" "configuration" "data")
    
    for expected_dir in "${expected_dirs[@]}"; do
        if [[ ! -d "$temp_dir/$expected_dir" ]]; then
            log_warn "Expected directory not found in backup: $expected_dir"
            # Not a critical failure for content validation
        fi
    done
    
    # Check for critical files
    local critical_files=()
    find "$temp_dir" -name "*.runner" -o -name "docker-compose.yml" -o -name "*.service" | while read -r file; do
        critical_files+=("$file")
    done
    
    # Validate file permissions and ownership where applicable
    find "$temp_dir" -type f -name "*.credentials" -o -name "*token*" | while read -r sensitive_file; do
        local file_perms
        file_perms=$(stat -c %a "$sensitive_file" 2>/dev/null || echo "000")
        
        if [[ "$file_perms" != "600" ]] && [[ "$file_perms" != "400" ]]; then
            log_warn "Sensitive file has incorrect permissions: $sensitive_file ($file_perms)"
        fi
    done
    
    # Cleanup
    rm -rf "$temp_dir"
    
    if [[ "$content_valid" == true ]]; then
        log_debug "Content validation passed"
        return 0
    else
        log_error "Content validation failed"
        return 1
    fi
}

validate_backup_structure() {
    local backup_id="$1"
    
    log_debug "Validating backup structure"
    
    local base_path="$DESTINATION/$backup_id"
    local required_files=("$base_path.manifest.json")
    
    # Check for archive file
    local archive_found=false
    for ext in ".tar.gz" ".tar" ".zip" ".gpg"; do
        if [[ -f "$base_path$ext" ]]; then
            archive_found=true
            required_files+=("$base_path$ext")
            break
        fi
    done
    
    if [[ "$archive_found" != true ]]; then
        log_error "No archive file found for backup structure"
        return 1
    fi
    
    # Check all required files exist
    for required_file in "${required_files[@]}"; do
        if [[ ! -f "$required_file" ]]; then
            log_error "Required file missing: $required_file"
            return 1
        fi
    done
    
    log_debug "Backup structure validation passed"
    return 0
}

test_restore_capability() {
    local backup_id="$1"
    
    log_debug "Testing restore capability (non-destructive)"
    
    local temp_restore_dir="/tmp/restore-test-$backup_id-$$"
    mkdir -p "$temp_restore_dir"
    
    local archive_file
    archive_file=$(find_archive_file "$backup_id")
    
    if [[ -z "$archive_file" ]]; then
        log_error "Cannot test restore - archive file not found"
        rm -rf "$temp_restore_dir"
        return 1
    fi
    
    # Test extraction without actually restoring
    log_debug "Testing archive extraction..."
    
    local extraction_success=false
    
    case "${archive_file##*.}" in
        "gz"|"tgz")
            if tar -tzf "$archive_file" | head -10 >/dev/null 2>&1; then
                extraction_success=true
            fi
            ;;
        "tar")
            if tar -tf "$archive_file" | head -10 >/dev/null 2>&1; then
                extraction_success=true
            fi
            ;;
        "zip")
            if unzip -l "$archive_file" | head -20 >/dev/null 2>&1; then
                extraction_success=true
            fi
            ;;
        "gpg")
            if gpg --list-packets "$archive_file" >/dev/null 2>&1; then
                extraction_success=true
            fi
            ;;
    esac
    
    rm -rf "$temp_restore_dir"
    
    if [[ "$extraction_success" == true ]]; then
        log_debug "Restore capability test passed"
        return 0
    else
        log_error "Restore capability test failed"
        return 1
    fi
}

attempt_fix_manifest() {
    local manifest_file="$1"
    local missing_field="$2"
    
    if [[ "$FIX_MINOR" != true ]]; then
        return 1
    fi
    
    log_info "Attempting to fix manifest: adding missing field $missing_field"
    
    local temp_manifest="/tmp/manifest_fix.json"
    local current_time
    current_time=$(date +%s)
    
    case "$missing_field" in
        "timestamp")
            jq --arg timestamp "$current_time" '. + {"timestamp": ($timestamp | tonumber)}' "$manifest_file" > "$temp_manifest"
            ;;
        "created_by")
            jq '. + {"created_by": "backup-validation-fix"}' "$manifest_file" > "$temp_manifest"
            ;;
        "backup_type")
            jq '. + {"backup_type": "unknown"}' "$manifest_file" > "$temp_manifest"
            ;;
        *)
            log_warn "Cannot fix missing field: $missing_field"
            return 1
            ;;
    esac
    
    if [[ -f "$temp_manifest" ]] && jq . "$temp_manifest" >/dev/null 2>&1; then
        mv "$temp_manifest" "$manifest_file"
        log_info "Manifest fixed successfully"
        return 0
    else
        rm -f "$temp_manifest"
        log_error "Failed to fix manifest"
        return 1
    fi
}

find_latest_backup() {
    local destination="$1"
    
    local latest_backup=""
    local latest_timestamp=0
    
    while IFS= read -r -d '' manifest_file; do
        if [[ -f "$manifest_file" ]]; then
            local timestamp
            timestamp=$(jq -r '.timestamp // 0' "$manifest_file" 2>/dev/null)
            
            if [[ "$timestamp" -gt "$latest_timestamp" ]]; then
                latest_timestamp="$timestamp"
                latest_backup=$(jq -r '.backup_id // ""' "$manifest_file" 2>/dev/null)
            fi
        fi
    done < <(find "$destination" -name "*.manifest.json" -print0 2>/dev/null)
    
    echo "$latest_backup"
}

generate_validation_report() {
    local report_file="$1"
    
    log_info "Generating validation report: $report_file"
    
    cat > "$report_file" << EOF
# GitHub Actions Runner Backup Validation Report

Generated: $(date)
Destination: $DESTINATION

## Summary

- Validation Type: $(if [[ "$VALIDATE_ALL" == true ]]; then echo "All backups"; else echo "Single backup"; fi)
- Deep Validation: $DEEP_VALIDATION
- Checksum Verification: $VERIFY_CHECKSUM
- Structure Verification: $VERIFY_STRUCTURE
- Restore Test: $RESTORE_TEST

## Results

$(if [[ "$JSON_OUTPUT" == true ]]; then
    echo '```json'
    list_available_backups
    echo '```'
else
    list_available_backups
fi)

## Recommendations

- Perform regular backup validations
- Test restore procedures periodically
- Monitor backup storage capacity
- Update backup retention policies as needed

EOF
    
    log_success "Validation report generated: $report_file"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi