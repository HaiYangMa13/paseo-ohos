import { GitDiffFile, DiffHunk, DiffHunkLine } from '../models/Workspace';

export class DiffParser {
  /**
   * Parse git unified diff text into structured files and hunks
   */
  public static parseUnifiedDiff(rawDiff: string): GitDiffFile[] {
    const files: GitDiffFile[] = [];
    if (!rawDiff || !rawDiff.trim()) return files;

    const lines = rawDiff.split(/\r?\n/);
    let currentFile: GitDiffFile | null = null;
    let currentHunk: DiffHunk | null = null;
    let oldLineNum = 0;
    let newLineNum = 0;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      if (line.startsWith('diff --git ')) {
        // e.g. diff --git a/src/index.ts b/src/index.ts
        const parts = line.split(' ');
        const oldP = parts[2]?.replace(/^a\//, '') || '';
        const newP = parts[3]?.replace(/^b\//, '') || '';

        currentFile = {
          oldPath: oldP,
          newPath: newP,
          status: 'modified',
          additions: 0,
          deletions: 0,
          hunks: []
        };
        files.push(currentFile);
        currentHunk = null;
      } else if (line.startsWith('new file mode') && currentFile) {
        currentFile.status = 'added';
      } else if (line.startsWith('deleted file mode') && currentFile) {
        currentFile.status = 'deleted';
      } else if (line.startsWith('rename from') && currentFile) {
        currentFile.status = 'renamed';
      } else if (line.startsWith('@@ ') && currentFile) {
        // Hunk header e.g. @@ -1,5 +1,7 @@
        currentHunk = {
          header: line,
          lines: []
        };
        currentFile.hunks.push(currentHunk);

        // Parse line numbers from @@ -l,s +l,s @@
        const match = /@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(line);
        if (match) {
          oldLineNum = parseInt(match[1], 10);
          newLineNum = parseInt(match[2], 10);
        }
      } else if (currentHunk) {
        if (line.startsWith('+')) {
          currentFile?.additions ? currentFile.additions++ : (currentFile!.additions = 1);
          currentHunk.lines.push({
            type: 'add',
            content: line.substring(1),
            newLineNumber: newLineNum++
          });
        } else if (line.startsWith('-')) {
          currentFile?.deletions ? currentFile.deletions++ : (currentFile!.deletions = 1);
          currentHunk.lines.push({
            type: 'delete',
            content: line.substring(1),
            oldLineNumber: oldLineNum++
          });
        } else if (line.startsWith(' ')) {
          currentHunk.lines.push({
            type: 'context',
            content: line.substring(1),
            oldLineNumber: oldLineNum++,
            newLineNumber: newLineNum++
          });
        }
      }
    }

    return files;
  }
}
