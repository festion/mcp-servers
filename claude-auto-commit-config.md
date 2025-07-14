# Claude Auto-Commit Configuration Reference

## Overview

This document provides configuration options for the Claude auto-commit feature in the GitHub MCP server.

## Environment Variables

### Required Variables

- `CLAUDE_API_KEY`: Claude API key for message generation
- `GITHUB_TOKEN`: GitHub personal access token with repository permissions

### Optional Variables

- `AUTO_COMMIT_CACHE_TTL`: Cache time-to-live in seconds (default: 3600)
- `AUTO_COMMIT_MAX_FILES`: Maximum files to analyze (default: 100)
- `AUTO_COMMIT_DEFAULT_LANGUAGE`: Default message language (default: "en")
- `AUTO_COMMIT_RATE_LIMIT`: Rate limit per hour (default: 100)

## Configuration File Format

### YAML Configuration

```yaml
auto_commit:
  cache:
    ttl: 3600
    max_entries: 1000
  analysis:
    max_files: 100
    context_lines: 3
    supported_languages:
      - go
      - javascript
      - python
      - typescript
  templates:
    default: conventional
    custom_path: ./templates
  rate_limiting:
    requests_per_hour: 100
    burst_limit: 10
```

### JSON Configuration

```json
{
  "auto_commit": {
    "cache": {
      "ttl": 3600,
      "max_entries": 1000
    },
    "analysis": {
      "max_files": 100,
      "context_lines": 3,
      "supported_languages": ["go", "js", "py", "ts"]
    },
    "templates": {
      "default": "conventional",
      "custom_path": "./templates"
    },
    "rate_limiting": {
      "requests_per_hour": 100,
      "burst_limit": 10
    }
  }
}
```

## Template Configuration

### Built-in Templates

- `conventional`: Conventional Commits format
- `simple`: Basic format without strict rules
- `detailed`: Extended format with body and footer
- `emoji`: Format with emoji prefixes

### Custom Template Structure

```yaml
templates:
  custom_feature:
    format: "{type}({scope}): {description}"
    required_fields: ["type", "description"]
    optional_fields: ["scope"]
    validation:
      max_length: 72
      allowed_types: ["feat", "fix", "docs", "refactor"]
```

## Language Settings

### Supported Languages

```yaml
languages:
  en:
    name: "English"
    sample: "feat: add user authentication"
  ja:
    name: "Japanese" 
    sample: "feat: ユーザー認証を追加"
  fr:
    name: "French"
    sample: "feat: ajouter l'authentification utilisateur"
  de:
    name: "German"
    sample: "feat: Benutzerauthentifizierung hinzufügen"
  es:
    name: "Spanish"
    sample: "feat: agregar autenticación de usuario"
```

## Performance Tuning

### Cache Settings

```yaml
performance:
  cache:
    enabled: true
    ttl: 3600
    max_size: "100MB"
    cleanup_interval: 300
  analysis:
    parallel_workers: 4
    timeout: 30
    memory_limit: "512MB"
```

### Rate Limiting

```yaml
rate_limiting:
  github_api:
    requests_per_hour: 5000
    burst_limit: 100
  claude_api:
    requests_per_hour: 1000
    burst_limit: 50
  auto_commit:
    requests_per_hour: 100
    per_repository: 50
```

## Security Configuration

### Token Management

```yaml
security:
  token_validation: true
  token_refresh_interval: 3600
  secure_storage: true
  audit_logging: true
```

### Access Control

```yaml
access_control:
  allowed_repositories: ["org/*", "user/specific-repo"]
  restricted_branches: ["main", "production"]
  require_permissions: ["contents:write", "metadata:read"]
```

## Monitoring and Logging

### Log Configuration

```yaml
logging:
  level: "info"
  format: "json"
  outputs: ["console", "file"]
  file_path: "/var/log/auto-commit.log"
  max_size: "100MB"
  max_backups: 5
```

### Metrics Collection

```yaml
metrics:
  enabled: true
  endpoint: "/metrics"
  collection_interval: 60
  retention_days: 30
```

## Service Configuration

### Docker Configuration

```yaml
version: '3.8'
services:
  github-mcp-server:
    image: github-mcp-server:latest
    environment:
      - CLAUDE_API_KEY=${CLAUDE_API_KEY}
      - GITHUB_TOKEN=${GITHUB_TOKEN}
    volumes:
      - ./config:/app/config:ro
      - ./templates:/app/templates:ro
    ports:
      - "3000:3000"
```

### Systemd Service

```ini
[Unit]
Description=GitHub MCP Server with Auto-Commit
After=network.target

[Service]
Type=simple
User=mcp-server
WorkingDirectory=/opt/github-mcp-server
ExecStart=/opt/github-mcp-server/bin/server
EnvironmentFile=/etc/github-mcp-server/environment
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

## Validation

### Configuration Validation

The server validates configuration on startup:
- Required environment variables
- Template syntax and structure
- Rate limit values
- File permissions
- Network connectivity

### Health Checks

```yaml
health_checks:
  enabled: true
  interval: 30
  timeout: 5
  endpoints:
    - path: "/health"
      method: "GET"
    - path: "/ready"
      method: "GET"
```

This configuration reference provides all necessary settings for deploying and customizing the Claude auto-commit feature.