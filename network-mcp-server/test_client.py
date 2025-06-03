#!/usr/bin/env python3
"""Simple test client for the Network MCP Server."""

import asyncio
import json
import subprocess
import sys
from typing import Any, Dict

async def test_mcp_server():
    """Test the MCP server by sending some basic commands."""
    
    config_path = "C:\\working\\network-mcp-server\\test_config.json"
    server_cmd = [
        "python", 
        "C:\\working\\network-mcp-server\\run_server.py", 
        "run", 
        "--config", 
        config_path
    ]
    
    print("Starting Network MCP Server...")
    
    # Start the server process
    process = subprocess.Popen(
        server_cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    try:
        # Send initialization request
        init_request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {
                    "name": "test-client",
                    "version": "1.0.0"
                }
            }
        }
        
        print("Sending initialization request...")
        process.stdin.write(json.dumps(init_request) + '\n')
        process.stdin.flush()
        
        # Read response
        response = process.stdout.readline()
        if response:
            print("Received response:")
            try:
                response_data = json.loads(response)
                print(f"   Response ID: {response_data.get('id')}")
                print(f"   Success: {'result' in response_data}")
                if 'result' in response_data:
                    capabilities = response_data['result'].get('capabilities', {})
                    tools = capabilities.get('tools', {})
                    print(f"   Tools capability: {tools}")
                else:
                    print(f"   Error: {response_data.get('error')}")
            except json.JSONDecodeError:
                print(f"   Raw response: {response}")
        
        # Send tools list request
        tools_request = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list"
        }
        
        print("\nSending tools list request...")
        process.stdin.write(json.dumps(tools_request) + '\n')
        process.stdin.flush()
        
        # Read tools response
        tools_response = process.stdout.readline()
        if tools_response:
            print("Received tools response:")
            try:
                tools_data = json.loads(tools_response)
                if 'result' in tools_data:
                    tools = tools_data['result'].get('tools', [])
                    print(f"   Available tools: {len(tools)}")
                    for tool in tools:
                        print(f"     - {tool.get('name')}: {tool.get('description')}")
                else:
                    print(f"   Error: {tools_data.get('error')}")
            except json.JSONDecodeError:
                print(f"   Raw response: {tools_response}")
        
        print("\nMCP Server test completed!")
        
    except Exception as e:
        print(f"Test failed: {e}")
    finally:
        # Terminate the server
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()

if __name__ == "__main__":
    asyncio.run(test_mcp_server())
