# Installation and Directory Structure

## Key Directory Structure
- **`C:\git\`** - Source code repositories (development)
- **`C:\my-tools\`** - Installation directory for MCP servers and tools
- **`C:\working\`** - Temporary/experimental workspace

## MCP Server Installation Pattern
- **Development**: Work in `C:\git\mcp-servers\[server-name]\`
- **Installation**: Install to `C:\my-tools\[server-name]\` or `C:\my-tools\`
- **Configuration**: MCP servers should be configured to run from `C:\my-tools\` installations

## Important Notes
- The user has already installed the code-linter MCP server to `C:\my-tools\`
- Don't assume installation is needed - check what's already in `C:\my-tools\` first
- The error `/mnt/c/my-tools/linter ENOENT` suggests the MCP configuration is using WSL paths instead of Windows paths
- The correct path should be `C:\my-tools\linter` or similar Windows path

## MCP Configuration Pattern
Claude Desktop MCP configurations should point to executables in `C:\my-tools\`, not in the source repository directories in `C:\git\`.