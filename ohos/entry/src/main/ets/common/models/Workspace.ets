/**
 * Workspace and Git Models
 */

export interface WorkspaceModel {
  id: string;
  name: string;
  rootPath: string;
  currentBranch?: string;
  isGitRepo: boolean;
  hasUncommittedChanges?: boolean;
  agentCount: number;
  lastActiveTime: number;
}

export interface DiffHunkLine {
  type: 'add' | 'delete' | 'context' | 'header';
  content: string;
  oldLineNumber?: number;
  newLineNumber?: number;
}

export interface DiffHunk {
  header: string;
  lines: DiffHunkLine[];
}

export interface GitDiffFile {
  oldPath: string;
  newPath: string;
  status: 'modified' | 'added' | 'deleted' | 'renamed';
  additions: number;
  deletions: number;
  hunks: DiffHunk[];
}
