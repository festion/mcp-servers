# Prompt 03: Docker Compose Configuration

## Task
Create a production-ready Docker Compose configuration for the GitHub Actions self-hosted runner with fault-tolerance and monitoring capabilities.

## Context
- Container-based deployment strategy
- Requires network access to private IP `192.168.1.155`
- Must integrate with existing homelab infrastructure
- Needs fault-tolerance and auto-recovery capabilities

## Requirements
Create `/home/dev/workspace/github-actions-runner/docker-compose.yml` with:

1. **Runner Service Configuration**
   - Official GitHub Actions runner image
   - Proper environment variable management
   - Volume mounts for persistence
   - Network connectivity configuration

2. **Supporting Services**
   - Health monitoring container
   - Log aggregation service
   - Backup service container
   - Metrics collection (Prometheus compatible)

3. **Network Configuration**
   - Bridge network for container communication
   - Host network access for private IP connectivity
   - Security group definitions
   - Port mapping specifications

4. **Volume Management**
   - Persistent storage for runner data
   - Log file persistence
   - Configuration file mounting
   - Backup data storage

5. **Resource Management**
   - CPU and memory limits
   - Restart policies
   - Health check definitions
   - Dependency management

## Deliverables
- Complete docker-compose.yml file
- Environment variable template (.env.example)
- Volume directory structure
- Network security configuration

## Success Criteria
- Containers start successfully and maintain connectivity
- Runner can access both GitHub and private network
- Health monitoring is functional
- Resource limits prevent system overload
- Auto-recovery mechanisms work properly