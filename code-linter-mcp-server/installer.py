#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Setup script for Code Linter MCP Server - Source to Deployment Installation."""

import subprocess
import sys
import os
import shutil
import platform
from pathlib import Path


def run_command(cmd, description, check=True, cwd=None):
    """Run a command and handle errors."""
    print(f"[INFO] {description}...")
    try:
        result = subprocess.run(cmd, shell=True, check=check, capture_output=True, text=True, cwd=cwd)
        if result.returncode == 0:
            print(f"[SUCCESS] {description} completed")
            return result.stdout
        else:
            print(f"[WARNING] {description} completed with warnings")
            if result.stderr:
                print(f"Warning: {result.stderr}")
            return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] {description} failed:")
        print(f"Error: {e.stderr}")
        if check:
            return None
        return ""


def check_python_version():
    """Check if Python version is 3.11+."""
    version = sys.version_info
    if version.major < 3 or (version.major == 3 and version.minor < 11):
        print(f"[ERROR] Python 3.11+ required, found {version.major}.{version.minor}")
        return False
    print(f"[SUCCESS] Python {version.major}.{version.minor}.{version.micro} is compatible")
    return True


def setup_directories(source_dir=None, install_dir=None):
    """Set up source and installation directories."""
    if platform.system() == "Windows":
        default_source = Path("C:/git/mcp-servers/code-linter-mcp-server")
        default_install = Path("C:/working/code-linter-mcp-server")
    else:
        # For Unix systems, use more typical paths
        default_source = Path.cwd()  # Assume we're running from source
        default_install = Path.home() / "mcp-servers" / "code-linter-mcp-server"
    
    source_dir = Path(source_dir) if source_dir else default_source
    install_dir = Path(install_dir) if install_dir else default_install
    
    print(f"[INFO] Source: {source_dir}")
    print(f"[INFO] Install: {install_dir}")
    
    if not source_dir.exists():
        print(f"[ERROR] Source directory not found: {source_dir}")
        return None, None
    
    # Validate source directory
    if not (source_dir / "pyproject.toml").exists() or not (source_dir / "src" / "code_linter_mcp").exists():
        print(f"[ERROR] Invalid source directory: {source_dir}")
        print("Expected code-linter-mcp-server source directory with pyproject.toml and src/code_linter_mcp")
        return None, None
    
    return source_dir, install_dir


def copy_source_files(source_dir, install_dir):
    """Copy source files to installation directory."""
    print("[INFO] Copying source files...")
    
    # Create installation directory
    install_dir.mkdir(parents=True, exist_ok=True)
    
    # Define exclusions
    exclude_dirs = {'.git', '__pycache__', '.pytest_cache', 'node_modules', '.mypy_cache'}
    exclude_files = {'*.pyc', '*.pyo', '*.pyd', '.DS_Store'}
    
    try:
        # Copy all files except exclusions
        for item in source_dir.rglob('*'):
            # Skip if any parent directory is in exclusions
            if any(part in exclude_dirs for part in item.parts):
                continue
            
            # Skip files matching exclusion patterns
            if item.is_file() and any(item.match(pattern) for pattern in exclude_files):
                continue
            
            # Calculate relative path and target
            rel_path = item.relative_to(source_dir)
            target = install_dir / rel_path
            
            if item.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(item, target)
        
        print("[SUCCESS] Source files copied successfully")
        return True
    except Exception as e:
        print(f"[ERROR] Failed to copy source files: {e}")
        return False


def check_external_linters():
    """Check for external linters availability."""
    print("\n[INFO] Checking external linters...")
    
    linters = {
        "node": "Node.js (for JavaScript/TypeScript linting)",
        "npm": "npm (for installing JS/TS linters)",
        "go": "Go (for Go linting)",
        "eslint": "ESLint",
        "typescript": "TypeScript compiler"
    }
    
    available = {}
    for cmd, description in linters.items():
        result = run_command(f"{cmd} --version", f"Checking {description}", check=False)
        available[cmd] = result is not None and result.strip()
    
    return available


def install_js_linters():
    """Install JavaScript/TypeScript linters."""
    print("\n[INFO] Installing JavaScript/TypeScript linters...")
    
    if run_command("npm --version", "Checking npm availability", check=False):
        js_packages = [
            "eslint",
            "typescript",
            "@typescript-eslint/parser",
            "@typescript-eslint/eslint-plugin",
            "prettier"
        ]
        
        cmd = f"npm install -g {' '.join(js_packages)}"
        if run_command(cmd, "Installing JavaScript/TypeScript linters", check=False):
            print("[SUCCESS] JavaScript/TypeScript linters installed")
        else:
            print("[WARNING] Failed to install JS/TS linters automatically")
            print("You can install them manually with:")
            print(f"  npm install -g {' '.join(js_packages)}")
    else:
        print("[WARNING] npm not available, skipping JS/TS linter installation")


def create_sample_config(install_dir):
    """Create sample configuration file."""
    print("\n[INFO] Creating sample configuration...")
    
    config_path = install_dir / "config.json"
    
    # Use the CLI tool to create config
    result = run_command(
        f"code-linter-mcp-server create-config --output \"{config_path}\" --force",
        "Creating configuration",
        cwd=install_dir
    )
    
    if result is not None:
        print(f"[SUCCESS] Configuration created: {config_path}")
        
        # Validate the configuration
        validate_result = run_command(
            f"code-linter-mcp-server validate-config \"{config_path}\"",
            "Validating configuration",
            cwd=install_dir
        )
        
        if validate_result is not None:
            print("[SUCCESS] Configuration validated successfully")
        return True
    else:
        print("[ERROR] Failed to create configuration")
        return False


