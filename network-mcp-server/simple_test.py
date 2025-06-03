#!/usr/bin/env python3
"""Direct test of the Network MCP Server."""

import json
import subprocess
import sys
import time

def test_mcp_server():
    """Test the MCP server with a simple message."""
    
    config_path = "C:\\working\\network-mcp-server\\test_config.json"
    server_cmd = [
        "C:\\Users\\Jeremy\\AppData\\Roaming\\Python\\Python313\\Scripts\\network-mcp-server.exe",
        "run", 
        "--config", 
        config_path
    ]
    
    print("Starting Network MCP Server...")
    
    try:
        # Start the server process
        process = subprocess.Popen(
            server_cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=0  # Unbuffered
        )
        
        # Wait a moment for startup
        time.sleep(2)
        
        # Check if process is still running
        if process.poll() is not None:
            # Process ended, check for errors
            _, stderr = process.communicate()
            print(f"Server exited with error: {stderr}")
            return False
        
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
        
        print("Sending initialize request...")
        request_str = json.dumps(init_request) + '\n'
        process.stdin.write(request_str)
        process.stdin.flush()
        
        # Try to read response with timeout
        print("Waiting for response...")
        time.sleep(1)
        
        # Check if there's any output
        if process.stdout.readable():
            try:
                # Try non-blocking read
                response = process.stdout.readline()
                if response:
                    print(f"Got response: {response.strip()}")
                    try:
                        response_data = json.loads(response)
                        if 'result' in response_data:
                            print("SUCCESS: Server responded to initialize!")
                            capabilities = response_data['result'].get('capabilities', {})
                            print(f"Server capabilities: {capabilities}")
                            return True
                        else:
                            print(f"Server error: {response_data.get('error')}")
                    except json.JSONDecodeError:
                        print(f"Invalid JSON response: {response}")
                else:
                    print("No response received")
            except Exception as e:
                print(f"Error reading response: {e}")
        
        return False
        
    except Exception as e:
        print(f"Test failed: {e}")
        return False
    finally:
        # Clean up
        try:
            if 'process' in locals():
                process.terminate()
                process.wait(timeout=2)
        except:
            try:
                process.kill()
            except:
                pass

if __name__ == "__main__":
    success = test_mcp_server()
    print(f"\nTest result: {'PASS' if success else 'FAIL'}")
    sys.exit(0 if success else 1)
