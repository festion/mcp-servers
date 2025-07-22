# GitHub Actions Self-Hosted Runner Architecture

## 1. Architecture Overview

### Problem Statement
GitHub's hosted runners cannot access private network infrastructure (192.168.1.155), causing Home Assistant CI/CD pipeline failures at SSH connection steps. This architecture provides a production-ready, fault-tolerant solution using self-hosted runners.

### Solution Strategy
- **Container-based deployment** using Docker Compose for consistent, reproducible environments
- **Network bridge connectivity** enabling access to private infrastructure (192.168.1.0/24)
- **Security isolation** through containerization and network segmentation
- **Fault tolerance** via health monitoring, automatic recovery, and backup systems

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Actions Ecosystem                    │
├─────────────────────────────────────────────────────────────────┤
│  Workflow Trigger → Queue → Self-Hosted Runner Assignment      │
└─────────────────────────┬───────────────────────────────────────┘
                          │ HTTPS/Webhook
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Homelab Infrastructure                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   GitHub Runner │  │   Monitoring    │  │     Backup      │  │
│  │    Container    │  │    Services     │  │    Services     │  │
│  │                 │  │                 │  │                 │  │
│  │ • Runner Agent  │  │ • Health Check  │  │ • Config Backup │  │
│  │ • Docker Engine │  │ • Log Aggreg.   │  │ • Token Mgmt    │  │
│  │ • SSH Client    │  │ • Alerting      │  │ • State Recovery│  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│           │                     │                     │         │
│           └─────────────────────┼─────────────────────┘         │
│                                 │                               │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                Docker Bridge Network                        │  │
│  │              (github-runner-network)                       │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                 │                               │
│           ┌─────────────────────┼─────────────────────┐         │
│           │                     │                     │         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Home Assistant  │  │   Proxmox VE    │  │  Other Private  │  │
│  │ 192.168.1.155   │  │ 192.168.1.137   │  │   Services      │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Component Design

### 2.1 GitHub Actions Runner Container

**Base Configuration:**
- **Image**: `ghcr.io/actions/actions-runner:latest`
- **Runtime**: Docker with privileged access for nested containerization
- **Network Mode**: Bridge with host network access
- **Persistent Storage**: Configuration and workspace volumes

**Container Specifications:**
```yaml
services:
  github-runner:
    image: ghcr.io/actions/actions-runner:latest
    container_name: github-actions-runner
    restart: unless-stopped
    privileged: true
    volumes:
      - ./runner-config:/runner
      - ./workspace:/workspace
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - github-runner-network
    environment:
      - GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - RUNNER_NAME=${RUNNER_NAME}
      - RUNNER_LABELS=${RUNNER_LABELS}
```

### 2.2 Network Bridge Configuration

**Network Architecture:**
- **Bridge Network**: `github-runner-network` with subnet 172.20.0.0/16
- **Host Network Access**: Enabled for private network connectivity
- **Port Mapping**: Selective exposure for monitoring services
- **Security Groups**: Container-level network policies

**Network Configuration:**
```yaml
networks:
  github-runner-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1
```

### 2.3 Health Monitoring System

**Components:**
- **Health Check Service**: Container health monitoring with restart policies
- **Log Aggregation**: Centralized logging with rotation and retention
- **Metrics Collection**: Resource usage and performance monitoring
- **Alert System**: Failure notifications and escalation procedures

