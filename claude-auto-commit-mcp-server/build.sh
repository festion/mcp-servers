#!/bin/bash

# Claude Auto-Commit MCP Server Build Script

set -e

echo "Building Claude Auto-Commit MCP Server..."

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "Error: package.json not found. Run this script from the project root."
    exit 1
fi

# Install dependencies
echo "Installing dependencies..."
npm install

# Build the TypeScript code
echo "Building TypeScript..."
npm run build

# Make the built index.js executable
chmod +x dist/index.js

echo "Build completed successfully!"
echo ""
echo "You can now use the server with:"
echo "  ./dist/index.js"
echo ""
echo "Or install it globally with:"
echo "  npm install -g ."