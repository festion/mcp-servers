# MCP Server Feature: [Feature Name]

## Description
Brief description of the MCP server changes and their purpose.

## Type of Change
- [ ] New MCP server
- [ ] MCP server enhancement (non-breaking change which adds functionality)
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Code refactoring
- [ ] Performance improvement
- [ ] Security enhancement

## Related Issues
Closes #[issue number]
Relates to #[issue number]

## Implementation Details
### Changes Made
- [ ] List of specific MCP server changes
- [ ] Protocol modifications (if any)
- [ ] Tool additions/modifications
- [ ] Configuration changes (if any)
- [ ] Wrapper script updates (if any)

### MCP Server Architecture
- Explain any significant architectural decisions
- Justify the approach taken for MCP protocol implementation

## MCP Protocol Compliance
- [ ] MCP protocol version compatibility verified
- [ ] Resource management implemented correctly
- [ ] Error handling follows MCP standards
- [ ] Tool definitions comply with MCP schema
- [ ] Server capabilities properly declared

## Testing
### Test Coverage
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] MCP server functionality tests added
- [ ] Protocol compliance tests completed
- [ ] Manual testing completed

### Test Results
```bash
# Paste test results here
./scripts/feature-branch.sh test <feature-name>
```

### Testing Instructions
1. Steps to test the MCP server manually
2. Expected behavior and tool responses
3. Test data or setup required
4. MCP client testing procedures

## Security Considerations
- [ ] Security review completed
- [ ] No hardcoded secrets or credentials
- [ ] Input validation implemented for all tools
- [ ] Authorization checks implemented
- [ ] Audit logging added (if applicable)
- [ ] MCP transport security considered

## Performance Impact
- [ ] Performance testing completed
- [ ] No significant performance degradation
- [ ] Resource usage optimization (if applicable)
- [ ] Memory management considerations
- [ ] Connection handling optimization

## Documentation
- [ ] MCP server documentation updated
- [ ] Tool documentation updated
- [ ] Configuration documentation updated
- [ ] README updated (if applicable)
- [ ] Changelog entry added
- [ ] Wrapper script documentation updated (if applicable)

## Deployment
### Deployment Considerations
- [ ] MCP server configuration updated
- [ ] Wrapper scripts updated (if needed)
- [ ] Environment variables documented
- [ ] Dependencies documented
- [ ] Installation instructions updated

### Configuration Changes
- [ ] Claude Desktop configuration updates documented
- [ ] MCP server registry updates needed
- [ ] Environment-specific configurations noted

### Rollback Plan
- [ ] Rollback procedure documented
- [ ] Configuration rollback plan
- [ ] Dependency rollback considerations

## MCP Server Checklist
- [ ] Server follows MCP protocol specification
- [ ] All tools properly implement input/output schemas
- [ ] Error responses follow MCP error format
- [ ] Server handles connection lifecycle correctly
- [ ] Resource cleanup implemented
- [ ] Logging follows project standards
- [ ] Code follows project coding standards

## Integration Testing
- [ ] Tested with Claude Desktop
- [ ] Tested with MCP client tools
- [ ] Wrapper script integration verified
- [ ] Configuration validation completed
- [ ] Cross-platform compatibility verified (if applicable)

## Screenshots/Examples (if applicable)
<!-- Add examples of tool usage, configuration snippets, or UI changes -->

## Additional Notes
<!-- Any additional information that reviewers should know -->

## Review Focus Areas
Please pay special attention to:
- [ ] MCP protocol compliance
- [ ] Security implications
- [ ] Performance impact
- [ ] Error handling
- [ ] Test coverage
- [ ] Documentation completeness
- [ ] Integration with existing MCP infrastructure

---

**Review Assignment:**
- @reviewer1 - MCP protocol review
- @reviewer2 - Security review
- @reviewer3 - Code review
- @reviewer4 - Testing review