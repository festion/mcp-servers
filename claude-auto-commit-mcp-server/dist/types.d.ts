export interface ReviewFinding {
    category: 'diff_analysis' | 'task_verification' | 'documentation_alignment' | 'functionality_removal' | 'test_quality' | 'test_alignment' | 'test_coverage';
    severity: 'critical' | 'high' | 'medium' | 'low' | 'info';
    message: string;
    file?: string;
    line?: number;
    suggestion?: string;
}
export interface PreCommitReviewResult {
    review_status: 'approved' | 'rejected' | 'warning';
    review_summary: string;
    findings: ReviewFinding[];
    recommendations: string[];
    commit_approved: boolean;
    review_duration: number;
}
export interface CommitAnalysis {
    change_type: string;
    scope?: string;
    complexity: 'low' | 'moderate' | 'high';
    impact: 'minor' | 'major' | 'breaking';
    files_modified: number;
    lines_added: number;
    lines_removed: number;
    languages: string[];
    breaking_changes: boolean;
    summary: string;
}
export interface CommitMessageResponse {
    message: string;
    confidence: number;
    alternative_messages: string[];
    analysis: CommitAnalysis;
    generated_at: string;
    model_used: string;
    tokens_used: number;
    processing_time: string;
}
export interface CommitResponse {
    success: boolean;
    commit_sha?: string;
    message: string;
    files_staged?: string[];
    changes_summary?: {
        files_modified: number;
        lines_added: number;
        lines_removed: number;
    };
    pre_commit_review?: PreCommitReviewResult;
    pushed?: boolean;
    commit_url?: string;
}
export interface MessageConfig {
    language?: 'en' | 'ja' | 'fr' | 'de' | 'es';
    template?: string;
    conventional_commits?: boolean;
    include_emoji?: boolean;
    max_length?: number;
}
export interface StageOptions {
    patterns?: string[];
    exclude_patterns?: string[];
    auto_detect?: boolean;
}
export interface ReviewConfig {
    enabled: boolean;
    depth: 'basic' | 'standard' | 'comprehensive';
    auto_approve_safe_changes: boolean;
    timeout_ms: number;
    fail_on_warnings: boolean;
    require_task_verification: boolean;
    require_documentation_check: boolean;
    require_test_validation: boolean;
}
export interface GitDiffEntry {
    file: string;
    status: 'added' | 'modified' | 'deleted' | 'renamed';
    additions: number;
    deletions: number;
    content: string;
}
export interface TaskStatus {
    completed: boolean;
    description: string;
    line_number: number;
    file: string;
}
export interface DocumentationFile {
    path: string;
    content: string;
    last_modified: Date;
}
