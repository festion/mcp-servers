#!/bin/bash
cd /home/dev/workspace/mcp-servers/network-mcp-server
PYTHONPATH=./src python3 run_server.py run --config network_mcp_config.json
