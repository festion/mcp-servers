#!/usr/bin/env python3
"""
Global MCP Server Installer
A standalone installer that can be used from any repository location
to manage MCP servers globally across all projects.

Usage:
    python3 global-mcp-installer.py install
    python3 global-mcp-installer.py status
    python3 global-mcp-installer.py configure --project /path/to/project
"""

import json
import os
import subprocess
import sys
import argparse
import logging
import shutil
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
from enum import Enum
import platform

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global configuration paths
if platform.system() == "Windows":
    DEFAULT_MCP_HOME = Path(os.environ.get('APPDATA', '')) / 'mcp-servers'
else:
    DEFAULT_MCP_HOME = Path.home() / '.mcp-servers'

MCP_CONFIG_FILE = 'mcp-global-config.json'
MCP_REGISTRY_FILE = 'mcp-registry.json'

class InstallLocation(Enum):
    """MCP server installation location types"""
    GLOBAL = "global"  # Installed in MCP_HOME
    LOCAL = "local"    # Installed in project directory
    SYSTEM = "system"  # Installed in system paths

@dataclass
class MCPServerInfo:
    """MCP server information"""
    name: str
    version: str
    description: str
    repository: str
    command: str
    args: List[str]
    config_template: Optional[Dict] = None
    dependencies: List[str] = None
    install_location: InstallLocation = InstallLocation.GLOBAL
    installed: bool = False
    install_path: Optional[str] = None

