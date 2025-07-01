# ProjectHub MCP Integration

## Overview

ProjectHub is a comprehensive project management web application that has been successfully integrated with the existing MCP (Model Context Protocol) infrastructure. This integration provides enterprise-grade project management capabilities with seamless connectivity to Home Assistant, WikiJS, and Proxmox services.

## Architecture

### Core Components

1. **Frontend**: React/Alpine.js web interface (Port 8080)
2. **Backend**: Node.js API server (Port 3001)
3. **Database**: PostgreSQL 17 with audit logging
4. **Cache**: Redis with password authentication
5. **Reverse Proxy**: Nginx with rate limiting and security headers
6. **Log Collector**: Centralized logging integration

### Network Configuration

- **Internal Network**: `projecthub-internal` (172.20.0.0/24)
- **MCP Integration**: Connected to `mcp-infrastructure` network (172.19.0.0/24)
- **External Access**: HTTP on localhost:8080

## Installation and Setup

### Prerequisites

- Docker and Docker Compose v2.37.3+
- Access to existing MCP infrastructure
- Network connectivity to Home Assistant, WikiJS, and Proxmox

### Quick Start

```bash
# Navigate to project directory
cd /home/dev/workspace/project-management

# Start all services
/home/dev/workspace/project-management-wrapper.sh start

# Check service health
/home/dev/workspace/project-management-wrapper.sh health

# View service status
/home/dev/workspace/project-management-wrapper.sh status
```

### Initial Configuration

1. **Environment Setup**: Configuration is automatically generated in `.env`
2. **Database Initialization**: PostgreSQL schema created with audit triggers
3. **MCP Registration**: Automatic registration with infrastructure
4. **Service Integration**: Connectivity verified with external services

## Management Commands

### Wrapper Script (`/home/dev/workspace/project-management-wrapper.sh`)

```bash
# Service Management
./project-management-wrapper.sh start     # Start all services
./project-management-wrapper.sh stop      # Stop all services
./project-management-wrapper.sh restart   # Restart all services
./project-management-wrapper.sh status    # Show service status

# Monitoring
./project-management-wrapper.sh health    # Check service health
./project-management-wrapper.sh logs      # View all logs
./project-management-wrapper.sh logs backend  # View specific service logs

# Database Operations
./project-management-wrapper.sh db backup # Create database backup
./project-management-wrapper.sh db shell  # Open database shell
./project-management-wrapper.sh db restore <file>  # Restore from backup

# Maintenance
./project-management-wrapper.sh update    # Update services
./project-management-wrapper.sh cleanup   # Clean up resources
```

### Health Monitoring (`scripts/health-monitor.sh`)

```bash
# Health Checks
./scripts/health-monitor.sh check         # Run full health check
./scripts/health-monitor.sh restart       # Restart unhealthy services
./scripts/health-monitor.sh monitor       # Continuous monitoring mode
./scripts/health-monitor.sh cleanup       # Clean up old logs
```

### Backup Management (`scripts/backup.sh`)

```bash
# Backup Operations
./scripts/backup.sh full                  # Create full backup
./scripts/backup.sh database             # Backup database only
./scripts/backup.sh config               # Backup configuration only
./scripts/backup.sh list                 # List available backups
./scripts/backup.sh restore <backup_id>  # Restore from backup
./scripts/backup.sh schedule             # Set up automated backups
```

### MCP Integration (`scripts/mcp-integration.sh`)

```bash
# Integration Management
./scripts/mcp-integration.sh setup       # Full integration setup
./scripts/mcp-integration.sh check       # Check integration status
./scripts/mcp-integration.sh sync        # Sync with external services
./scripts/mcp-integration.sh register    # Register with MCP infrastructure
```

## Integration Points

### Home Assistant Integration
- **Endpoint**: http://192.168.1.155:8123
- **Purpose**: Project task automation and smart home integration
- **Status**: ✅ Active and monitored

### WikiJS Integration
- **Endpoint**: http://192.168.1.90:3000
- **Purpose**: Project documentation and knowledge management
- **Status**: ✅ Active and monitored

### Proxmox Integration
- **Endpoint**: http://192.168.1.137:8006
- **Purpose**: Infrastructure monitoring and resource management
- **Status**: ✅ Active and monitored

## Security Features

### Authentication & Authorization
- JWT-based authentication with secure secret generation
- Role-based access control (RBAC) support
- Session management with configurable timeouts

### Network Security
- Rate limiting on API endpoints (10 req/s general, 5 req/s auth)
- CORS configuration for secure cross-origin requests
- Security headers (XSS protection, content type sniffing prevention)
- Internal network isolation with bridge networking

### Data Protection
- PostgreSQL with audit logging and triggers
- Automated backup with retention policies
- Environment variable protection (excluded from backups)
- Secure Redis authentication

## Monitoring and Logging

### Health Monitoring
- **Container Health**: Automated health checks for all services
- **Database Connectivity**: PostgreSQL connection monitoring
- **Cache Performance**: Redis connectivity and performance
- **Integration Status**: External service availability monitoring
- **Resource Usage**: Disk space and memory monitoring

### Logging Architecture
- **Unified Logging**: JSON-formatted logs forwarded to MCP infrastructure
- **Service-Specific Logs**: Individual service logging with rotation
- **Integration Logs**: External service sync status tracking
- **Audit Logs**: Database operation auditing with triggers

