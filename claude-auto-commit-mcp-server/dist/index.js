#!/usr/bin/env node
"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const index_js_1 = require("@modelcontextprotocol/sdk/server/index.js");
const stdio_js_1 = require("@modelcontextprotocol/sdk/server/stdio.js");
const types_js_1 = require("@modelcontextprotocol/sdk/types.js");
const child_process_1 = require("child_process");
const simple_git_1 = __importDefault(require("simple-git"));
const claude_client_js_1 = require("./claude-client.js");
const review_engine_js_1 = require("./review-engine.js");
class ClaudeAutoCommitServer {
    server;
    claudeClient = null;
    git;
    workingDir;
    defaultReviewConfig;
    constructor() {
        this.server = new index_js_1.Server({
            name: 'claude-auto-commit-server',
            version: '1.0.0',
        }, {
            capabilities: {
                tools: {},
            },
        });
        this.workingDir = process.cwd();
        this.git = (0, simple_git_1.default)(this.workingDir);
        // Default review configuration
        this.defaultReviewConfig = {
            enabled: true,
            depth: 'standard',
            auto_approve_safe_changes: false,
            timeout_ms: 30000,
            fail_on_warnings: false,
            require_task_verification: true,
            require_documentation_check: true,
            require_test_validation: true
        };
        this.setupToolHandlers();
    }
    setupToolHandlers() {
        this.server.setRequestHandler(types_js_1.ListToolsRequestSchema, async () => ({
            tools: [
                {
                    name: 'generate_commit_message',
                    description: 'Generate AI-powered commit messages based on repository changes using Claude',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            language: {
                                type: 'string',
                                enum: ['en', 'ja', 'fr', 'de', 'es'],
                                description: 'Message language',
                                default: 'en'
                            },
                            conventional_commits: {
                                type: 'boolean',
                                description: 'Use conventional commits format',
                                default: false
                            },
                            include_emoji: {
                                type: 'boolean',
                                description: 'Include emojis in commit messages',
                                default: false
                            },
                            template: {
                                type: 'string',
                                description: 'Template name to use for message generation'
                            },
                            max_length: {
                                type: 'integer',
                                description: 'Maximum commit message length',
                                default: 72
                            },
                            generate_count: {
                                type: 'integer',
                                description: 'Number of alternative messages to generate',
                                default: 1,
                                maximum: 5
                            },
                            context_lines: {
                                type: 'integer',
                                description: 'Number of context lines to include in diff analysis',
                                default: 3
                            },
                            analyze_file_types: {
                                type: 'array',
                                items: { type: 'string' },
                                description: 'File types to analyze specifically'
                            }
                        }
                    }
                },
                {
                    name: 'auto_stage_and_commit',
                    description: 'Automatically stage changes and create commits with AI-generated messages and pre-commit review',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            message: {
                                type: 'string',
                                description: 'Commit message (if not provided, will be auto-generated)'
                            },
                            message_config: {
                                type: 'object',
                                description: 'Configuration for message generation',
                                properties: {
                                    language: { type: 'string', enum: ['en', 'ja', 'fr', 'de', 'es'] },
                                    template: { type: 'string' },
                                    conventional_commits: { type: 'boolean' },
                                    include_emoji: { type: 'boolean' }
                                }
                            },
                            stage_options: {
                                type: 'object',
                                description: 'Configuration for staging',
                                properties: {
                                    patterns: {
                                        type: 'array',
                                        items: { type: 'string' },
                                        description: 'File patterns to include'
                                    },
                                    exclude_patterns: {
                                        type: 'array',
                                        items: { type: 'string' },
                                        description: 'File patterns to exclude'
                                    },
                                    auto_detect: {
                                        type: 'boolean',
                                        description: 'Auto-detect relevant files',
                                        default: true
                                    }
                                }
                            },
                            enable_pre_commit_review: {
                                type: 'boolean',
                                description: 'Enable pre-commit review',
                                default: true
                            },
                            review_config: {
                                type: 'object',
                                description: 'Pre-commit review configuration',
                                properties: {
                                    depth: { type: 'string', enum: ['basic', 'standard', 'comprehensive'] },
                                    auto_approve_safe_changes: { type: 'boolean' },
                                    fail_on_warnings: { type: 'boolean' },
                                    require_task_verification: { type: 'boolean' },
                                    require_documentation_check: { type: 'boolean' },
                                    require_test_validation: { type: 'boolean' }
                                }
                            },
                            dry_run: {
                                type: 'boolean',
                                description: 'Preview changes without committing',
                                default: false
                            }
                        }
                    }
                },
                {
                    name: 'smart_commit',
                    description: 'Advanced commit generation with deep analysis, workflow integration, and comprehensive pre-commit review',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            analysis_depth: {
                                type: 'string',
                                enum: ['basic', 'standard', 'deep', 'comprehensive'],
                                description: 'Analysis depth',
                                default: 'standard'
                            },
                            template_name: {
                                type: 'string',
                                description: 'Template to use'
                            },
                            auto_stage: {
                                type: 'boolean',
                                description: 'Automatically stage files',
                                default: true
                            },
                            require_confirmation: {
                                type: 'boolean',
                                description: 'Require user confirmation',
                                default: false
                            },
                            generate_suggestions: {
                                type: 'boolean',
                                description: 'Generate improvement suggestions',
                                default: true
                            },
                            include_pre_commit_review: {
                                type: 'boolean',
                                description: 'Include pre-commit review in analysis',
                                default: true
                            },
                            require_review_approval: {
                                type: 'boolean',
                                description: 'Require review approval before committing',
                                default: true
                            },
                            dry_run: {
                                type: 'boolean',
                                description: 'Perform analysis without committing',
                                default: false
                            }
                        }
                    }
                }
            ]
        }));
        this.server.setRequestHandler(types_js_1.CallToolRequestSchema, async (request) => {
            try {
                const { name, arguments: args } = request.params;
                switch (name) {
                    case 'generate_commit_message':
                        return await this.handleGenerateCommitMessage(args);
                    case 'auto_stage_and_commit':
                        return await this.handleAutoStageAndCommit(args);
                    case 'smart_commit':
                        return await this.handleSmartCommit(args);
                    default:
                        throw new types_js_1.McpError(types_js_1.ErrorCode.MethodNotFound, `Unknown tool: ${name}`);
                }
            }
            catch (error) {
                if (error instanceof types_js_1.McpError) {
                    throw error;
                }
                throw new types_js_1.McpError(types_js_1.ErrorCode.InternalError, `Tool execution failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
            }
        });
    }
    async initializeClaudeClient() {
        if (this.claudeClient)
            return;
        // Try API key first (for backwards compatibility)
        const apiKey = process.env.ANTHROPIC_API_KEY || process.env.CLAUDE_API_KEY;
        // Try username/password (like Claude Code)
        const username = process.env.CLAUDE_USERNAME || process.env.CLAUDE_EMAIL;
        const password = process.env.CLAUDE_PASSWORD;
        if (apiKey) {
            console.log('Using Claude API key authentication');
            this.claudeClient = new claude_client_js_1.ClaudeCommitClient({ apiKey });
        }
        else if (username && password) {
            console.log('Using Claude username/password authentication (like Claude Code)');
            this.claudeClient = new claude_client_js_1.ClaudeCommitClient({ username, password });
        }
        else {
            throw new types_js_1.McpError(types_js_1.ErrorCode.InvalidRequest, 'Claude authentication not found. Set either:\n' +
                '  - ANTHROPIC_API_KEY or CLAUDE_API_KEY (for API key auth)\n' +
                '  - CLAUDE_USERNAME/CLAUDE_EMAIL and CLAUDE_PASSWORD (for web auth like Claude Code)');
        }
    }
    async handleGenerateCommitMessage(args) {
        await this.initializeClaudeClient();
        const config = {
            language: args.language || 'en',
            conventional_commits: args.conventional_commits || false,
            include_emoji: args.include_emoji || false,
            template: args.template,
            max_length: args.max_length || 72
        };
        // Get staged changes
        const diffEntries = await this.getStagedChanges();
        if (diffEntries.length === 0) {
            throw new types_js_1.McpError(types_js_1.ErrorCode.InvalidRequest, 'No staged changes found. Stage some changes first with: git add');
        }
        const result = await this.claudeClient.generateCommitMessage(diffEntries, config);
        return {
            content: [
                {
                    type: 'text',
                    text: JSON.stringify(result, null, 2)
                }
            ]
        };
    }
    async handleAutoStageAndCommit(args) {
        await this.initializeClaudeClient();
        const enableReview = args.enable_pre_commit_review !== false;
        const reviewConfig = {
            ...this.defaultReviewConfig,
            ...args.review_config
        };
        const stageOptions = {
            auto_detect: true,
            ...args.stage_options
        };
        const messageConfig = {
            language: 'en',
            conventional_commits: false,
            include_emoji: false,
            ...args.message_config
        };
        try {
            // Step 1: Stage files
            await this.stageFiles(stageOptions);
            // Step 2: Get staged changes
            const diffEntries = await this.getStagedChanges();
            if (diffEntries.length === 0) {
                throw new types_js_1.McpError(types_js_1.ErrorCode.InvalidRequest, 'No changes to commit after staging');
            }
            let preCommitReview;
            // Step 3: Pre-commit review
            if (enableReview) {
                const reviewEngine = new review_engine_js_1.PreCommitReviewEngine(reviewConfig, this.workingDir);
                preCommitReview = await reviewEngine.performReview();
                if (!preCommitReview.commit_approved) {
                    const response = {
                        success: false,
                        message: 'Commit rejected by pre-commit review',
                        pre_commit_review: preCommitReview
                    };
                    return {
                        content: [
                            {
                                type: 'text',
                                text: JSON.stringify(response, null, 2)
                            }
                        ]
                    };
                }
            }
            if (args.dry_run) {
                const response = {
                    success: true,
                    message: 'Dry run completed - no commit made',
                    files_staged: diffEntries.map(e => e.file),
                    changes_summary: {
                        files_modified: diffEntries.length,
                        lines_added: diffEntries.reduce((sum, e) => sum + e.additions, 0),
                        lines_removed: diffEntries.reduce((sum, e) => sum + e.deletions, 0)
                    },
                    pre_commit_review: preCommitReview
                };
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify(response, null, 2)
                        }
                    ]
                };
            }
            // Step 4: Generate commit message
            let commitMessage = args.message;
            if (!commitMessage) {
                const messageResult = await this.claudeClient.generateCommitMessage(diffEntries, messageConfig);
                commitMessage = messageResult.message;
            }
            // Step 5: Create commit
            const commitResult = await this.git.commit(commitMessage);
            const response = {
                success: true,
                commit_sha: commitResult.commit,
                message: commitMessage,
                files_staged: diffEntries.map(e => e.file),
                changes_summary: {
                    files_modified: diffEntries.length,
                    lines_added: diffEntries.reduce((sum, e) => sum + e.additions, 0),
                    lines_removed: diffEntries.reduce((sum, e) => sum + e.deletions, 0)
                },
                pre_commit_review: preCommitReview,
                pushed: false,
                commit_url: `https://github.com/${await this.getRepoInfo()}/commit/${commitResult.commit}`
            };
            return {
                content: [
                    {
                        type: 'text',
                        text: JSON.stringify(response, null, 2)
                    }
                ]
            };
        }
        catch (error) {
            throw new types_js_1.McpError(types_js_1.ErrorCode.InternalError, `Auto-commit failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
        }
    }
    async handleSmartCommit(args) {
        await this.initializeClaudeClient();
        const includeReview = args.include_pre_commit_review !== false;
        const requireReviewApproval = args.require_review_approval !== false;
        // Enhanced review config for comprehensive analysis
        const reviewConfig = {
            ...this.defaultReviewConfig,
            depth: 'comprehensive',
            require_task_verification: true,
            require_documentation_check: true,
            require_test_validation: true
        };
        try {
            // Stage files if requested
            if (args.auto_stage) {
                await this.stageFiles({ auto_detect: true });
            }
            const diffEntries = await this.getStagedChanges();
            if (diffEntries.length === 0) {
                throw new types_js_1.McpError(types_js_1.ErrorCode.InvalidRequest, 'No staged changes found for smart commit');
            }
            let preCommitReview;
            // Comprehensive pre-commit review
            if (includeReview) {
                const reviewEngine = new review_engine_js_1.PreCommitReviewEngine(reviewConfig, this.workingDir);
                preCommitReview = await reviewEngine.performReview();
                if (requireReviewApproval && !preCommitReview.commit_approved) {
                    const response = {
                        success: false,
                        message: 'Smart commit rejected by comprehensive review',
                        analysis: {
                            change_type: 'review_failure',
                            complexity: 'high',
                            impact: 'blocked',
                            confidence: 0,
                            recommendations: preCommitReview.recommendations
                        },
                        pre_commit_review: preCommitReview,
                        workflow_integration: {
                            suggested_next_steps: [
                                'Address critical and high-priority review findings',
                                'Update documentation if needed',
                                'Ensure all tests are meaningful',
                                'Verify task completion status'
                            ],
                            blocked_reasons: preCommitReview.findings
                                .filter(f => f.severity === 'critical' || f.severity === 'high')
                                .map(f => f.message)
                        }
                    };
                    return {
                        content: [
                            {
                                type: 'text',
                                text: JSON.stringify(response, null, 2)
                            }
                        ]
                    };
                }
            }
            if (args.dry_run) {
                // Generate analysis without committing
                const messageResult = await this.claudeClient.generateCommitMessage(diffEntries, {
                    conventional_commits: true,
                    language: 'en'
                });
                const response = {
                    success: true,
                    message: 'Smart commit analysis completed - no commit made',
                    analysis: messageResult.analysis,
                    pre_commit_review: preCommitReview,
                    workflow_integration: {
                        suggested_next_steps: this.generateWorkflowSteps(messageResult.analysis, preCommitReview),
                        commit_readiness: preCommitReview ? preCommitReview.commit_approved : true,
                        estimated_risk: this.assessRisk(messageResult.analysis, preCommitReview)
                    }
                };
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify(response, null, 2)
                        }
                    ]
                };
            }
            // Generate optimized commit message
            const messageResult = await this.claudeClient.generateCommitMessage(diffEntries, {
                conventional_commits: true,
                language: 'en',
                max_length: 72
            });
            // Create the commit
            const commitResult = await this.git.commit(messageResult.message);
            const response = {
                success: true,
                commit_sha: commitResult.commit,
                message: messageResult.message,
                analysis: messageResult.analysis,
                pre_commit_review: preCommitReview,
                workflow_integration: {
                    suggested_next_steps: this.generateWorkflowSteps(messageResult.analysis, preCommitReview),
                    commit_url: `https://github.com/${await this.getRepoInfo()}/commit/${commitResult.commit}`,
                    follow_up_actions: this.generateFollowUpActions(messageResult.analysis)
                }
            };
            return {
                content: [
                    {
                        type: 'text',
                        text: JSON.stringify(response, null, 2)
                    }
                ]
            };
        }
        catch (error) {
            throw new types_js_1.McpError(types_js_1.ErrorCode.InternalError, `Smart commit failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
        }
    }
    async getStagedChanges() {
        try {
            const diffOutput = (0, child_process_1.execSync)('git diff --cached --name-status', {
                cwd: this.workingDir,
                encoding: 'utf8'
            });
            const entries = [];
            const lines = diffOutput.trim().split('\n').filter(line => line.trim());
            for (const line of lines) {
                const [status, ...fileParts] = line.split('\t');
                const file = fileParts.join('\t');
                if (!file)
                    continue;
                try {
                    const fileStats = (0, child_process_1.execSync)(`git diff --cached --numstat "${file}"`, {
                        cwd: this.workingDir,
                        encoding: 'utf8'
                    }).trim();
                    const [additions = '0', deletions = '0'] = fileStats.split('\t');
                    const content = (0, child_process_1.execSync)(`git diff --cached "${file}"`, {
                        cwd: this.workingDir,
                        encoding: 'utf8'
                    });
                    entries.push({
                        file,
                        status: status,
                        additions: parseInt(additions) || 0,
                        deletions: parseInt(deletions) || 0,
                        content
                    });
                }
                catch (error) {
                    entries.push({
                        file,
                        status: status,
                        additions: 0,
                        deletions: 0,
                        content: ''
                    });
                }
            }
            return entries;
        }
        catch (error) {
            return [];
        }
    }
    async stageFiles(options) {
        if (options.auto_detect) {
            // Stage all modified files
            await this.git.add('.');
        }
        else if (options.patterns && options.patterns.length > 0) {
            // Stage specific patterns
            for (const pattern of options.patterns) {
                await this.git.add(pattern);
            }
        }
    }
    generateWorkflowSteps(analysis, review) {
        const steps = [];
        if (review && review.findings.length > 0) {
            steps.push('Review and address findings from pre-commit analysis');
        }
        if (analysis.change_type === 'feat') {
            steps.push('Consider updating documentation for new features');
            steps.push('Add or update tests for new functionality');
        }
        if (analysis.complexity === 'high') {
            steps.push('Consider breaking down complex changes into smaller commits');
            steps.push('Run comprehensive tests before merging');
        }
        if (analysis.breaking_changes) {
            steps.push('Update version numbers for breaking changes');
            steps.push('Update changelog with breaking change details');
            steps.push('Notify team of breaking changes');
        }
        return steps;
    }
    generateFollowUpActions(analysis) {
        const actions = [];
        if (analysis.change_type === 'feat') {
            actions.push('Consider creating pull request for review');
            actions.push('Update project documentation if needed');
        }
        if (analysis.files_modified > 5) {
            actions.push('Run integration tests');
            actions.push('Check for unexpected side effects');
        }
        return actions;
    }
    assessRisk(analysis, review) {
        if (review && review.findings.some(f => f.severity === 'critical')) {
            return 'high';
        }
        if (analysis.breaking_changes || analysis.complexity === 'high') {
            return 'high';
        }
        if (analysis.complexity === 'moderate' || analysis.files_modified > 3) {
            return 'medium';
        }
        return 'low';
    }
    async getRepoInfo() {
        try {
            const remotes = await this.git.getRemotes(true);
            const origin = remotes.find(r => r.name === 'origin');
            if (origin && origin.refs.fetch) {
                const match = origin.refs.fetch.match(/github\.com[:/]([^/]+)\/(.+?)(?:\.git)?$/);
                if (match) {
                    return `${match[1]}/${match[2]}`;
                }
            }
            return 'unknown/repo';
        }
        catch {
            return 'unknown/repo';
        }
    }
    async run() {
        const transport = new stdio_js_1.StdioServerTransport();
        await this.server.connect(transport);
    }
}
const server = new ClaudeAutoCommitServer();
server.run().catch(console.error);
