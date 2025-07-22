# Task Completion Checklist

## After Making Code Changes

### 1. Run Tests
```bash
# Test server startup
python test_startup.py

# Run unit tests  
python -m pytest tests/ -v

# Test configuration validation
python -m [module].cli validate-config config.json
```

### 2. Validate Configuration
```bash
# Check configuration loading
python -m [module].cli create-config
python -m [module].cli validate-config [config-file]
```

### 3. Security Validation
- Ensure SecurityValidator tests pass
- Check for path traversal vulnerabilities
- Validate file extension restrictions
- Test operation-specific security controls

### 4. Integration Testing
```bash
# Test MCP protocol compliance
python simple_test.py

# Test with global installer
python global-mcp-installer.py status
```

### 5. Documentation
- Update docstrings for modified methods
- Update configuration templates if schema changed
- Update CLI help text if commands changed

### 6. Code Quality
- Follow existing naming conventions
- Maintain consistent error handling patterns
- Use appropriate dataclass validation
- Ensure logging is properly configured

## Pre-Deployment
- All startup tests pass
- Configuration validation works
- Security tests pass
- Integration tests with MCP protocol succeed