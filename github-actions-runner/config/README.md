# Configuration Management System

This directory contains the comprehensive configuration management system for the GitHub Actions self-hosted runner. The system provides secure token handling, environment management, and automated configuration updates without requiring container rebuilds.

## Directory Structure

```
config/
├── README.md                     # This file
├── runner.env.example            # Environment variables template
├── runner-config.yml             # Main runner configuration
├── network-config.yml            # Network settings and connectivity
├── integration-config.yml        # External service integrations
├── token-manager.sh              # Secure token management script
├── validate-config.sh            # Configuration validation script
├── update-config.sh              # Configuration update management
└── environments/                 # Environment-specific templates
    ├── development.env           # Development environment settings
    └── production.env            # Production environment settings
```

## Quick Start

### 1. Initial Setup

1. **Copy environment template**:
   ```bash
   cp runner.env.example runner.env
   ```

2. **Configure basic settings**:
   ```bash
   nano runner.env
   ```
   
   Set required variables:
   - `GITHUB_REPOSITORY_URL`
   - `RUNNER_NAME`
   - `RUNNER_ENVIRONMENT`

3. **Store GitHub token securely**:
   ```bash
   ./token-manager.sh store github ghp_your_token_here
   ```

4. **Validate configuration**:
   ```bash
   ./validate-config.sh
   ```

### 2. Environment-Specific Setup

For development environment:
```bash
./update-config.sh generate development
```

For production environment:
```bash
./update-config.sh generate production
```

## Configuration Files

### Environment Configuration (`runner.env`)

Contains all environment variables for the runner. Key sections:

- **GitHub Settings**: Repository URL, runner identity, labels
- **Security**: Token management, audit settings
- **Resources**: CPU, memory, disk limits
- **Network**: Private network access, proxy settings
- **Monitoring**: Health checks, metrics, logging
- **Integration**: Home Assistant, external services

### Runner Configuration (`runner-config.yml`)

YAML-based configuration for:

- Runner identity and registration
- Resource management
- Network settings
- Security policies
- Monitoring and logging
- Backup settings
- Feature flags

### Network Configuration (`network-config.yml`)

Network-specific settings:

- Network topology and segments
- Connectivity requirements
- DNS configuration
- SSL/TLS settings
- Firewall rules
- Routing configuration

### Integration Configuration (`integration-config.yml`)

External service integrations:

- Home Assistant integration
- Monitoring systems (Prometheus, Grafana)
- Logging systems (Fluent Bit, Elasticsearch)
- Notification services (Slack, email)
- Backup systems

## Token Management

### Secure Token Storage

The token management system provides:

- **Encrypted Storage**: Tokens encrypted at rest
- **Access Control**: Secure file permissions
- **Validation**: Automatic token validation
- **Rotation**: Automated token rotation
- **Backup**: Token backup and recovery

### Token Operations

**Store a token**:
```bash
./token-manager.sh store github ghp_your_token_here
```

**Retrieve a token**:
```bash
./token-manager.sh retrieve github
```

**Validate a token**:
```bash
./token-manager.sh validate github
```

**Rotate a token**:
```bash
./token-manager.sh rotate github ghp_new_token_here
```

**Backup tokens**:
```bash
./token-manager.sh backup github
```

**Health check**:
```bash
./token-manager.sh health
```

## Configuration Validation

### Validation Types

**Full validation**:
```bash
./validate-config.sh all
```

**Configuration files only**:
```bash
./validate-config.sh config
```

**Network connectivity**:
```bash
./validate-config.sh network
```

**Security settings**:
```bash
./validate-config.sh security
```

**System requirements**:
```bash
./validate-config.sh system
```

### Validation Checks

- **File Syntax**: YAML and environment file validation
- **Variable Format**: Environment variable format checking
- **Network Connectivity**: GitHub API and private network access
- **Docker Environment**: Docker and Docker Compose validation
- **File Permissions**: Security permission checks
- **System Resources**: Resource availability checks

## Configuration Updates

### Update Operations

**Update environment variable**:
```bash
./update-config.sh update-env RUNNER_DEBUG true
```

**Update YAML configuration**:
```bash
./update-config.sh update-yaml runner-config.yml '.logging.level' 'DEBUG'
```

**Reload service configuration**:
```bash
./update-config.sh reload runner
```

**Backup configuration**:
```bash
./update-config.sh backup all
```

**Restore configuration**:
```bash
./update-config.sh restore /path/to/backup
```

### Configuration Migration

**Migrate between versions**:
```bash
./update-config.sh migrate 1.0 1.1
```

**Generate from template**:
```bash
./update-config.sh generate production
```

**Check configuration status**:
```bash
./update-config.sh status
```

