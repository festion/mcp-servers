# Claude Auto-Commit Troubleshooting Guide

## Common Issues

### Authentication Problems

**Issue: Invalid or expired token**
- Check token validity
- Verify token permissions
- Regenerate token if needed

**Issue: Insufficient permissions**
- Ensure token has repository access
- Check organization settings
- Verify branch permissions

### Repository Issues

**Issue: Repository not found**
- Verify repository name and owner
- Check access permissions
- Ensure repository exists

**Issue: No changes detected**
- Run git status to check for changes
- Verify files are modified
- Check if changes are already committed

### Rate Limiting

**Issue: GitHub API rate limit exceeded**
- Check current rate limit status
- Wait for rate limit reset
- Use authenticated requests
- Implement rate limiting in your application

**Issue: Claude API rate limit exceeded**
- Monitor API usage
- Implement request throttling
- Consider upgrading API plan
- Add retry logic with backoff

### Generation Issues

**Issue: Poor commit message quality**
- Provide more context in changes
- Use specific file patterns
- Try different analysis depths
- Review and refine templates

**Issue: Template not found**
- Verify template name spelling
- Check template configuration
- Use built-in templates as fallback
- Review template syntax

### Performance Issues

**Issue: Slow commit generation**
- Reduce analysis scope
- Limit file count
- Use caching
- Optimize network connectivity

**Issue: High memory usage**
- Limit concurrent operations
- Reduce context lines
- Clear cache periodically
- Monitor resource usage

## Diagnostic Steps

### 1. Check Service Status

Verify the MCP server is running and responding:
```bash
curl http://localhost:3000/health
```

### 2. Test Authentication

Validate credentials:
```bash
mcp call github get_user
```

### 3. Verify Repository Access

Test repository connectivity:
```bash
mcp call github get_repository --data '{"owner": "test", "repo": "test"}'
```

### 4. Check Git Status

Ensure there are changes to commit:
```bash
git status
git diff --name-only
```

### 5. Test Basic Generation

Try minimal commit generation:
```bash
mcp call github generate_commit_message --data '{"owner": "test", "repo": "test"}'
```

## Error Codes

### Authentication Errors
- `AUTH_001`: Invalid token format
- `AUTH_002`: Token expired
- `AUTH_003`: Insufficient permissions
- `AUTH_004`: Token revoked

### Repository Errors
- `REPO_001`: Repository not found
- `REPO_002`: Access denied
- `REPO_003`: No changes detected
- `REPO_004`: Branch not found

### API Errors
- `API_001`: Rate limit exceeded
- `API_002`: Service unavailable
- `API_003`: Request timeout
- `API_004`: Invalid response format

### Generation Errors
- `GEN_001`: Analysis failed
- `GEN_002`: Template error
- `GEN_003`: Language not supported
- `GEN_004`: Content too large

## Solutions by Error Type

### Authentication Solutions

1. **Token Issues**
   - Regenerate personal access token
   - Update environment variables
   - Restart MCP server

2. **Permission Issues**
   - Review token scopes
   - Check organization policies
   - Contact repository administrator

### Repository Solutions

1. **Access Issues**
   - Verify repository URL
   - Check spelling of owner/repo names
   - Ensure repository is not private

2. **Change Detection**
   - Stage files before commit generation
   - Check file modifications
   - Verify working directory

### API Solutions

1. **Rate Limiting**
   - Implement exponential backoff
   - Use multiple tokens for high volume
   - Cache responses when possible

2. **Service Issues**
   - Check API status pages
   - Retry failed requests
   - Implement circuit breakers

### Performance Solutions

1. **Speed Optimization**
   - Use smaller file sets
   - Reduce analysis depth
   - Enable caching

2. **Resource Management**
   - Monitor memory usage
   - Implement request queuing
   - Set appropriate timeouts

## Monitoring and Debugging

### Log Analysis

Check logs for error patterns:
- Authentication failures
- Rate limit warnings
- Template errors
- API timeouts

### Metrics Monitoring

Track key metrics:
- Request success rate
- Response times
- Error frequencies
- Cache hit rates

### Health Checks

Implement regular health checks:
- Service availability
- API connectivity
- Resource utilization
- Error rates

## Prevention Best Practices

### Reliable Operations

1. **Error Handling**
   - Implement comprehensive error catching
   - Add retry logic for transient failures
   - Provide meaningful error messages

2. **Resource Management**
   - Set appropriate timeouts
   - Monitor resource usage
   - Implement rate limiting

3. **Configuration**
   - Validate configuration on startup
   - Use environment variables for secrets
   - Implement configuration reloading

### Monitoring Setup

1. **Alerting**
   - Set up error rate alerts
   - Monitor API rate limits
   - Track performance metrics

2. **Logging**
   - Use structured logging
   - Include correlation IDs
   - Log at appropriate levels

This troubleshooting guide helps identify and resolve common issues with the Claude auto-commit feature.