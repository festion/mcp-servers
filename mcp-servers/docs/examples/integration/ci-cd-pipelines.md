# CI/CD Pipeline Integration Examples

This document provides examples for integrating Claude auto-commit functionality into various CI/CD pipelines.

## GitHub Actions Integration

### Basic Auto-Commit Workflow

```yaml
name: Auto-Commit Documentation Updates
on:
  push:
    branches: [main]
    paths: ['src/**', 'lib/**']

jobs:
  auto-commit-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Setup MCP Environment
        run: |
          npm install -g @modelcontextprotocol/cli
          echo "CLAUDE_API_KEY=${{ secrets.CLAUDE_API_KEY }}" >> $GITHUB_ENV

      - name: Generate Documentation Commits
        run: |
          # Auto-generate commit messages for documentation updates
          mcp call github auto_stage_and_commit \
            --data '{
              "message_config": {
                "type": "docs",
                "language": "en",
                "template": "conventional"
              },
              "stage_options": {
                "patterns": ["docs/**", "*.md"],
                "exclude_patterns": ["node_modules/**"]
              }
            }'

      - name: Push Changes
        run: |
          git push origin main
```

### Advanced Multi-Environment Pipeline

```yaml
name: Smart Auto-Commit Pipeline
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'development'
        type: choice
        options:
        - development
        - staging
        - production

jobs:
  smart-commit:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Configure Environment-Specific Settings
        run: |
          case "${{ github.event.inputs.environment }}" in
            "development")
              echo "COMMIT_TEMPLATE=development" >> $GITHUB_ENV
              echo "AUTO_STAGE=true" >> $GITHUB_ENV
              ;;
            "staging")
              echo "COMMIT_TEMPLATE=staging" >> $GITHUB_ENV
              echo "AUTO_STAGE=false" >> $GITHUB_ENV
              ;;
            "production")
              echo "COMMIT_TEMPLATE=production" >> $GITHUB_ENV
              echo "AUTO_STAGE=false" >> $GITHUB_ENV
              echo "REQUIRE_REVIEW=true" >> $GITHUB_ENV
              ;;
          esac

      - name: Smart Commit Generation
        run: |
          mcp call github smart_commit \
            --data '{
              "analysis_depth": "deep",
              "template_name": "${{ env.COMMIT_TEMPLATE }}",
              "auto_stage": ${{ env.AUTO_STAGE }},
              "require_confirmation": ${{ env.REQUIRE_REVIEW || false }}
            }'
```

## GitLab CI Integration

### Basic Pipeline Configuration

```yaml
# .gitlab-ci.yml
stages:
  - analyze
  - commit
  - deploy

variables:
  MCP_SERVER_URL: "http://mcp-server:3000"
  CLAUDE_API_KEY: $CLAUDE_API_KEY

auto_commit:
  stage: commit
  image: node:18-alpine
  script:
    - npm install -g @modelcontextprotocol/cli
    - |
      mcp call github generate_commit_message \
        --data '{
          "changes_summary": "'"$(git diff --name-only HEAD~1)"'",
          "language": "en",
          "template": "conventional",
          "include_files": true
        }' > commit_message.json
    - |
      COMMIT_MSG=$(jq -r '.message' commit_message.json)
      git add .
      git commit -m "$COMMIT_MSG"
      git push origin $CI_COMMIT_REF_NAME
  only:
    - merge_requests
  when: manual

smart_analysis:
  stage: analyze
  script:
    - |
      mcp call github smart_commit \
        --data '{
          "analysis_depth": "comprehensive",
          "generate_suggestions": true,
          "dry_run": true
        }' > analysis_report.json
  artifacts:
    reports:
      junit: analysis_report.json
    expire_in: 1 hour
```

## Jenkins Pipeline Integration

### Declarative Pipeline

```groovy
pipeline {
    agent any
    
    environment {
        CLAUDE_API_KEY = credentials('claude-api-key')
        MCP_SERVER_URL = 'http://localhost:3000'
    }
    
    stages {
        stage('Setup') {
            steps {
                sh 'npm install -g @modelcontextprotocol/cli'
            }
        }
        
        stage('Auto-Commit Analysis') {
            steps {
                script {
                    def analysis = sh(
                        script: '''
                            mcp call github smart_commit \
                                --data '{
                                    "analysis_depth": "standard",
                                    "dry_run": true,
                                    "generate_report": true
                                }'
                        ''',
                        returnStdout: true
                    ).trim()
                    
                    env.COMMIT_ANALYSIS = analysis
                }
            }
        }
        
        stage('Generate Commit') {
            when {
                expression { 
                    return env.BRANCH_NAME == 'main' || env.BRANCH_NAME.startsWith('feature/')
                }
            }
            steps {
                script {
                    def commitResult = sh(
                        script: '''
                            mcp call github auto_stage_and_commit \
                                --data '{
                                    "message_config": {
                                        "type": "auto",
                                        "template": "jenkins",
                                        "language": "en"
                                    },
                                    "stage_options": {
                                        "auto_detect": true
                                    }
                                }'
                        ''',
                        returnStdout: true
                    ).trim()
                    
                    echo "Commit Result: ${commitResult}"
                }
            }
        }
        
        stage('Push Changes') {
            steps {
                withCredentials([gitUsernamePassword(credentialsId: 'github-credentials')]) {
                    sh 'git push origin ${BRANCH_NAME}'
                }
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'commit_analysis.json', fingerprint: true
        }
        failure {
            emailext (
                subject: "Auto-Commit Pipeline Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: "The auto-commit pipeline failed. Check the analysis: ${env.COMMIT_ANALYSIS}",
                to: "${env.CHANGE_AUTHOR_EMAIL}"
            )
        }
    }
}
```

This integration guide provides comprehensive examples for incorporating Claude auto-commit functionality into various CI/CD platforms with proper security, performance, and monitoring considerations.