## Environment Management

### Development Environment

Optimized for:
- Debugging and troubleshooting
- Verbose logging
- Shorter retention periods
- Enhanced monitoring
- Feature flag testing

Configuration:
```bash
cp environments/development.env runner.env
./validate-config.sh
```

### Production Environment

Optimized for:
- Performance and stability
- Security and compliance
- Resource efficiency
- Long-term operation
- Minimal logging overhead

Configuration:
```bash
cp environments/production.env runner.env
./validate-config.sh
```

## Security Features

### Token Security

- **Encryption**: AES-256-CBC encryption for stored tokens
- **Access Control**: Restricted file permissions (600)
- **Validation**: Regular token validation against APIs
- **Rotation**: Automated token rotation with zero downtime
- **Audit**: Complete audit trail of token operations

### Configuration Security

- **Validation**: Comprehensive configuration validation
- **Backup**: Automatic backup before changes
- **Versioning**: Configuration version tracking
- **Access Control**: Secure file permissions
- **Audit Logging**: All configuration changes logged

### Network Security

- **SSL/TLS**: Configurable SSL verification
- **Firewall**: Network access restrictions
- **Private Network**: Secure private network access
- **Proxy Support**: HTTP/HTTPS proxy configuration

## Integration Points

### Home Assistant Integration

- **API Access**: Secure token-based authentication
- **Notifications**: Job status and health notifications
- **Sensors**: Runner metrics and status sensors
- **Automations**: Trigger Home Assistant automations

### Monitoring Integration

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Dashboard integration
- **Fluent Bit**: Log aggregation and forwarding
- **Health Checks**: Comprehensive health monitoring

### Notification Integration

- **Email**: SMTP-based email notifications
- **Slack**: Webhook-based Slack notifications
- **Discord**: Discord webhook integration
- **Custom Webhooks**: Configurable webhook endpoints

## Troubleshooting

### Common Issues

1. **Configuration Validation Fails**:
   ```bash
   ./validate-config.sh config
   # Check specific error messages and fix configuration
   ```

2. **Token Validation Fails**:
   ```bash
   ./token-manager.sh validate github
   # Verify token has required permissions
   ```

3. **Network Connectivity Issues**:
   ```bash
   ./validate-config.sh network
   # Check GitHub API and private network access
   ```

4. **Service Reload Fails**:
   ```bash
   ./update-config.sh status
   # Check service status and logs
   ```

### Debug Mode

Enable debug mode for troubleshooting:
```bash
./update-config.sh update-env RUNNER_DEBUG true
./update-config.sh update-env RUNNER_LOG_LEVEL DEBUG
./update-config.sh reload runner
```

### Log Analysis

Check configuration logs:
```bash
tail -f ../logs/config-validation.log
tail -f ../logs/config-update.log
tail -f ../logs/token-manager.log
```

## Best Practices

### Configuration Management

1. **Always Validate**: Run validation after any configuration change
2. **Backup First**: Create backups before major changes
3. **Test Changes**: Use development environment for testing
4. **Monitor Impact**: Check service status after updates
5. **Document Changes**: Maintain change documentation

### Security Practices

1. **Regular Token Rotation**: Enable automatic token rotation
2. **Secure Storage**: Use proper file permissions
3. **Audit Trail**: Enable comprehensive audit logging
4. **Regular Validation**: Schedule regular token validation
5. **Backup Tokens**: Maintain secure token backups

### Environment Management

1. **Environment-Specific Configs**: Use appropriate environment templates
2. **Resource Sizing**: Configure resources based on workload
3. **Monitoring Setup**: Enable appropriate monitoring for environment
4. **Log Retention**: Set appropriate log retention policies
5. **Feature Flags**: Use feature flags for controlled rollouts

## Support

For configuration issues:

1. **Validation**: Run `./validate-config.sh all`
2. **Documentation**: Review this README and configuration comments
3. **Logs**: Check configuration management logs
4. **Status**: Use `./update-config.sh status` for service status
5. **Health Check**: Run `./token-manager.sh health` for token status

## Advanced Topics

### Custom Integrations

Add custom integrations by:
1. Extending `integration-config.yml`
2. Adding validation rules to `validate-config.sh`
3. Implementing update procedures in `update-config.sh`

### Configuration Templates

Create custom templates by:
1. Adding new environment files in `environments/`
2. Extending `update-config.sh` with template generation logic
3. Adding validation rules for template-specific settings

### Automated Configuration

Implement automated configuration updates by:
1. Using configuration management tools (Ansible, Chef, Puppet)
2. Integrating with CI/CD pipelines
3. Implementing configuration drift detection
4. Setting up automated validation and rollback