class GlobalMCPInstaller:
    """Global MCP server installer and manager"""
    
    def __init__(self, mcp_home: Path = None):
        self.mcp_home = mcp_home or DEFAULT_MCP_HOME
        self.config_dir = self.mcp_home / 'config'
        self.servers_dir = self.mcp_home / 'servers'
        self.bin_dir = self.mcp_home / 'bin'
        self.registry_path = self.mcp_home / MCP_REGISTRY_FILE
        self.config_path = self.mcp_home / MCP_CONFIG_FILE
        
        # Create directories if they don't exist
        self._ensure_directories()
        
        # Load or create registry
        self.registry = self._load_registry()
        
        logger.info(f"Global MCP Installer initialized at: {self.mcp_home}")
    
    def _ensure_directories(self):
        """Ensure all required directories exist"""
        for dir_path in [self.mcp_home, self.config_dir, self.servers_dir, self.bin_dir]:
            dir_path.mkdir(parents=True, exist_ok=True)
    
    def _load_registry(self) -> Dict[str, MCPServerInfo]:
        """Load MCP server registry"""
        registry = {}
        
        # Default server definitions
        default_servers = {
            "wikijs-mcp": MCPServerInfo(
                name="wikijs-mcp",
                version="0.1.0",
                description="WikiJS MCP server for wiki document management",
                repository="https://github.com/festion/mcp-servers.git",
                command="python",
                args=["-m", "wikijs_mcp", "run"],
                config_template={
                    "wikijs_url": "http://your-wiki-url",
                    "api_key": "your-api-key",
                    "allowed_paths": ["/path/to/docs"]
                }
            ),
            "proxmox-mcp": MCPServerInfo(
                name="proxmox-mcp",
                version="0.1.0",
                description="Proxmox MCP server for VM management",
                repository="https://github.com/festion/mcp-servers.git",
                command="python",
                args=["-m", "proxmox_mcp", "run"],
                config_template={
                    "proxmox_host": "https://your-proxmox-host:8006",
                    "username": "user@pam",
                    "password": "your-password"
                }
            ),
            "code-linter-mcp": MCPServerInfo(
                name="code-linter-mcp",
                version="0.1.0",
                description="Code linter MCP server for code analysis",
                repository="https://github.com/festion/mcp-servers.git",
                command="python",
                args=["-m", "code_linter_mcp.server"],
                config_template={
                    "linters": {
                        "python": ["pylint", "flake8"],
                        "javascript": ["eslint"]
                    }
                }
            ),
            "network-mcp": MCPServerInfo(
                name="network-mcp",
                version="0.1.0",
                description="Network MCP server for network file access",
                repository="https://github.com/festion/mcp-servers.git",
                command="python",
                args=["-m", "network_mcp", "run"],
                config_template={
                    "shares": {
                        "example": {
                            "host": "\\server\share",
                            "username": "user",
                            "password": "password"
                        }
                    }
                }
            ),
            "truenas-mcp": MCPServerInfo(
                name="truenas-mcp",
                version="2.0.0",
                description="TrueNAS Core MCP server for NAS management",
                repository="https://github.com/vespo92/TrueNasCoreMCP.git",
                command="python",
                args=["truenas_mcp_server.py"],
                config_template={
                    "truenas_url": "https://your-truenas-ip",
                    "api_key": "your-api-key",
                    "verify_ssl": False,
                    "timeout": 30
                }
            )
        }
        
        # Load from registry file if exists
        if self.registry_path.exists():
            try:
                with open(self.registry_path, 'r') as f:
                    saved_registry = json.load(f)
                    for name, info in saved_registry.items():
                        # Convert install_location string back to InstallLocation enum
                        if 'install_location' in info and isinstance(info['install_location'], str):
                            info['install_location'] = InstallLocation(info['install_location'])
                        registry[name] = MCPServerInfo(**info)
            except Exception as e:
                logger.warning(f"Could not load registry: {e}")
        
        # Merge with defaults (defaults take precedence for structure)
        for name, server in default_servers.items():
            if name not in registry:
                registry[name] = server
        
        return registry
    
    def _save_registry(self):
        """Save registry to file"""
        registry_data = {}
        for name, server in self.registry.items():
            server_dict = asdict(server)
            # Convert InstallLocation enum to string for JSON serialization
            if 'install_location' in server_dict:
                server_dict['install_location'] = server_dict['install_location'].value
            registry_data[name] = server_dict
        
        with open(self.registry_path, 'w') as f:
            json.dump(registry_data, f, indent=2)
    
    def _get_mcp_servers_repo_path(self) -> Optional[Path]:
        """Find the mcp-servers repository"""
        # Check common locations
        possible_paths = [
            Path("/mnt/c/GIT/mcp-servers"),
            Path.cwd() / "mcp-servers",
            Path.cwd().parent / "mcp-servers",
            self.servers_dir / "mcp-servers"
        ]
        
        for path in possible_paths:
            if path.exists() and (path / "install-all-mcp-servers.py").exists():
                return path
        
        return None
    
    def clone_mcp_servers_repo(self) -> Path:
        """Clone the MCP servers repository"""
        repo_path = self.servers_dir / "mcp-servers"
        
        if repo_path.exists():
            logger.info(f"Updating existing repository at {repo_path}")
            subprocess.run(
                ["git", "pull", "origin", "main"],
                cwd=repo_path,
                check=True
            )
        else:
            logger.info(f"Cloning MCP servers repository to {repo_path}")
            subprocess.run(
                ["git", "clone", "https://github.com/festion/mcp-servers.git", str(repo_path)],
                check=True
            )
        
        return repo_path
    
    def install_server(self, server_name: str, force: bool = False) -> bool:
        """Install a specific MCP server globally"""
        if server_name not in self.registry:
            logger.error(f"Unknown server: {server_name}")
            return False
        
        server = self.registry[server_name]
        
        if server.installed and not force:
            logger.info(f"Server {server_name} is already installed")
            return True
        
        logger.info(f"🚀 Installing {server_name} globally...")
        
        try:
            # Find or clone the repository
            repo_path = self._get_mcp_servers_repo_path()
            if not repo_path:
                repo_path = self.clone_mcp_servers_repo()
            
            # Server source directory
            server_src = repo_path / f"{server_name}-server"
            if not server_src.exists():
                logger.error(f"Server source not found: {server_src}")
                return False
            
            # Global installation directory
            install_dir = self.servers_dir / server_name
            
            # Copy server files to global location
            if install_dir.exists() and force:
                shutil.rmtree(install_dir)
            
            # Copy server files excluding venv and __pycache__ directories
            def ignore_dirs(dir, files):
                ignored = {f for f in files if f in {'venv', '__pycache__', '.git', '.pytest_cache', 'node_modules'}}
                if ignored:
                    logger.debug(f"Ignoring directories in {dir}: {ignored}")
                return ignored
            
            logger.info(f"Copying server files from {server_src} to {install_dir}...")
            shutil.copytree(server_src, install_dir, dirs_exist_ok=True, ignore=ignore_dirs)
            logger.info(f"Server files copied successfully")
            
            # Create virtual environment
            venv_path = install_dir / "venv"
            if not venv_path.exists():
                logger.info(f"Creating virtual environment...")
                subprocess.run(
                    [sys.executable, "-m", "venv", str(venv_path)],
                    check=True
                )
            
            # Install dependencies
            pip_path = venv_path / ("Scripts" if platform.system() == "Windows" else "bin") / "pip"
            requirements = install_dir / "requirements.txt"
            
            if requirements.exists():
                logger.info(f"Installing dependencies...")
                subprocess.run(
                    [str(pip_path), "install", "-r", str(requirements)],
                    check=True
                )
            
            # Create wrapper script
            self._create_wrapper_script(server_name, install_dir)
            
            # Update registry
            server.installed = True
            server.install_path = str(install_dir)
            self._save_registry()
            
            # Create default config if not exists
            config_file = self.config_dir / f"{server_name}-config.json"
            if not config_file.exists() and server.config_template:
                with open(config_file, 'w') as f:
                    json.dump(server.config_template, f, indent=2)
                logger.info(f"Created default config: {config_file}")
            
            logger.info(f"✅ Successfully installed {server_name}")
            return True
            
        except Exception as e:
            logger.error(f"Installation failed for {server_name}: {str(e)}")
            return False
    
    def _create_wrapper_script(self, server_name: str, install_dir: Path):
        """Create a wrapper script for the MCP server"""
        wrapper_name = f"mcp-{server_name}"
        
        if platform.system() == "Windows":
            wrapper_path = self.bin_dir / f"{wrapper_name}.bat"
            python_path = install_dir / "venv" / "Scripts" / "python.exe"
            
            wrapper_content = f"""@echo off
"{python_path}" -m {server_name.replace('-', '_')} %*
"""
        else:
            wrapper_path = self.bin_dir / wrapper_name
            python_path = install_dir / "venv" / "bin" / "python"
            
            wrapper_content = f"""#!/bin/bash
"{python_path}" -m {server_name.replace('-', '_')} "$@"
"""
        
        with open(wrapper_path, 'w') as f:
            f.write(wrapper_content)
        
        if platform.system() != "Windows":
            os.chmod(wrapper_path, 0o755)
        
        logger.info(f"Created wrapper script: {wrapper_path}")
    
    def configure_project(self, project_path: Path, servers: List[str] = None):
        """Configure MCP servers for a specific project"""
        project_config_dir = project_path / ".mcp"
        project_config_dir.mkdir(exist_ok=True)
        
        project_config = project_config_dir / "servers.json"
        
        # Load existing config or create new
        if project_config.exists():
            with open(project_config, 'r') as f:
                config = json.load(f)
        else:
            config = {"mcpServers": {}}
        
        # Add requested servers or all installed servers
        servers_to_add = servers or [name for name, info in self.registry.items() if info.installed]
        
        for server_name in servers_to_add:
            if server_name not in self.registry:
                logger.warning(f"Unknown server: {server_name}")
                continue
            
            server = self.registry[server_name]
            if not server.installed:
                logger.warning(f"Server not installed: {server_name}")
                continue
            
            # Add server configuration
            if platform.system() == "Windows":
                command = str(self.bin_dir / f"mcp-{server_name}.bat")
            else:
                command = str(self.bin_dir / f"mcp-{server_name}")
            
            config_path = self.config_dir / f"{server_name}-config.json"
            
            config["mcpServers"][server_name] = {
                "command": command,
                "args": ["run", "--config", str(config_path)]
            }
        
        # Save project configuration
        with open(project_config, 'w') as f:
            json.dump(config, f, indent=2)
        
        logger.info(f"✅ Configured {len(config['mcpServers'])} servers for {project_path}")
        
        # Create project-specific configs if needed
        for server_name in servers_to_add:
            project_server_config = project_config_dir / f"{server_name}-config.json"
            global_config = self.config_dir / f"{server_name}-config.json"
            
            if not project_server_config.exists() and global_config.exists():
                shutil.copy(global_config, project_server_config)
                logger.info(f"Created project config: {project_server_config}")
    
    def status(self) -> Dict[str, dict]:
        """Get status of all MCP servers"""
        status_info = {
            "mcp_home": str(self.mcp_home),
            "servers": {}
        }
        
        for name, server in self.registry.items():
            server_status = {
                "name": server.name,
                "version": server.version,
                "description": server.description,
                "installed": server.installed,
                "install_path": server.install_path,
                "config_exists": (self.config_dir / f"{name}-config.json").exists()
            }
            
            # Check if wrapper exists
            if platform.system() == "Windows":
                wrapper = self.bin_dir / f"mcp-{name}.bat"
            else:
                wrapper = self.bin_dir / f"mcp-{name}"
            
            server_status["wrapper_exists"] = wrapper.exists()
            
            status_info["servers"][name] = server_status
        
        return status_info
    
    def install_all(self):
        """Install all available MCP servers"""
        logger.info("🚀 Installing all MCP servers...")
        
        success_count = 0
        for server_name in self.registry.keys():
            if self.install_server(server_name):
                success_count += 1
        
        logger.info(f"✅ Installed {success_count}/{len(self.registry)} servers")
        return success_count == len(self.registry)
    
    def update_path(self):
        """Add MCP bin directory to PATH"""
        bin_path = str(self.bin_dir)
        
        if platform.system() == "Windows":
            logger.info(f"Add this to your PATH: {bin_path}")
            logger.info("You can do this through System Properties > Environment Variables")
        else:
            shell_rc = Path.home() / ".bashrc"
            if shell_rc.exists():
                with open(shell_rc, 'r') as f:
                    content = f.read()
                
                if bin_path not in content:
                    with open(shell_rc, 'a') as f:
                        f.write(f'\n# MCP Servers\nexport PATH="{bin_path}:$PATH"\n')
                    logger.info(f"Added {bin_path} to {shell_rc}")
                    logger.info("Run 'source ~/.bashrc' to update your current shell")
                else:
                    logger.info(f"PATH already includes {bin_path}")
    
    def uninstall_server(self, server_name: str) -> bool:
        """Uninstall a specific MCP server"""
        if server_name not in self.registry:
            logger.error(f"Unknown server: {server_name}")
            return False
        
        server = self.registry[server_name]
        
        if not server.installed:
            logger.info(f"Server {server_name} is not installed")
            return True
        
        logger.info(f"🗑️ Uninstalling {server_name}...")
        
        try:
            # Remove installation directory
            if server.install_path and Path(server.install_path).exists():
                shutil.rmtree(server.install_path)
                logger.info(f"Removed installation directory: {server.install_path}")
            
            # Remove wrapper script
            if platform.system() == "Windows":
                wrapper = self.bin_dir / f"mcp-{server_name}.bat"
            else:
                wrapper = self.bin_dir / f"mcp-{server_name}"
            
            if wrapper.exists():
                wrapper.unlink()
                logger.info(f"Removed wrapper script: {wrapper}")
            
            # Remove config file (optional - ask user)
            config_file = self.config_dir / f"{server_name}-config.json"
            if config_file.exists():
                response = input(f"Remove configuration file {config_file}? [y/N]: ").strip().lower()
                if response == 'y':
                    config_file.unlink()
                    logger.info(f"Removed configuration file: {config_file}")
                else:
                    logger.info(f"Kept configuration file: {config_file}")
            
            # Update registry
            server.installed = False
            server.install_path = None
            self._save_registry()
            
            logger.info(f"✅ Successfully uninstalled {server_name}")
            return True
            
        except Exception as e:
            logger.error(f"Uninstallation failed for {server_name}: {str(e)}")
            return False
    
    def update_server(self, server_name: str) -> bool:
        """Update a specific MCP server"""
        if server_name not in self.registry:
            logger.error(f"Unknown server: {server_name}")
            return False
        
        server = self.registry[server_name]
        
        if not server.installed:
            logger.error(f"Server {server_name} is not installed")
            return False
        
        logger.info(f"🔄 Updating {server_name}...")
        
        try:
            # Update repository
            repo_path = self._get_mcp_servers_repo_path()
            if not repo_path:
                repo_path = self.clone_mcp_servers_repo()
            else:
                # Pull latest changes
                logger.info("Updating repository...")
                subprocess.run(
                    ["git", "pull", "origin", "main"],
                    cwd=repo_path,
                    check=True
                )
            
            # Backup current installation
            install_dir = Path(server.install_path)
            backup_dir = install_dir.parent / f"{server_name}.backup"
            
            if backup_dir.exists():
                shutil.rmtree(backup_dir)
            
            logger.info(f"Creating backup at {backup_dir}")
            shutil.copytree(install_dir, backup_dir)
            
            # Copy updated files (preserve venv and configs)
            server_src = repo_path / f"{server_name}-server"
            
            # Update source files only (not venv or user configs)
            for item in server_src.iterdir():
                if item.name not in ['venv', 'config', '__pycache__']:
                    dest = install_dir / item.name
                    if dest.exists():
                        if dest.is_dir():
                            shutil.rmtree(dest)
                        else:
                            dest.unlink()
                    
                    if item.is_dir():
                        shutil.copytree(item, dest)
                    else:
                        shutil.copy2(item, dest)
            
            # Update dependencies
            pip_path = install_dir / "venv" / ("Scripts" if platform.system() == "Windows" else "bin") / "pip"
            requirements = install_dir / "requirements.txt"
            
            if requirements.exists():
                logger.info("Updating dependencies...")
                subprocess.run(
                    [str(pip_path), "install", "-r", str(requirements), "--upgrade"],
                    check=True
                )
            
            # Remove backup
            shutil.rmtree(backup_dir)
            
            logger.info(f"✅ Successfully updated {server_name}")
            return True
            
        except Exception as e:
            logger.error(f"Update failed for {server_name}: {str(e)}")
            
            # Attempt to restore backup
            backup_dir = Path(server.install_path).parent / f"{server_name}.backup"
            if backup_dir.exists():
                logger.info("Restoring from backup...")
                install_dir = Path(server.install_path)
                if install_dir.exists():
                    shutil.rmtree(install_dir)
                shutil.move(str(backup_dir), str(install_dir))
                logger.info("Backup restored")
            
            return False
    
    def update_all(self):
        """Update all installed MCP servers"""
        logger.info("🔄 Updating all installed MCP servers...")
        
        installed_servers = [name for name, server in self.registry.items() if server.installed]
        
        if not installed_servers:
            logger.info("No servers installed")
            return True
        
        success_count = 0
        for server_name in installed_servers:
            if self.update_server(server_name):
                success_count += 1
        
        logger.info(f"✅ Updated {success_count}/{len(installed_servers)} servers")
        return success_count == len(installed_servers)

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Global MCP Server Installer",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Install all MCP servers globally
  %(prog)s install --all
  
  # Install specific servers
  %(prog)s install wikijs-mcp proxmox-mcp
  
  # Configure MCP servers for current project
  %(prog)s configure
  
  # Configure for specific project
  %(prog)s configure --project /path/to/project
  
  # Show status
  %(prog)s status
  
  # Update PATH
  %(prog)s update-path
