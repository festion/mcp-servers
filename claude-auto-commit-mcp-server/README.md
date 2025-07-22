# Claude Auto-Commit MCP Server

An AI-powered Model Context Protocol (MCP) server that provides intelligent Git commit functionality with comprehensive pre-commit review capabilities.

## Features

### 🤖 AI-Powered Commit Messages
- **Claude Integration**: Uses Anthropic's Claude AI to generate contextual commit messages
- **Multi-language Support**: English, Japanese, French, German, Spanish
- **Conventional Commits**: Supports conventional commits format
- **Smart Analysis**: Analyzes code changes to determine appropriate commit types and scopes

### 🔍 Comprehensive Pre-Commit Review
Your requested pre-commit review instructions are fully implemented:

1. **Diff Analysis**: Reviews changes for problems, bugs, and potential issues
2. **Task Verification**: Checks if completed tasks actually have corresponding implementations  
3. **Documentation Alignment**: Ensures code changes align with documentation
4. **Functionality Removal Detection**: Reports any removed functionality or logic
5. **Test Quality Assessment**: Validates tests are proper and complete (no placeholders)
6. **Test Alignment Verification**: Ensures tests remain aligned with their purpose
7. **Test Coverage Analysis**: Reports if test functionality/coverage was reduced
8. **Recommendations**: Provides actionable concerns and recommendations

### 🛠️ Three Powerful Tools

#### 1. `generate_commit_message`
Generates AI-powered commit messages based on staged changes.

```json
{
  "name": "generate_commit_message",
  "arguments": {
    "language": "en",
    "conventional_commits": true,
    "include_emoji": false,
    "max_length": 72
  }
}
```

#### 2. `auto_stage_and_commit`
Automatically stages files and creates commits with pre-commit review.

```json
{
  "name": "auto_stage_and_commit",
  "arguments": {
    "enable_pre_commit_review": true,
    "dry_run": false,
    "message_config": {
      "conventional_commits": true
    }
  }
}
```

#### 3. `smart_commit` 
Advanced commit workflow with comprehensive analysis and review.

```json
{
  "name": "smart_commit",
  "arguments": {
    "analysis_depth": "comprehensive",
    "include_pre_commit_review": true,
    "require_review_approval": true,
    "auto_stage": true
  }
}
```

## Installation

1. **Navigate to the server directory:**
   ```bash
   cd /home/dev/workspace/mcp-servers/claude-auto-commit-mcp-server
   ```

2. **Build the server:**
   ```bash
   ./build.sh
   ```

3. **Set up authentication (choose one option):**
   
   **Option A: API Key Authentication**
   ```bash
   export ANTHROPIC_API_KEY="your-claude-api-key"
   # OR
   export CLAUDE_API_KEY="your-claude-api-key"
   ```
   
   **Option B: Username/Password Authentication (like Claude Code)**
   ```bash
   export CLAUDE_USERNAME="your-email@example.com"
   export CLAUDE_PASSWORD="your-password"
   # OR
   export CLAUDE_EMAIL="your-email@example.com"
   export CLAUDE_PASSWORD="your-password"
   ```
   
   **Note:** Option B uses the same credentials as Claude Code and provides a seamless experience similar to Claude Code's authentication.

## Usage

### Using the Wrapper Script

```bash
# Start in stdio mode (for MCP clients)
/home/dev/workspace/claude-auto-commit-wrapper.sh stdio

# Or use directly
/home/dev/workspace/mcp-servers/claude-auto-commit-wrapper.sh stdio

# Background mode
/home/dev/workspace/claude-auto-commit-wrapper.sh start
/home/dev/workspace/claude-auto-commit-wrapper.sh status
/home/dev/workspace/claude-auto-commit-wrapper.sh stop
```

### MCP Client Configuration

Add to your MCP client configuration:

```json
{
  "mcpServers": {
    "claude-auto-commit": {
      "command": "/home/dev/workspace/claude-auto-commit-wrapper.sh",
      "args": ["stdio"],
      "env": {
        "ANTHROPIC_API_KEY": "your-api-key"
      }
    }
  }
}
```