### Key Log Files
```
/home/dev/workspace/project-management/logs/
├── projecthub.log              # Main application logs
├── health-monitor.log          # Health monitoring logs
├── backup.log                  # Backup operation logs
├── integration-sync.log        # External service sync logs
├── integration-status.csv      # Service availability tracking
├── health-history.csv          # Historical health data
└── health-status.txt           # Current health percentage
```

## Backup and Recovery

### Automated Backups
- **Schedule**: Daily at 2:00 AM (configurable via cron)
- **Retention**: 30 days for backups, 90 days for snapshots
- **Components**: Database, configuration, application data, logs
- **Verification**: Integrity checks and checksums

### Recovery Procedures
1. **Database Recovery**: Automated PostgreSQL restoration from compressed backups
2. **Configuration Recovery**: Service configuration restoration
3. **Full System Recovery**: Complete environment restoration from backup manifest

### Backup Storage
```
/home/dev/workspace/project-management/backups/
├── database/                   # PostgreSQL dumps (compressed)
├── config/                     # Configuration archives
├── data/                       # Application data archives
├── logs/                       # Log archives
└── manifest_*.txt              # Backup manifests with checksums
```

## Performance Optimization

### Database Optimization
- PostgreSQL 17 with optimized configuration
- Connection pooling and query optimization
- Audit logging with minimal performance impact

### Caching Strategy
- Redis caching layer for session management
- Application-level caching for frequently accessed data
- Static asset caching with long expiration times

### Network Optimization
- Nginx reverse proxy with upstream load balancing
- Gzip compression for text-based content
- Keep-alive connections for reduced latency

## Troubleshooting

### Common Issues

1. **Services Not Starting**
   ```bash
   # Check Docker status
   docker compose ps
   
   # View startup logs
   docker compose logs
   
   # Restart services
   ./project-management-wrapper.sh restart
   ```

2. **Database Connection Issues**
   ```bash
   # Check PostgreSQL health
   ./scripts/health-monitor.sh check
   
   # Access database shell
   ./project-management-wrapper.sh db shell
   
   # Restart database service
   docker compose restart postgres
   ```

3. **Integration Connectivity Issues**
   ```bash
   # Check external service status
   ./scripts/mcp-integration.sh check
   
   # Re-sync with services
   ./scripts/mcp-integration.sh sync
   ```

### Log Analysis
```bash
# View recent errors
docker compose logs --tail=50 | grep ERROR

# Monitor real-time logs
./project-management-wrapper.sh logs

# Check health monitoring
tail -f logs/health-monitor.log

# Review integration status
cat logs/integration-sync.log
```

## Directory Structure

```
/home/dev/workspace/project-management/
├── ProjectHub-Mcp/             # Cloned repository
├── docker-compose.yml          # Service orchestration
├── .env                        # Environment configuration
├── config/
│   ├── init-db.sql            # Database initialization
│   ├── nginx.conf             # Nginx configuration
│   ├── logging.conf           # Unified logging config
│   └── dashboard-integration.json
├── scripts/
│   ├── health-monitor.sh      # Health monitoring
│   ├── backup.sh              # Backup management
│   └── mcp-integration.sh     # MCP integration
├── data/                      # Persistent data
├── logs/                      # Application logs
└── backups/                   # Backup storage
```

## API Endpoints

### Health Checks
- `GET /health` - Nginx health check
- `GET /api/health` - Backend API health
- `GET /nginx-status` - Nginx status (internal)

### Main Application
- `http://localhost:8080` - Frontend application
- `http://localhost:3001/api` - Backend API
- `http://localhost:3001/api/docs` - API documentation

## Environment Variables

### Core Configuration
```bash
# Database
POSTGRES_DB=projecthub
POSTGRES_USER=projecthub
POSTGRES_PASSWORD=<generated>

# Redis
REDIS_PASSWORD=<generated>

# Application
NODE_ENV=production
JWT_SECRET=<generated>
API_BASE_URL=http://localhost:3001

# Integration
HOME_ASSISTANT_URL=http://192.168.1.155:8123
WIKIJS_URL=http://192.168.1.90:3000
PROXMOX_URL=http://192.168.1.137:8006
```

## Maintenance Schedule

### Daily
- Automated health checks (every 5 minutes in monitor mode)
- Automated backups (2:00 AM)
- Log rotation and cleanup

### Weekly
- Integration status review
- Performance metrics analysis
- Security update checks

### Monthly
- Full system health audit
- Backup integrity verification
- Configuration review and updates

## Support and Maintenance

### Monitoring Dashboard Integration
The system provides metrics for integration with monitoring dashboards:
- Service health indicators
- Response time metrics
- Resource utilization
- Integration endpoint status

### Contact and Support
- **Logs Location**: `/home/dev/workspace/project-management/logs/`
- **Configuration**: `/home/dev/workspace/project-management/config/`
- **Management Script**: `/home/dev/workspace/project-management-wrapper.sh`

## Future Enhancements

### Planned Integrations
1. **Home Assistant Automations**: Project milestone triggers
2. **WikiJS Documentation**: Automated project documentation sync
3. **Proxmox Resource Monitoring**: Project resource allocation tracking

### Scalability Considerations
- Container orchestration with Docker Swarm or Kubernetes
- Database clustering and replication
- Load balancing for high availability
- Distributed caching strategies

---

**Last Updated**: July 1, 2025  
**Version**: 1.0.0  
**Status**: Production Ready