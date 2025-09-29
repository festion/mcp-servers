# AprilBrother BLE Gateway Suite - Task Completion Guidelines

## When a Task is Completed

### Required Quality Checks
1. **Code Formatting**: Run Black, Flake8, and isort on all modified Python files
2. **Testing**: Execute pytest on relevant test files  
3. **Configuration Validation**: Ensure YAML files are valid and follow HA conventions
4. **Version Synchronization**: Update both component and add-on versions if needed

### Pre-Commit Checklist
```bash
# 1. Format and lint code
black custom_components/ enhanced_ble_discovery/
flake8 custom_components/ enhanced_ble_discovery/ble_discovery.py
isort custom_components/ enhanced_ble_discovery/

# 2. Run tests
pytest tests/

# 3. Validate YAML files (if yamllint is available)
yamllint *.yaml enhanced_ble_discovery/*.yaml

# 4. Check for obvious issues
grep -r "TODO\|FIXME\|XXX" . --include="*.py"
```

### Version Management
- **Component Version**: Update `custom_components/ab_ble_gateway/manifest.json`
- **Add-on Version**: Update `enhanced_ble_discovery/config.json`
- **Documentation**: Update `CLAUDE.md` with changes and version notes
- **Consistency**: Ensure versions increment logically (semantic versioning)

### Testing Requirements

#### Custom Component Testing
- Unit tests must pass: `pytest tests/`
- Integration testing in development HA instance
- MQTT connectivity validation
- Service call verification (reconnect, clean_failed_entries)

#### Add-on Testing
- Local execution test: `./enhanced_ble_discovery/run.sh`
- Docker build verification: `docker build -t test ./enhanced_ble_discovery`
- API connectivity test with Home Assistant
- Dashboard functionality verification

### Documentation Updates
- **CLAUDE.md**: Add implementation details and version history
- **README.md**: Update if features or installation process changed
- **Code Comments**: Document complex logic or workarounds
- **Changelog**: Maintain version history for users

### Deployment Validation

#### Development Environment
- Test component installation via HACS
- Verify add-on installation through HA add-on store
- Confirm dashboard appears in sidebar
- Test MQTT message processing

#### Production Readiness
- Multi-architecture Docker build support
- Error handling for edge cases
- Graceful degradation when dependencies unavailable
- Logging appropriate for production debugging

## Common Task Types and Specific Guidelines

### Bug Fixes
1. **Reproduce the Issue**: Confirm bug exists and understand root cause
2. **Minimal Fix**: Implement smallest change that resolves the issue
3. **Regression Testing**: Ensure fix doesn't break existing functionality
4. **Documentation**: Update CLAUDE.md with fix details and version info

### Feature Additions
1. **Design Review**: Ensure feature fits architecture and user needs
2. **Implementation**: Follow existing code patterns and conventions
3. **Testing**: Add unit tests for new functionality
4. **Integration**: Verify feature works with existing components
5. **Documentation**: Update user-facing documentation

### Performance Improvements
1. **Benchmarking**: Measure before and after performance
2. **Resource Usage**: Monitor memory and CPU impact
3. **Adaptive Behavior**: Consider different usage scenarios
4. **Backwards Compatibility**: Ensure existing configurations work

### Dashboard/UI Changes
1. **Multiple Complexity Levels**: Test basic, minimal, and combined dashboards
2. **Entity Availability**: Handle missing or unavailable entities gracefully
3. **Template Validation**: Ensure Jinja2 templates are syntactically correct
4. **Mobile Responsiveness**: Test on different screen sizes

## Troubleshooting Common Issues

### Home Assistant Restart Problems
- Check for infinite loops in automation triggers
- Validate service call parameters
- Ensure proper error handling in MQTT message processing
- Test with minimal configuration first

### Template Syntax Errors
- Place complex JavaScript code on single lines
- Use proper Jinja2 escaping for special characters
- Test templates in HA Developer Tools
- Validate entity existence before accessing attributes

### MQTT Integration Issues
- Verify MQTT broker connectivity
- Check topic naming and payload format
- Test with MQTT explorer or command-line tools
- Implement fallback mechanisms for missing data

### Docker/Add-on Problems
- Check container logs for startup errors
- Verify file permissions and volume mappings
- Test with minimal configuration
- Ensure all required dependencies are installed

## Quality Standards

### Code Quality Metrics
- **Flake8 Score**: No errors or warnings
- **Test Coverage**: Aim for >80% coverage on new code
- **Documentation**: All public functions have docstrings
- **Error Handling**: All external calls have proper exception handling

### User Experience Standards
- **Installation**: Should work with standard HACS/add-on installation
- **Configuration**: UI-based setup with validation
- **Feedback**: Clear notifications for user actions
- **Recovery**: Graceful handling of temporary failures

### Maintainability Requirements
- **Code Structure**: Logical organization and separation of concerns
- **Naming**: Clear, descriptive names for variables and functions
- **Dependencies**: Minimal external dependencies
- **Backwards Compatibility**: Maintain API stability where possible

## Release Process

### Pre-Release
1. Update version numbers in both manifest.json and config.json
2. Update CLAUDE.md with comprehensive change documentation
3. Test complete installation process from scratch
4. Verify all dashboard variants work correctly

### Release
1. Create git tag with version number
2. Push to GitHub to trigger any automated builds
3. Test installation from published repository
4. Monitor for user-reported issues

### Post-Release
1. Monitor logs for common error patterns
2. Address critical issues quickly with patch releases
3. Collect user feedback for future improvements
4. Plan next development cycle