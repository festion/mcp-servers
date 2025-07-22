# Claude Auto-Commit User Guide

## Introduction

The Claude auto-commit feature provides AI-powered commit message generation and automated Git workflows through the GitHub MCP server.

## Quick Start

### Generate Commit Message

Basic commit message generation:
```bash
mcp call github generate_commit_message
```

### Auto-Stage and Commit

Automatically stage files and create commits:
```bash
mcp call github auto_stage_and_commit
```

### Smart Commit

Advanced commit with deep analysis:
```bash
mcp call github smart_commit
```

## Language Support

Supported languages for commit messages:
- English (en) - Default
- Japanese (ja)
- French (fr) 
- German (de)
- Spanish (es)

## Templates

### Conventional Commits

Standard format following conventional commits specification:
- `feat: add new feature`
- `fix: resolve bug`
- `docs: update documentation`
- `refactor: improve code structure`

### Custom Templates

Create custom templates for your team's workflow with configurable formats and required fields.

## Workflow Examples

### Feature Development
1. Create feature branch
2. Make code changes
3. Use smart commit for analysis
4. Push and create pull request

### Documentation Updates
1. Modify documentation files
2. Use auto-stage targeting docs
3. Generate appropriate commit message
4. Push changes

## Advanced Features

### Multiple Alternatives
Generate several commit message options to choose from.

### File Type Analysis
Focus analysis on specific programming languages or file types.

### Dry Run Mode
Test commit generation without making actual changes.

## Best Practices

### Commit Messages
- Use descriptive action verbs
- Include relevant scope information
- Keep titles under 72 characters
- Follow team conventions

### Template Management
- Create standardized team templates
- Version control template configurations
- Document template usage guidelines

### Security
- Protect API credentials
- Use environment variables for configuration
- Regularly rotate access tokens
- Monitor API usage

## Troubleshooting

### Common Issues

**No Changes Detected**
- Verify files are modified
- Check git status

**Rate Limits**
- Monitor API usage
- Implement appropriate delays
- Use multiple tokens if needed

**Template Errors**
- Verify template exists
- Check template syntax
- Use default template as fallback

## Integration

### CI/CD Pipelines
Integrate auto-commit into continuous integration workflows.

### Development Tools
Connect with IDEs and development environments.

### Git Hooks
Automate commit message generation with git hooks.

This guide covers the essential features and usage patterns for the Claude auto-commit system.