# MCP Servers - Technical Architecture & Development Guidelines

## Core Technical Architecture

### MCP Server Base Pattern
All servers in this project follow a consistent architecture based on the Network MCP Server implementation:

```python
class [Name]MCPServer:
    def __init__(self, config: [Name]Config):
        self.config = config
        self.security = SecurityValidator(config.security)
        self.app = Server("[server-name]")
        self._setup_tools()
    
    def _setup_tools(self):
        # Register all MCP tools with proper error handling
        pass
    
    async def run(self):
        # Start the MCP server with proper initialization
        pass
```

### Configuration Architecture
Use Pydantic models for type-safe configuration:

```python
class [Resource]Config(BaseModel):
    # Resource-specific configuration
    
class SecurityConfig(BaseModel):
    allowed_extensions: List[str] = [".txt", ".py", ".json", ".md"]
    blocked_paths: List[str] = []
    max_file_size: str = "100MB"
    allow_write: bool = True
    allow_delete: bool = False

class [Server]MCPConfig(BaseModel):
    [resources]: Dict[str, [Resource]Config]
    security: SecurityConfig = Field(default_factory=SecurityConfig)
```

### Security Validation Pattern
Implement comprehensive security validation:

```python
class SecurityValidator:
    def validate_file_extension(self, filename: str) -> bool
    def validate_path(self, path: str) -> bool  
    def validate_operation(self, operation: str) -> bool
    def validate_file_size(self, size: int) -> bool
```

### Error Handling Pattern
Use custom exception hierarchy:

```python
class [Server]MCPError(Exception): pass
class [Resource]Error([Server]MCPError): pass
class AuthenticationError([Server]MCPError): pass
class ValidationError([Server]MCPError): pass
```

### Async Operations Pattern
For servers interfacing with synchronous APIs:

```python
class Async[Resource]Connection:
    def __init__(self, config, executor=None):
        self.executor = executor or ThreadPoolExecutor(max_workers=4)
    
    async def [operation](self, *args, **kwargs):
        return await asyncio.get_event_loop().run_in_executor(
            self.executor, self._sync_[operation], *args, **kwargs
        )
```

## CLI Implementation Standards

### CLI Structure
Use Click or argparse for consistent CLI interfaces:

```python
def create_sample_config() -> dict:
    """Generate sample configuration"""
    
def validate_config(config_path: str) -> bool:
    """Validate configuration file"""
    
def main():
    """Main server runner"""
    
def cli_main():
    """CLI entry point with argument parsing"""
```

### Entry Points
Configure in pyproject.toml:

```toml
[project.scripts]
"[server-name]-mcp-server" = "[package_name].cli:cli_main"
```

## Testing Standards

### Test Coverage Requirements
- Configuration validation tests
- Security validator tests  
- Core functionality tests
- Integration tests (where possible)
- CLI command tests

### Test Structure
```python
def test_[component]_[scenario]():
    """Test [component] [scenario]"""
    # Arrange
    # Act  
    # Assert
```

## Packaging Standards

### pyproject.toml Configuration
```toml
[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "[server-name]-mcp-server"
version = "0.1.0"
description = "[Description]"
dependencies = [
    "mcp>=1.0.0",
    "pydantic>=2.0.0",
    # Server-specific dependencies
]

[project.scripts]
"[server-name]-mcp-server" = "[package].cli:cli_main"
```

## Documentation Standards

### README.md Structure
1. **Title & Description**: Clear purpose statement
2. **Features**: Bullet list of key capabilities
3. **Installation**: Step-by-step installation instructions
4. **Configuration**: Example configuration with explanations
5. **Usage**: Basic usage examples
6. **Available Tools**: List of all MCP tools with descriptions
7. **Security Considerations**: Security features and best practices
8. **Claude Desktop Integration**: Configuration examples

### Code Documentation
- Class docstrings with purpose and usage
- Method docstrings with parameters and return values
- Complex logic should have inline comments
- Type hints for all public methods

## Integration Patterns

### Claude Desktop Configuration
Standard format:
```json
{
  "mcpServers": {
    "[server-name]": {
      "command": "[path-to-executable]",
      "args": ["run", "--config", "[config-path]"]
    }
  }
}
```

### Configuration File Patterns
- Use JSON for configuration files
- Provide example_config.json with documentation
- Support both relative and absolute paths
- Include security section in all configurations

## Quality Assurance

### Pre-commit Checklist
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Configuration examples tested
- [ ] Security validation implemented
- [ ] Error handling comprehensive
- [ ] Logging properly implemented
- [ ] CLI commands functional

### Performance Considerations
- Use async/await for I/O operations
- Implement proper connection pooling where applicable
- Add configurable timeouts
- Handle resource cleanup properly
- Use lazy loading for expensive resources

This architecture ensures consistency, security, and maintainability across all MCP servers in the project.