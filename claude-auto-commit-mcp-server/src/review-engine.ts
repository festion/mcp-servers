import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as Diff from 'diff';
import { glob } from 'glob';
import { minimatch } from 'minimatch';
import {
  PreCommitReviewResult,
  ReviewFinding,
  ReviewConfig,
  GitDiffEntry,
  TaskStatus,
  DocumentationFile
} from './types';

export class PreCommitReviewEngine {
  private config: ReviewConfig;
  private workingDir: string;

  constructor(config: ReviewConfig, workingDir: string = process.cwd()) {
    this.config = config;
    this.workingDir = workingDir;
  }

  async performReview(): Promise<PreCommitReviewResult> {
    const startTime = Date.now();
    const findings: ReviewFinding[] = [];
    const recommendations: string[] = [];

    try {
      // Get git diff
      const diffEntries = await this.getGitDiff();
      
      if (diffEntries.length === 0) {
        return {
          review_status: 'rejected',
          review_summary: 'No changes detected for commit',
          findings: [{
            category: 'diff_analysis',
            severity: 'critical',
            message: 'No changes found to commit',
            suggestion: 'Make some changes before attempting to commit'
          }],
          recommendations: ['Add files or make changes before committing'],
          commit_approved: false,
          review_duration: (Date.now() - startTime) / 1000
        };
      }

      // 1. Review the diff to check for problems and bugs
      const diffFindings = await this.analyzeDiffForProblems(diffEntries);
      findings.push(...diffFindings);

      // 2. Check task completion verification
      if (this.config.require_task_verification) {
        const taskFindings = await this.verifyTaskCompletion(diffEntries);
        findings.push(...taskFindings);
      }

      // 3. Check documentation alignment
      if (this.config.require_documentation_check) {
        const docFindings = await this.checkDocumentationAlignment(diffEntries);
        findings.push(...docFindings);
      }

      // 4. Report functionality removal
      const removalFindings = await this.detectFunctionalityRemoval(diffEntries);
      findings.push(...removalFindings);

      // 5. Check test quality
      if (this.config.require_test_validation) {
        const testQualityFindings = await this.assessTestQuality(diffEntries);
        findings.push(...testQualityFindings);

        // 6. Check test alignment
        const testAlignmentFindings = await this.verifyTestAlignment(diffEntries);
        findings.push(...testAlignmentFindings);

        // 7. Check test coverage
        const coverageFindings = await this.analyzeCoverageReduction(diffEntries);
        findings.push(...coverageFindings);
      }

      // Generate recommendations
      recommendations.push(...this.generateRecommendations(findings));

      // Determine review status
      const criticalCount = findings.filter(f => f.severity === 'critical').length;
      const highCount = findings.filter(f => f.severity === 'high').length;
      
      let reviewStatus: 'approved' | 'rejected' | 'warning';
      let commitApproved: boolean;

      if (criticalCount > 0) {
        reviewStatus = 'rejected';
        commitApproved = false;
      } else if (highCount > 0 && this.config.fail_on_warnings) {
        reviewStatus = 'rejected';
        commitApproved = false;
      } else if (highCount > 0 || findings.filter(f => f.severity === 'medium').length > 0) {
        reviewStatus = 'warning';
        commitApproved = this.config.auto_approve_safe_changes;
      } else {
        reviewStatus = 'approved';
        commitApproved = true;
      }

      const reviewSummary = this.generateReviewSummary(findings, diffEntries);

      return {
        review_status: reviewStatus,
        review_summary: reviewSummary,
        findings,
        recommendations,
        commit_approved: commitApproved,
        review_duration: (Date.now() - startTime) / 1000
      };

    } catch (error) {
      return {
        review_status: 'rejected',
        review_summary: `Review failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
        findings: [{
          category: 'diff_analysis',
          severity: 'critical',
          message: `Review engine error: ${error instanceof Error ? error.message : 'Unknown error'}`,
          suggestion: 'Check review engine configuration and try again'
        }],
        recommendations: ['Fix review engine issues before committing'],
        commit_approved: false,
        review_duration: (Date.now() - startTime) / 1000
      };
    }
  }

  private async getGitDiff(): Promise<GitDiffEntry[]> {
    try {
      const diffOutput = execSync('git diff --cached --name-status', { 
        cwd: this.workingDir, 
        encoding: 'utf8' 
      });
      
      const entries: GitDiffEntry[] = [];
      const lines = diffOutput.trim().split('\n').filter(line => line.trim());

      for (const line of lines) {
        const [status, ...fileParts] = line.split('\t');
        const file = fileParts.join('\t');
        
        if (!file) continue;

        try {
          const fileStats = execSync(`git diff --cached --numstat "${file}"`, {
            cwd: this.workingDir,
            encoding: 'utf8'
          }).trim();
          
          const [additions = '0', deletions = '0'] = fileStats.split('\t');
          
          const content = execSync(`git diff --cached "${file}"`, {
            cwd: this.workingDir,
            encoding: 'utf8'
          });

          entries.push({
            file,
            status: status as GitDiffEntry['status'],
            additions: parseInt(additions) || 0,
            deletions: parseInt(deletions) || 0,
            content
          });
        } catch (error) {
          // File might be binary or have other issues, add with minimal info
          entries.push({
            file,
            status: status as GitDiffEntry['status'],
            additions: 0,
            deletions: 0,
            content: ''
          });
        }
      }

      return entries;
    } catch (error) {
      return [];
    }
  }

  private async analyzeDiffForProblems(diffEntries: GitDiffEntry[]): Promise<ReviewFinding[]> {
    const findings: ReviewFinding[] = [];

    for (const entry of diffEntries) {
      const content = entry.content;
      const lines = content.split('\n');

      // Check for common issues
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        
        // Skip diff headers
        if (line.startsWith('@@') || line.startsWith('+++') || line.startsWith('---')) continue;
        
        // Only check added lines (starting with +)
        if (!line.startsWith('+')) continue;
        
        const actualLine = line.substring(1);
        
        // Check for debugging code
        if (actualLine.includes('console.log') || actualLine.includes('print(') || actualLine.includes('debug')) {
          findings.push({
            category: 'diff_analysis',
            severity: 'medium',
            message: 'Debugging code found in commit',
            file: entry.file,
            line: i + 1,
            suggestion: 'Remove debugging statements before committing'
          });
        }

        // Check for TODO/FIXME comments
        if (actualLine.includes('TODO') || actualLine.includes('FIXME') || actualLine.includes('HACK')) {
          findings.push({
            category: 'diff_analysis',
            severity: 'low',
            message: 'TODO/FIXME comment added',
            file: entry.file,
            line: i + 1,
            suggestion: 'Consider addressing TODO items or documenting why they\'re needed'
          });
        }

        // Check for hardcoded credentials or secrets
        const secretPatterns = [
          /password\s*[=:]\s*['""][^'""]+['""]?/i,
          /api[_-]?key\s*[=:]\s*['""][^'""]+['""]?/i,
          /secret\s*[=:]\s*['""][^'""]+['""]?/i,
          /token\s*[=:]\s*['""][^'""]+['""]?/i
        ];

        for (const pattern of secretPatterns) {
          if (pattern.test(actualLine)) {
            findings.push({
              category: 'diff_analysis',
              severity: 'critical',
              message: 'Potential hardcoded secret or credential detected',
              file: entry.file,
              line: i + 1,
              suggestion: 'Move secrets to environment variables or secure configuration'
            });
          }
        }

        // Check for syntax issues (basic)
        if (actualLine.includes('undefined') && actualLine.includes('===')) {
          findings.push({
            category: 'diff_analysis',
            severity: 'medium',
            message: 'Potential undefined check - consider safer patterns',
            file: entry.file,
            line: i + 1,
            suggestion: 'Use optional chaining or proper type guards'
          });
        }
      }
    }

    return findings;
  }

  private async verifyTaskCompletion(diffEntries: GitDiffEntry[]): Promise<ReviewFinding[]> {
    const findings: ReviewFinding[] = [];
    const taskFiles = diffEntries.filter(entry => 
      entry.file.includes('tasks.md') || 
      entry.file.includes('TODO.md') ||
      entry.file.includes('checklist')
    );

    for (const taskFile of taskFiles) {
      const tasks = this.extractTasksFromDiff(taskFile.content);
      
      for (const task of tasks) {
        if (task.completed) {
          // Check if there are corresponding implementation changes
          const hasImplementation = diffEntries.some(entry => 
            entry.file !== taskFile.file && 
            (entry.additions > 0 || entry.status === 'added')
          );
          
          if (!hasImplementation) {
            findings.push({
              category: 'task_verification',
              severity: 'high',
              message: `Task marked complete but no implementation changes found: "${task.description}"`,
              file: taskFile.file,
              line: task.line_number,
              suggestion: 'Verify the task is actually completed or uncheck it'
            });
          }
        }
      }
    }

    return findings;
  }

  private extractTasksFromDiff(diffContent: string): TaskStatus[] {
    const tasks: TaskStatus[] = [];
    const lines = diffContent.split('\n');
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      
      // Look for added lines with task markers
      if (line.startsWith('+') && (line.includes('- [x]') || line.includes('- [ ]'))) {
        const actualLine = line.substring(1);
        const completed = actualLine.includes('- [x]');
        const description = actualLine.replace(/^.*?- \[[x ]\]\s*/, '').trim();
        
        tasks.push({
          completed,
          description,
          line_number: i + 1,
          file: 'tasks.md' // Will be updated by caller
        });
      }
    }
    
    return tasks;
  }

  private async checkDocumentationAlignment(diffEntries: GitDiffEntry[]): Promise<ReviewFinding[]> {
    const findings: ReviewFinding[] = [];
    
    // Look for documentation files
    const docFiles = diffEntries.filter(entry => 
      entry.file.endsWith('.md') || 
      entry.file.includes('README') ||
      entry.file.includes('docs/')
    );

    // Look for code files
    const codeFiles = diffEntries.filter(entry => 
      entry.file.endsWith('.js') ||
      entry.file.endsWith('.ts') ||
      entry.file.endsWith('.py') ||
      entry.file.endsWith('.go') ||
      entry.file.endsWith('.java')
    );

    // If there are code changes but no doc updates, flag it
    if (codeFiles.length > 0 && docFiles.length === 0) {
      const hasSignificantChanges = codeFiles.some(file => 
        file.additions > 20 || file.status === 'added'
      );
      
      if (hasSignificantChanges) {
        findings.push({
          category: 'documentation_alignment',
          severity: 'medium',
          message: 'Significant code changes without documentation updates',
          suggestion: 'Consider updating README.md or relevant documentation files'
        });
      }
    }

    // Check for API changes in code
    for (const codeFile of codeFiles) {
      const hasApiChanges = this.detectApiChanges(codeFile.content);
      if (hasApiChanges && docFiles.length === 0) {
        findings.push({
          category: 'documentation_alignment',
          severity: 'high',
          message: 'API changes detected without documentation updates',
          file: codeFile.file,
          suggestion: 'Update API documentation to reflect changes'
        });
      }
    }

    return findings;
  }

  private detectApiChanges(diffContent: string): boolean {
    const apiPatterns = [
      /export\s+(function|class|interface|type)/,
      /public\s+(function|method)/,
      /\bapi\b.*[=:]/i,
      /route\s*\(/,
      /app\.(get|post|put|delete)/
    ];

    return apiPatterns.some(pattern => 
      diffContent.split('\n').some(line => 
        line.startsWith('+') && pattern.test(line)
      )
    );
  }

  private async detectFunctionalityRemoval(diffEntries: GitDiffEntry[]): Promise<ReviewFinding[]> {
    const findings: ReviewFinding[] = [];

    for (const entry of diffEntries) {
      if (entry.status === 'deleted') {
        findings.push({
          category: 'functionality_removal',
          severity: 'high',
          message: `File deleted: ${entry.file}`,
          file: entry.file,
          suggestion: 'Verify this file removal is intentional and update dependencies'
        });
        continue;
      }

      const removedLines = entry.content.split('\n').filter(line => line.startsWith('-'));
      const significantRemovals = removedLines.filter(line => {
        const actualLine = line.substring(1);
        return actualLine.includes('function ') ||
               actualLine.includes('class ') ||
               actualLine.includes('export ') ||
               actualLine.includes('def ') ||
               actualLine.includes('func ');
      });

      if (significantRemovals.length > 0) {
        findings.push({
          category: 'functionality_removal',
          severity: 'medium',
          message: `Functions/classes removed in ${entry.file}`,
          file: entry.file,
          suggestion: 'Verify these removals are intentional and won\'t break existing functionality'
        });
      }
    }

    return findings;
  }

  private async assessTestQuality(diffEntries: GitDiffEntry[]): Promise<ReviewFinding[]> {
    const findings: ReviewFinding[] = [];
    
    const testFiles = diffEntries.filter(entry => 
      entry.file.includes('test') ||
      entry.file.includes('spec') ||
      entry.file.endsWith('.test.js') ||
      entry.file.endsWith('.test.ts') ||
      entry.file.endsWith('.spec.js') ||
      entry.file.endsWith('.spec.ts')
    );

    for (const testFile of testFiles) {
      const lines = testFile.content.split('\n');
      
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        
        if (!line.startsWith('+')) continue;
        
        const actualLine = line.substring(1);
        
        // Check for placeholder tests
        if (actualLine.includes('// TODO') || actualLine.includes('pass') || actualLine.includes('true')) {
          const isPlaceholder = actualLine.includes('expect(true)') ||
                               actualLine.includes('assert(true)') ||
                               actualLine.includes('pass  # TODO');
          
          if (isPlaceholder) {
            findings.push({
              category: 'test_quality',
              severity: 'high',
              message: 'Placeholder test found - not validating actual behavior',
              file: testFile.file,
              line: i + 1,
              suggestion: 'Replace placeholder with meaningful test assertions'
            });
          }
        }

        // Check for skipped tests
        if (actualLine.includes('.skip') || actualLine.includes('@skip') || actualLine.includes('x.describe')) {
          findings.push({
            category: 'test_quality',
            severity: 'medium',
            message: 'Skipped test found',
            file: testFile.file,
            line: i + 1,
            suggestion: 'Enable or remove skipped tests'
          });
        }
      }
    }

    return findings;
  }

  private async verifyTestAlignment(diffEntries: GitDiffEntry[]): Promise<ReviewFinding[]> {
    const findings: ReviewFinding[] = [];
    
    // This is a simplified version - in practice, you'd need more sophisticated analysis
    const testFiles = diffEntries.filter(entry => 
      entry.file.includes('test') || entry.file.includes('spec')
    );

    for (const testFile of testFiles) {
      const removedAssertions = testFile.content.split('\n').filter(line => 
        line.startsWith('-') && 
        (line.includes('expect') || line.includes('assert') || line.includes('should'))
      );

      if (removedAssertions.length > 0) {
        findings.push({
          category: 'test_alignment',
          severity: 'medium',
          message: 'Test assertions were removed or modified',
          file: testFile.file,
          suggestion: 'Verify that test changes still validate correct behavior'
        });
      }
    }

    return findings;
  }

  private async analyzeCoverageReduction(diffEntries: GitDiffEntry[]): Promise<ReviewFinding[]> {
    const findings: ReviewFinding[] = [];

    const testFiles = diffEntries.filter(entry => 
      entry.file.includes('test') || entry.file.includes('spec')
    );

    // Count deleted test files
    const deletedTestFiles = testFiles.filter(entry => entry.status === 'deleted');
    
    if (deletedTestFiles.length > 0) {
      findings.push({
        category: 'test_coverage',
        severity: 'high',
        message: `${deletedTestFiles.length} test file(s) deleted`,
        suggestion: 'Verify that test coverage is maintained through other tests'
      });
    }

    // Count reduced test content
    for (const testFile of testFiles) {
      if (testFile.deletions > testFile.additions * 2) {
        findings.push({
          category: 'test_coverage',
          severity: 'medium',
          message: 'Significant test content reduction detected',
          file: testFile.file,
          suggestion: 'Verify that test coverage hasn\'t been reduced inappropriately'
        });
      }
    }

    return findings;
  }

  private generateRecommendations(findings: ReviewFinding[]): string[] {
    const recommendations: string[] = [];
    
    const criticalCount = findings.filter(f => f.severity === 'critical').length;
    const highCount = findings.filter(f => f.severity === 'high').length;

    if (criticalCount > 0) {
      recommendations.push('Address all critical issues before committing');
    }

    if (highCount > 0) {
      recommendations.push('Review and resolve high-priority findings');
    }

    const categories = [...new Set(findings.map(f => f.category))];
    
    if (categories.includes('test_quality') || categories.includes('test_coverage')) {
      recommendations.push('Ensure all tests are meaningful and provide adequate coverage');
    }

    if (categories.includes('documentation_alignment')) {
      recommendations.push('Update documentation to reflect code changes');
    }

    if (categories.includes('functionality_removal')) {
      recommendations.push('Verify that removed functionality won\'t break existing systems');
    }

    return recommendations;
  }

  private generateReviewSummary(findings: ReviewFinding[], diffEntries: GitDiffEntry[]): string {
    const totalFiles = diffEntries.length;
    const totalAdditions = diffEntries.reduce((sum, entry) => sum + entry.additions, 0);
    const totalDeletions = diffEntries.reduce((sum, entry) => sum + entry.deletions, 0);
    
    const criticalCount = findings.filter(f => f.severity === 'critical').length;
    const highCount = findings.filter(f => f.severity === 'high').length;
    const mediumCount = findings.filter(f => f.severity === 'medium').length;

    let summary = `Reviewed ${totalFiles} file(s) with ${totalAdditions} additions and ${totalDeletions} deletions. `;
    
    if (criticalCount > 0) {
      summary += `Found ${criticalCount} critical issue(s). `;
    }
    
    if (highCount > 0) {
      summary += `Found ${highCount} high-priority issue(s). `;
    }
    
    if (mediumCount > 0) {
      summary += `Found ${mediumCount} medium-priority issue(s). `;
    }

    if (findings.length === 0) {
      summary += 'No issues detected.';
    }

    return summary;
  }
}