# Claude Auto-Commit API Documentation

## Overview

The Claude auto-commit feature provides AI-powered Git commit message generation and automated commit workflows through the MCP (Model Context Protocol) interface. This feature enables intelligent analysis of code changes and generation of contextually appropriate commit messages with support for multiple languages, formats, and workflow patterns.

## Available Tools

### generate_commit_message

Generates AI-powered commit messages based on repository changes using Claude's advanced language understanding capabilities.

**Parameters:**
- `owner` (string, required): Repository owner/organization name
- `repo` (string, required): Repository name  
- `branch` (string, optional): Target branch (defaults to current branch)
- `language` (string, optional): Message language (`en`, `ja`, `fr`, `de`, `es`, default: `en`)
- `conventional_commits` (boolean, optional): Use conventional commits format (default: `false`)
- `include_emoji` (boolean, optional): Include emojis in commit messages (default: `false`)
- `template` (string, optional): Template name to use for message generation
- `max_length` (integer, optional): Maximum commit message length (default: 72)
- `generate_count` (integer, optional): Number of alternative messages to generate (default: 1, max: 5)
- `context_lines` (integer, optional): Number of context lines to include in diff analysis (default: 3)
- `analyze_file_types` (array, optional): File types to analyze specifically (e.g., ["go", "js", "py"])

**Response:**
```json
{
  "message": "feat: add user authentication system",
  "confidence": 0.95,
  "alternative_messages": [
    "chore: implement user auth",
    "feature: add login functionality"
  ],
  "analysis": {
    "change_type": "feat",
    "scope": "auth",
    "complexity": "moderate",
    "impact": "minor",
    "files_modified": 5,
    "lines_added": 127,
    "lines_removed": 23,
    "languages": ["go", "typescript"],
    "breaking_changes": false,
    "summary": "Implements comprehensive user authentication with JWT tokens"
  },
  "generated_at": "2024-01-15T10:30:00Z",
  "model_used": "claude-3-sonnet-20240229",
  "tokens_used": 1247,
  "processing_time": "3.2s"
}
```

### auto_stage_and_commit

Automatically stages changes and creates commits with AI-generated messages.

**Parameters:**
- `owner` (string, required): Repository owner/organization name
- `repo` (string, required): Repository name
- `branch` (string, optional): Target branch (defaults to current branch)
- `message_config` (object, optional): Configuration for message generation
  - `language` (string): Message language
  - `template` (string): Template to use
  - `conventional_commits` (boolean): Use conventional commits format
  - `include_emoji` (boolean): Include emojis
- `stage_options` (object, optional): Configuration for staging
  - `patterns` (array): File patterns to include
  - `exclude_patterns` (array): File patterns to exclude
  - `auto_detect` (boolean): Auto-detect relevant files

**Response:**
```json
{
  "success": true,
  "commit_sha": "a1b2c3d4e5f6",
  "message": "feat: implement user authentication",
  "files_staged": [
    "src/auth/login.go",
    "src/auth/middleware.go"
  ],
  "changes_summary": {
    "files_modified": 2,
    "lines_added": 89,
    "lines_removed": 12
  }
}
```

### smart_commit

Advanced commit generation with deep analysis and workflow integration.

**Parameters:**
- `owner` (string, required): Repository owner/organization name
- `repo` (string, required): Repository name
- `branch` (string, optional): Target branch
- `analysis_depth` (string, optional): Analysis depth (`basic`, `standard`, `deep`, `comprehensive`)
- `template_name` (string, optional): Template to use
- `auto_stage` (boolean, optional): Automatically stage files
- `require_confirmation` (boolean, optional): Require user confirmation
- `generate_suggestions` (boolean, optional): Generate improvement suggestions
- `dry_run` (boolean, optional): Perform analysis without committing

**Response:**
```json
{
  "success": true,
  "commit_sha": "a1b2c3d4e5f6",
  "message": "refactor: optimize database queries for performance",
  "analysis": {
    "change_type": "refactor",
    "complexity": "high",
    "impact": "major",
    "confidence": 0.92,
    "recommendations": [
      "Consider adding performance tests",
      "Update documentation for new query patterns"
    ]
  },
  "workflow_integration": {
    "suggested_next_steps": [
      "Run performance benchmarks",
      "Update API documentation"
    ],
    "related_issues": ["#123", "#456"],
    "affected_services": ["user-service", "notification-service"]
  }
}
```

## Error Handling

All tools return structured error responses:

```json
{
  "error": {
    "code": "AUTHENTICATION_FAILED",
    "message": "GitHub token is invalid or expired",
    "details": {
      "timestamp": "2024-01-15T10:30:00Z",
      "request_id": "req_123456"
    },
    "suggestions": [
      "Verify your GitHub token is valid",
      "Check token permissions include repository access"
    ]
  }
}
```

## Common Error Codes

- `AUTHENTICATION_FAILED`: Invalid or expired GitHub token
- `REPOSITORY_NOT_FOUND`: Repository does not exist or access denied
- `NO_CHANGES_DETECTED`: No uncommitted changes found
- `RATE_LIMIT_EXCEEDED`: GitHub API rate limit reached
- `ANALYSIS_FAILED`: Claude API error during message generation
- `TEMPLATE_NOT_FOUND`: Specified template does not exist
- `INVALID_PARAMETERS`: Required parameters missing or invalid

## Rate Limiting

- GitHub API: 5000 requests/hour (authenticated)
- Claude API: 1000 requests/hour (varies by plan)
- Auto-commit operations: Maximum 100/hour per repository

## Authentication

Requires:
- Valid GitHub token with repository permissions
- Claude API key for message generation
- MCP server properly configured and running