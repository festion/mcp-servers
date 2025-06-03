# Serena MCP Autonomous Operation Guide

## Core Autonomous Capabilities
Serena is designed to operate independently with minimal user intervention. Use this workflow for maximum efficiency:

### Standard Autonomous Workflow
1. **Project Context**: Always check existing memories first - use `read_memory` only for task-relevant files
2. **System Assessment**: Use coordinated MCP server approach for comprehensive analysis
3. **Implementation**: Develop in c:\working, test thoroughly, deploy via network-mcp
4. **Knowledge Capture**: Update consolidated memories with new patterns/solutions

### MCP Server Coordination Pattern
```
Serena (Orchestrator)
├── network-mcp: Direct HA source access (192.168.1.155)
├── hass-mcp: API operations & monitoring
├── filesystem: Local staging (c:\working)
├── context7: Analysis & documentation
└── search tools: Research as needed
```

### Autonomous Decision Framework
- **Low Impact Changes**: Deploy directly after testing
- **Template Changes**: Always test in staging first (history of cascade failures)
- **Health Monitoring**: Use existing working sensors, don't recreate
- **Error Patterns**: Apply proven solutions from development patterns memory

### Autonomous Troubleshooting Framework
1. **Assessment**: system_overview() → health status → identify scope
2. **Service Operations**: Use HA service calls for safe remediation
3. **Strategic Restart**: Only when service operations insufficient
4. **Validation**: Health metrics confirm improvement
5. **Documentation**: Update memories with new patterns

### Decision Framework for Autonomy
- **Service First**: automation.reload, homeassistant.reload_core_config
- **Health-Driven**: Use sensor.integration_health_percentage for decisions
- **Restart Threshold**: Only restart if health <80% or service ops fail
- **Validation**: Always confirm improvements via health sensors

### Memory Management for Autonomy
- **Essential Memories**: System state, development patterns, architecture
- **Task-Specific**: Read only when relevant to current task
- **Knowledge Update**: Update consolidated memories, not fragmented ones
- **Context Efficiency**: Prefer action over extensive analysis

### Key Autonomy Enablers
1. **Proven Patterns**: Apply established solutions from memories
2. **Health Validation**: Use existing monitoring for status confirmation
3. **Staged Testing**: c:\working → validation → network-mcp deployment
4. **Error Recovery**: Known working sensor references and templates
5. **Documentation**: Update memories with new proven patterns only

## Success Metrics for Autonomous Operation
- Faster task completion without extensive user consultation
- Reduced memory fragmentation and context usage
- Higher success rate on first attempts using proven patterns
- Minimal need for multiple exploratory cycles