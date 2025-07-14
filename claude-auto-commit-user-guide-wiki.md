# Claude Auto-Commit User Guide

## Introduction

Welcome to the Claude auto-commit feature! This guide will help you get started with AI-powered commit message generation and automated Git workflows using the GitHub MCP server.

## Quick Start

### Basic Usage

1. **Generate a commit message:**
```bash
mcp call github generate_commit_message \
  --data '{
    "owner": "your-username",
    "repo": "your-repository",
    "language": "en",
    "conventional_commits": true
  }'
```

2. **Auto-stage and commit:**
```bash
mcp call github auto_stage_and_commit \
  --data '{
    "owner": "your-username", 
    "repo": "your-repository",
    "message_config": {
      "language": "en",
      "template": "conventional"
    }
  }'
```

3. **Smart commit with analysis:**
```bash
mcp call github smart_commit \
  --data '{
    "owner": "your-username",
    "repo": "your-repository", 
    "analysis_depth": "standard",
    "auto_stage": true
  }'
```

## Language Support

The auto-commit feature supports multiple languages for commit messages:

- **English (en)**: Default language
- **Japanese (ja)**: `言語設定を変更`
- **French (fr)**: `modifier la configuration de langue`
- **German (de)**: `Sprachkonfiguration ändern`
- **Spanish (es)**: `modificar configuración de idioma`

### Example in Japanese:
```bash
mcp call github generate_commit_message \
  --data '{
    "owner": "your-username",
    "repo": "your-repository",
    "language": "ja",
    "conventional_commits": true
  }'
```

Response: `"feat: ユーザー認証システムを追加"`

## Templates

### Conventional Commits

Standard format following [Conventional Commits](https://conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Example:
- `feat: add user authentication system`
- `fix(auth): resolve login token expiration`
- `docs: update API documentation`

### Custom Templates

Create custom templates for your team's workflow:

```json
{
  "template_name": "feature-branch",
  "format": "{type}({scope}): {description}\n\nIssue: #{issue_number}",
  "required_fields": ["type", "description"],
  "optional_fields": ["scope", "issue_number"]
}
```

## Workflow Examples

### Feature Development

Complete workflow for feature development:

```bash
# 1. Create and switch to feature branch
git checkout -b feature/user-authentication

# 2. Make your changes
# ... coding ...

# 3. Use smart commit for comprehensive analysis
mcp call github smart_commit \
  --data '{
    "owner": "company",
    "repo": "product", 
    "analysis_depth": "deep",
    "template_name": "feature-branch",
    "auto_stage": true,
    "require_confirmation": false
  }'

# 4. Push and create PR
git push origin feature/user-authentication
```

### Hotfix Workflow

Quick workflow for urgent fixes:

```bash
# 1. Switch to hotfix branch
git checkout -b hotfix/security-patch

# 2. Apply fix
# ... fix security issue ...

# 3. Generate urgent commit
mcp call github auto_stage_and_commit \
  --data '{
    "owner": "company",
    "repo": "product",
    "message_config": {
      "language": "en",
      "template": "conventional",
      "conventional_commits": true,
      "include_emoji": false
    },
    "stage_options": {
      "auto_detect": true
    }
  }'
```

### Documentation Updates

Optimized for documentation changes:

```bash
mcp call github auto_stage_and_commit \
  --data '{
    "owner": "company",
    "repo": "docs",
    "message_config": {
      "language": "en",
      "template": "docs"
    },
    "stage_options": {
      "patterns": ["docs/**", "*.md", "*.rst"],
      "exclude_patterns": ["node_modules/**"]
    }
  }'
```

## Advanced Features

### Multi-Alternative Generation

Generate multiple commit message options:

```bash
mcp call github generate_commit_message \
  --data '{
    "owner": "company",
    "repo": "product",
    "generate_count": 3,
    "language": "en"
  }'
```

Response:
```json
{
  "message": "feat: implement user authentication system",
  "alternative_messages": [
    "add: user login and registration functionality", 
    "feature: complete authentication workflow implementation"
  ]
}
```

### File Type Analysis

Focus analysis on specific file types:

```bash
mcp call github generate_commit_message \
  --data '{
    "owner": "company",
    "repo": "backend",
    "analyze_file_types": ["go", "sql", "yaml"],
    "context_lines": 5
  }'
```

### Dry Run Mode

Test commit generation without making changes:

```bash
mcp call github smart_commit \
  --data '{
    "owner": "company",
    "repo": "product",
    "analysis_depth": "comprehensive", 
    "dry_run": true,
    "generate_suggestions": true
  }'
```

## Performance Optimization

### Caching

The system automatically caches:
- Repository metadata
- File analysis results  
- Template configurations
- Language models

### Batch Operations

Process multiple repositories efficiently:

```bash
# Process multiple repos in sequence
for repo in frontend backend mobile; do
  mcp call github smart_commit \
    --data "{
      \"owner\": \"company\",
      \"repo\": \"$repo\",
      \"analysis_depth\": \"standard\"
    }"
done
```

## Best Practices

### Commit Message Quality

1. **Use descriptive verbs**: `implement`, `fix`, `update`, `refactor`
2. **Include scope when relevant**: `auth`, `api`, `ui`, `database`
3. **Keep messages concise**: Under 72 characters for the title
4. **Use conventional format**: Consistent team communication

### Template Management

1. **Create team templates**: Standardize across projects
2. **Version control templates**: Track changes and updates
3. **Test templates regularly**: Ensure they work with current workflows
4. **Document template usage**: Help team members understand options

### Security Considerations

1. **Protect API keys**: Never commit tokens to repositories
2. **Use environment variables**: Configure sensitive data securely
3. **Regular token rotation**: Update GitHub and Claude API keys
4. **Audit access logs**: Monitor API usage and access patterns

## Troubleshooting

### Common Issues

**Error: "No changes detected"**
```bash
# Check git status
git status

# Ensure files are modified
git diff --name-only
```

**Error: "Rate limit exceeded"**
```bash
# Check current rate limit
curl -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/rate_limit

# Wait for reset or use different token
```

**Error: "Template not found"**
```bash
# List available templates
mcp call github list_templates

# Use default template
mcp call github generate_commit_message \
  --data '{"owner": "company", "repo": "product"}'
```

### Getting Help

1. **Check the API documentation**: Reference for all parameters
2. **Review error messages**: Detailed information about issues
3. **Enable debug mode**: Additional logging for troubleshooting
4. **Test with minimal examples**: Isolate problems
5. **Check GitHub/Claude API status**: Verify service availability

## Integration Examples

### VS Code Extension

```javascript
const { exec } = require('child_process');

function generateCommitMessage() {
  const command = `mcp call github generate_commit_message \
    --data '{"owner": "company", "repo": "product", "language": "en"}'`;
  
  exec(command, (error, stdout, stderr) => {
    if (error) {
      console.error(`Error: ${error}`);
      return;
    }
    const result = JSON.parse(stdout);
    return result.message;
  });
}
```

### Git Hook Integration

```bash
#!/bin/sh
# .git/hooks/prepare-commit-msg

# Generate commit message if none provided
if [ -z "$2" ]; then
  MESSAGE=$(mcp call github generate_commit_message \
    --data '{"owner": "company", "repo": "product"}' | \
    jq -r '.message')
  
  echo "$MESSAGE" > "$1"
fi
```

This user guide provides comprehensive information for getting started with and mastering the Claude auto-commit feature.