**Health Monitor Configuration:**
```yaml
healthcheck:
  test: ["CMD", "/runner/health-check.sh"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

### 2.4 Backup and Recovery Mechanisms

**Backup Strategy:**
- **Configuration Backup**: Runner registration tokens and settings
- **State Persistence**: Workspace and cache preservation
- **Automated Recovery**: Self-healing container restart policies
- **Disaster Recovery**: Complete environment restoration procedures

## 3. Technical Decisions

### 3.1 Container Orchestration Choice: Docker Compose

**Decision**: Use Docker Compose over Kubernetes or Docker Swarm

**Rationale:**
- **Simplicity**: Single-node deployment with minimal overhead
- **Maintenance**: Easier operational management for homelab environment
- **Resource Efficiency**: Lower resource consumption compared to K8s
- **Integration**: Better compatibility with existing Docker-based infrastructure
- **Development Velocity**: Faster iteration and deployment cycles

### 3.2 Service Isolation Strategy

**Decision**: Container-level isolation with selective host access

**Rationale:**
- **Security**: Process isolation while maintaining network connectivity
- **Flexibility**: Privileged access for Docker-in-Docker scenarios
- **Performance**: Minimal network overhead with bridge networking
- **Compatibility**: Support for existing CI/CD pipeline requirements

### 3.3 Resource Allocation Requirements

**CPU Allocation:**
- **Runner Container**: 2-4 CPU cores (burstable)
- **Monitoring Services**: 0.5 CPU cores
- **System Overhead**: 0.5 CPU cores
- **Total Recommended**: 4-6 CPU cores

**Memory Allocation:**
- **Runner Container**: 4-8 GB RAM
- **Docker Engine**: 2 GB RAM
- **Monitoring Stack**: 1 GB RAM
- **System Buffer**: 1 GB RAM
- **Total Recommended**: 8-12 GB RAM

**Storage Requirements:**
- **Container Images**: 5 GB
- **Workspace Storage**: 10-20 GB
- **Log Storage**: 2-5 GB
- **Backup Storage**: 5-10 GB
- **Total Recommended**: 25-40 GB SSD

### 3.4 Network Security Model

**Security Layers:**
1. **Container Isolation**: Non-root user execution within containers
2. **Network Segmentation**: Dedicated bridge network with controlled access
3. **Token Management**: Secure GitHub token storage and rotation
4. **Access Control**: SSH key-based authentication for deployment targets
5. **Audit Logging**: Comprehensive activity logging and monitoring

## 4. Integration Points

### 4.1 Home Assistant Deployment Pipeline

**Integration Method:**
- **SSH Connectivity**: Direct SSH access to Home Assistant host (192.168.1.155)
- **Deployment Scripts**: Existing homelab-gitops-auditor scripts
- **Configuration Management**: Automated config validation and deployment
- **Service Restart**: Controlled Home Assistant service management

**Pipeline Integration:**
```yaml
# .github/workflows/deploy-homeassistant.yml
runs-on: self-hosted
steps:
  - name: Deploy to Home Assistant
    run: |
      ssh homeassistant@192.168.1.155 "cd /config && git pull"
      ssh homeassistant@192.168.1.155 "ha core restart"
```

### 4.2 Existing homelab-gitops-auditor Infrastructure

**Integration Points:**
- **Audit Logging**: Enhanced audit trail with GitHub Actions events
- **Monitoring Integration**: Existing Prometheus/Grafana monitoring
- **Alert Integration**: Webhook integration with existing alert managers
- **Backup Coordination**: Integration with existing backup schedules

### 4.3 Monitoring and Alerting Systems

**Integration Components:**
- **Prometheus Metrics**: Custom metrics export for runner performance
- **Grafana Dashboards**: Visual monitoring of CI/CD pipeline health
- **Alert Manager**: Integration with existing notification channels
- **Log Aggregation**: ELK stack integration for centralized logging

## 5. Scalability Considerations

### 5.1 Multi-Runner Support

**Horizontal Scaling Strategy:**
- **Runner Pool**: Support for 2-5 concurrent runners
- **Load Distribution**: GitHub-managed job distribution across runners
- **Resource Isolation**: Per-runner resource limits and quotas
- **Dynamic Scaling**: Auto-scaling based on queue depth (future enhancement)

**Implementation Approach:**
```yaml
# Multi-runner compose configuration
services:
  github-runner-1:
    <<: *runner-template
    container_name: github-runner-1
    environment:
      - RUNNER_NAME=homelab-runner-1
  
  github-runner-2:
    <<: *runner-template
    container_name: github-runner-2
    environment:
      - RUNNER_NAME=homelab-runner-2
