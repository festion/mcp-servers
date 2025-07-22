#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/common.sh"

ENVIRONMENT="${1:-dev}"

log_info "Deploying infrastructure for environment: $ENVIRONMENT"

deploy_terraform() {
    log_info "Deploying Terraform infrastructure"
    
    local terraform_dir="$SCRIPT_DIR/terraform"
    
    if [[ -d "$terraform_dir" ]]; then
        cd "$terraform_dir"
        
        # Initialize Terraform
        terraform init
        
        # Plan the deployment
        terraform plan -var-file="$ENVIRONMENT.tfvars" -out="$ENVIRONMENT.tfplan"
        
        # Apply the plan
        terraform apply "$ENVIRONMENT.tfplan"
        
        log_success "Terraform infrastructure deployed"
        cd "$SCRIPT_DIR"
    else
        log_warn "Terraform directory not found: $terraform_dir"
    fi
}

deploy_ansible() {
    log_info "Deploying Ansible configuration"
    
    local ansible_dir="$SCRIPT_DIR/ansible"
    
    if [[ -d "$ansible_dir" ]]; then
        cd "$ansible_dir"
        
        # Run Ansible playbook
        ansible-playbook -i "inventory/$ENVIRONMENT" site.yml
        
        log_success "Ansible configuration deployed"
        cd "$SCRIPT_DIR"
    else
        log_warn "Ansible directory not found: $ansible_dir"
    fi
}

deploy_kubernetes() {
    log_info "Deploying Kubernetes resources"
    
    local k8s_dir="$SCRIPT_DIR/kubernetes"
    
    if [[ -d "$k8s_dir" ]]; then
        cd "$k8s_dir"
        
        # Apply Kubernetes manifests
        kubectl apply -f namespace.yml
        kubectl apply -f configmap.yml
        kubectl apply -f secret.yml
        kubectl apply -f deployment.yml
        kubectl apply -f service.yml
        kubectl apply -f ingress.yml
        
        log_success "Kubernetes resources deployed"
        cd "$SCRIPT_DIR"
    else
        log_warn "Kubernetes directory not found: $k8s_dir"
    fi
}

create_network_infrastructure() {
    log_info "Creating network infrastructure"
    
    # Create Docker networks
    docker network create github-runner-network 2>/dev/null || true
    docker network create monitoring-network 2>/dev/null || true
    
    log_success "Network infrastructure created"
}

create_storage_infrastructure() {
    log_info "Creating storage infrastructure"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    # Create required volumes
    docker volume create runner1-data 2>/dev/null || true
    docker volume create runner2-data 2>/dev/null || true
    docker volume create runner3-data 2>/dev/null || true
    docker volume create prometheus-data 2>/dev/null || true
    docker volume create grafana-data 2>/dev/null || true
    docker volume create redis-data 2>/dev/null || true
    
    # Create host directories
    local directories=(
        "$DATA_DIR"
        "$LOG_DIR"
        "$BACKUP_DIR"
        "${DATA_DIR}/github-runner"
        "${DATA_DIR}/monitoring"
        "${LOG_DIR}/github-runner"
        "${LOG_DIR}/monitoring"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_success "Created directory: $dir"
        fi
    done
    
    log_success "Storage infrastructure created"
}

configure_ssl_certificates() {
    log_info "Configuring SSL certificates"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    if [[ "$ENABLE_SSL" == "true" ]]; then
        local ssl_dir="$SCRIPT_DIR/nginx/ssl"
        mkdir -p "$ssl_dir"
        
        if [[ -n "${SSL_CERT_PATH:-}" ]] && [[ -n "${SSL_KEY_PATH:-}" ]]; then
            cp "$SSL_CERT_PATH" "$ssl_dir/cert.pem"
            cp "$SSL_KEY_PATH" "$ssl_dir/key.pem"
            
            log_success "SSL certificates configured"
        else
            log_warn "SSL enabled but certificate paths not provided"
        fi
    else
        log_info "SSL disabled for environment: $ENVIRONMENT"
    fi
}

main() {
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    create_network_infrastructure
    create_storage_infrastructure
    configure_ssl_certificates
    deploy_terraform
    deploy_ansible
    deploy_kubernetes
    
    log_success "Infrastructure deployment completed successfully"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi