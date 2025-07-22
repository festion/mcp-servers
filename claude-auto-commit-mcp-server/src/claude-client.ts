import Anthropic from '@anthropic-ai/sdk';
import { CommitMessageResponse, CommitAnalysis, MessageConfig, GitDiffEntry } from './types';

interface ClaudeAuth {
  username?: string;
  password?: string;
  apiKey?: string;
}

export class ClaudeCommitClient {
  private client: Anthropic | null = null;
  private auth: ClaudeAuth;
  private sessionToken: string | null = null;
  
  constructor(auth: ClaudeAuth) {
    this.auth = auth;
    this.initializeClient();
  }

  private async initializeClient() {
    if (this.auth.apiKey) {
      // Use API key if provided
      this.client = new Anthropic({
        apiKey: this.auth.apiKey,
      });
    } else if (this.auth.username && this.auth.password) {
      // Use username/password authentication like Claude Code
      await this.authenticateWithCredentials();
    } else {
      throw new Error('Either API key or username/password must be provided');
    }
  }

  private async authenticateWithCredentials(): Promise<void> {
    try {
      // Simulate Claude Code's authentication flow
      // In practice, this would use Claude's web authentication endpoints
      console.log(`Authenticating with Claude using username: ${this.auth.username}`);
      
      // Mock authentication - replace with actual Claude web auth flow
      const authResponse = await this.performWebAuthentication();
      
      if (authResponse.success && authResponse.sessionToken) {
        this.sessionToken = authResponse.sessionToken;
        
        // Create client with session-based authentication
        this.client = new Anthropic({
          apiKey: this.sessionToken, // Use session token as API key
          baseURL: 'https://claude.ai/api', // Claude web API endpoint
        });
      } else {
        throw new Error('Authentication failed');
      }
    } catch (error) {
      throw new Error(`Claude authentication failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  private async performWebAuthentication(): Promise<{success: boolean, sessionToken?: string}> {
    // This simulates the Claude Code authentication flow
    // In a real implementation, this would:
    // 1. Make a POST request to Claude's login endpoint
    // 2. Handle 2FA if required
    // 3. Extract session cookies/tokens
    // 4. Return the authentication token
    
    const authPayload = {
      email_address: this.auth.username,
      password: this.auth.password,
    };

    try {
      // Mock successful authentication
      // Replace with actual fetch to Claude's auth endpoints
      console.log('Performing web authentication...');
      
      // Simulate network delay
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // For demo purposes, generate a mock session token
      const mockSessionToken = `claude_session_${Date.now()}_${Math.random().toString(36).substring(2)}`;
      
      return {
        success: true,
        sessionToken: mockSessionToken
      };
      
    } catch (error) {
      console.error('Authentication error:', error);
      return { success: false };
    }
  }

  private async ensureAuthenticated(): Promise<void> {
    if (!this.client) {
      await this.initializeClient();
    }
    
    // Check if session is still valid (for username/password auth)
    if (this.sessionToken && !this.auth.apiKey) {
      const isValid = await this.validateSession();
      if (!isValid) {
        console.log('Session expired, re-authenticating...');
        await this.authenticateWithCredentials();
      }
    }
  }

  private async validateSession(): Promise<boolean> {
    try {
      // Simple validation - try a small API call
      if (!this.client) return false;
      
      // Mock session validation
      return true;
    } catch (error) {
      return false;
    }
  }

  async generateCommitMessage(
    diffEntries: GitDiffEntry[],
    config: MessageConfig = {}
  ): Promise<CommitMessageResponse> {
    await this.ensureAuthenticated();
    
    const startTime = Date.now();
    
    const {
      language = 'en',
      conventional_commits = false,
      include_emoji = false,
      max_length = 72,
      template
    } = config;

    // Analyze the changes
    const analysis = this.analyzeDiff(diffEntries);
    
    // Build the prompt
    const prompt = this.buildCommitMessagePrompt(diffEntries, analysis, {
      language,
      conventional_commits,
      include_emoji,
      max_length,
      template
    });

    try {
      if (!this.client) {
        throw new Error('Claude client not initialized');
      }

      const response = await this.client.messages.create({
        model: 'claude-3-sonnet-20240229',
        max_tokens: 1000,
        temperature: 0.3,
        messages: [
          {
            role: 'user',
            content: prompt
          }
        ]
      });

      const content = response.content[0];
      if (content.type !== 'text') {
        throw new Error('Unexpected response type from Claude API');
      }

      // Parse Claude's response
      const result = this.parseCommitResponse(content.text);
      
      return {
        message: result.primary_message,
        confidence: result.confidence,
        alternative_messages: result.alternative_messages,
        analysis,
        generated_at: new Date().toISOString(),
        model_used: 'claude-3-sonnet-20240229',
        tokens_used: response.usage.input_tokens + response.usage.output_tokens,
        processing_time: `${(Date.now() - startTime) / 1000}s`
      };
      
    } catch (error) {
      throw new Error(`Claude API error: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  private analyzeDiff(diffEntries: GitDiffEntry[]): CommitAnalysis {
    const totalAdditions = diffEntries.reduce((sum, entry) => sum + entry.additions, 0);
    const totalDeletions = diffEntries.reduce((sum, entry) => sum + entry.deletions, 0);
    const filesModified = diffEntries.length;
    
    // Determine change type based on file patterns and content
    let changeType = 'chore';
    let scope = '';
    
    const hasNewFiles = diffEntries.some(entry => entry.status === 'added');
    const hasDeletedFiles = diffEntries.some(entry => entry.status === 'deleted');
    const hasTestFiles = diffEntries.some(entry => 
      entry.file.includes('test') || entry.file.includes('spec')
    );
    const hasDocFiles = diffEntries.some(entry => entry.file.endsWith('.md'));
    
    // Analyze file extensions to determine languages
    const languages = [...new Set(
      diffEntries.map(entry => {
        const ext = entry.file.split('.').pop()?.toLowerCase();
        switch (ext) {
          case 'js':
          case 'jsx': return 'javascript';
          case 'ts':
          case 'tsx': return 'typescript';
          case 'py': return 'python';
          case 'go': return 'go';
          case 'java': return 'java';
          case 'php': return 'php';
          case 'rb': return 'ruby';
          case 'rs': return 'rust';
          default: return ext || 'unknown';
        }
      })
    )];

    // Determine change type
    if (hasNewFiles && !hasDeletedFiles) {
      changeType = 'feat';
    } else if (hasDeletedFiles) {
      changeType = 'refactor';
    } else if (hasTestFiles && !diffEntries.some(entry => !entry.file.includes('test'))) {
      changeType = 'test';
    } else if (hasDocFiles && !diffEntries.some(entry => !entry.file.endsWith('.md'))) {
      changeType = 'docs';
    } else if (totalAdditions > totalDeletions * 2) {
      changeType = 'feat';
    } else if (totalDeletions > totalAdditions) {
      changeType = 'refactor';
    }

    // Determine complexity
    let complexity: 'low' | 'moderate' | 'high';
    if (filesModified <= 2 && totalAdditions + totalDeletions <= 50) {
      complexity = 'low';
    } else if (filesModified <= 5 && totalAdditions + totalDeletions <= 200) {
      complexity = 'moderate';
    } else {
      complexity = 'high';
    }

    // Determine impact
    let impact: 'minor' | 'major' | 'breaking';
    const hasApiChanges = diffEntries.some(entry => 
      entry.content.includes('export') || 
      entry.content.includes('public') ||
      entry.content.includes('interface')
    );
    
    if (hasApiChanges || hasDeletedFiles) {
      impact = 'major';
    } else {
      impact = 'minor';
    }

    // Check for breaking changes
    const breakingChanges = diffEntries.some(entry =>
      entry.content.includes('BREAKING CHANGE') ||
      entry.content.includes('breaking:') ||
      (hasDeletedFiles && entry.status === 'deleted')
    );

    return {
      change_type: changeType,
      scope,
      complexity,
      impact,
      files_modified: filesModified,
      lines_added: totalAdditions,
      lines_removed: totalDeletions,
      languages: languages.filter(lang => lang !== 'unknown'),
      breaking_changes: breakingChanges,
      summary: this.generateChangeSummary(diffEntries, changeType)
    };
  }

  private generateChangeSummary(diffEntries: GitDiffEntry[], changeType: string): string {
    const fileNames = diffEntries.map(entry => entry.file);
    const mainAreas = this.identifyMainAreas(fileNames);
    
    switch (changeType) {
      case 'feat':
        return `Implements new functionality in ${mainAreas.join(', ')}`;
      case 'fix':
        return `Fixes issues in ${mainAreas.join(', ')}`;
      case 'refactor':
        return `Refactors code in ${mainAreas.join(', ')}`;
      case 'test':
        return `Adds or updates tests for ${mainAreas.join(', ')}`;
      case 'docs':
        return `Updates documentation for ${mainAreas.join(', ')}`;
      default:
        return `Updates ${mainAreas.join(', ')}`;
    }
  }

  private identifyMainAreas(filePaths: string[]): string[] {
    const areas = new Set<string>();
    
    for (const path of filePaths) {
      const parts = path.split('/');
      if (parts.length > 1) {
        areas.add(parts[0]); // First directory
      } else {
        areas.add('root');
      }
    }
    
    return Array.from(areas).slice(0, 3); // Limit to 3 main areas
  }

  private buildCommitMessagePrompt(
    diffEntries: GitDiffEntry[],
    analysis: CommitAnalysis,
    config: MessageConfig
  ): string {
    const diffSummary = this.createDiffSummary(diffEntries);
    
    let prompt = `You are an expert developer assistant. Generate a commit message for the following changes.

CHANGE ANALYSIS:
- Type: ${analysis.change_type}
- Complexity: ${analysis.complexity}
- Files modified: ${analysis.files_modified}
- Lines added: ${analysis.lines_added}
- Lines removed: ${analysis.lines_removed}
- Languages: ${analysis.languages.join(', ')}
- Breaking changes: ${analysis.breaking_changes ? 'Yes' : 'No'}

DIFF SUMMARY:
${diffSummary}

REQUIREMENTS:
- Language: ${config.language}
- Max length: ${config.max_length} characters
- Conventional commits: ${config.conventional_commits ? 'Yes' : 'No'}
- Include emoji: ${config.include_emoji ? 'Yes' : 'No'}
`;

    if (config.template) {
      prompt += `- Template to follow: ${config.template}\n`;
    }

    prompt += `
Generate a JSON response with:
{
  "primary_message": "main commit message",
  "confidence": 0.95,
  "alternative_messages": ["alt1", "alt2", "alt3"]
}

The commit message should be clear, concise, and follow best practices.`;

    if (config.conventional_commits) {
      prompt += ` Use conventional commits format: type(scope): description`;
    }

    return prompt;
  }

  private createDiffSummary(diffEntries: GitDiffEntry[]): string {
    let summary = '';
    
    for (const entry of diffEntries.slice(0, 10)) { // Limit to first 10 files
      summary += `\n${entry.status.toUpperCase()}: ${entry.file} (+${entry.additions}, -${entry.deletions})`;
      
      if (entry.content) {
        // Include a few key lines from the diff
        const lines = entry.content.split('\n');
        const significantLines = lines
          .filter(line => (line.startsWith('+') || line.startsWith('-')) && !line.startsWith('+++') && !line.startsWith('---'))
          .slice(0, 3);
        
        if (significantLines.length > 0) {
          summary += '\n  Key changes:';
          significantLines.forEach(line => {
            summary += `\n    ${line}`;
          });
        }
      }
    }
    
    if (diffEntries.length > 10) {
      summary += `\n... and ${diffEntries.length - 10} more files`;
    }
    
    return summary;
  }

  private parseCommitResponse(response: string): {
    primary_message: string;
    confidence: number;
    alternative_messages: string[];
  } {
    try {
      // Try to parse as JSON first
      const parsed = JSON.parse(response);
      return {
        primary_message: parsed.primary_message || parsed.message || 'Update files',
        confidence: parsed.confidence || 0.8,
        alternative_messages: parsed.alternative_messages || []
      };
    } catch (error) {
      // If JSON parsing fails, extract manually
      const lines = response.split('\n');
      const primaryMessage = lines.find(line => 
        line.includes('primary_message') || 
        line.includes('message')
      )?.replace(/.*[:"]([^"]+)[",].*/, '$1') || 'Update files';
      
      return {
        primary_message: primaryMessage,
        confidence: 0.7,
        alternative_messages: []
      };
    }
  }
}