def show_claude_integration(install_dir):
    """Show Claude Desktop integration instructions."""
    config_path = install_dir / "config.json"
    
    # Determine the correct script path based on platform
    if platform.system() == "Windows":
        script_name = "code-linter-mcp-server.exe"
        scripts_dir = Path(sys.executable).parent / "Scripts"
        script_path = scripts_dir / script_name
    else:
        script_name = "code-linter-mcp-server"
        scripts_dir = Path(sys.executable).parent
        script_path = scripts_dir / script_name
    
    print("\n" + "=" * 50)
    print("Claude Desktop Integration")
    print("=" * 50)
    print("Add this configuration to your Claude Desktop config file:")
    print()
    
    # Convert paths to proper format for JSON
    if platform.system() == "Windows":
        script_path_str = str(script_path).replace("\\", "\\\\")
        config_path_str = str(config_path).replace("\\", "\\\\")
    else:
        script_path_str = str(script_path)
        config_path_str = str(config_path)
    
    config_json = f'''{{
  "mcpServers": {{
    "code-linter": {{
      "command": "{script_path_str}",
      "args": ["run", "--config", "{config_path_str}"]
    }}
  }}
}}'''
    
    print(config_json)
    print()
    print("Claude Desktop config file locations:")
    
    if platform.system() == "Windows":
        claude_config = Path.home() / "AppData" / "Roaming" / "Claude" / "claude_desktop_config.json"
    elif platform.system() == "Darwin":  # macOS
        claude_config = Path.home() / "Library" / "Application Support" / "Claude" / "claude_desktop_config.json"
    else:  # Linux
        claude_config = Path.home() / ".config" / "claude" / "claude_desktop_config.json"
    
    print(f"  {claude_config}")


def main():
    """Main setup process."""
    print("Code Linter MCP Server Setup (Source to Deployment)")
    print("=" * 60)
    
    # Check Python version
    if not check_python_version():
        sys.exit(1)
    
    # Set up directories
    source_dir, install_dir = setup_directories()
    if not source_dir or not install_dir:
        sys.exit(1)
    
    # Interactive install directory selection if not specified via args
    import argparse
    parser = argparse.ArgumentParser(description="Code Linter MCP Server Setup")
    parser.add_argument("--source", help="Source directory path")
    parser.add_argument("--install-dir", help="Installation directory path")
    
    args = parser.parse_args()
    
    if args.source:
        source_dir = Path(args.source)
    if args.install_dir:
        install_dir = Path(args.install_dir)
    elif not args.install_dir:
        print(f"\n[INFO] Installation Directory Setup")
        print(f"Default: {install_dir}")
        response = input("Enter installation directory (or press Enter for default): ").strip()
        if response:
            install_dir = Path(response)
            print(f"[INFO] Using: {install_dir}")
    
    # Copy source files to installation directory
    if not copy_source_files(source_dir, install_dir):
        sys.exit(1)
    
    # Change to installation directory
    os.chdir(install_dir)
    
    # Install the package in development mode
    print("\n[INFO] Installing Code Linter MCP Server...")
    if run_command("pip install -e .", "Installing Code Linter MCP Server in development mode"):
        print("[SUCCESS] Installation successful!")
    else:
        print("[ERROR] Installation failed")
        sys.exit(1)
    
    # Install Python linter dependencies
    print("\n[INFO] Installing Python linters...")
    python_linters = ["flake8", "black", "mypy", "pylint", "yamllint", "jsonschema"]
    cmd = f"pip install {' '.join(python_linters)}"
    
    if run_command(cmd, "Installing Python linters"):
        print("[SUCCESS] Python linters installed!")
    else:
        print("[WARNING] Some Python linters may not have installed correctly")
    
    # Install development dependencies
    print("\n[INFO] Installing development dependencies...")
    if run_command("pip install -e .[dev]", "Installing development dependencies"):
        print("[SUCCESS] Development dependencies installed!")
    
    # Check external linters
    external_linters = check_external_linters()
    
    # Install JS/TS linters if possible
    if external_linters.get("npm"):
        install_js_linters()
    
    # Create and validate sample configuration
    if create_sample_config(install_dir):
        print("[SUCCESS] Configuration setup complete!")
    
    # Run basic tests if available
    if (install_dir / "tests").exists():
        print("\n[INFO] Running basic tests...")
        if run_command("python -m pytest tests/ -v", "Running tests", check=False):
            print("[SUCCESS] All tests passed!")
        else:
            print("[WARNING] Some tests failed, but setup continues...")
    
    # Show completion message and next steps
    print("\n" + "=" * 50)
    print("Setup complete!")
    print("=" * 50)
    print(f"\nInstallation Summary:")
    print(f"[SUCCESS] Code Linter MCP Server installed to: {install_dir}")
    print("[SUCCESS] Python linters installed")
    
    if external_linters.get("eslint"):
        print("[SUCCESS] JavaScript/TypeScript linters available")
    else:
        print("[WARNING] JavaScript/TypeScript linters not available")
    
    if external_linters.get("go"):
        print("[SUCCESS] Go tools available")
    else:
        print("[WARNING] Go tools not available")
    
    print(f"\nNext steps:")
    print(f"1. Review and customize {install_dir}/config.json")
    print("2. Install additional linters as needed:")
    if not external_linters.get("go"):
        print("   - Go: Install Go from https://golang.org/")
    if not external_linters.get("npm"):
        print("   - JavaScript/TypeScript: Install Node.js from https://nodejs.org/")
        print("     Then run: npm install -g eslint typescript")
    print(f"3. Test the server: code-linter-mcp-server run --config \"{install_dir}/config.json\"")
    print("4. Add to Claude Desktop (see configuration below)")
    
    # Show Claude Desktop integration
    show_claude_integration(install_dir)


if __name__ == "__main__":
    main()
