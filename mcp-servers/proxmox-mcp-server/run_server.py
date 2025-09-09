#!/usr/bin/env python3
"""
Run script for Proxmox MCP Server.
This script provides a simple way to start the Proxmox MCP server.
"""

import sys
import os
from pathlib import Path

# Add the source directory to Python path
current_dir = Path(__file__).parent
src_dir = current_dir / "src"
sys.path.insert(0, str(src_dir))

if __name__ == "__main__":
    # Import inside main to avoid relative import issues
    from proxmox_mcp.cli import cli_main
    
    # Check if config file exists
    config_file = current_dir / "proxmox_mcp_config.json"
    
    if len(sys.argv) == 1:
        # No arguments provided, try to run with default config
        if config_file.exists():
            print(f"Starting Proxmox MCP Server with config: {config_file}")
            sys.argv.extend(["run", str(config_file)])
        else:
            print("No configuration file found. Available commands:")
            print("  python run_server.py create-config    # Create sample configuration")
            print("  python run_server.py run <config>     # Run server with config")
            print("  python run_server.py info             # Show server information")
            sys.exit(1)
    
    cli_main()