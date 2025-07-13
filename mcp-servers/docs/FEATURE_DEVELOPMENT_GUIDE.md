# MCP Server Feature Development Guide

## Overview
This guide outlines the standardized process for developing features in the MCP servers project. It covers branch management, development workflows, testing procedures, and deployment guidelines.

## Table of Contents
- [Branch Strategy](#branch-strategy)
- [Development Workflow](#development-workflow)
- [Feature Branch Management](#feature-branch-management)
- [Code Standards](#code-standards)
- [Testing Requirements](#testing-requirements)
- [Review Process](#review-process)
- [MCP Protocol Compliance](#mcp-protocol-compliance)
- [Security Guidelines](#security-guidelines)
- [Documentation Requirements](#documentation-requirements)

## Branch Strategy

### Branch Naming Convention
All MCP feature branches must follow this pattern:
```
feature/mcp-<feature-name>
```

Examples:
- `feature/mcp-webhook-validation`
- `feature/mcp-enhanced-logging`
- `feature/mcp-performance-monitoring`
- `feature/mcp-new-server-type`

### Branch Types
- **Main/Master**: Production-ready code
- **Feature branches**: New features and enhancements
- **Hotfix branches**: Critical bug fixes (pattern: `hotfix/mcp-<issue>`)
- **Release branches**: Release preparation (pattern: `release/v<version>`)

## Development Workflow

### 1. Feature Planning
Before creating a feature branch:
- [ ] Create or reference a GitHub issue
- [ ] Define clear acceptance criteria
- [ ] Identify MCP protocol requirements
- [ ] Plan testing approach
- [ ] Consider security implications

### 2. Branch Creation
```bash
# Create new feature branch
./scripts/feature-branch.sh create <feature-name>
```

This will:
- Create a properly named branch
- Generate feature documentation template
- Set up initial commit
- Push branch to remote

### 3. Development Process
1. **Update feature documentation**
   - Edit `docs/features/<feature-name>.md`
   - Define implementation plan
   - List acceptance criteria

2. **Implement the feature**
   - Follow MCP protocol specifications
   - Adhere to project coding standards
   - Implement proper error handling
   - Add comprehensive logging

3. **Write tests**
   - Unit tests for all new functionality
   - Integration tests for MCP protocol
   - Security tests for input validation
   - Performance tests if applicable

4. **Update documentation**
   - README files for affected servers
   - API documentation
   - Configuration examples
   - Troubleshooting guides

### 4. Testing and Validation
```bash
# Run comprehensive tests
./scripts/feature-branch.sh test <feature-name>
```

### 5. Pre-Review Preparation
```bash
# Prepare feature for review
./scripts/feature-branch.sh prepare <feature-name>
```

### 6. Pull Request Creation
```bash
# Create pull request
./scripts/feature-branch.sh pr <feature-name>
```

### 7. Post-Merge Cleanup
```bash
# Clean up merged branch
./scripts/feature-branch.sh cleanup <feature-name>
```

## Feature Branch Management

### Available Commands
```bash
# Check feature status
./scripts/feature-branch.sh status <feature-name>

# Test feature implementation
./scripts/feature-branch.sh test <feature-name>

# Prepare for code review
./scripts/feature-branch.sh prepare <feature-name>

# Create pull request
./scripts/feature-branch.sh pr <feature-name>

# Clean up after merge
./scripts/feature-branch.sh cleanup <feature-name>
```

### Status Checking
The status command provides:
- Branch commit information
- File change summary
- Documentation status
- Test coverage status
- MCP server changes detected

## Code Standards

### General Guidelines
- Follow existing code style in each MCP server
- Use meaningful variable and function names
- Add comprehensive docstrings/comments
- Implement proper error handling
- Include logging for debugging

### Python MCP Servers
- Follow PEP 8 style guidelines
- Use type hints where applicable
- Include docstrings for all functions/classes
- Use `black` for code formatting
- Pass `flake8` and `mypy` checks

```python
# Example Python MCP server structure
from mcp import server, types
import logging

logger = logging.getLogger(__name__)

@server.tool()
async def example_tool(
    param1: str,
    param2: int = 10
) -> types.TextContent:
    """
    Example tool implementation.
    
    Args:
        param1: Description of parameter
        param2: Optional parameter with default
        
    Returns:
        Text content response
        
    Raises:
        ValueError: When invalid input provided
    """
    try:
        # Implementation logic
        result = process_input(param1, param2)
        return types.TextContent(
            type="text",
            text=str(result)
        )
    except Exception as e:
        logger.error(f"Tool execution failed: {e}")
        raise
```

### Node.js MCP Servers
- Follow project's ESLint configuration
- Use TypeScript for type safety
- Include JSDoc comments
- Use async/await for asynchronous operations
- Implement proper error handling

```typescript
// Example Node.js MCP server structure
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';

interface ExampleToolArgs {
  param1: string;
  param2?: number;
}

/**
 * Example tool implementation
 * @param args Tool arguments
 * @returns Tool response
 */
async function exampleTool(args: ExampleToolArgs): Promise<any> {
  try {
    const { param1, param2 = 10 } = args;
    
    // Implementation logic
    const result = await processInput(param1, param2);
    
    return {
      content: [{
        type: "text",
        text: String(result)
      }]
    };
  } catch (error) {
    console.error('Tool execution failed:', error);
    throw error;
  }
}
```

## Testing Requirements

### Test Types Required
1. **Unit Tests**
   - Test individual functions/methods
   - Mock external dependencies
   - Cover edge cases and error conditions

2. **Integration Tests**
   - Test MCP protocol compliance
   - Test tool interactions
   - Test configuration loading

3. **Security Tests**
   - Input validation testing
   - Authentication/authorization tests
   - Secret handling validation

4. **Performance Tests** (if applicable)
   - Response time measurements
   - Memory usage validation
   - Concurrent request handling

### Test Structure
```
tests/
├── unit/
│   ├── test_tools.py
│   ├── test_config.py
│   └── test_utils.py
├── integration/
│   ├── test_mcp_protocol.py
│   └── test_server_startup.py
├── security/
│   ├── test_input_validation.py
│   └── test_secrets.py
└── performance/
    └── test_response_times.py
```

### Test Coverage Requirements
- Minimum 80% code coverage for new features
- 100% coverage for security-critical functions
- All public APIs must have tests
- Error conditions must be tested

## Review Process

### Code Review Checklist
- [ ] **Functionality**: Feature works as specified
- [ ] **MCP Compliance**: Follows MCP protocol standards
- [ ] **Security**: No security vulnerabilities introduced
- [ ] **Performance**: No significant performance degradation
- [ ] **Testing**: Comprehensive tests included
- [ ] **Documentation**: All documentation updated
- [ ] **Code Quality**: Follows project standards

### Review Types
1. **Security Review**: Focus on security implications
2. **Protocol Review**: Ensure MCP compliance
3. **Code Review**: Check implementation quality
4. **Documentation Review**: Verify documentation completeness

### Approval Requirements
- **Main Branch**: 2 approving reviews required
- **Develop Branch**: 1 approving review required
- **Code Owner**: Must approve if CODEOWNERS affected
- **CI/CD**: All automated checks must pass

## MCP Protocol Compliance

### Required Validations
- [ ] Server implements required MCP methods
- [ ] Tool definitions follow MCP schema
- [ ] Error responses use MCP error format
- [ ] Resource management follows MCP patterns
- [ ] Connection lifecycle handled correctly

### MCP Server Checklist
```python
# Essential MCP server components
class MCPServer:
    def __init__(self):
        # Server initialization
        pass
    
    async def list_tools(self) -> list:
        """Return available tools"""
        pass
    
    async def call_tool(self, name: str, arguments: dict):
        """Execute tool with given arguments"""
        pass
    
    async def list_resources(self) -> list:
        """Return available resources"""
        pass
    
    async def read_resource(self, uri: str):
        """Read specific resource"""
        pass
```

### Protocol Testing
```bash
# Test MCP protocol compliance
python -m mcp_test_client --server-command "python server.py"

# Validate tool schemas
python -m mcp_schema_validator --tools-file tools.json
```

## Security Guidelines

### Input Validation
- Validate all user inputs
- Sanitize data before processing
- Use parameterized queries for databases
- Implement rate limiting where appropriate

### Secret Management
- Never hardcode secrets in source code
- Use environment variables for configuration
- Implement proper secret rotation
- Log security events appropriately

### Error Handling
```python
# Good: Secure error handling
try:
    result = process_user_input(user_data)
except ValidationError as e:
    logger.warning(f"Invalid input received: {type(e).__name__}")
    return {"error": "Invalid input provided"}
except Exception as e:
    logger.error(f"Unexpected error: {type(e).__name__}")
    return {"error": "Internal server error"}

# Bad: Exposes internal details
except Exception as e:
    return {"error": str(e)}  # Could leak sensitive information
```

### Security Testing
```bash
# Run security scans
bandit -r mcp-servers/
safety check
semgrep --config=security mcp-servers/
```

## Documentation Requirements

### Required Documentation
1. **Feature Documentation** (`docs/features/<feature-name>.md`)
   - Feature description
   - Implementation details
   - Usage examples
   - Configuration options

2. **API Documentation**
   - Tool descriptions
   - Parameter specifications
   - Response formats
   - Error codes

3. **Configuration Documentation**
   - Environment variables
   - Configuration files
   - Setup instructions
   - Troubleshooting guide

4. **Changelog Entry** (`docs/changelog/<feature-name>.md`)
   - Summary of changes
   - Impact assessment
   - Migration notes
   - Breaking changes

### Documentation Standards
- Use clear, concise language
- Include practical examples
- Keep documentation up-to-date
- Use consistent formatting
- Include troubleshooting information

### Example Documentation Structure
```markdown
# Tool Name

## Description
Brief description of what the tool does.

## Usage
\`\`\`python
# Example usage
result = await call_tool("tool_name", {
    "param1": "value1",
    "param2": 42
})
\`\`\`

## Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| param1    | str  | Yes      | Description |
| param2    | int  | No       | Description |

## Response Format
\`\`\`json
{
  "content": [{
    "type": "text",
    "text": "Response text"
  }]
}
\`\`\`

## Error Handling
- `InvalidInput`: When parameters are invalid
- `NotFound`: When resource doesn't exist
- `PermissionDenied`: When access is restricted

## Examples
\`\`\`bash
# Command line example
mcp-client call-tool tool_name '{"param1": "test"}'
\`\`\`
```

## Troubleshooting

### Common Issues
1. **Branch Creation Fails**
   - Ensure you're on the main branch
   - Check if branch name already exists
   - Verify git configuration

2. **Tests Fail**
   - Check dependency installation
   - Verify environment variables
   - Review test configuration

3. **MCP Protocol Errors**
   - Validate tool schemas
   - Check error response formats
   - Verify resource handling

4. **CI/CD Failures**
   - Review GitHub Actions logs
   - Check code quality issues
   - Verify security scan results

### Getting Help
- Check existing GitHub issues
- Review MCP protocol documentation
- Ask in team chat channels
- Create detailed bug reports

## Best Practices

### Development
- Start with small, focused features
- Write tests before implementation (TDD)
- Regularly commit and push changes
- Keep feature branches up-to-date with main

### Collaboration
- Communicate changes early
- Request reviews promptly
- Address feedback constructively
- Share knowledge with team

### Quality
- Run tests locally before pushing
- Follow coding standards consistently
- Write clear commit messages
- Keep documentation current

---

This guide is living documentation. Please update it as processes evolve and new best practices emerge.