```

### 5.2 Resource Scaling Strategy

**Vertical Scaling:**
- **Memory Scaling**: Dynamic memory allocation based on job requirements
- **CPU Scaling**: Burst capability for compute-intensive workflows
- **Storage Scaling**: Automatic workspace cleanup and expansion
- **Network Scaling**: Quality of Service (QoS) management

**Horizontal Scaling:**
- **Multi-Node Support**: Future expansion to multiple physical hosts
- **Load Balancing**: Intelligent job distribution across runners
- **Geographic Distribution**: Support for multi-region deployments

### 5.3 Performance Optimization

**Container Optimization:**
- **Image Caching**: Local Docker image registry for faster pulls
- **Layer Optimization**: Minimized container layers and size
- **Startup Optimization**: Pre-warmed containers and reduced cold start time
- **Resource Tuning**: Optimized CPU and memory allocation patterns

**Network Optimization:**
- **Connection Pooling**: Persistent SSH connections for repeated deployments
- **Bandwidth Management**: QoS prioritization for critical traffic
- **Latency Optimization**: Local DNS caching and route optimization

**Storage Optimization:**
- **Workspace Caching**: Persistent workspace storage across jobs
- **Artifact Caching**: Local caching of frequently used dependencies
- **Log Rotation**: Automated log cleanup and compression
- **Backup Optimization**: Incremental backup strategies

## 6. Security Architecture

### 6.1 Security Boundaries

**Container Security:**
- Non-privileged execution where possible
- Read-only root filesystem for security containers
- Capability dropping for minimal attack surface
- Security scanning of container images

**Network Security:**
- Firewall rules restricting unnecessary traffic
- TLS encryption for all external communications
- Network segmentation between services
- Intrusion detection at network level

### 6.2 Secrets Management

**Token Security:**
- GitHub token stored in secure environment variables
- Automatic token rotation capabilities
- Encrypted storage of SSH private keys
- Secure secret injection at runtime

## 7. Operational Procedures

### 7.1 Deployment Process

1. **Environment Preparation**: Docker and Docker Compose installation
2. **Configuration Setup**: GitHub token and runner registration
3. **Service Deployment**: Docker Compose stack deployment
4. **Health Verification**: End-to-end connectivity testing
5. **Integration Testing**: Full CI/CD pipeline validation

### 7.2 Maintenance Procedures

1. **Regular Updates**: Container image and security updates
2. **Log Management**: Regular log rotation and cleanup
3. **Performance Monitoring**: Resource usage analysis and optimization
4. **Backup Verification**: Regular backup and recovery testing

### 7.3 Troubleshooting Framework

1. **Health Check Diagnostics**: Systematic component health verification
2. **Log Analysis**: Centralized logging and analysis procedures
3. **Network Diagnostics**: Connectivity and routing verification
4. **Performance Analysis**: Resource bottleneck identification

## 8. Implementation Timeline

### Phase 1: Foundation (Days 1-3)
- Core runner container deployment
- Basic network connectivity
- Initial health monitoring

### Phase 2: Integration (Days 4-6)
- Home Assistant pipeline integration
- Monitoring system integration
- Security hardening

### Phase 3: Optimization (Days 7-10)
- Performance tuning
- Multi-runner support
- Advanced monitoring and alerting

### Phase 4: Production (Days 11-14)
- Full documentation
- Operational procedures
- Disaster recovery testing

## 9. Success Metrics

### Technical Metrics
- **Deployment Success Rate**: >99% successful deployments
- **Pipeline Execution Time**: <5 minutes end-to-end
- **System Availability**: >99.9% uptime
- **Resource Utilization**: <70% average CPU/memory usage

### Operational Metrics
- **Mean Time to Recovery**: <15 minutes for common failures
- **Deployment Frequency**: Support for multiple daily deployments
- **Security Incident Rate**: Zero security breaches
- **Maintenance Overhead**: <2 hours/week operational maintenance

## 10. Risk Mitigation

### High-Risk Items
1. **Network Connectivity Failures**: Redundant network paths and monitoring
2. **Token Expiration**: Automated token rotation and alerting
3. **Resource Exhaustion**: Resource monitoring and automatic scaling
4. **Security Vulnerabilities**: Regular security updates and scanning

### Mitigation Strategies
- Comprehensive monitoring and alerting
- Automated recovery procedures
- Regular backup and disaster recovery testing
- Security-first design principles

---

**Document Version**: 1.0  
**Last Updated**: 2025-07-16  
**Author**: Claude Code Assistant  
**Review Status**: Ready for Implementation