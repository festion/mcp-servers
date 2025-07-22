# Claude Auto-Commit Architecture Documentation

## Architecture Overview

This document provides detailed technical architecture for integrating claude-auto-commit functionality into the GitHub MCP server. The integration maintains the existing server's architectural patterns while adding AI-powered commit generation capabilities.

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          MCP Client                             │
│                    (Claude Desktop/CLI)                         │
└─────────────────────────┬───────────────────────────────────────┘
                          │ MCP Protocol (stdio/JSON-RPC)
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                   GitHub MCP Server                             │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                  Toolset Router                             ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  ││
│  │  │   repos     │  │   issues    │  │   auto_commit       │  ││
│  │  │   toolset   │  │   toolset   │  │   toolset (NEW)     │  ││
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘  ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                  Client Layer                               ││
│  │  ┌─────────────┐  ┌─────────────────────────────────────────┐││
│  │  │   GitHub    │  │         Claude Client (NEW)            │││
│  │  │   Client    │  │                                         │││
│  │  └─────────────┘  └─────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────┬───────────────────────┬───────────────┘
                          │                       │
                          │                       │
              ┌───────────▼──────────┐  ┌─────────▼──────────┐
              │     GitHub API       │  │    Claude API      │
              │                      │  │   (Code SDK)       │
              └──────────────────────┘  └────────────────────┘
```

### Component Architecture

#### 1. MCP Server Core
- **Framework**: mark3labs/mcp-go
- **Communication**: stdio-based JSON-RPC
- **Configuration**: viper-based configuration management
- **Logging**: Structured logging with configurable levels

#### 2. Toolset System
- **Organization**: Functional grouping of related tools
- **Registration**: Dynamic toolset registration and discovery
- **Permissions**: Read/write tool separation
- **Validation**: Input validation and error handling

#### 3. Client Layer
- **GitHub Client**: Existing go-github/v72 client
- **Claude Client**: New Claude Code SDK integration
- **Authentication**: Token-based authentication for both services
- **Rate Limiting**: Intelligent rate limiting and retry logic

## New Components

### Claude Auto-Commit Toolset

#### File Structure
```
pkg/github/
├── auto_commit.go          # Main auto-commit implementation
├── claude_client.go        # Claude API client wrapper
├── commit_analyzer.go      # Code change analysis logic
├── commit_generator.go     # Message generation logic
├── template_manager.go     # Template management
└── __toolsnaps__/
    ├── generate_commit_message.snap
    ├── auto_stage_and_commit.snap
    └── smart_commit.snap
```

#### Tool Implementation Pattern
```go
// Tool implementation following existing patterns
func GenerateCommitMessage(
    getClient GetClientFn, 
    getClaudeClient GetClaudeClientFn, 
    t translations.TranslationHelperFunc,
) (tool mcp.Tool, handler server.ToolHandlerFunc) {
    return mcp.NewTool("generate_commit_message",
        mcp.WithDescription(t("TOOL_GENERATE_COMMIT_MESSAGE_DESCRIPTION", 
            "Generate AI-powered commit messages based on code changes")),
        mcp.WithToolAnnotation(mcp.ToolAnnotation{
            Title:        t("TOOL_GENERATE_COMMIT_MESSAGE_TITLE", "Generate commit message"),
            ReadOnlyHint: ToBoolPtr(true),
        }),
        // Parameter definitions...
    ), handlerFunc
}
```

## Data Flow Architecture

### 1. Generate Commit Message Flow

```
┌─────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   MCP       │    │   Auto-Commit   │    │   Claude API    │
│   Client    │    │   Tool          │    │                 │
└─────────────┘    └─────────────────┘    └─────────────────┘
       │                    │                      │
       │ generate_commit_   │                      │
       │ message()          │                      │
       ├───────────────────►│                      │
       │                    │                      │
       │                    │ Get repository diff  │
       │                    │ via GitHub API       │
       │                    ├─────────────────────►│
       │                    │                      │
       │                    │ Analyze changes with │
       │                    │ Claude Code SDK      │
       │                    ├─────────────────────►│
       │                    │                      │
       │                    │ Generated message    │
       │                    │◄─────────────────────┤
       │                    │                      │
       │ AI-generated       │                      │
       │ commit message     │                      │
       │◄───────────────────┤                      │
       │                    │                      │
