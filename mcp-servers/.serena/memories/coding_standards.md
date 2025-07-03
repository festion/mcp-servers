# Coding Standards and Conventions

## Code Style
- **Language**: Python 3.x
- **Naming**: snake_case for functions/variables, PascalCase for classes
- **Type Hints**: Used throughout codebase with dataclasses
- **Docstrings**: Present for classes and public methods
- **Error Handling**: Custom exception hierarchy per server

## Project Structure Patterns
Each MCP server follows consistent structure:
```
server-name/
├── src/server_name/
│   ├── __init__.py
│   ├── server.py          # Main MCP server class
│   ├── config.py          # Configuration dataclasses  
│   ├── cli.py             # Command-line interface
│   ├── exceptions.py      # Custom exceptions
│   └── security.py        # Security validation
├── tests/
├── installer.py
├── test_startup.py
└── requirements.txt
```

## Configuration Standards
- JSON-based configuration files
- Dataclasses for configuration validation
- Environment variable override support
- Sample configuration generation via CLI

## Security Patterns
- SecurityValidator class in each server
- Path traversal protection
- File extension validation
- Operation-specific security checks

## Testing Standards
- Unit tests in `tests/` directory
- Startup validation in `test_startup.py`
- Integration tests for external systems
- Mock-based testing for external dependencies