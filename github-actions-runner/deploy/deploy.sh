#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/scripts/common.sh"

ENVIRONMENT="${1:-dev}"
OPERATION="${2:-deploy}"
VERSION="${3:-latest}"

log_info "Starting deployment automation for GitHub Actions Runner"
log_info "Environment: $ENVIRONMENT"
log_info "Operation: $OPERATION"
log_info "Version: $VERSION"

validate_environment() {
    local env="$1"
    if [[ ! -f "$SCRIPT_DIR/environments/$env.env" ]]; then
        log_error "Environment configuration not found: $env"
        exit 1
    fi
}

load_environment() {
    local env="$1"
    log_info "Loading environment configuration: $env"
    source "$SCRIPT_DIR/environments/$env.env"
    
    export DEPLOY_ENV="$env"
    export DEPLOY_VERSION="$VERSION"
    export DEPLOY_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    export DEPLOY_TAG="${DEPLOY_ENV}_${DEPLOY_VERSION}_${DEPLOY_TIMESTAMP}"
}

pre_deployment_checks() {
    log_info "Running pre-deployment checks"
    
    if ! "$SCRIPT_DIR/scripts/pre-deploy.sh" "$ENVIRONMENT"; then
        log_error "Pre-deployment checks failed"
        exit 1
    fi
}

execute_deployment() {
    log_info "Executing deployment"
    
    case "$OPERATION" in
        deploy)
            deploy_application
            ;;
        rollback)
            rollback_application
            ;;
        status)
            show_deployment_status
            ;;
        *)
            log_error "Unknown operation: $OPERATION"
            exit 1
            ;;
    esac
}

deploy_application() {
    log_info "Starting application deployment"
    
    # Infrastructure deployment
    if [[ "$DEPLOY_INFRASTRUCTURE" == "true" ]]; then
        log_info "Deploying infrastructure"
        cd "$SCRIPT_DIR/infrastructure"
        ./deploy-infrastructure.sh "$ENVIRONMENT"
        cd "$SCRIPT_DIR"
    fi
    
    # Configuration deployment
    log_info "Deploying configuration"
    ./scripts/deploy-config.sh "$ENVIRONMENT"
    
    # Application deployment
    log_info "Deploying application"
    ./scripts/deploy-app.sh "$ENVIRONMENT" "$VERSION"
    
    # Post-deployment verification
    log_info "Running post-deployment verification"
    ./scripts/post-deploy.sh "$ENVIRONMENT"
    
    # Record deployment
    record_deployment
    
    log_info "Deployment completed successfully"
}

rollback_application() {
    log_info "Starting application rollback"
    
    local rollback_version="${VERSION:-}"
    if [[ -z "$rollback_version" ]]; then
        rollback_version=$(get_previous_version)
    fi
    
    if [[ -z "$rollback_version" ]]; then
        log_error "No previous version found for rollback"
        exit 1
    fi
    
    log_info "Rolling back to version: $rollback_version"
    ./scripts/rollback.sh "$ENVIRONMENT" "$rollback_version"
    
    log_info "Rollback completed successfully"
}

show_deployment_status() {
    log_info "Deployment Status"
    echo "================================"
    echo "Environment: $ENVIRONMENT"
    echo "Current Version: $(get_current_version)"
    echo "Last Deployment: $(get_last_deployment_time)"
    echo "Health Status: $(check_health_status)"
    echo "================================"
}

record_deployment() {
    local deployment_log="$SCRIPT_DIR/logs/deployments.log"
    mkdir -p "$(dirname "$deployment_log")"
    
    cat >> "$deployment_log" << EOF
{
    "timestamp": "$DEPLOY_TIMESTAMP",
    "environment": "$DEPLOY_ENV",
    "version": "$DEPLOY_VERSION",
    "tag": "$DEPLOY_TAG",
    "operation": "$OPERATION",
    "status": "success",
    "user": "$(whoami)",
    "commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
}
EOF
}

get_current_version() {
    local version_file="$SCRIPT_DIR/environments/$ENVIRONMENT.current"
    if [[ -f "$version_file" ]]; then
        cat "$version_file"
    else
        echo "unknown"
    fi
}

get_previous_version() {
    local deployments_log="$SCRIPT_DIR/logs/deployments.log"
    if [[ -f "$deployments_log" ]]; then
        grep -B1 "\"environment\": \"$ENVIRONMENT\"" "$deployments_log" | \
        grep "\"version\":" | tail -2 | head -1 | \
        sed 's/.*"version": "\([^"]*\)".*/\1/'
    fi
}

get_last_deployment_time() {
    local deployments_log="$SCRIPT_DIR/logs/deployments.log"
    if [[ -f "$deployments_log" ]]; then
        grep -A1 "\"environment\": \"$ENVIRONMENT\"" "$deployments_log" | \
        grep "\"timestamp\":" | tail -1 | \
        sed 's/.*"timestamp": "\([^"]*\)".*/\1/'
    else
        echo "never"
    fi
}

check_health_status() {
    if ./validation/health-check.sh "$ENVIRONMENT" >/dev/null 2>&1; then
        echo "healthy"
    else
        echo "unhealthy"
    fi
}

cleanup() {
    log_info "Cleaning up deployment resources"
}

main() {
    validate_environment "$ENVIRONMENT"
    load_environment "$ENVIRONMENT"
    pre_deployment_checks
    execute_deployment
    cleanup
}

trap cleanup EXIT

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi