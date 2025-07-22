# Git Commit and Push Guide

## Overview
This guide covers Git commit and push workflows, best practices, and common patterns used in our development environment.

## Basic Workflow

### 1. Check Repository Status
```bash
git status
```
Shows:
- Modified files
- Untracked files  
- Staged changes
- Current branch

### 2. Stage Changes
```bash
# Stage specific files
git add filename.txt

# Stage all changes
git add .

# Stage all tracked files (ignores new files)
git add -u

# Interactive staging
git add -i
```

### 3. Create Commit
```bash
# Basic commit with message
git commit -m "Add new feature implementation"

# Commit with detailed message
git commit -m "Add user authentication system

- Implement JWT token validation
- Add password hashing with bcrypt
- Create login/logout endpoints
- Add session management middleware"

# Commit all tracked changes (skip staging)
git commit -am "Fix typo in documentation"
```

### 4. Push Changes
```bash
# Push to current branch
git push

# Push new branch to remote
git push -u origin feature-branch

# Force push (use with caution)
git push --force-with-lease
```

## Commit Message Best Practices

### Format
```
<type>: <short description>

<detailed description>
<blank line>
- Bullet point changes
- Additional context
```

### Types
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code formatting (no logic changes)
- **refactor**: Code restructuring
- **test**: Adding or updating tests
- **chore**: Maintenance tasks

### Examples
```bash
git commit -m "feat: add user profile management

Implement complete user profile system including:
- Profile creation and editing
- Avatar upload functionality  
- Privacy settings management
- Profile validation and sanitization"

git commit -m "fix: resolve memory leak in image processing

- Fix unclosed file handles in ImageProcessor
- Add proper error handling for corrupted images
- Update unit tests for edge cases"

git commit -m "docs: update API documentation for v2.0"
```

## Advanced Workflows

### Amending Commits
```bash
# Modify last commit message
git commit --amend -m "Updated commit message"

# Add files to last commit
git add forgotten-file.txt
git commit --amend --no-edit

# Amend and push (if already pushed)
git commit --amend
git push --force-with-lease
```

### Branch Management
```bash
# Create and switch to new branch
git checkout -b feature/new-functionality

# Push new branch
git push -u origin feature/new-functionality

# Merge branch
git checkout main
git merge feature/new-functionality
git push
```

### Handling Conflicts
```bash
# When merge conflicts occur
git status  # Check conflicted files
# Edit files to resolve conflicts
git add resolved-file.txt
git commit -m "Resolve merge conflicts"
git push
```

## Common Patterns

### Feature Development
```bash
# 1. Create feature branch
git checkout -b feature/user-dashboard

# 2. Make changes and commit regularly
git add .
git commit -m "feat: implement dashboard layout"

git add .
git commit -m "feat: add data visualization components"

# 3. Push branch
git push -u origin feature/user-dashboard

# 4. Create pull request (via GitHub/GitLab)
# 5. After review, merge to main
```

### Hotfix Workflow
```bash
# 1. Create hotfix branch from main
git checkout main
git pull
git checkout -b hotfix/critical-security-fix

# 2. Make minimal fix
git add .
git commit -m "fix: patch SQL injection vulnerability"

# 3. Push and create urgent PR
git push -u origin hotfix/critical-security-fix
```

### Release Preparation
```bash
# 1. Create release branch
git checkout -b release/v2.1.0

# 2. Update version numbers, changelogs
git add .
git commit -m "chore: prepare release v2.1.0"

# 3. Push and create release PR
git push -u origin release/v2.1.0
```

## Environment-Specific Notes

### Claude Code Integration
When using Claude Code for commits:
- Claude automatically follows commit message conventions
- Includes co-authored-by metadata
- Runs linting and type checking before commits
- Uses `--force-with-lease` for safer force pushes

### Pre-commit Hooks
Our repositories may include:
- Code formatting (prettier, black)
- Linting (eslint, pylint)
- Type checking (typescript, mypy)
- Security scanning
- Test execution

### Branch Protection
Main branches typically have:
- Required pull request reviews
- Status check requirements
- No direct pushes allowed
- Linear history enforcement

## Troubleshooting

### Common Issues

**Rejected Push**
```bash
# Usually due to remote changes
git pull --rebase
git push
```

**Uncommitted Changes Blocking Operations**
```bash
# Stash changes temporarily
git stash
git pull
git stash pop
```

**Wrong Branch**
```bash
# Move commits to correct branch
git checkout correct-branch
git cherry-pick commit-hash
```

**Accidental Commit to Main**
```bash
# Create new branch with current changes
git branch feature/accidental-commits
git reset --hard HEAD~1  # Remove from main
git checkout feature/accidental-commits
```

### Recovery Commands
```bash
# View commit history
git log --oneline

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1

# Find lost commits
git reflog
```

## Security Considerations

### Never Commit
- Sensitive credentials
- Environment configuration files
- Personal configuration files
- Large binary files
- Temporary/cache files

### Credential Management
- Use environment variables for sensitive data
- Rotate credentials regularly
- Use repository secrets for CI/CD
- Audit access permissions

### Best Practices
- Sign commits with GPG when required
- Use SSH keys for authentication
- Enable two-factor authentication
- Review changes before pushing
- Use branch protection rules

---

*Last updated: 2025-07-01*
*Environment: Claude Code MCP Setup*