```

### 2. Smart Commit Flow

```
┌─────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   MCP       │    │   Auto-Commit   │    │   GitHub API    │    │   Claude API    │
│   Client    │    │   Tool          │    │                 │    │                 │
└─────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
       │                    │                      │                      │
       │ smart_commit()     │                      │                      │
       ├───────────────────►│                      │                      │
       │                    │                      │                      │
       │                    │ 1. Get diff          │                      │
       │                    ├─────────────────────►│                      │
       │                    │                      │                      │
       │                    │ 2. Analyze changes   │                      │
       │                    ├─────────────────────────────────────────────►│
       │                    │                      │                      │
       │                    │ 3. Generate message  │                      │
       │                    │◄─────────────────────────────────────────────┤
       │                    │                      │                      │
       │                    │ 4. Stage & commit    │                      │
       │                    ├─────────────────────►│                      │
       │                    │                      │                      │
       │                    │ 5. Push (optional)   │                      │
       │                    ├─────────────────────►│                      │
       │                    │                      │                      │
       │ Complete result    │                      │                      │
       │◄───────────────────┤                      │                      │
```

## API Design

### Claude Client Interface

```go
// Claude client interface for commit message generation
type ClaudeClient interface {
    GenerateCommitMessage(ctx context.Context, req *CommitMessageRequest) (*CommitMessageResponse, error)
    AnalyzeChanges(ctx context.Context, req *AnalysisRequest) (*AnalysisResponse, error)
    ValidateTemplate(ctx context.Context, template string) error
}

// Request structures
type CommitMessageRequest struct {
    Diff              string
    Language          string
    ConventionalCommits bool
    IncludeEmoji      bool
    Template          string
    FileTypes         []string
    ChangeScope       string
}

type CommitMessageResponse struct {
    Message     string
    Confidence  float64
    Analysis    ChangeAnalysis
    Suggestions []string
}
```

### GitHub Integration Interface

```go
// Extended GitHub operations for auto-commit
type AutoCommitOperations interface {
    GetRepositoryDiff(ctx context.Context, owner, repo, branch string) (*DiffResult, error)
    StageFiles(ctx context.Context, owner, repo, branch string, patterns []string) error
    CreateCommit(ctx context.Context, owner, repo, branch, message string) (*CommitResult, error)
    PushChanges(ctx context.Context, owner, repo, branch string) error
}

// Supporting structures
type DiffResult struct {
    Files       []FileDiff
    Stats       DiffStats
    Summary     string
    ChangeTypes []string
}

type FileDiff struct {
    Path        string
    Status      string // added, modified, deleted
    Additions   int
    Deletions   int
    Changes     string
    Language    string
}
```

## Configuration Architecture

### Configuration Structure

```yaml
# Auto-commit specific configuration
auto_commit:
  claude:
    api_key: "${CLAUDE_API_KEY}"
    base_url: "https://api.anthropic.com"
    model: "claude-3-sonnet-20240229"
    timeout: 30s
    max_retries: 3
    rate_limit:
      requests_per_minute: 100
      burst_size: 10
  
  defaults:
    language: "en"
    conventional_commits: false
    include_emoji: true
    auto_push: false
    dry_run: false
  
  templates:
    directory: "./templates"
    default_template: "standard"
  
  analysis:
    max_diff_size: 10000
    include_context_lines: 3
    analyze_file_types: ["go", "js", "py", "java", "cpp"]
```

### Configuration Management

```go
// Configuration structures
type AutoCommitConfig struct {
    Claude    ClaudeConfig    `mapstructure:"claude"`
    Defaults  DefaultsConfig  `mapstructure:"defaults"`
    Templates TemplatesConfig `mapstructure:"templates"`
    Analysis  AnalysisConfig  `mapstructure:"analysis"`
}

type ClaudeConfig struct {
    APIKey      string        `mapstructure:"api_key"`
    BaseURL     string        `mapstructure:"base_url"`
    Model       string        `mapstructure:"model"`
    Timeout     time.Duration `mapstructure:"timeout"`
    MaxRetries  int           `mapstructure:"max_retries"`
    RateLimit   RateLimitConfig `mapstructure:"rate_limit"`
}
```

## Error Handling Architecture

### Error Hierarchy

```go
// Custom error types for auto-commit functionality
type AutoCommitError struct {
    Code    ErrorCode
    Message string
    Cause   error
    Context map[string]interface{}
}

// Error codes for different failure scenarios
type ErrorCode int

const (
    ErrClaudeAPIFailure ErrorCode = iota
    ErrRepositoryAccess
    ErrInvalidConfiguration
    ErrGitOperationFailure
    ErrTemplateNotFound
    ErrRateLimitExceeded
    ErrAnalysisFailure
)
```

### Error Handling Strategy

1. **Graceful Degradation**: Fallback to basic commit messages when Claude API fails
2. **Retry Logic**: Exponential backoff for transient failures
3. **Detailed Logging**: Comprehensive error logging for debugging
4. **User Feedback**: Clear error messages through MCP protocol

## Security Architecture

### Authentication Flow

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   MCP Client    │    │   GitHub MCP    │    │   External APIs │
│                 │    │   Server        │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │ Request with tokens   │                       │
         ├──────────────────────►│                       │
         │                       │                       │
         │                       │ Validate GitHub token │
         │                       ├──────────────────────►│
         │                       │                       │
         │                       │ Validate Claude key   │
         │                       ├──────────────────────►│
         │                       │                       │
         │                       │ Execute operation     │
         │                       ├──────────────────────►│
         │                       │                       │
         │ Response              │                       │
         │◄──────────────────────┤                       │
```

