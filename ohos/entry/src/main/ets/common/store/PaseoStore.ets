import {
  PaseoWebSocketClient,
  ConnectionState,
  MessageListener
} from '../protocol/PaseoWebSocketClient';
import { TerminalFrame, TerminalOpcode } from '../protocol/TerminalBinaryCodec';
import { AgentModel, ToolPermissionRequest } from '../models/Agent';
import { WorkspaceModel } from '../models/Workspace';
import { TimelineItem } from '../models/TimelineItem';
import { SessionMessage, ServerInfoPayload } from '../models/ProtocolMessages';
import { Logger } from '../utils/Logger';

export type StoreChangeListener = () => void;
export type PermissionRequestListener = (request: ToolPermissionRequest) => void;

interface WorkspacesRpcResponse extends SessionMessage {
  workspaces?: WorkspaceModel[];
}

interface AgentsRpcResponse extends SessionMessage {
  agents?: AgentModel[];
}

interface TimelineRpcResponse extends SessionMessage {
  items?: TimelineItem[];
}

interface AgentUpdateSessionMessage extends SessionMessage {
  agent?: AgentModel;
}

interface WorkspaceUpdateSessionMessage extends SessionMessage {
  workspace?: WorkspaceModel;
}

export class PaseoStore implements MessageListener {
  private static instance: PaseoStore | null = null;
  private wsClient: PaseoWebSocketClient;

  // Reactive State
  public connectionState: ConnectionState = 'disconnected';
  public serverInfo: ServerInfoPayload | null = null;
  public agents: Map<string, AgentModel> = new Map();
  public workspaces: Map<string, WorkspaceModel> = new Map();
  public activeAgentId: string = '';
  public timelineMap: Map<string, TimelineItem[]> = new Map();
  public pendingPermissions: Map<string, ToolPermissionRequest> = new Map();
  public terminalBuffers: Map<number, string> = new Map();

  // Listeners
  private changeListeners: Set<StoreChangeListener> = new Set();
  private permissionListeners: Set<PermissionRequestListener> = new Set();

  private constructor() {
    this.wsClient = PaseoWebSocketClient.getInstance();
    this.wsClient.addListener(this);
  }

  public static getInstance(): PaseoStore {
    if (!PaseoStore.instance) {
      PaseoStore.instance = new PaseoStore();
    }
    return PaseoStore.instance;
  }

  public subscribe(listener: StoreChangeListener): void {
    this.changeListeners.add(listener);
  }

  public unsubscribe(listener: StoreChangeListener): void {
    this.changeListeners.delete(listener);
  }

  public onPermissionRequest(listener: PermissionRequestListener): void {
    this.permissionListeners.add(listener);
  }

  public offPermissionRequest(listener: PermissionRequestListener): void {
    this.permissionListeners.delete(listener);
  }

  private notify(): void {
    this.changeListeners.forEach((l) => l());
  }

  // --- Actions ---

  public connect(url: string): void {
    this.wsClient.connect(url);
  }

  public disconnect(): void {
    this.wsClient.disconnect();
  }

  public async fetchInitialState(): Promise<void> {
    try {
      // 1. Fetch Workspaces
      const wsReq: SessionMessage = { type: 'fetch_workspaces' };
      const wsResp = await this.wsClient.sendRPC(wsReq) as WorkspacesRpcResponse;
      if (wsResp && wsResp.workspaces) {
        const list = wsResp.workspaces;
        this.workspaces.clear();
        list.forEach((w) => this.workspaces.set(w.id, w));
      }

      // 2. Fetch Agents
      const agentReq: SessionMessage = { type: 'agent_list' };
      const agentResp = await this.wsClient.sendRPC(agentReq) as AgentsRpcResponse;
      if (agentResp && agentResp.agents) {
        const list = agentResp.agents;
        this.agents.clear();
        list.forEach((a) => {
          this.agents.set(a.id, a);
          if (!this.timelineMap.has(a.id)) {
            this.timelineMap.set(a.id, []);
          }
        });
      }

      this.notify();
    } catch (err) {
      Logger.error('Failed to fetch initial Paseo state: %{public}s', JSON.stringify(err));
    }
  }

  public async selectAgent(agentId: string): Promise<void> {
    this.activeAgentId = agentId;
    if (!this.timelineMap.has(agentId)) {
      this.timelineMap.set(agentId, []);
    }

    // Authoritative timeline fetch for this agent
    try {
      const timelineReq: SessionMessage = {
        type: 'fetch_agent_timeline_request',
        agentId: agentId,
        limit: 100
      };
      const resp = await this.wsClient.sendRPC(timelineReq) as TimelineRpcResponse;

      if (resp && resp.items) {
        const items = resp.items;
        this.timelineMap.set(agentId, items);
      }
    } catch (err) {
      Logger.warn('Timeline fetch error: %{public}s', JSON.stringify(err));
    }

    this.notify();
  }

  public sendAgentMessage(agentId: string, text: string): void {
    if (!text.trim()) return;

    const userItem: TimelineItem = {
      id: 'local_' + Date.now(),
      agentId: agentId,
      type: 'user_prompt',
      sequence: Date.now(),
      timestamp: Date.now(),
      content: text
    };

    const stream = this.timelineMap.get(agentId) || [];
    stream.push(userItem);
    this.timelineMap.set(agentId, stream);

    const sessionMsg: SessionMessage = {
      type: 'send_agent_message',
      agentId: agentId,
      chunk: text
    };
    this.wsClient.sendSessionMessage(sessionMsg);

    this.notify();
  }

