# Suggested Commands for MCP Servers Development

## Testing Commands
```bash
# Test individual server startup
cd [server-name] && python test_startup.py

# Run all tests for a server
cd [server-name] && python -m pytest tests/

# Test configuration validation
cd [server-name] && python -m [server_module].cli validate-config config.json
```

## Installation Commands
```bash
# Install all servers globally
python install-all-mcp-servers.py

# Install single server globally  
python global-mcp-installer.py install [server-name]

# Install server locally
cd [server-name] && python installer.py
```

## Development Commands
```bash
# Run server in development mode
cd [server-name] && python run_server.py

# Create sample configuration
cd [server-name] && python -m [server_module].cli create-config

# Validate existing configuration
cd [server-name] && python -m [server_module].cli validate-config config.json
```

## Debugging Commands  
```bash
# Check server status
python global-mcp-installer.py status

# Test MCP protocol connectivity
cd [server-name] && python simple_test.py

# View server logs (if logging configured)
tail -f [server-name]/logs/*.log
```

## System Commands (Linux)
- `ls` - List directory contents
- `cd` - Change directory
- `grep` - Search text patterns
- `find` - Find files by name/pattern
- `git` - Version control operations
- `python` - Python interpreter
- `pip` - Python package installer