### Security Measures

1. **Token Validation**: Validate all API tokens before use
2. **Access Control**: Repository-level permission checks
3. **Data Minimization**: Only send necessary code context to Claude API
4. **Secure Storage**: Encrypted token storage and management
5. **Audit Logging**: Comprehensive logging of all operations

## Performance Architecture

### Caching Strategy

```go
// Multi-level caching for performance optimization
type CacheManager struct {
    // Diff caching to avoid repeated GitHub API calls
    diffCache     cache.Cache
    
    // Generated message caching for similar changes
    messageCache  cache.Cache
    
    // Template caching for faster template processing
    templateCache cache.Cache
    
    // Analysis result caching
    analysisCache cache.Cache
}
```

### Performance Optimizations

1. **Diff Caching**: Cache repository diffs to reduce GitHub API calls
2. **Message Caching**: Cache generated messages for similar code changes
3. **Template Caching**: Cache processed templates for faster generation
4. **Parallel Processing**: Concurrent processing where possible
5. **Rate Limiting**: Intelligent rate limiting to prevent API exhaustion

## Monitoring and Observability

### Metrics Collection

```go
// Metrics for monitoring auto-commit operations
type AutoCommitMetrics struct {
    // Operation counters
    CommitMessagesGenerated   counter.Counter
    SuccessfulCommits        counter.Counter
    FailedOperations         counter.Counter
    
    // Performance metrics
    GenerationLatency        histogram.Histogram
    ClaudeAPILatency        histogram.Histogram
    GitOperationLatency     histogram.Histogram
    
    // Error metrics
    ErrorsByType            counter.CounterVec
    RateLimitHits          counter.Counter
}
```

### Logging Strategy

1. **Structured Logging**: JSON-formatted logs with contextual information
2. **Operation Tracing**: Trace requests through the entire pipeline
3. **Error Tracking**: Detailed error logging with stack traces
4. **Performance Monitoring**: Latency and throughput metrics
5. **Security Auditing**: Security-relevant event logging

## Testing Architecture

### Test Structure

```
pkg/github/
├── auto_commit_test.go          # Unit tests for auto-commit tools
├── claude_client_test.go        # Claude client unit tests
├── commit_analyzer_test.go      # Analysis logic tests
├── template_manager_test.go     # Template management tests
├── integration_test.go          # Integration tests
└── testdata/
    ├── sample_diffs/
    ├── expected_messages/
    └── test_templates/
```

### Testing Strategy

1. **Unit Tests**: Individual component testing with mocks
2. **Integration Tests**: End-to-end workflow testing
3. **Performance Tests**: Load testing and performance validation
4. **Security Tests**: Authentication and authorization testing
5. **Compatibility Tests**: Cross-platform and version compatibility

## Deployment Architecture

### Container Integration

```dockerfile
# Extension to existing GitHub MCP server Dockerfile
FROM existing-github-mcp-server:latest

# Add Claude Code SDK dependencies
RUN go mod download github.com/claude-sdk/go-client

# Add auto-commit specific configurations
COPY auto-commit-config.yaml /app/config/

# Environment variables for Claude API
ENV CLAUDE_API_KEY=""
ENV CLAUDE_BASE_URL="https://api.anthropic.com"
ENV AUTO_COMMIT_ENABLED="true"
```

### Configuration Management

1. **Environment Variables**: Secure credential management
2. **Configuration Files**: Flexible configuration options
3. **Runtime Configuration**: Dynamic configuration updates
4. **Secrets Management**: Secure API key handling

## Future Architecture Considerations

### Scalability Enhancements

1. **Microservice Architecture**: Potential separation of auto-commit functionality
2. **Distributed Caching**: Redis-based caching for multi-instance deployments
3. **Queue-Based Processing**: Asynchronous commit message generation
4. **Load Balancing**: Multiple server instances for high availability

### Extension Points

1. **Plugin Architecture**: Support for custom commit message generators
2. **Webhook Integration**: Integration with CI/CD pipelines
3. **Multi-Provider Support**: Support for other AI providers
4. **Advanced Analytics**: Commit quality analysis and metrics

## Conclusion

This architecture provides a robust foundation for integrating claude-auto-commit functionality into the GitHub MCP server. The design maintains consistency with existing patterns while adding powerful AI capabilities. The modular approach ensures maintainability and extensibility, while the comprehensive error handling and security measures ensure production readiness.

The architecture supports both immediate needs and future enhancements, providing a solid foundation for AI-powered Git workflow automation within the MCP ecosystem.