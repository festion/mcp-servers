# MCP Server Branch Management System

A comprehensive feature branch management system for MCP (Model Context Protocol) server development, providing standardized workflows for branch creation, testing, code review, and deployment.

## 🚀 Quick Start

### Prerequisites
- Git configured and authenticated
- GitHub CLI (`gh`) installed and authenticated
- Python 3.8+ or Node.js 16+ (depending on your MCP servers)

### Basic Workflow
```bash
# 1. Create a new feature branch
./scripts/feature-branch.sh create webhook-validation

# 2. Develop your feature
# ... make your changes ...

# 3. Test your implementation
./scripts/feature-branch.sh test webhook-validation

# 4. Prepare for review
./scripts/feature-branch.sh prepare webhook-validation

# 5. Create pull request
./scripts/feature-branch.sh pr webhook-validation

# 6. After merge, clean up
./scripts/feature-branch.sh cleanup webhook-validation
```

## 📁 Project Structure

```
mcp-servers/
├── .github/
│   ├── workflows/
│   │   ├── mcp-feature-ci.yml          # CI/CD for feature branches
│   │   └── branch-cleanup.yml          # Automated branch cleanup
│   ├── pull_request_template.md        # PR template for MCP features
│   ├── branch-protection-rules.sh      # Branch protection configuration
│   └── CODEOWNERS                      # Automated review assignment
├── scripts/
│   └── feature-branch.sh               # Main branch management script
├── docs/
│   ├── FEATURE_DEVELOPMENT_GUIDE.md    # Complete development guide
│   ├── features/                       # Feature-specific documentation
│   └── changelog/                      # Feature change logs
├── mcp-servers/                        # MCP server implementations
└── tests/                              # Test suites
```

## 🛠 Feature Branch Management

### Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `create` | Create new feature branch | `./scripts/feature-branch.sh create my-feature` |
| `status` | Check branch status and progress | `./scripts/feature-branch.sh status my-feature` |
| `test` | Run comprehensive test suite | `./scripts/feature-branch.sh test my-feature` |
| `prepare` | Prepare feature for review | `./scripts/feature-branch.sh prepare my-feature` |
| `pr` | Create pull request | `./scripts/feature-branch.sh pr my-feature` |
| `cleanup` | Clean up merged branch | `./scripts/feature-branch.sh cleanup my-feature` |

### Branch Naming Convention
All feature branches follow the pattern: `feature/mcp-<feature-name>`

Examples:
- `feature/mcp-webhook-validation`
- `feature/mcp-enhanced-logging`
- `feature/mcp-new-server-type`

## 🔄 Development Workflow

### 1. Feature Planning
- Create GitHub issue with clear requirements
- Define MCP protocol compliance needs
- Plan testing approach
- Consider security implications

### 2. Branch Creation
```bash
./scripts/feature-branch.sh create <feature-name>
```

Creates:
- ✅ Properly named feature branch
- ✅ Feature documentation template
- ✅ Initial commit with planning structure
- ✅ Remote branch tracking

### 3. Development Process
1. **Update Documentation**: Edit `docs/features/<feature-name>.md`
2. **Implement Feature**: Follow MCP protocol standards
3. **Write Tests**: Comprehensive test coverage
4. **Update Configs**: MCP server configurations

### 4. Testing & Validation
```bash
./scripts/feature-branch.sh test <feature-name>
```

Runs:
- ✅ Python/Node.js dependency installation
- ✅ Code quality checks (linting, formatting)
- ✅ Unit and integration tests
- ✅ MCP server functionality validation
- ✅ Security scans

### 5. Review Preparation
```bash
./scripts/feature-branch.sh prepare <feature-name>
```

Performs:
- ✅ Merge latest main branch changes
- ✅ Run full test suite
- ✅ Generate changelog entry
- ✅ Validate documentation completeness

### 6. Pull Request & Review
- Comprehensive PR template with MCP-specific checklist
- Automated CI/CD validation
- Required code reviews (2 for main branch)
- Security and protocol compliance checks

## 🤖 Automated CI/CD

### Feature Branch CI Pipeline
Triggers on: `feature/mcp-*` branch pushes

**Pipeline Stages:**
1. **Change Detection**: Identifies modified MCP servers
2. **Python Testing**: Multi-version testing (3.8-3.11)
3. **Node.js Testing**: Multi-version testing (16, 18, 20)
4. **MCP Protocol Validation**: Compliance verification
5. **Security Scanning**: Vulnerability detection
6. **Integration Testing**: End-to-end validation

### Branch Cleanup Automation
- **Automatic**: Removes merged feature branches
- **Scheduled**: Weekly cleanup of stale branches (30+ days)
- **Safe**: Preserves branches with open PRs
- **Documented**: Generates cleanup reports

## 🔒 Security & Compliance

### Security Measures
- ✅ Automated security scanning (Bandit, Safety)
- ✅ Secret detection and validation
- ✅ Input validation requirements
- ✅ SQL injection pattern detection
- ✅ Dependency vulnerability checks

### MCP Protocol Compliance
- ✅ Schema validation for tools and resources
- ✅ Error response format verification
- ✅ Connection lifecycle testing
- ✅ Resource management validation
- ✅ Protocol version compatibility

## 📋 Code Review Process

### Review Requirements
- **Main Branch**: 2 approving reviews + code owner approval
- **All CI Checks**: Must pass before merge
- **Documentation**: Must be complete and updated
- **Security Review**: Required for security-sensitive changes

### Review Checklist
- [ ] MCP protocol compliance verified
- [ ] Security implications assessed
- [ ] Performance impact evaluated
- [ ] Test coverage adequate
- [ ] Documentation complete
- [ ] Configuration changes documented

## 🛡 Branch Protection

### Main Branch Protection
- ✅ Required status checks
- ✅ Up-to-date branches enforced
- ✅ Administrator enforcement
- ✅ Required pull request reviews
- ✅ Dismiss stale reviews
- ✅ Restrict force pushes

### Configuration Script
```bash
# Apply branch protection rules
./.github/branch-protection-rules.sh
```

Sets up:
- Branch protection rules
- Required status checks
- Review requirements
- Repository settings
- Development labels
- CODEOWNERS file

## 📊 Quality Gates

### Code Quality
- **Python**: Black formatting, Flake8 linting, MyPy type checking
- **Node.js**: ESLint, Prettier, TypeScript validation
- **Coverage**: Minimum 80% for new features
- **Documentation**: Required for all public APIs

### Testing Requirements
- **Unit Tests**: Individual component testing
- **Integration Tests**: MCP protocol testing
- **Security Tests**: Input validation and secret handling
- **Performance Tests**: Response time and resource usage

## 📚 Documentation

### Required Documentation
1. **Feature Docs**: `docs/features/<feature-name>.md`
2. **API Documentation**: Tool and resource specifications
3. **Configuration**: Setup and environment variables
4. **Changelog**: Impact and migration notes

### Documentation Standards
- Clear, concise language
- Practical examples included
- Troubleshooting information
- Up-to-date configurations
- Migration guides when needed

## 🔧 Configuration

### Environment Setup
```bash
# Make scripts executable
chmod +x scripts/feature-branch.sh
chmod +x .github/branch-protection-rules.sh

# Install dependencies (Python example)
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Install dependencies (Node.js example)
npm ci
```

### GitHub Setup
1. Configure branch protection rules:
   ```bash
   ./.github/branch-protection-rules.sh
   ```

2. Set up GitHub teams mentioned in CODEOWNERS:
   - `@mcp-team`
   - `@mcp-server-maintainers`
   - `@python-mcp-maintainers`
   - `@nodejs-mcp-maintainers`

3. Configure repository secrets for CI/CD

## 🚨 Troubleshooting

### Common Issues

#### Branch Creation Fails
```bash
# Ensure you're on main/master branch
git checkout main
git pull origin main

# Check for existing branch
git branch -a | grep feature/mcp-my-feature
```

#### Tests Fail
```bash
# Check dependencies
pip install -r requirements.txt  # Python
npm ci                           # Node.js

# Verify environment
python --version
node --version
```

#### CI/CD Issues
- Check GitHub Actions logs
- Verify required status checks
- Review security scan results
- Validate MCP protocol compliance

### Getting Help
1. Check [Feature Development Guide](docs/FEATURE_DEVELOPMENT_GUIDE.md)
2. Review existing GitHub issues
3. Check MCP protocol documentation
4. Create detailed bug reports with logs

## 📈 Monitoring & Metrics

### Branch Analytics
- Active feature branches count
- Average feature development time
- Code review turnaround time
- Test success rates

### Quality Metrics
- Test coverage percentage
- Security scan results
- Documentation completeness
- Protocol compliance rate

## 🤝 Contributing

### For New Contributors
1. Read the [Feature Development Guide](docs/FEATURE_DEVELOPMENT_GUIDE.md)
2. Set up development environment
3. Start with small features
4. Follow the standard workflow

### For Maintainers
1. Monitor CI/CD pipeline health
2. Review and update protection rules
3. Maintain documentation currency
4. Conduct security reviews

## 📄 License

This project follows the same license as the main MCP servers project.

---

## 🎯 Key Benefits

✅ **Standardized Workflow**: Consistent development process across all MCP features  
✅ **Automated Quality**: CI/CD ensures code quality and protocol compliance  
✅ **Security First**: Built-in security scanning and validation  
✅ **Documentation Driven**: Comprehensive documentation requirements  
✅ **Team Collaboration**: Structured review process with clear ownership  
✅ **Maintenance Friendly**: Automated cleanup and monitoring  

For detailed development instructions, see the [Feature Development Guide](docs/FEATURE_DEVELOPMENT_GUIDE.md).