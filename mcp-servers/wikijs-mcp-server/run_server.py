#!/usr/bin/env python3
"""Direct server runner for wikijs MCP server."""

import sys
import asyncio
from pathlib import Path

# Add the src directory to Python path
current_dir = Path(__file__).parent
src_dir = current_dir / "src"
sys.path.insert(0, str(src_dir))

if __name__ == "__main__":
    from wikijs_mcp.server import main
    # Pass the config file path from the same directory as this script
    sys.argv = [sys.argv[0], str(current_dir / "wikijs_mcp_config.json")]
    asyncio.run(main())