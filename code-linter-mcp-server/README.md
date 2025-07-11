# Code Linter MCP Server

A comprehensive Model Context Protocol (MCP) server that provides code linting and validation for multiple programming languages. This server integrates with Serena's workflow to ensure all code meets quality standards before being saved.

## Features

- **Multi-Language Support**: Python, Go, JavaScript, TypeScript, YAML, JSON, and more
- **Comprehensive Linting**: Supports popular linters for each language (flake8, black, mypy, eslint, gofmt, etc.)
- **Serena Integration**: Blocks code saves when quality standards aren't met
- **Security Validation**: File type restrictions and content security checks
- **Configurable Rules**: Customizable linting rules and severity levels
- **Concurrent Execution**: Parallel linter execution for improved performance
- **Result Caching**: Caches linting results to improve performance
- **Detailed Reporting**: Structured error and warning reports with line numbers

## Installation

```bash
# Install in development mode
pip install -e ./code-linter-mcp-server

# Or install with linter dependencies
pip install -e "./code-linter-mcp-server[linters]"
```

## External Linter Dependencies

This server requires external linting tools to be installed separately:

### Python Linters
```bash
pip install flake8 black mypy pylint
```

### Go Linters
```bash
# gofmt and go vet are included with Go
go install golang.org/x/lint/golint@latest
go install honnef.co/go/tools/cmd/staticcheck@latest
```

### JavaScript/TypeScript Linters
```bash
npm install -g eslint @typescript-eslint/parser typescript prettier
```

### YAML/JSON Linters
```bash
pip install yamllint
npm install -g jsonlint
```

## Configuration

Create a configuration file using the CLI:

```bash
code-linter-mcp-server create-config --output config.json
```

### Example Configuration

```json
{
  "languages": {
    "python": {
      "extensions": [".py", ".pyw"],
      "linters": {
        "flake8": {
          "enabled": true,
          "args": ["--max-line-length=88"],
          "timeout": 30
        },
        "black": {
          "enabled": true,
          "args": ["--check", "--diff"]
        }
      },
      "default_linters": ["flake8", "black"]
    }
  },
  "serena_integration": {
    "block_on_error": true,
    "block_on_warning": false,
    "integration_mode": "strict"
  }
}
```

## Usage

### Start the MCP Server
```bash
code-linter-mcp-server run --config config.json
```

### Validate Configuration
```bash
code-linter-mcp-server validate-config config.json
```

### Check Linter Availability
```bash
# The server provides a tool to check if required linters are installed
```

## Available MCP Tools

1. **`lint_file`** - Lint a file with appropriate linters for its language
2. **`lint_content`** - Lint code content directly without a file
3. **`validate_syntax`** - Quick syntax validation for code content
4. **`get_supported_languages`** - Get list of supported languages and linters
5. **`check_linter_availability`** - Check if required linters are installed
6. **`serena_pre_save_validation`** - Validate code before Serena saves it

## Serena Integration

The server includes a special tool `serena_pre_save_validation` that integrates with Serena's workflow:

- **Automatic Validation**: All code is validated before being saved
- **Blocking Behavior**: Configurable blocking on errors/warnings
- **Security Checks**: Content is scanned for suspicious patterns
- **Real-time Feedback**: Immediate feedback on code quality issues

### Integration Modes

- **`strict`**: Block saves on any linting errors
- **`permissive`**: Allow saves but show warnings
- **`advisory`**: Show linting results without blocking

## Claude Desktop Integration

Add to your Claude Desktop configuration:

```json
{
  "mcpServers": {
    "code-linter": {
      "command": "code-linter-mcp-server",
      "args": ["run", "--config", "path/to/config.json"]
    }
  }
}
```

## Security Considerations

- **File Type Restrictions**: Only allowed file extensions are processed
- **Content Scanning**: Code content is scanned for suspicious patterns
- **Sandbox Mode**: Linters run in restricted environment
- **Size Limits**: Configurable file size limits
- **Network Controls**: Option to disable network access for linters

## Supported Languages and Linters

| Language   | Extensions        | Supported Linters                    |
|------------|------------------|--------------------------------------|
| Python     | .py, .pyw        | flake8, black, mypy, pylint         |
| Go         | .go              | gofmt, govet, golint, staticcheck    |
| JavaScript | .js, .jsx        | eslint, prettier                     |
| TypeScript | .ts, .tsx        | eslint, tsc, prettier                |
| YAML       | .yaml, .yml      | yamllint                             |
| JSON       | .json            | jsonlint                             |

## Performance Features

- **Concurrent Execution**: Multiple linters run in parallel
- **Result Caching**: Results cached for improved performance
- **Timeout Controls**: Configurable timeouts prevent hanging
- **Selective Linting**: Choose specific linters to run

## Error Handling

The server provides detailed error reporting including:
- Line numbers and column positions
- Error severity levels (error/warning)
- Linter-specific rule violations
- Execution timeouts and failures

## Development

### Running Tests
```bash
pytest tests/ -v --cov=src/
```

### Code Quality
```bash
black src/ tests/
flake8 src/ tests/
mypy src/
```

## Contributing

This server follows the MCP Servers project standards. See the project documentation for contribution guidelines.

## License

MIT License - see LICENSE file for details.
