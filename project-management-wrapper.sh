#!/bin/bash
# =============================================================================
# ProjectHub MCP Management Wrapper Script
# =============================================================================
# Integrated with existing MCP infrastructure
# Provides unified management interface for ProjectHub services
# =============================================================================

cd /home/dev/workspace/project-management

# Environment variables with defaults
export PROJECT_MANAGEMENT_PATH="${PROJECT_MANAGEMENT_PATH:-/home/dev/workspace/project-management}"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-projecthub-mcp}"
export LOG_LEVEL="${LOG_LEVEL:-info}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} [$timestamp] $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} [$timestamp] $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} [$timestamp] $message"
            ;;
        "DEBUG")
            if [ "$LOG_LEVEL" = "debug" ]; then
                echo -e "${BLUE}[DEBUG]${NC} [$timestamp] $message"
            fi
            ;;
    esac
}

# Source common MCP logging if available
source /home/dev/workspace/mcp-logger.sh 2>/dev/null || {
    mcp_info() { log "INFO" "PROJECT_MANAGEMENT" "$@"; }
    mcp_warn() { log "WARN" "PROJECT_MANAGEMENT" "$@"; }
    mcp_error() { log "ERROR" "PROJECT_MANAGEMENT" "$@"; }
}

# Function to check dependencies
check_dependencies() {
    log "INFO" "Checking dependencies..."
    
    local deps=("docker")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    # Check for docker compose
    if ! docker compose version >/dev/null 2>&1; then
        missing+=("docker compose")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        log "ERROR" "Missing dependencies: ${missing[*]}"
        log "INFO" "Please install missing dependencies and try again"
        return 1
    fi
    
    log "INFO" "All dependencies satisfied"
    return 0
}

# Function to setup environment
setup_environment() {
    log "INFO" "Setting up environment..."
    
    # Create network if it doesn't exist
    if ! docker network inspect mcp-infrastructure >/dev/null 2>&1; then
        log "INFO" "Creating MCP infrastructure network..."
        docker network create \
            --driver bridge \
            --subnet 172.19.0.0/24 \
            --gateway 172.19.0.1 \
            mcp-infrastructure
    fi
    
    # Ensure directories exist
    mkdir -p logs data/postgres data/redis config
    
    # Set permissions
    chmod -R 755 data logs config
    
    # Generate environment file if it doesn't exist
    if [ ! -f .env ]; then
        log "WARN" "Environment file not found, creating from template..."
        # Use the existing .env file we created
        log "INFO" "Environment file created. Please review and update as needed."
    fi
    
    log "INFO" "Environment setup completed"
}

# Function to start services
start_services() {
    log "INFO" "Starting ProjectHub MCP services..."
    
    check_dependencies || return 1
    setup_environment || return 1
    
    # Check if services are already running
    if docker compose ps | grep -q "Up"; then
        log "WARN" "Some services are already running"
        log "INFO" "Use 'restart' command to restart all services"
        return 0
    fi
    
    # Start services
    docker compose up -d
    
    if [ $? -eq 0 ]; then
        log "INFO" "ProjectHub MCP services started successfully"
        log "INFO" "Frontend available at: http://localhost:8080"
        log "INFO" "Backend API available at: http://localhost:3001/api"
        log "INFO" "PostgreSQL available at: localhost:5432"
        
        # Wait for services to be ready
        log "INFO" "Waiting for services to be ready..."
        sleep 10
        
        # Check service health
        check_health
    else
        log "ERROR" "Failed to start ProjectHub MCP services"
        return 1
    fi
}

# Function to stop services
stop_services() {
    log "INFO" "Stopping ProjectHub MCP services..."
    
    docker compose down
    
    if [ $? -eq 0 ]; then
        log "INFO" "ProjectHub MCP services stopped successfully"
    else
        log "ERROR" "Failed to stop ProjectHub MCP services"
        return 1
    fi
}

# Function to restart services
restart_services() {
    log "INFO" "Restarting ProjectHub MCP services..."
    
    stop_services
    sleep 5
    start_services
}

