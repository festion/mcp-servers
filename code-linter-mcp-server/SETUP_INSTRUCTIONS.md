# Setup Instructions for Code Linter MCP Server

## Current Status
✅ **Server Created**: Code Linter MCP Server is successfully implemented
✅ **Configuration Valid**: Basic configuration is working
⚠️ **Missing Linters**: Some external linters need to be installed

## Complete the Setup

### 1. Install Python Linters (if not already installed)
```bash
pip install flake8 black mypy pylint yamllint
```

### 2. Install Node.js Linters (for JavaScript/TypeScript support)
```bash
npm install -g eslint jsonlint typescript @typescript-eslint/parser prettier
```

### 3. Install Go Linters (if you have Go installed)
```bash
# gofmt and go vet come with Go
go install golang.org/x/lint/golint@latest
go install honnef.co/go/tools/cmd/staticcheck@latest
```

### 4. Test the Server
```bash
# Test linting functionality
code-linter-mcp-server validate-config config.json

# Test with a sample file
flake8 test_sample.py  # Should show linting errors
```

### 5. Add to Claude Desktop
Add this to your Claude Desktop configuration:
```json
{
  "mcpServers": {
    "code-linter": {
      "command": "code-linter-mcp-server",
      "args": ["run", "--config", "C:\\git\\mcp-servers\\code-linter-mcp-server\\config.json"]
    }
  }
}
```

## Integration with Serena

The server provides the critical `serena_pre_save_validation` tool that:
- **Blocks file saves** when code has linting errors (configurable)
- **Validates security** of code content
- **Provides detailed feedback** on what needs to be fixed

### Configure Blocking Behavior
Edit `config.json`:
```json
{
  "serena_integration": {
    "block_on_error": true,      // Blocks saves on linting errors
    "block_on_warning": false,   // Allow saves with warnings  
    "integration_mode": "strict" // Enforcement level
  }
}
```

## Testing the Linter

The `test_sample.py` file has intentional linting issues:
- Missing spaces around operators
- Missing newline at end of file

Run flake8 on it to see the linting in action:
```bash
flake8 test_sample.py
```

Expected output:
```
test_sample.py:3:7: E225 missing whitespace around operator
test_sample.py:6:1: W292 no newline at end of file
```

## Usage Examples

Once integrated with Claude Desktop, you can:
- "Lint this Python file for errors"
- "Check if all my linters are installed" 
- "Validate this code before saving"
- "Show me supported programming languages"

## Performance Tips

- Adjust `concurrent_linters` in config.json based on your system
- Enable `cache_results` to speed up repeated operations
- Set appropriate timeouts for slower linters

The server is now ready for use and will enforce code quality standards across your development workflow!
