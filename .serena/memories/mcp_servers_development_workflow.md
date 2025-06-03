# MCP Servers - Development Workflow & Contribution Guidelines

## Development Environment Setup

### File Structure Organization
- **Primary Development**: `C:\git\mcp-servers\` - All production code, GitHub synchronized
- **Temporary/Experimental**: `C:\working\` - Volatile workspace for prototyping and testing only
- **Production Usage**: Install packages from `C:\git\mcp-servers\[server-name]\`

### Prerequisites
- Python 3.11 or higher
- Git for version control (essential for `C:\git\mcp-servers\`)
- Text editor with Python support
- Claude Desktop for testing integrations

### Project Setup
1. Clone/create repository in `C:\git\mcp-servers\`
2. Create virtual environment per server: `python -m venv [server-name]-env`
3. Activate environment: `[server-name]-env\Scripts\activate` (Windows) or `source [server-name]-env/bin/activate` (Unix)
4. Install in development mode: `pip install -e ./[server-name]-mcp-server`

### Version Control Workflow
```bash
cd C:\git\mcp-servers
git init  # If new repository
git remote add origin https://github.com/[username]/mcp-servers.git

# For new servers
git checkout -b feature/[server-name]-mcp-server
# Development work
git add .
git commit -m "Add [server-name] MCP server implementation"
git push origin feature/[server-name]-mcp-server
```

## Creating New MCP Servers

### Step 1: Project Structure in C:\git\mcp-servers\
```bash
cd C:\git\mcp-servers
mkdir [purpose]-mcp-server
cd [purpose]-mcp-server

# Create directory structure
mkdir -p src/[package_name]_mcp
mkdir tests
```

### Step 2: Core Files
Create these essential files in `C:\git\mcp-servers\[server-name]\`:
- `pyproject.toml` - Python packaging configuration
- `src/[package_name]_mcp/__init__.py` - Package initialization
- `src/[package_name]_mcp/server.py` - Main MCP server implementation
- `src/[package_name]_mcp/config.py` - Configuration models
- `src/[package_name]_mcp/cli.py` - Command-line interface
- `src/[package_name]_mcp/exceptions.py` - Custom exceptions
- `README.md` - Documentation
- `example_config.json` - Sample configuration

### Step 3: Implementation Checklist
- [ ] Define configuration models using Pydantic
- [ ] Implement security validation
- [ ] Create main server class inheriting MCP patterns
- [ ] Implement all required MCP tools
- [ ] Add proper error handling and logging
- [ ] Create CLI interface with standard commands
- [ ] Write comprehensive tests
- [ ] Document all functionality
- [ ] Commit to Git regularly

### Step 4: Testing Strategy
1. **Unit Tests**: Test individual components
2. **Integration Tests**: Test server initialization and tool registration
3. **Configuration Tests**: Validate configuration loading and validation
4. **Security Tests**: Verify security controls work properly
5. **CLI Tests**: Test command-line interface functionality

### Step 5: Documentation Requirements
- [ ] README.md with installation and usage instructions
- [ ] Configuration documentation with examples
- [ ] Claude Desktop integration guide
- [ ] Security considerations documented
- [ ] Troubleshooting section included

## Development Best Practices

### Working with C:\working\ vs C:\git\mcp-servers\
- **Prototyping**: Use `C:\working\` for initial experiments and proof-of-concepts
- **Development**: Move to `C:\git\mcp-servers\` once ready for serious development
- **Migration**: Copy successful prototypes from `C:\working\` to `C:\git\mcp-servers\` and clean up
- **Never rely on `C:\working\` for long-term storage**

### Installation Paths
For production use, always install from the Git repository:
```bash
# Correct installation from Git repository
pip install -e C:\git\mcp-servers\[server-name]-mcp-server

