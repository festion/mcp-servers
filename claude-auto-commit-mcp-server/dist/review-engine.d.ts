import { PreCommitReviewResult, ReviewConfig } from './types';
export declare class PreCommitReviewEngine {
    private config;
    private workingDir;
    constructor(config: ReviewConfig, workingDir?: string);
    performReview(): Promise<PreCommitReviewResult>;
    private getGitDiff;
    private analyzeDiffForProblems;
    private verifyTaskCompletion;
    private extractTasksFromDiff;
    private checkDocumentationAlignment;
    private detectApiChanges;
    private detectFunctionalityRemoval;
    private assessTestQuality;
    private verifyTestAlignment;
    private analyzeCoverageReduction;
    private generateRecommendations;
    private generateReviewSummary;
}
