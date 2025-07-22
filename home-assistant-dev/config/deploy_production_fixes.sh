#!/bin/bash
# =============================================================================
# PRODUCTION ERROR FIXES DEPLOYMENT SCRIPT
# Deploys fixes for identified production issues
# =============================================================================

set -e  # Exit on any error

# Configuration
PRODUCTION_IP="192.168.1.155"
DEV_IP="192.168.1.239"
BACKUP_DIR="/home/dev/workspace/home-assistant-config/backup_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/home/dev/workspace/home-assistant-config/deployment.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "[INFO] $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "[SUCCESS] $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "[WARNING] $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "[ERROR] $1"
}

# =============================================================================
# DEPLOYMENT FUNCTIONS
# =============================================================================

create_backup() {
    print_status "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Backup current configuration files
    if [ -f "automations.yaml" ]; then
        cp "automations.yaml" "$BACKUP_DIR/automations.yaml.backup"
        print_success "Backed up automations.yaml"
    fi
    
    if [ -f "unified_appliances.yaml" ]; then
        cp "unified_appliances.yaml" "$BACKUP_DIR/unified_appliances.yaml.backup"
        print_success "Backed up unified_appliances.yaml"
    fi
    
    # Backup ESPHome configurations
    if [ -d "esphome" ]; then
        cp -r "esphome" "$BACKUP_DIR/esphome_backup"
        print_success "Backed up ESPHome configurations"
    fi
}

validate_fixes() {
    print_status "Validating fix files..."
    
    if [ ! -f "production_error_fixes.yaml" ]; then
        print_error "production_error_fixes.yaml not found!"
        return 1
    fi
    
    if [ ! -f "esphome_ble_proxy_fixes.yaml" ]; then
        print_error "esphome_ble_proxy_fixes.yaml not found!"
        return 1
    fi
    
    # Validate YAML syntax (requires yamllint)
    if command -v yamllint &> /dev/null; then
        yamllint production_error_fixes.yaml
        yamllint esphome_ble_proxy_fixes.yaml
        print_success "YAML syntax validation passed"
    else
        print_warning "yamllint not available, skipping syntax validation"
    fi
    
    return 0
}

deploy_automation_fixes() {
    print_status "Deploying automation fixes..."
    
    # Check if automations.yaml includes our fixes
    if ! grep -q "production_error_fixes.yaml" automations.yaml 2>/dev/null; then
        print_status "Adding fixes to automations.yaml"
        
        # Append fixes to automations.yaml
        echo "" >> automations.yaml
        echo "# Production Error Fixes - Added $(date)" >> automations.yaml
        cat production_error_fixes.yaml >> automations.yaml
        
        print_success "Automation fixes added to automations.yaml"
    else
        print_warning "Fixes already present in automations.yaml"
    fi
}

deploy_esphome_fixes() {
    print_status "Deploying ESPHome BLE proxy fixes..."
    
    # Update bleproxy-with-lux.yaml if it exists
    if [ -f "esphome/bleproxy-with-lux.yaml" ]; then
        print_status "Updating bleproxy-with-lux.yaml configuration"
        
        # Extract just the ESPHome config from our fixes file
        sed -n '/^esphome:/,/^# =============================================================================$/p' esphome_ble_proxy_fixes.yaml > "esphome/bleproxy-with-lux-updated.yaml"
        
        # Keep original as backup
        cp "esphome/bleproxy-with-lux.yaml" "esphome/bleproxy-with-lux.yaml.backup"
        
        print_success "ESPHome configuration updated (backup created)"
        print_warning "Manual compilation and upload required via ESPHome dashboard"
    else
        print_warning "bleproxy-with-lux.yaml not found in esphome directory"
    fi
}

test_configuration() {
    print_status "Testing Home Assistant configuration..."
    
    # Test configuration if Home Assistant core is available
    if command -v hass &> /dev/null; then
        print_status "Running configuration check..."
        if hass --script check_config; then
            print_success "Configuration check passed"
            return 0
        else
            print_error "Configuration check failed!"
            return 1
        fi
    else
        print_warning "Home Assistant core not available for local testing"
        print_warning "Manual configuration check required after deployment"
        return 0
    fi
}

deploy_to_production() {
    print_status "Deploying to production environment..."
    print_warning "This will deploy changes to $PRODUCTION_IP"
    
    # Confirm deployment
    read -p "Deploy to production? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled by user"
        return 1
    fi
    
    # Use network-mcp or SSH to deploy (implement based on your setup)
    print_status "Deployment method: Manual copy required"
    print_warning "Copy updated files to production system at $PRODUCTION_IP"
    print_warning "Restart Home Assistant or reload automations after deployment"
    
    return 0
}

# =============================================================================
# MAIN DEPLOYMENT PROCESS
# =============================================================================

main() {
    print_status "Starting production error fixes deployment"
    print_status "Target production system: $PRODUCTION_IP"
    
    # Step 1: Create backup
    create_backup
    
    # Step 2: Validate fix files
    if ! validate_fixes; then
        print_error "Validation failed, aborting deployment"
        exit 1
    fi
    
    # Step 3: Deploy automation fixes
    deploy_automation_fixes
    
    # Step 4: Deploy ESPHome fixes
    deploy_esphome_fixes
    
    # Step 5: Test configuration
    if ! test_configuration; then
        print_error "Configuration test failed"
        print_warning "Review errors before deploying to production"
        exit 1
    fi
    
    # Step 6: Deploy to production (manual step)
    deploy_to_production
    
    print_success "Deployment process completed!"
    print_status "Manual steps required:"
    echo "  1. Copy files to production system ($PRODUCTION_IP)"
    echo "  2. Restart Home Assistant or reload automations"
    echo "  3. Compile and upload ESPHome configurations"
    echo "  4. Monitor logs for 24-48 hours"
    echo "  5. Update MCP server tokens with real values"
    
    print_status "Backup location: $BACKUP_DIR"
    print_status "Deployment log: $LOG_FILE"
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Check if running from correct directory
if [ ! -f "configuration.yaml" ]; then
    print_error "Must run from Home Assistant configuration directory"
    print_error "Current directory: $(pwd)"
    exit 1
fi

# Run main deployment process
main "$@"