**Or with username/password (like Claude Code):**

```json
{
  "mcpServers": {
    "claude-auto-commit": {
      "command": "/home/dev/workspace/claude-auto-commit-wrapper.sh",
      "args": ["stdio"],
      "env": {
        "CLAUDE_USERNAME": "your-email@example.com",
        "CLAUDE_PASSWORD": "your-password"
      }
    }
  }
}
```

### Claude Code Integration

Add to your Claude Code MCP configuration:

```bash
claude mcp add claude-auto-commit "/home/dev/workspace/claude-auto-commit-wrapper.sh stdio"
```

## Pre-Commit Review Process

When you use `auto_stage_and_commit` or `smart_commit` with review enabled, the system performs:

### 1. Diff Analysis
- ✅ Checks for debugging code, TODOs, hardcoded secrets
- ✅ Identifies syntax issues and potential bugs
- ✅ Validates code quality and security

### 2. Task Verification  
- ✅ **Checks if tasks marked completed [x] actually have implementations**
- ✅ Validates task status updates in tasks.md
- ✅ Reports erroneously marked completed tasks

### 3. Documentation Alignment
- ✅ **Checks if implementation aligns with documentation (a.md, b.md, c.md)**
- ✅ Ensures API changes are documented
- ✅ Validates examples still work

### 4. Functionality Removal
- ✅ **Reports if any functionality/logic was removed**
- ✅ Identifies deleted files and functions
- ✅ Warns about breaking changes

### 5. Test Quality
- ✅ **Checks if tests are proper and complete**
- ✅ **Reports placeholder tests or bypassed assertions**
- ✅ Identifies skipped tests

### 6. Test Alignment
- ✅ **Reports if tests became misaligned from before**
- ✅ Validates test expectations haven't been lowered
- ✅ Ensures tests still validate correct behavior

### 7. Coverage Analysis
- ✅ **Reports if test functionality/coverage was reduced**
- ✅ Identifies deleted test files
- ✅ Warns about significant test content reduction

### 8. Final Review
- ✅ **Raises concerns and recommendations**
- ✅ Provides actionable suggestions
- ✅ Approves or rejects commits based on findings

## Example Workflow

1. **Make changes to your code**
2. **Run smart commit with review:**
   ```json
   {
     "name": "smart_commit",
     "arguments": {
       "analysis_depth": "comprehensive",
       "include_pre_commit_review": true,
       "require_review_approval": true
     }
   }
   ```

3. **Review the comprehensive analysis:**
   - Code change analysis
   - Pre-commit review findings
   - Task completion verification
   - Documentation alignment check
   - Test quality assessment

4. **Address any issues** identified by the review

5. **Commit approved** automatically if no critical issues found

## Configuration

Copy `config.example.json` to `config.json` and customize:

```json
{
  "review_config": {
    "enabled": true,
    "depth": "comprehensive",
    "require_task_verification": true,
    "require_documentation_check": true,
    "require_test_validation": true
  }
}
```

## Error Handling

The server provides detailed error responses with:
- Error codes and messages
- Specific suggestions for resolution
- Context about what went wrong
- Recommendations for fixing issues

## Security

- API keys are loaded from environment variables
- No credentials are logged or stored
- Secure handling of Git operations
- Validation of all inputs

## Troubleshooting

### Common Issues

1. **Missing API Key**
   ```bash
   export ANTHROPIC_API_KEY="your-key"
   ```

2. **No Staged Changes**
   ```bash
   git add .
   ```

3. **Review Failures**
   - Address critical and high-priority findings
   - Update documentation as needed
   - Ensure tests are meaningful

### Logs

Check logs for detailed information:
```bash
tail -f /tmp/claude-auto-commit-mcp.log
```

## Integration with Existing Workflow

This implementation integrates seamlessly with your existing MCP server setup and follows the same patterns as your other MCP servers in `/home/dev/workspace/mcp-servers/`.

The pre-commit review instructions you requested are now fully implemented and will execute before any commit operation, ensuring code quality and preventing issues from being committed to your repository.