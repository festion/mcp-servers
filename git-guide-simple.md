# Git Commit and Push Guide

## Basic Workflow

### 1. Check Status
```bash
git status
```

### 2. Stage Changes
```bash
git add filename.txt    # Stage specific file
git add .              # Stage all changes
```

### 3. Create Commit
```bash
git commit -m "Add new feature"
```

### 4. Push Changes
```bash
git push               # Push to current branch
git push -u origin branch-name  # Push new branch
```

## Commit Message Best Practices

### Format
```
type: short description

Detailed explanation if needed
```

### Types
- **feat**: New feature
- **fix**: Bug fix  
- **docs**: Documentation
- **refactor**: Code restructuring
- **test**: Adding tests
- **chore**: Maintenance

### Examples
```bash
git commit -m "feat: add user dashboard"
git commit -m "fix: resolve login issue"
git commit -m "docs: update setup instructions"
```

## Branch Management

```bash
# Create new branch
git checkout -b feature/new-feature

# Switch branches
git checkout main

# Merge branch
git merge feature/new-feature
```

## Common Commands

```bash
# View history
git log --oneline

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Stash changes
git stash
git stash pop

# Pull latest changes
git pull
```

## Troubleshooting

### Rejected Push
```bash
git pull --rebase
git push
```

### Merge Conflicts
1. Edit conflicted files
2. `git add resolved-file.txt`
3. `git commit`
4. `git push`

---

*Development Guide - Updated 2025-07-01*