  public resolvePermission(permissionId: string, decision: 'allow' | 'deny'): void {
    this.pendingPermissions.delete(permissionId);
    const sessionMsg: SessionMessage = {
      type: 'agent_permission_resolved',
      permissionId: permissionId,
      decision: decision
    };
    this.wsClient.sendSessionMessage(sessionMsg);
    this.notify();
  }

  public stopAgent(agentId: string): void {
    const msg: SessionMessage = {
      type: 'agent.stop.request',
      agentId: agentId
    };
    this.wsClient.sendSessionMessage(msg);
  }

  public resumeAgent(agentId: string): void {
    const msg: SessionMessage = {
      type: 'agent.resume.request',
      agentId: agentId
    };
    this.wsClient.sendSessionMessage(msg);
  }

  public sendTerminalInput(slot: number, text: string): void {
    this.wsClient.sendTerminalInput(slot, text);
  }

  public sendTerminalResize(slot: number, cols: number, rows: number): void {
    this.wsClient.sendTerminalResize(slot, cols, rows);
  }

  // --- WebSocket Callbacks ---

  public onConnectionChange(state: ConnectionState): void {
    this.connectionState = state;
    if (state === 'connected') {
      this.fetchInitialState();
    }
    this.notify();
  }

  public onServerInfo(info: ServerInfoPayload): void {
    this.serverInfo = info;
    this.notify();
  }

  public onSessionMessage(msg: SessionMessage): void {
    switch (msg.type) {
      case 'agent_update': {
        const updateMsg = msg as AgentUpdateSessionMessage;
        if (updateMsg.agent) {
          this.agents.set(updateMsg.agent.id, updateMsg.agent);
          this.notify();
        }
        break;
      }
      case 'agent_stream': {
        const agentId = msg.agentId;
        if (!agentId) return;

        const stream = this.timelineMap.get(agentId) || [];
        const eventType = msg.streamType || '';
        const chunk = msg.chunk || '';

        if (eventType === 'chunk' || eventType === 'assistant_text') {
          const last = stream[stream.length - 1];
          if (last && last.type === 'assistant_text' && last.isStreaming) {
            last.content += chunk;
          } else {
            const newItem: TimelineItem = {
              id: 'stream_' + Date.now(),
              agentId: agentId,
              type: 'assistant_text',
              sequence: Date.now(),
              timestamp: Date.now(),
              content: chunk,
              isStreaming: true
            };
            stream.push(newItem);
          }
        } else if (eventType === 'chunk_end') {
          const last = stream[stream.length - 1];
          if (last && last.type === 'assistant_text') {
            last.isStreaming = false;
          }
        } else if (eventType === 'tool_use') {
          const toolItem: TimelineItem = {
            id: 'tool_' + Date.now(),
            agentId: agentId,
            type: 'tool_use',
            sequence: Date.now(),
            timestamp: Date.now(),
            content: `Invoking tool: ${msg.toolName || 'action'}`,
            toolName: msg.toolName
          };
          stream.push(toolItem);
        } else if (eventType === 'tool_result') {
          const resItem: TimelineItem = {
            id: 'tool_res_' + Date.now(),
            agentId: agentId,
            type: 'tool_result',
            sequence: Date.now(),
            timestamp: Date.now(),
            content: msg.output || '',
            toolOutput: msg.output || ''
          };
          stream.push(resItem);
        }

        this.timelineMap.set(agentId, stream);
        this.notify();
        break;
      }
      case 'agent_permission_request': {
        const req: ToolPermissionRequest = {
          permissionId: msg.permissionId || 'perm_' + Date.now(),
          agentId: msg.agentId || '',
          tool: msg.tool || 'command',
          description: msg.description || 'Agent requests permission to run action',
          riskLevel: 'medium',
          timestamp: Date.now()
        };
        this.pendingPermissions.set(req.permissionId, req);
        this.notify();
        this.permissionListeners.forEach((l) => l(req));
        break;
      }
      case 'agent_permission_resolved': {
        const permId = msg.permissionId;
        if (permId) {
          this.pendingPermissions.delete(permId);
          this.notify();
        }
        break;
      }
      case 'workspace_update': {
        const wsMsg = msg as WorkspaceUpdateSessionMessage;
        if (wsMsg.workspace) {
          this.workspaces.set(wsMsg.workspace.id, wsMsg.workspace);
          this.notify();
        }
        break;
      }
    }
  }

  public onTerminalFrame(frame: TerminalFrame): void {
    if (frame.opcode === TerminalOpcode.Output || frame.opcode === TerminalOpcode.Snapshot) {
      const current = this.terminalBuffers.get(frame.slot) || '';
      let nextBuffer = current + frame.payloadText;
      if (nextBuffer.length > 200000) {
        nextBuffer = nextBuffer.substring(nextBuffer.length - 150000);
      }
      this.terminalBuffers.set(frame.slot, nextBuffer);
      this.notify();
    }
  }
}
