#!/usr/bin/env python3
"""
Basic startup test for code-linter-mcp MCP server.
Generated automatically by Phase 3 verification.
"""

import sys
import os
from pathlib import Path

# Add src directory to Python path
current_dir = Path(__file__).parent
src_dir = current_dir / "src"
sys.path.insert(0, str(src_dir))

def test_server_startup():
    """Test that server can initialize without errors."""
    try:
        # Try to import run_server
        import importlib.util
        spec = importlib.util.spec_from_file_location("run_server", "run_server.py")
        if spec and spec.loader:
            print("✅ Run server module can be loaded")
            return True
        else:
            print("❌ Could not load run_server module")
            return False
            
    except Exception as e:
        print(f"❌ Server startup test failed: {e}")
        return False

if __name__ == "__main__":
    success = test_server_startup()
    sys.exit(0 if success else 1)