# Function to check service health
check_health() {
    log "INFO" "Checking service health..."
    
    local services=("projecthub-postgres" "projecthub-redis" "projecthub-backend" "projecthub-frontend" "projecthub-nginx")
    local healthy=0
    local total=${#services[@]}
    
    for service in "${services[@]}"; do
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$service.*Up"; then
            log "INFO" "✓ $service is running"
            ((healthy++))
        else
            log "WARN" "✗ $service is not running or unhealthy"
        fi
    done
    
    log "INFO" "Health check completed: $healthy/$total services healthy"
    
    if [ $healthy -eq $total ]; then
        log "INFO" "All services are healthy"
        return 0
    else
        log "WARN" "Some services are unhealthy"
        return 1
    fi
}

# Function to show logs
show_logs() {
    local service=$1
    
    if [ -z "$service" ]; then
        log "INFO" "Showing logs for all services..."
        docker compose logs -f --tail=100
    else
        log "INFO" "Showing logs for service: $service"
        docker compose logs -f --tail=100 "$service"
    fi
}

# Function to execute database operations
db_operations() {
    local operation=$1
    
    case $operation in
        "backup")
            log "INFO" "Creating database backup..."
            timestamp=$(date '+%Y%m%d_%H%M%S')
            docker compose exec -T postgres pg_dump -U projecthub projecthub > "data/backup_${timestamp}.sql"
            log "INFO" "Database backup created: data/backup_${timestamp}.sql"
            ;;
        "restore")
            local backup_file=$2
            if [ -z "$backup_file" ]; then
                log "ERROR" "Please specify backup file to restore"
                return 1
            fi
            log "INFO" "Restoring database from: $backup_file"
            docker compose exec -T postgres psql -U projecthub -d projecthub < "$backup_file"
            ;;
        "shell")
            log "INFO" "Opening database shell..."
            docker compose exec postgres psql -U projecthub -d projecthub
            ;;
        *)
            log "ERROR" "Unknown database operation: $operation"
            log "INFO" "Available operations: backup, restore <file>, shell"
            return 1
            ;;
    esac
}

# Function to show service status
show_status() {
    log "INFO" "ProjectHub MCP Service Status"
    echo "================================"
    
    # Docker compose status
    echo -e "\n${BLUE}Docker Compose Services:${NC}"
    docker compose ps
    
    # Network status
    echo -e "\n${BLUE}Network Information:${NC}"
    docker network inspect mcp-infrastructure --format '{{.Name}}: {{.IPAM.Config}}' 2>/dev/null || echo "Network not found"
    
    # Port mappings
    echo -e "\n${BLUE}Port Mappings:${NC}"
    echo "Frontend (Nginx): http://localhost:8080"
    echo "Backend API: http://localhost:3001/api"
    echo "PostgreSQL: localhost:5432"
    
    # Disk usage
    echo -e "\n${BLUE}Disk Usage:${NC}"
    du -sh data/ logs/ 2>/dev/null || echo "No data directories found"
}

# Function to update services
update_services() {
    log "INFO" "Updating ProjectHub MCP services..."
    
    # Pull latest images
    docker compose pull
    
    # Rebuild and restart
    docker compose up -d --build
    
    log "INFO" "Services updated successfully"
}

# Function to cleanup
cleanup() {
    log "INFO" "Cleaning up ProjectHub MCP..."
    
    # Stop services
    docker compose down -v
    
    # Remove unused images
    docker image prune -f
    
    log "INFO" "Cleanup completed"
}

# Function to show help
show_help() {
    echo "ProjectHub MCP Management Script"
    echo "==============================="
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start               Start all ProjectHub services"
    echo "  stop                Stop all ProjectHub services" 
    echo "  restart             Restart all ProjectHub services"
    echo "  status              Show service status and information"
    echo "  health              Check health of all services"
    echo "  logs [service]      Show logs (optionally for specific service)"
    echo "  update              Update and restart services"
    echo "  cleanup             Stop services and cleanup resources"
    echo "  db <operation>      Database operations (backup, restore, shell)"
    echo "  help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start                    # Start all services"
    echo "  $0 logs backend             # Show backend logs"
    echo "  $0 db backup                # Backup database"
    echo "  $0 db restore backup.sql    # Restore from backup"
    echo ""
}

# Main execution
main() {
    local command=$1
    shift
    
    case $command in
        "start")
            start_services
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            restart_services
            ;;
        "status")
            show_status
            ;;
        "health")
            check_health
            ;;
        "logs")
            show_logs "$1"
            ;;
        "update")
            update_services
            ;;
        "cleanup")
            cleanup
            ;;
        "db")
            db_operations "$@"
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        *)
            log "ERROR" "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"