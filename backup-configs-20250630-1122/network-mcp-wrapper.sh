#!/bin/bash
cd /home/dev/workspace/mcp-servers/mcp-servers/network-mcp-server
uv run python run_server.py run --config config.json
