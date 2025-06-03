#!/usr/bin/env python3
"""Test script to verify the server can import and initialize correctly."""

import sys
import os
import asyncio

# Add the src directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

try:
    from code_linter_mcp.server import CodeLinterMCPServer, load_config
    print("[OK] Successfully imported CodeLinterMCPServer")
    
    # Try to load the config
    config_path = os.path.join(os.path.dirname(__file__), 'config.json')
    config = load_config(config_path)
    print("[OK] Successfully loaded configuration")
    
    # Try to initialize the server
    server = CodeLinterMCPServer(config)
    print("[OK] Successfully initialized server")
    
    print("[SUCCESS] All tests passed - server should start correctly")
    
except Exception as e:
    print(f"[ERROR] Test failed: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
