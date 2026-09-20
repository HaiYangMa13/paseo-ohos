/**
 * Paseo WebSocket Wire Protocol Message Definitions
 */

export interface ClientCapabilities {
  ownedSubscriptions?: boolean;
  pushNotifications?: boolean;
  voice?: boolean;
}

export interface WSHelloMessage {
  type: string;
  clientId: string;
  clientType: string;
  protocolVersion: number;
  appVersion?: string;
  capabilities?: ClientCapabilities;
}

export interface WSPingMessage {
  type: string;
}

export interface WSPongMessage {
  type: string;
}

export interface ServerInfoPayload {
  status: string;
  serverId: string;
  hostname: string;
  version: string;
}

export interface WSSessionEnvelope {
  type: string;
  message: SessionMessage;
}

export interface SessionMessage {
  type: string;
  requestId?: string;
  agentId?: string;
  workspaceId?: string;
  status?: string;
  error?: string;
  code?: string;
  permissionId?: string;
  tool?: string;
  description?: string;
  streamType?: string;
  chunk?: string;
  toolName?: string;
  output?: string;
  decision?: string;
  limit?: number;
  serverId?: string;
  hostname?: string;
  version?: string;
}
