import { CommitMessageResponse, MessageConfig, GitDiffEntry } from './types';
interface ClaudeAuth {
    username?: string;
    password?: string;
    apiKey?: string;
}
export declare class ClaudeCommitClient {
    private client;
    private auth;
    private sessionToken;
    constructor(auth: ClaudeAuth);
    private initializeClient;
    private authenticateWithCredentials;
    private performWebAuthentication;
    private ensureAuthenticated;
    private validateSession;
    generateCommitMessage(diffEntries: GitDiffEntry[], config?: MessageConfig): Promise<CommitMessageResponse>;
    private analyzeDiff;
    private generateChangeSummary;
    private identifyMainAreas;
    private buildCommitMessagePrompt;
    private createDiffSummary;
    private parseCommitResponse;
}
export {};
