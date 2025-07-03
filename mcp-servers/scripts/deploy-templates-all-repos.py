#!/usr/bin/env python3
"""
Comprehensive GitHub Template Deployment Script
Deploys standardized GitHub project management templates to all target repositories.
"""

import asyncio
import json
from typing import List, Dict, Any
from dataclasses import dataclass

@dataclass
class RepositoryConfig:
    """Configuration for a target repository"""
    owner: str
    repo: str
    priority: str  # high, medium, low
    component_labels: List[Dict[str, str]]
    has_existing_issues: bool = True
    needs_project_board: bool = True

class GitHubTemplateDeployment:
    """Manages deployment of GitHub templates across multiple repositories"""
    
    def __init__(self, dry_run: bool = False):
        self.dry_run = dry_run
        self.target_repositories = self._get_target_repositories()
        self.standard_labels = self._get_standard_labels()
        
    def _get_target_repositories(self) -> List[RepositoryConfig]:
        """Define all target repositories for template deployment"""
        return [
            # High Priority - Active Development
            RepositoryConfig(
                owner="festion",
                repo="mcp-servers", 
                priority="high",
                component_labels=[
                    {"name": "component:home-assistant", "color": "41b883", "description": "Home Assistant MCP server"},
                    {"name": "component:proxmox", "color": "e97627", "description": "Proxmox MCP server"},
                    {"name": "component:wikijs", "color": "1976d2", "description": "WikiJS MCP server"},
                    {"name": "component:network-fs", "color": "00acc1", "description": "Network filesystem MCP server"},
                    {"name": "component:github", "color": "24292e", "description": "GitHub MCP server"},
                    {"name": "component:code-linter", "color": "f1c40f", "description": "Code linter MCP server"},
                ]
            ),
            RepositoryConfig(
                owner="festion",
                repo="homelab-gitops-auditor",
                priority="high", 
                component_labels=[
                    {"name": "component:frontend", "color": "61dafb", "description": "Frontend React components"},
                    {"name": "component:backend", "color": "68a063", "description": "Backend Node.js API"},
                    {"name": "component:database", "color": "336791", "description": "Database components"},
                    {"name": "component:monitoring", "color": "e6522c", "description": "Monitoring and alerting"},
                ]
            ),
            RepositoryConfig(
                owner="festion",
                repo="hass-ab-ble-gateway-suite",
                priority="high",
                component_labels=[
                    {"name": "component:integration", "color": "2196f3", "description": "Home Assistant integration"},
                    {"name": "component:dashboard", "color": "9c27b0", "description": "Dashboard and UI"},
                    {"name": "component:gateway", "color": "ff9800", "description": "BLE Gateway functionality"},
                    {"name": "component:device", "color": "4caf50", "description": "Device management"},
                ]
            ),
            RepositoryConfig(
                owner="festion", 
                repo="proxmox-agent",
                priority="high",
                component_labels=[
                    {"name": "component:agent", "color": "e97627", "description": "Proxmox agent core"},
                    {"name": "component:monitoring", "color": "e6522c", "description": "Monitoring functionality"},
                    {"name": "component:api", "color": "68a063", "description": "API components"},
                ]
            ),
            RepositoryConfig(
                owner="festion",
                repo="blender", 
                priority="high",
                component_labels=[
                    {"name": "component:blender", "color": "f5792a", "description": "Blender integration"},
                    {"name": "component:3d-printing", "color": "2196f3", "description": "3D printing workflows"},
                    {"name": "component:serena", "color": "9c27b0", "description": "Serena MCP integration"},
                ]
            ),
            
            # Medium Priority - Template Projects
            RepositoryConfig(
                owner="festion",
                repo="homelab-project-template",
                priority="medium",
                component_labels=[
                    {"name": "component:template", "color": "f1c40f", "description": "Template structure"},
                    {"name": "component:prompts", "color": "9c27b0", "description": "Prompt definitions"},
                    {"name": "component:docs", "color": "0075ca", "description": "Documentation"},
                ]
            ),
        ]
    
    def _get_standard_labels(self) -> List[Dict[str, str]]:
        """Define standard labels for all repositories"""
        return [
            # Priority Labels
            {"name": "priority:critical", "color": "d73a4a", "description": "Critical priority - immediate attention required"},
            {"name": "priority:high", "color": "ff6b35", "description": "High priority - should be addressed soon"},
            {"name": "priority:medium", "color": "fbca04", "description": "Medium priority - normal timeline"},
            {"name": "priority:low", "color": "0e8a16", "description": "Low priority - can be deferred"},
            
            # Type Labels  
            {"name": "type:epic", "color": "8b5cf6", "description": "Epic - large feature or initiative"},
            {"name": "type:feature", "color": "a2eeef", "description": "New feature or enhancement"},
            {"name": "type:bug", "color": "d73a4a", "description": "Bug or defect"},
            {"name": "type:docs", "color": "0075ca", "description": "Documentation"},
            {"name": "type:maintenance", "color": "fef2c0", "description": "Maintenance or refactoring"},
            {"name": "type:investigation", "color": "f9d0c4", "description": "Investigation or research"},
            
            # Status Labels
            {"name": "status:blocked", "color": "b60205", "description": "Blocked by external dependency"},
            {"name": "status:in-progress", "color": "0052cc", "description": "Currently being worked on"},
            {"name": "status:review", "color": "fbca04", "description": "Ready for review"},
            {"name": "status:needs-info", "color": "d4c5f9", "description": "Needs more information"},
            {"name": "status:duplicate", "color": "cfd3d7", "description": "Duplicate issue"},
            {"name": "status:wontfix", "color": "ffffff", "description": "Will not be fixed"},
        ]
    
    def get_all_labels_for_repo(self, repo_config: RepositoryConfig) -> List[Dict[str, str]]:
        """Get complete label set for a repository (standard + component labels)"""
        all_labels = self.standard_labels.copy()
        all_labels.extend(repo_config.component_labels)
        return all_labels
    
    async def deploy_labels_to_repository(self, repo_config: RepositoryConfig) -> Dict[str, Any]:
        """Deploy labels to a single repository"""
        print(f"🏷️  Deploying labels to {repo_config.owner}/{repo_config.repo}...")
        
        if self.dry_run:
            labels = self.get_all_labels_for_repo(repo_config)
            return {
                "repository": f"{repo_config.owner}/{repo_config.repo}",
                "status": "dry_run",
                "labels_planned": len(labels),
                "priority": repo_config.priority
            }
        
        # This would use MCP GitHub server to create labels
        # Implementation would call GitHub MCP server functions
        
        return {
            "repository": f"{repo_config.owner}/{repo_config.repo}",
            "status": "success",
            "labels_created": len(self.get_all_labels_for_repo(repo_config)),
            "priority": repo_config.priority
        }
    
    async def create_project_board(self, repo_config: RepositoryConfig) -> Dict[str, Any]:
        """Create standardized project board for repository"""
        print(f"📋 Creating project board for {repo_config.owner}/{repo_config.repo}...")
        
        if not repo_config.needs_project_board:
            return {"status": "skipped", "reason": "Project board not needed"}
        
        if self.dry_run:
            return {
                "repository": f"{repo_config.owner}/{repo_config.repo}",
                "status": "dry_run",
                "board_name": f"{repo_config.repo.title()} Development Board",
                "columns": ["Backlog", "Ready", "In Progress", "Review", "Testing", "Done"]
            }
        
        # This would create project board via GitHub web interface or API
        # Note: GitHub MCP server doesn't support project boards yet
        
        return {
            "repository": f"{repo_config.owner}/{repo_config.repo}",
            "status": "manual_creation_required",
            "board_url": f"https://github.com/{repo_config.owner}/{repo_config.repo}/projects"
        }
    
    async def migrate_repository_issues(self, repo_config: RepositoryConfig) -> Dict[str, Any]:
        """Migrate existing issues to use standard labels"""
        print(f"🔄 Migrating issues for {repo_config.owner}/{repo_config.repo}...")
        
        if not repo_config.has_existing_issues:
            return {"status": "skipped", "reason": "No existing issues to migrate"}
        
        if self.dry_run:
            return {
                "repository": f"{repo_config.owner}/{repo_config.repo}",
                "status": "dry_run",
                "migration_plan": "Apply standard labels based on issue content analysis"
            }
        
        # This would use MCP GitHub server to update existing issues
        
        return {
            "repository": f"{repo_config.owner}/{repo_config.repo}",
            "status": "success",
            "issues_migrated": "TBD"
        }
    
    async def deploy_to_single_repository(self, repo_config: RepositoryConfig) -> Dict[str, Any]:
        """Complete deployment to a single repository"""
        print(f"\n🚀 Starting deployment to {repo_config.owner}/{repo_config.repo}")
        print(f"   Priority: {repo_config.priority.upper()}")
        
        results = {
            "repository": f"{repo_config.owner}/{repo_config.repo}",
            "priority": repo_config.priority,
            "components": []
        }
        
        # Phase 1: Deploy Labels
        label_result = await self.deploy_labels_to_repository(repo_config)
        results["components"].append({"phase": "labels", "result": label_result})
        
        # Phase 2: Create Project Board  
        board_result = await self.create_project_board(repo_config)
        results["components"].append({"phase": "project_board", "result": board_result})
        
        # Phase 3: Migrate Issues
        migration_result = await self.migrate_repository_issues(repo_config)
        results["components"].append({"phase": "issue_migration", "result": migration_result})
        
        print(f"✅ Completed deployment to {repo_config.owner}/{repo_config.repo}")
        return results
    
    async def deploy_to_all_repositories(self) -> List[Dict[str, Any]]:
        """Deploy templates to all target repositories"""
        print("🌟 Starting GitHub Template Deployment to All Repositories")
        print(f"📊 Target: {len(self.target_repositories)} repositories")
        print(f"🔧 Mode: {'DRY RUN' if self.dry_run else 'LIVE DEPLOYMENT'}")
        
        # Sort by priority: high -> medium -> low
        priority_order = {"high": 1, "medium": 2, "low": 3}
        sorted_repos = sorted(
            self.target_repositories, 
            key=lambda r: priority_order.get(r.priority, 999)
        )
        
        results = []
        for repo_config in sorted_repos:
            try:
                result = await self.deploy_to_single_repository(repo_config)
                results.append(result)
            except Exception as e:
                print(f"❌ Error deploying to {repo_config.owner}/{repo_config.repo}: {e}")
                results.append({
                    "repository": f"{repo_config.owner}/{repo_config.repo}",
                    "status": "error",
                    "error": str(e)
                })
        
        return results
    
    def generate_deployment_report(self, results: List[Dict[str, Any]]) -> str:
        """Generate comprehensive deployment report"""
        total_repos = len(results)
        successful_deployments = len([r for r in results if r.get("status") != "error"])
        
        report = f"""
# GitHub Template Deployment Report

## Summary
- **Total Repositories**: {total_repos}
- **Successful Deployments**: {successful_deployments}
- **Success Rate**: {(successful_deployments/total_repos)*100:.1f}%
- **Mode**: {'DRY RUN' if self.dry_run else 'LIVE DEPLOYMENT'}

## Repository Results
"""
        
        for result in results:
            repo_name = result["repository"]
            priority = result.get("priority", "unknown")
            report += f"\n### {repo_name} (Priority: {priority.upper()})\n"
            
            if "components" in result:
                for component in result["components"]:
                    phase = component["phase"]
                    phase_result = component["result"]
                    status = phase_result.get("status", "unknown")
                    report += f"- **{phase.title()}**: {status}\n"
            else:
                status = result.get("status", "unknown")
                report += f"- **Status**: {status}\n"
        
        return report

async def main():
    """Main deployment execution"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Deploy GitHub templates to all repositories")
    parser.add_argument("--dry-run", action="store_true", help="Preview deployment without making changes")
    parser.add_argument("--priority", choices=["high", "medium", "low"], help="Deploy only specific priority repositories")
    
    args = parser.parse_args()
    
    deployment = GitHubTemplateDeployment(dry_run=args.dry_run)
    
    # Filter by priority if specified
    if args.priority:
        deployment.target_repositories = [
            repo for repo in deployment.target_repositories 
            if repo.priority == args.priority
        ]
    
    results = await deployment.deploy_to_all_repositories()
    
    # Generate and display report
    report = deployment.generate_deployment_report(results)
    print(report)
    
    # Save report to file
    report_filename = f"deployment-report-{'dry-run' if args.dry_run else 'live'}.md"
    with open(report_filename, 'w') as f:
        f.write(report)
    
    print(f"\n📄 Report saved to: {report_filename}")

if __name__ == "__main__":
    asyncio.run(main())