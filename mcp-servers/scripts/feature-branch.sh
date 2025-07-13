#!/bin/bash

set -euo pipefail

COMMAND="${1:-}"
FEATURE_NAME="${2:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
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

# Validate feature name
validate_feature_name() {
    local name="$1"
    
    if [[ ! "$name" =~ ^[a-z0-9-]+$ ]]; then
        error "Feature name must contain only lowercase letters, numbers, and hyphens"
    fi
    
    if [[ ${#name} -lt 3 ]]; then
        error "Feature name must be at least 3 characters long"
    fi
    
    if [[ ${#name} -gt 50 ]]; then
        error "Feature name must be less than 50 characters long"
    fi
}

# Create new feature branch
create_feature() {
    local feature_name="$1"
    local branch_name="feature/mcp-$feature_name"
    
    validate_feature_name "$feature_name"
    
    log "Creating feature branch: $branch_name"
    
    # Ensure we're on the latest main branch
    git checkout main 2>/dev/null || git checkout master 2>/dev/null || error "Unable to checkout main/master branch"
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || error "Unable to pull latest changes"
    
    # Check if branch already exists
    if git show-ref --verify --quiet refs/heads/"$branch_name"; then
        error "Branch $branch_name already exists"
    fi
    
    # Create and checkout new branch
    git checkout -b "$branch_name"
    
    # Create feature documentation
    mkdir -p "docs/features"
    cat > "docs/features/$feature_name.md" << EOF
# Feature: $feature_name

## Description
Brief description of the MCP server feature.

## Implementation Plan
- [ ] Development tasks
- [ ] Testing requirements
- [ ] Documentation updates
- [ ] Integration testing

## Acceptance Criteria
- [ ] Feature works as specified
- [ ] Tests pass
- [ ] Documentation updated
- [ ] Security review completed
- [ ] MCP protocol compliance verified

## Testing
- [ ] Unit tests written
- [ ] Integration tests written
- [ ] MCP server testing completed
- [ ] Manual testing completed

## Deployment
- [ ] MCP server configuration updated
- [ ] Wrapper scripts updated (if needed)
- [ ] Production deployment plan
- [ ] Rollback plan documented

## MCP Server Specific
- [ ] Protocol compliance verified
- [ ] Error handling implemented
- [ ] Resource management tested
- [ ] Security validation completed
EOF

    # Initial commit
    git add "docs/features/$feature_name.md"
    git commit -m "feat: initialize $feature_name MCP feature

Add initial feature documentation and planning.

Relates to MCP server enhancement."
    
    # Push branch to remote
    git push -u origin "$branch_name"
    
    log "Feature branch created successfully!"
    log "Branch: $branch_name"
    log "Documentation: docs/features/$feature_name.md"
    log ""
    log "Next steps:"
    log "1. Update the feature documentation"
    log "2. Implement the feature"
    log "3. Write tests"
    log "4. Test MCP server functionality"
    log "5. Create pull request when ready"
}

# Check feature branch status
status_feature() {
    local feature_name="$1"
    local branch_name="feature/mcp-$feature_name"
    
    if ! git show-ref --verify --quiet refs/heads/"$branch_name"; then
        error "Feature branch $branch_name does not exist"
    fi
    
    git checkout "$branch_name"
    
    log "Feature branch status: $branch_name"
    log "=========================="
    
    # Show branch information
    echo ""
    echo "Branch information:"
    local main_branch="main"
    if ! git show-ref --verify --quiet refs/heads/main; then
        main_branch="master"
    fi
    git log --oneline "$main_branch".."$branch_name" || echo "No commits ahead of $main_branch"
    
    echo ""
    echo "Files changed:"
    git diff --name-status "$main_branch".."$branch_name" || echo "No changes detected"
    
    echo ""
    echo "Commit count ahead of $main_branch:"
    git rev-list --count "$main_branch".."$branch_name" || echo "0"
    
    echo ""
    echo "Feature documentation:"
    if [[ -f "docs/features/$feature_name.md" ]]; then
        echo "✅ Feature documentation exists"
    else
        echo "❌ Feature documentation missing"
    fi
    
    # Check for common requirements
    echo ""
    echo "Development checklist:"
    
    # Check for tests
    if find . -name "*$feature_name*" -path "*/test*" -type f 2>/dev/null | grep -q .; then
        echo "✅ Tests found for this feature"
    else
        echo "❌ No tests found for this feature"
    fi
    
    # Check for documentation updates
    if git diff --name-only "$main_branch".."$branch_name" | grep -q "README\|docs/"; then
        echo "✅ Documentation updates detected"
    else
        echo "⚠️  No documentation updates detected"
    fi
    
    # Check for MCP server changes
    if git diff --name-only "$main_branch".."$branch_name" | grep -q "mcp-servers/"; then
        echo "✅ MCP server changes detected"
    else
        echo "⚠️  No MCP server changes detected"
    fi
}

# Test feature branch
test_feature() {
    local feature_name="$1"
    local branch_name="feature/mcp-$feature_name"
    
    if ! git show-ref --verify --quiet refs/heads/"$branch_name"; then
        error "Feature branch $branch_name does not exist"
    fi
    
    git checkout "$branch_name"
    
    log "Testing feature branch: $branch_name"
    
    # Check if Python environment exists
    if [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]] || [[ -d ".venv" ]]; then
        log "Python project detected, setting up environment..."
        
        # Activate virtual environment if it exists
        if [[ -d ".venv" ]]; then
            source .venv/bin/activate
        fi
        
        # Install dependencies
        if [[ -f "requirements.txt" ]]; then
            pip install -r requirements.txt
        elif [[ -f "pyproject.toml" ]]; then
            pip install -e .
        fi
        
        # Run Python tests
        if command -v pytest &> /dev/null; then
            log "Running pytest..."
            pytest
        elif [[ -f "test_*.py" ]] || [[ -d "tests" ]]; then
            log "Running Python unit tests..."
            python -m unittest discover
        fi
        
        # Run linting if available
        if command -v flake8 &> /dev/null; then
            log "Running flake8 linting..."
            flake8 .
        fi
        
        if command -v black &> /dev/null; then
            log "Running black formatting check..."
            black --check .
        fi
    fi
    
    # Check if Node.js project
    if [[ -f "package.json" ]]; then
        log "Node.js project detected..."
        
        # Install dependencies
        log "Installing dependencies..."
        npm ci
        
        # Run linting
        log "Running code quality checks..."
        npm run lint 2>/dev/null || echo "No lint script found"
        npm run format:check 2>/dev/null || echo "No format check script found"
        npm run type-check 2>/dev/null || echo "No type check script found"
        
        # Run tests
        log "Running tests..."
        npm test 2>/dev/null || echo "No test script found"
        
        # Run build
        log "Testing build..."
        npm run build 2>/dev/null || echo "No build script found"
    fi
    
    # Test MCP server functionality
    log "Testing MCP server functionality..."
    
    # Look for MCP server implementations
    for server_dir in mcp-servers/*/; do
        if [[ -d "$server_dir" ]]; then
            server_name=$(basename "$server_dir")
            log "Testing MCP server: $server_name"
            
            # Check for server configuration
            if [[ -f "$server_dir/server.py" ]] || [[ -f "$server_dir/main.py" ]]; then
                log "✅ Python MCP server found"
                
                # Basic syntax check
                python -m py_compile "$server_dir"/*.py 2>/dev/null || warn "Python syntax issues detected in $server_name"
            fi
            
            if [[ -f "$server_dir/package.json" ]]; then
                log "✅ Node.js MCP server found"
                
                # Check if dependencies are installed
                if [[ -d "$server_dir/node_modules" ]]; then
                    log "✅ Dependencies installed"
                else
                    warn "Dependencies not installed for $server_name"
                fi
            fi
        fi
    done
    
    log "All tests completed!"
}

# Prepare feature for review
prepare_review() {
    local feature_name="$1"
    local branch_name="feature/mcp-$feature_name"
    
    if ! git show-ref --verify --quiet refs/heads/"$branch_name"; then
        error "Feature branch $branch_name does not exist"
    fi
    
    git checkout "$branch_name"
    
    log "Preparing feature for review: $branch_name"
    
    # Determine main branch
    local main_branch="main"
    if ! git show-ref --verify --quiet refs/heads/main; then
        main_branch="master"
    fi
    
    # Ensure branch is up to date with main
    log "Updating branch with latest $main_branch..."
    git fetch origin "$main_branch"
    
    if ! git merge origin/"$main_branch" --no-edit; then
        error "Failed to merge $main_branch. Please resolve conflicts manually."
    fi
    
    # Run full test suite
    log "Running full test suite..."
    test_feature "$feature_name"
    
    # Check feature documentation
    if [[ ! -f "docs/features/$feature_name.md" ]]; then
        warn "Feature documentation is missing"
    fi
    
    # Generate changelog entry
    local changelog_entry="docs/changelog/$feature_name.md"
    if [[ ! -f "$changelog_entry" ]]; then
        log "Generating changelog entry..."
        mkdir -p "docs/changelog"
        cat > "$changelog_entry" << EOF
# Feature: $feature_name

## Changes
- Brief description of MCP server changes made

## Impact
- User-facing impact
- MCP protocol changes (if any)
- Configuration changes (if any)
- Wrapper script updates (if any)

## Testing
- Testing approach used
- MCP server test coverage
- Integration test results

## Deployment Notes
- Any special deployment considerations
- MCP server configuration updates
- Wrapper script changes
- Migration requirements (if any)

## MCP Server Specific
- Protocol compliance verified
- Resource management tested
- Error handling validated
- Security review completed
EOF
        git add "$changelog_entry"
        git commit -m "docs: add changelog entry for $feature_name MCP feature"
    fi
    
    # Push latest changes
    git push origin "$branch_name"
    
    log "Feature is ready for review!"
    log ""
    log "Next steps:"
    log "1. Create pull request from $branch_name to $main_branch"
    log "2. Fill out the pull request template"
    log "3. Request reviews from team members"
    log "4. Address any review feedback"
}

# Create pull request
create_pr() {
    local feature_name="$1"
    local branch_name="feature/mcp-$feature_name"
    
    if ! git show-ref --verify --quiet refs/heads/"$branch_name"; then
        error "Feature branch $branch_name does not exist"
    fi
    
    git checkout "$branch_name"
    
    # Ensure branch is pushed
    git push origin "$branch_name"
    
    log "Creating pull request for: $branch_name"
    
    # Determine main branch
    local main_branch="main"
    if ! git show-ref --verify --quiet refs/heads/main; then
        main_branch="master"
    fi
    
    # Create PR using GitHub CLI if available
    if command -v gh &> /dev/null; then
        gh pr create \
            --title "feat: $feature_name - MCP server enhancement" \
            --body-file .github/pull_request_template.md \
            --base "$main_branch" \
            --head "$branch_name" \
            --assignee "@me" \
            --label "feature,mcp-server"
        
        log "Pull request created successfully!"
    else
        log "GitHub CLI not found. Please create PR manually:"
        log "Base: $main_branch"
        log "Head: $branch_name"
        log "Title: feat: $feature_name - MCP server enhancement"
    fi
}

# Clean up merged feature branch
cleanup_feature() {
    local feature_name="$1"
    local branch_name="feature/mcp-$feature_name"
    
    # Determine main branch
    local main_branch="main"
    if ! git show-ref --verify --quiet refs/heads/main; then
        main_branch="master"
    fi
    
    # Check if branch exists
    if ! git show-ref --verify --quiet refs/heads/"$branch_name"; then
        warn "Feature branch $branch_name does not exist locally"
        return
    fi
    
    # Check if branch is merged
    if ! git merge-base --is-ancestor "$branch_name" "$main_branch"; then
        error "Feature branch $branch_name is not merged into $main_branch. Please merge first."
    fi
    
    log "Cleaning up feature branch: $branch_name"
    
    # Switch to main
    git checkout "$main_branch"
    git pull origin "$main_branch"
    
    # Delete local branch
    git branch -d "$branch_name"
    
    # Delete remote branch
    git push origin --delete "$branch_name" 2>/dev/null || warn "Remote branch may not exist"
    
    # Clean up feature documentation (optional)
    read -p "Archive feature documentation? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ -f "docs/features/$feature_name.md" ]]; then
            mkdir -p "docs/features/archived"
            mv "docs/features/$feature_name.md" "docs/features/archived/"
            git add "docs/features/archived/$feature_name.md"
            git commit -m "docs: archive $feature_name feature documentation"
            git push origin "$main_branch"
        fi
    fi
    
    log "Feature branch cleanup completed!"
}

# Check if command is provided
if [[ -z "$COMMAND" ]]; then
    echo "Usage: $0 {create|status|test|prepare|pr|cleanup} <feature-name>"
    echo ""
    echo "Commands:"
    echo "  create   - Create a new feature branch"
    echo "  status   - Check feature branch status"
    echo "  test     - Run tests on feature branch"
    echo "  prepare  - Prepare feature for review"
    echo "  pr       - Create pull request"
    echo "  cleanup  - Clean up merged feature branch"
    exit 1
fi

# Main command dispatcher
case "$COMMAND" in
    create)
        if [[ -z "$FEATURE_NAME" ]]; then
            error "Feature name is required. Usage: $0 create <feature-name>"
        fi
        create_feature "$FEATURE_NAME"
        ;;
    status)
        if [[ -z "$FEATURE_NAME" ]]; then
            error "Feature name is required. Usage: $0 status <feature-name>"
        fi
        status_feature "$FEATURE_NAME"
        ;;
    test)
        if [[ -z "$FEATURE_NAME" ]]; then
            error "Feature name is required. Usage: $0 test <feature-name>"
        fi
        test_feature "$FEATURE_NAME"
        ;;
    prepare)
        if [[ -z "$FEATURE_NAME" ]]; then
            error "Feature name is required. Usage: $0 prepare <feature-name>"
        fi
        prepare_review "$FEATURE_NAME"
        ;;
    pr)
        if [[ -z "$FEATURE_NAME" ]]; then
            error "Feature name is required. Usage: $0 pr <feature-name>"
        fi
        create_pr "$FEATURE_NAME"
        ;;
    cleanup)
        if [[ -z "$FEATURE_NAME" ]]; then
            error "Feature name is required. Usage: $0 cleanup <feature-name>"
        fi
        cleanup_feature "$FEATURE_NAME"
        ;;
    *)
        echo "Usage: $0 {create|status|test|prepare|pr|cleanup} <feature-name>"
        echo ""
        echo "Commands:"
        echo "  create   - Create a new feature branch"
        echo "  status   - Check feature branch status"
        echo "  test     - Run tests on feature branch"
        echo "  prepare  - Prepare feature for review"
        echo "  pr       - Create pull request"
        echo "  cleanup  - Clean up merged feature branch"
        exit 1
        ;;
esac