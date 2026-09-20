/**
 * Agent Timeline Stream Item Models
 */

export type TimelineItemType =
  | 'user_prompt'
  | 'assistant_text'
  | 'tool_use'
  | 'tool_result'
  | 'permission_prompt'
  | 'status_notice'
  | 'error';

export interface TimelineItem {
  id: string;
  agentId: string;
  type: TimelineItemType;
  sequence: number;
  timestamp: number;
  content: string;
  isStreaming?: boolean;
  toolName?: string;
  toolInput?: Record<string, Object>;
  toolOutput?: string;
  toolError?: boolean;
  permissionId?: string;
}
