#!/usr/bin/env python3
"""
Proxmox MCP Server runner script.
"""

import sys
import os
from pathlib import Path

# Add src directory to Python path
current_dir = Path(__file__).parent
src_dir = current_dir / "src"
sys.path.insert(0, str(src_dir))

if __name__ == "__main__":
    from proxmox_mcp.cli import main
    main()