"""
    )
    
    parser.add_argument("--mcp-home", type=Path,
                      help=f"MCP home directory (default: {DEFAULT_MCP_HOME})")
    
    subparsers = parser.add_subparsers(dest="command", help="Commands")
    
    # Install command
    install_parser = subparsers.add_parser("install", help="Install MCP servers")
    install_parser.add_argument("servers", nargs="*", help="Servers to install")
    install_parser.add_argument("--all", action="store_true", help="Install all servers")
    install_parser.add_argument("--force", action="store_true", help="Force reinstall")
    
    # Configure command
    config_parser = subparsers.add_parser("configure", help="Configure MCP servers for a project")
    config_parser.add_argument("--project", type=Path, default=Path.cwd(),
                             help="Project directory (default: current directory)")
    config_parser.add_argument("--servers", nargs="*", help="Specific servers to configure")
    
    # Status command
    subparsers.add_parser("status", help="Show MCP server status")
    
    # Update PATH command
    subparsers.add_parser("update-path", help="Update PATH environment variable")
    
    # Update command
    update_parser = subparsers.add_parser("update", help="Update MCP servers")
    update_parser.add_argument("servers", nargs="*", help="Servers to update")
    update_parser.add_argument("--all", action="store_true", help="Update all servers")
    
    # Uninstall command
    uninstall_parser = subparsers.add_parser("uninstall", help="Uninstall MCP servers")
    uninstall_parser.add_argument("servers", nargs="+", help="Servers to uninstall")
    
    args = parser.parse_args()
    
    # Initialize installer
    installer = GlobalMCPInstaller(args.mcp_home)
    
    if args.command == "install":
        if args.all:
            installer.install_all()
        elif args.servers:
            for server in args.servers:
                installer.install_server(server, force=args.force)
        else:
            logger.error("Specify servers to install or use --all")
    
    elif args.command == "configure":
        installer.configure_project(args.project, args.servers)
    
    elif args.command == "status":
        status = installer.status()
        print(json.dumps(status, indent=2))
    
    elif args.command == "update-path":
        installer.update_path()
    
    elif args.command == "update":
        if args.all:
            installer.update_all()
        elif args.servers:
            for server in args.servers:
                installer.update_server(server)
        else:
            logger.error("Specify servers to update or use --all")
    
    elif args.command == "uninstall":
        for server in args.servers:
            installer.uninstall_server(server)
    
    else:
        parser.print_help()

if __name__ == "__main__":
    main()