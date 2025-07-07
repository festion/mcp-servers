# Troubleshooting Overview

## Quick Diagnostic Commands

### MCP Server Health Check
```bash
# Test all MCP servers
/mcp

# List configured servers
claude mcp list

# Test specific server connectivity
claude mcp test <server-name>
```

### System Status
```bash
# Check service status
systemctl status <service-name>

# View logs
journalctl -fu <service-name>

# Network connectivity
ping <target-host>
curl -I <api-endpoint>
```

## Common Issue Categories

### MCP Server Issues
- **[Server Connection Problems](/troubleshooting/mcp-connection)** - Connectivity and authentication
- **[Tool Access Errors](/troubleshooting/mcp-tools)** - Tool invocation and permissions
- **[Protocol Errors](/troubleshooting/mcp-protocol)** - Communication and format issues

### Home Assistant Problems
- **[Device Connectivity](/troubleshooting/hass-devices)** - Device discovery and communication
- **[Z-Wave Network Issues](/troubleshooting/zwave-network)** - Z-Wave mesh and device problems
- **[BLE Gateway Problems](/troubleshooting/ble-gateway)** - Bluetooth connectivity issues

### Infrastructure Issues
- **[Network Problems](/troubleshooting/network)** - Connectivity and routing
- **[Authentication Failures](/troubleshooting/auth)** - Token and permission issues
- **[Performance Problems](/troubleshooting/performance)** - Slow response and timeouts

## Diagnostic Tools

### MCP Diagnostics
- **MCP Health Monitor** - Server status and connectivity testing
- **Protocol Validator** - Message format and compliance checking
- **Performance Monitor** - Response time and throughput analysis

### System Diagnostics
- **Network Scanner** - Port and service discovery
- **Log Analyzer** - Automated log parsing and error detection
- **Health Dashboard** - Real-time system status monitoring

## Error Resolution Workflows

### Step 1: Identify the Problem
1. Collect error messages and symptoms
2. Identify affected components or services
3. Determine scope and impact
4. Check recent changes or updates

### Step 2: Initial Diagnosis
1. Verify basic connectivity
2. Check service status and logs
3. Test with minimal configuration
4. Isolate the problem area

### Step 3: Detailed Investigation
1. Enable debug logging
2. Use diagnostic tools
3. Check configuration files
4. Review documentation

### Step 4: Resolution
1. Apply known fixes or workarounds
2. Test the solution thoroughly
3. Update documentation
4. Monitor for recurrence

## Common Solutions

### MCP Server Recovery
```bash
# Restart MCP wrapper
./wrapper-script.sh restart

# Clear cache and reconnect
rm -f /tmp/mcp-*.sock
claude mcp reload

# Test with diagnostic token
export TOKEN=test-diagnostic-token
./wrapper-script.sh test
```

### Home Assistant Recovery
```bash
# Restart Home Assistant service
sudo systemctl restart home-assistant

# Check configuration
hass --script check_config

# Reload integrations
# Use Home Assistant UI: Developer Tools > YAML
```

### Network Troubleshooting
```bash
# Test connectivity
ping <target-host>
telnet <host> <port>
nslookup <hostname>

# Check firewall rules
sudo iptables -L
sudo ufw status

# Verify services
sudo netstat -tlnp | grep <port>
```

## Escalation Procedures

### Level 1: Self-Service
- Check this troubleshooting guide
- Review error messages and logs
- Try common solutions
- Test with diagnostic tools

### Level 2: Documentation Review
- Search wiki for specific error patterns
- Review component-specific guides
- Check recent update notes
- Consult configuration examples

### Level 3: Community Support
- Search GitHub issues and discussions
- Check project documentation
- Post detailed problem description
- Include diagnostic information

## Prevention Strategies

### Monitoring
- Set up health checks for critical services
- Configure alerting for failures
- Regular backup of configurations
- Document known issues and solutions

### Maintenance
- Keep systems updated
- Regular configuration reviews
- Test disaster recovery procedures
- Maintain diagnostic tools

### Documentation
- Record resolution steps
- Update troubleshooting guides
- Share lessons learned
- Maintain configuration baselines