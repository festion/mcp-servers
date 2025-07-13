#!/bin/bash

# Configure branch protection rules for MCP servers repository
# Run this script to apply consistent branch protection

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) is required but not installed. Please install it first."
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    error "Not authenticated with GitHub. Please run 'gh auth login' first."
fi

# Get repository information
REPO_INFO=$(gh repo view --json owner,name)
REPO_OWNER=$(echo "$REPO_INFO" | jq -r '.owner.login')
REPO_NAME=$(echo "$REPO_INFO" | jq -r '.name')

log "Configuring branch protection for $REPO_OWNER/$REPO_NAME"

# Determine main branch
MAIN_BRANCH="main"
if ! gh api repos/$REPO_OWNER/$REPO_NAME/branches/main &> /dev/null; then
    if gh api repos/$REPO_OWNER/$REPO_NAME/branches/master &> /dev/null; then
        MAIN_BRANCH="master"
        log "Using master as main branch"
    else
        error "Could not find main or master branch"
    fi
else
    log "Using main as main branch"
fi

# Main branch protection
log "Applying protection rules to $MAIN_BRANCH branch..."

MAIN_PROTECTION='{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "MCP Feature Branch CI / Python MCP Server Tests (3.11)",
      "MCP Feature Branch CI / MCP Protocol Validation",
      "MCP Feature Branch CI / Security Scan",
      "MCP Feature Branch CI / MCP Integration Test"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 2,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "require_last_push_approval": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false
}'

if gh api repos/$REPO_OWNER/$REPO_NAME/branches/$MAIN_BRANCH/protection \
   --method PUT \
   --input - <<< "$MAIN_PROTECTION"; then
    log "✅ Main branch protection rules applied successfully"
else
    warn "Failed to apply main branch protection rules"
fi

# Develop branch protection (if it exists)
if gh api repos/$REPO_OWNER/$REPO_NAME/branches/develop &> /dev/null; then
    log "Applying protection rules to develop branch..."
    
    DEVELOP_PROTECTION='{
      "required_status_checks": {
        "strict": true,
        "contexts": [
          "MCP Feature Branch CI / Python MCP Server Tests (3.11)",
          "MCP Feature Branch CI / MCP Protocol Validation",
          "MCP Feature Branch CI / Security Scan"
        ]
      },
      "enforce_admins": false,
      "required_pull_request_reviews": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews": true,
        "require_code_owner_reviews": false,
        "require_last_push_approval": false
      },
      "restrictions": null,
      "allow_force_pushes": false,
      "allow_deletions": false,
      "block_creations": false
    }'
    
    if gh api repos/$REPO_OWNER/$REPO_NAME/branches/develop/protection \
       --method PUT \
       --input - <<< "$DEVELOP_PROTECTION"; then
        log "✅ Develop branch protection rules applied successfully"
    else
        warn "Failed to apply develop branch protection rules"
    fi
else
    log "No develop branch found, skipping develop branch protection"
fi

# Create branch protection rule for feature branches
log "Setting up branch protection rule for MCP feature branches..."

# Note: GitHub doesn't support wildcard branch protection via API for all plans
# This would need to be configured manually in GitHub UI for wildcard patterns
warn "Feature branch protection (feature/mcp-*) must be configured manually in GitHub UI"
warn "Go to Settings > Branches and add a rule for pattern: feature/mcp-*"

# Create CODEOWNERS file for automated review assignment
log "Creating CODEOWNERS file..."

cat > .github/CODEOWNERS << 'EOF'
# MCP Servers Code Owners
# These owners will be requested for review when someone opens a pull request.

# Global ownership - all files require review from MCP team
* @mcp-team

# MCP Server specific ownership
/mcp-servers/ @mcp-team @mcp-server-maintainers

# Python MCP servers
/mcp-servers/**/*.py @mcp-team @python-mcp-maintainers

# Node.js MCP servers  
/mcp-servers/**/package.json @mcp-team @nodejs-mcp-maintainers
/mcp-servers/**/*.js @mcp-team @nodejs-mcp-maintainers
/mcp-servers/**/*.ts @mcp-team @nodejs-mcp-maintainers

# Configuration files
/mcp-servers/**/config.json @mcp-team @config-maintainers
/mcp-servers/**/.env* @mcp-team @config-maintainers

# Scripts and automation
/scripts/ @mcp-team @automation-maintainers
/.github/ @mcp-team @automation-maintainers

# Documentation
/docs/ @mcp-team @documentation-maintainers
README.md @mcp-team @documentation-maintainers

# Wrapper scripts in root
/*-wrapper.sh @mcp-team @wrapper-maintainers
EOF

# Repository settings
log "Configuring repository settings..."

REPO_SETTINGS='{
  "delete_branch_on_merge": true,
  "allow_squash_merge": true,
  "allow_merge_commit": false,
  "allow_rebase_merge": false,
  "allow_auto_merge": true,
  "use_squash_pr_title_as_default": true
}'

if gh api repos/$REPO_OWNER/$REPO_NAME \
   --method PATCH \
   --input - <<< "$REPO_SETTINGS"; then
    log "✅ Repository settings updated successfully"
else
    warn "Failed to update repository settings"
fi

# Create issue and PR labels
log "Creating labels for MCP development..."

LABELS='[
  {
    "name": "mcp-server",
    "color": "0052CC",
    "description": "Related to MCP server development"
  },
  {
    "name": "feature",
    "color": "a2eeef",
    "description": "New feature or enhancement"
  },
  {
    "name": "bug",
    "color": "d73a4a",
    "description": "Something is not working"
  },
  {
    "name": "security",
    "color": "dd0000",
    "description": "Security related issue"
  },
  {
    "name": "protocol-compliance",
    "color": "6f42c1",
    "description": "MCP protocol compliance issue"
  },
  {
    "name": "python-mcp",
    "color": "3776ab",
    "description": "Python MCP server related"
  },
  {
    "name": "nodejs-mcp",
    "color": "68a063",
    "description": "Node.js MCP server related"
  },
  {
    "name": "documentation",
    "color": "0075ca",
    "description": "Improvements or additions to documentation"
  },
  {
    "name": "needs-review",
    "color": "fbca04",
    "description": "Needs code review"
  },
  {
    "name": "ready-to-merge",
    "color": "0e8a16",
    "description": "Ready to be merged"
  }
]'

echo "$LABELS" | jq -c '.[]' | while read label; do
    NAME=$(echo "$label" | jq -r '.name')
    if gh label create "$NAME" \
       --color "$(echo "$label" | jq -r '.color')" \
       --description "$(echo "$label" | jq -r '.description')" 2>/dev/null; then
        log "✅ Created label: $NAME"
    else
        log "Label $NAME already exists or failed to create"
    fi
done

log ""
log "Branch protection configuration completed!"
log ""
log "Summary of applied settings:"
log "• Main branch ($MAIN_BRANCH) protected with required reviews and status checks"
log "• Repository configured for squash merging"
log "• Automatic branch deletion on merge enabled"
log "• CODEOWNERS file created for review assignment"
log "• MCP development labels created"
log ""
log "Manual steps required:"
log "1. Configure feature branch protection pattern 'feature/mcp-*' in GitHub UI"
log "2. Set up teams mentioned in CODEOWNERS file:"
log "   - @mcp-team"
log "   - @mcp-server-maintainers"
log "   - @python-mcp-maintainers"
log "   - @nodejs-mcp-maintainers"
log "   - @config-maintainers"
log "   - @automation-maintainers"
log "   - @documentation-maintainers"
log "   - @wrapper-maintainers"
log "3. Review and adjust protection rules as needed"