# NOT from working directory (temporary only)
# pip install -e C:\working\[server-name]-mcp-server
```

### Claude Desktop Configuration
Use Git repository paths for production Claude Desktop configuration:
```json
{
  "mcpServers": {
    "[server-name]": {
      "command": "C:\\Users\\[User]\\AppData\\Roaming\\Python\\Python313\\Scripts\\[server-name]-mcp-server.exe",
      "args": ["run", "--config", "C:\\git\\mcp-servers\\[server-name]-mcp-server\\config.json"]
    }
  }
}
```

## Code Standards

### Python Style
- Follow PEP 8 style guidelines
- Use Black formatter with 88-character line length
- Use isort for import sorting
- Use mypy for type checking

### Naming Conventions
- Classes: PascalCase (`NetworkMCPServer`)
- Functions/methods: snake_case (`validate_config`)
- Constants: UPPER_SNAKE_CASE (`MAX_FILE_SIZE`)
- Files: snake_case (`network_mcp_server.py`)
- Packages: snake_case with underscores (`network_mcp`)

### Type Hints
- Use type hints for all public methods
- Use appropriate generic types (List, Dict, Optional)
- Use Union types when necessary
- Document complex type relationships

## Testing Standards

### Test Organization
```
tests/
├── test_config.py          # Configuration tests
├── test_security.py        # Security validation tests
├── test_server.py          # Main server tests
├── test_cli.py            # CLI tests
└── test_integration.py    # Integration tests
```

### Test Patterns
```python
import pytest
from [package_name]_mcp.config import [Config]
from [package_name]_mcp.exceptions import [Exception]

class Test[Component]:
    def test_[scenario]_[expected_outcome](self):
        # Arrange
        # Act
        # Assert
        
    def test_[scenario]_raises_[exception](self):
        with pytest.raises([Exception]):
            # Code that should raise exception
```

## Quality Assurance

### Pre-commit Checks (in C:\git\mcp-servers\)
Run these checks before committing:
```bash
# Code formatting
black src/ tests/
isort src/ tests/

# Type checking
mypy src/

# Linting
flake8 src/ tests/

# Testing
pytest tests/ -v --cov=src/

# Git checks
git status
git diff --staged
```

### Integration Testing
1. **Manual Testing**: Test with actual Claude Desktop
2. **Configuration Validation**: Test with various configurations
3. **Error Scenarios**: Test network failures, authentication errors, etc.
4. **Performance Testing**: Test with large files/operations where applicable

## Release Process

### Version Management
- Use semantic versioning (major.minor.patch)
- Update version in `pyproject.toml`
- Update `__version__` in `__init__.py`
- Document changes in release notes
- Tag releases in Git

### Release Checklist
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Version numbers updated
- [ ] Example configurations tested
- [ ] Claude Desktop integration verified
- [ ] Security review completed
- [ ] Git repository clean and committed
- [ ] GitHub repository synchronized

## Debugging and Troubleshooting

### Common Issues
1. **MCP Tool Registration**: Ensure all tools are properly registered
2. **Configuration Loading**: Verify JSON syntax and required fields
3. **Security Validation**: Check file extensions and path restrictions
4. **Claude Desktop Integration**: Verify executable paths and arguments
5. **Path Issues**: Ensure using `C:\git\mcp-servers\` paths, not `C:\working\`

### Debugging Techniques
- Use verbose logging during development
- Test CLI commands independently
- Validate configurations with `validate-config` command
- Use Claude Desktop developer tools for MCP debugging

### Log Levels
- **DEBUG**: Detailed operational information
- **INFO**: General operational information
- **WARNING**: Potentially harmful situations
- **ERROR**: Error events that might allow application to continue
- **CRITICAL**: Serious error events

## Contribution Guidelines

### Pull Request Process
1. Create feature branch from main in `C:\git\mcp-servers\`
2. Implement changes following standards
3. Add/update tests for new functionality
4. Update documentation
5. Run full test suite
6. Commit with clear messages
7. Push to GitHub and submit pull request with clear description

### Code Review Criteria
- Follows established patterns and architecture
- Has comprehensive test coverage
- Documentation is clear and complete
- Security considerations addressed
- Performance implications considered
- Error handling is robust
- Uses proper file organization (Git vs working directories)

This workflow ensures consistent, high-quality MCP servers that integrate seamlessly with Claude Desktop while maintaining proper version control and backup through GitHub.