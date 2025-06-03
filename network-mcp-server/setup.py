#!/usr/bin/env python3
"""Setup script for Network MCP Server."""

import subprocess
import sys
import os
from pathlib import Path


def run_command(cmd, description):
    """Run a command and handle errors."""
    print(f"🔄 {description}...")
    try:
        result = subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
        print(f"✅ {description} completed")
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"❌ {description} failed:")
        print(f"Error: {e.stderr}")
        return None


def check_python_version():
    """Check if Python version is 3.10+."""
    version = sys.version_info
    if version.major < 3 or (version.major == 3 and version.minor < 10):
        print(f"❌ Python 3.10+ required, found {version.major}.{version.minor}")
        return False
    print(f"✅ Python {version.major}.{version.minor}.{version.micro} is compatible")
    return True


def main():
    """Main setup process."""
    print("🚀 Network MCP Server Setup")
    print("=" * 50)
    
    # Check Python version
    if not check_python_version():
        sys.exit(1)
    
    # Install in development mode
    if run_command("pip install -e .", "Installing Network MCP Server in development mode"):
        print("✅ Installation successful!")
    else:
        print("❌ Installation failed")
        sys.exit(1)
    
    # Install development dependencies
    if run_command("pip install pytest pytest-asyncio black ruff mypy", "Installing development dependencies"):
        print("✅ Development dependencies installed!")
    
    # Run basic tests
    if os.path.exists("tests"):
        if run_command("python -m pytest tests/ -v", "Running basic tests"):
            print("✅ All tests passed!")
        else:
            print("⚠️  Some tests failed, but setup continues...")
    
    print("\n🎉 Setup complete!")
    print("\nNext steps:")
    print("1. Copy example_config.json to your desired location")
    print("2. Edit the configuration with your SMB share details")
    print("3. Test the configuration: network-mcp-server validate-config your_config.json")
    print("4. Run the server: network-mcp-server run --config your_config.json")
    print("\nFor Claude Desktop integration, add this to your Claude config:")
    print("""
{
  "mcpServers": {
    "network-fs": {
      "command": "network-mcp-server",
      "args": ["run", "--config", "path/to/your_config.json"]
    }
  }
}""")


if __name__ == "__main__":
    main()
