#!/bin/bash

# Simple HTTP server to host community scripts
# This serves the scripts locally for testing the 1-line deployment

PORT=8080
SCRIPT_DIR="/home/dev/workspace/community-scripts-fork"

echo "🚀 Starting Community Scripts HTTP Server..."
echo "📂 Serving directory: $SCRIPT_DIR"
echo "🌐 Server URL: http://192.168.1.239:$PORT"
echo "📜 WikiJS Integration Script: http://192.168.1.239:$PORT/ct/wikijs-integration.sh"
echo ""
echo "One-line deployment command:"
echo "bash -c \"\$(curl -fsSL http://192.168.1.239:$PORT/ct/wikijs-integration.sh)\""
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

cd "$SCRIPT_DIR"
python3 -m http.server $PORT --bind 0.0.0.0