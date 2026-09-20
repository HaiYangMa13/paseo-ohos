/**
 * Agent Lifecycle & Domain Models
 */

export type AgentStatus = 'initializing' | 'idle' | 'running' | 'error' | 'closed';

export interface AgentModel {
  id: string;
  provider: string; // 'claude-code' | 'codex' | 'copilot' | 'opencode' | 'pi' | 'cursor' etc.
  title: string;
  status: AgentStatus;
  workspaceId: string;
  cwd: string;
  model?: string;
  turnId?: string;
  createdAt: number;
  updatedAt: number;
  labels?: Record<string, string>;
  error?: string;
}

export interface ToolPermissionRequest {
  permissionId: string;
  agentId: string;
  tool: string;
  description: string;
  params?: Record<string, Object>;
  riskLevel?: 'low' | 'medium' | 'high';
  timestamp: number;
}

export interface ToolPermissionResolution {
  permissionId: string;
  decision: 'allow' | 'deny';
  reason?: string;
}
