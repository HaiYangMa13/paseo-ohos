import webSocket from '@ohos.net.webSocket';
import { AppConstants } from '../constants/AppConstants';
import { Logger } from '../utils/Logger';
import {
  WSHelloMessage,
  WSPingMessage,
  WSSessionEnvelope,
  SessionMessage,
  ServerInfoPayload
} from '../models/ProtocolMessages';
import { TerminalBinaryCodec, TerminalFrame } from './TerminalBinaryCodec';

export type ConnectionState = 'disconnected' | 'connecting' | 'connected' | 'reconnecting';

export interface MessageListener {
  onSessionMessage?: (message: SessionMessage) => void;
  onTerminalFrame?: (frame: TerminalFrame) => void;
  onConnectionChange?: (state: ConnectionState) => void;
  onServerInfo?: (info: ServerInfoPayload) => void;
}

export class PaseoWebSocketClient {
  private static instance: PaseoWebSocketClient | null = null;
  private ws: webSocket.WebSocket | null = null;
  private currentUrl: string = '';
  private state: ConnectionState = 'disconnected';
  private pingTimerId: number = -1;
  private reconnectTimerId: number = -1;
  private clientId: string = '';
  private serverInfo: ServerInfoPayload | null = null;

  private pendingRequests: Map<string, (msg: SessionMessage) => void> = new Map();
  private listeners: Set<MessageListener> = new Set();

  private constructor() {
    this.clientId = 'ohos-' + Math.random().toString(36).substring(2, 10);
  }

  public static getInstance(): PaseoWebSocketClient {
    if (!PaseoWebSocketClient.instance) {
      PaseoWebSocketClient.instance = new PaseoWebSocketClient();
    }
    return PaseoWebSocketClient.instance;
  }

  public getConnectionState(): ConnectionState {
    return this.state;
  }

  public getServerInfo(): ServerInfoPayload | null {
    return this.serverInfo;
  }

  public addListener(listener: MessageListener): void {
    this.listeners.add(listener);
  }

  public removeListener(listener: MessageListener): void {
    this.listeners.delete(listener);
  }

  public connect(wsUrl: string): void {
    if (this.state === 'connected' || this.state === 'connecting') {
      if (this.currentUrl === wsUrl) {
        Logger.info('WebSocket already connected or connecting to %{public}s', wsUrl);
        return;
      }
      this.disconnect();
    }

    this.currentUrl = wsUrl;
    this.setState('connecting');
    this.clearTimers();

    try {
      this.ws = webSocket.createWebSocket();
      this.setupCallbacks();
      this.ws.connect(wsUrl, (err, value) => {
        if (err) {
          Logger.error('WebSocket connect error: %{public}s', JSON.stringify(err));
          this.scheduleReconnect();
        } else {
          Logger.info('WebSocket connect initiate success: %{public}s', JSON.stringify(value));
        }
      });
    } catch (err) {
      Logger.error('Failed to create WebSocket client: %{public}s', JSON.stringify(err));
      this.scheduleReconnect();
    }
  }

  public disconnect(): void {
    this.clearTimers();
    if (this.ws) {
      try {
        this.ws.close({ code: 1000, reason: 'Normal client disconnect' });
      } catch (err) {
        Logger.warn('Error closing websocket: %{public}s', JSON.stringify(err));
      }
      this.ws = null;
    }
    this.setState('disconnected');
  }

  private setupCallbacks(): void {
    if (!this.ws) return;

    this.ws.on('open', (err, value) => {
      if (err) {
        Logger.error('WebSocket onOpen error: %{public}s', JSON.stringify(err));
        return;
      }
      Logger.info('WebSocket connection open! Sending hello...');
      this.setState('connected');
      this.sendHello();
      this.startHeartbeat();
    });

    this.ws.on('message', (err, value: string | ArrayBuffer) => {
      if (err) {
        Logger.error('WebSocket onMessage error: %{public}s', JSON.stringify(err));
        return;
      }

      if (typeof value === 'string') {
        this.handleTextMessage(value);
      } else if (value instanceof ArrayBuffer) {
        this.handleBinaryMessage(value);
      }
    });

    this.ws.on('close', (err, value) => {
      Logger.warn('WebSocket closed: %{public}s, code: %{public}d', value?.reason ?? '', value?.code ?? 0);
      this.scheduleReconnect();
    });

    this.ws.on('error', (err) => {
      Logger.error('WebSocket error event: %{public}s', JSON.stringify(err));
      this.scheduleReconnect();
    });
  }

  private sendHello(): void {
    const hello: WSHelloMessage = {
      type: 'hello',
      clientId: this.clientId,
      clientType: 'mobile',
      protocolVersion: AppConstants.PROTOCOL_VERSION,
      appVersion: AppConstants.APP_VERSION,
      capabilities: {
        ownedSubscriptions: true,
        pushNotifications: true
      }
    };
    this.sendRaw(JSON.stringify(hello));
  }

  private startHeartbeat(): void {
    this.clearPingTimer();
    this.pingTimerId = setInterval(() => {
      if (this.state === 'connected') {
        const ping: WSPingMessage = { type: 'ping' };
        this.sendRaw(JSON.stringify(ping));
      }
    }, AppConstants.PING_INTERVAL_MS);
  }

  private handleTextMessage(raw: string): void {
    try {
      const envelope = JSON.parse(raw) as WSSessionEnvelope;
      const type = envelope.type;

      if (type === 'pong') {
        return;
      }

      if (type === 'session') {
        const msg = envelope.message;
        if (!msg) return;

        if (msg.type === 'status' && msg.status === 'server_info') {
          const sInfo: ServerInfoPayload = {
            status: msg.status || 'server_info',
            serverId: msg.serverId || '',
            hostname: msg.hostname || '',
            version: msg.version || ''
          };
          this.serverInfo = sInfo;
          this.notifyServerInfo(sInfo);
        }

        if (msg.requestId && this.pendingRequests.has(msg.requestId)) {
          const resolve = this.pendingRequests.get(msg.requestId);
          if (resolve) {
            this.pendingRequests.delete(msg.requestId);
            resolve(msg);
          }
        }

        this.notifySessionMessage(msg);
      }
    } catch (err) {
      Logger.error('Failed to parse text message: %{public}s', JSON.stringify(err));
    }
  }

  private handleBinaryMessage(buffer: ArrayBuffer): void {
    const frame = TerminalBinaryCodec.decode(buffer);
    if (frame) {
      this.notifyTerminalFrame(frame);
    }
  }

  /**
   * Execute an RPC request and await correlated response
   */
  public sendRPC(message: SessionMessage): Promise<SessionMessage> {
    return new Promise<SessionMessage>((resolve, reject) => {
      if (this.state !== 'connected') {
        reject(new Error('WebSocket is not connected'));
        return;
      }

      const requestId = 'req_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7);
      message.requestId = requestId;

      const envelope: WSSessionEnvelope = {
        type: 'session',
        message: message
      };

      const timeoutId = setTimeout(() => {
        if (this.pendingRequests.has(requestId)) {
          this.pendingRequests.delete(requestId);
          reject(new Error(`RPC request '${message.type}' timed out`));
        }
      }, AppConstants.RPC_TIMEOUT_MS);

      this.pendingRequests.set(requestId, (response: SessionMessage) => {
        clearTimeout(timeoutId);
        if (response.type === 'rpc_error') {
          reject(new Error(response.error ?? 'Unknown RPC Error'));
        } else {
          resolve(response);
        }
      });

      this.sendRaw(JSON.stringify(envelope));
    });
  }

  public sendSessionMessage(message: SessionMessage): void {
    const envelope: WSSessionEnvelope = {
      type: 'session',
      message: message
    };
    this.sendRaw(JSON.stringify(envelope));
  }

  public sendTerminalInput(slot: number, input: string): void {
    if (this.state !== 'connected' || !this.ws) return;
    const buffer = TerminalBinaryCodec.encodeInput(slot, input);
    this.ws.send(buffer);
  }

  public sendTerminalResize(slot: number, cols: number, rows: number): void {
    if (this.state !== 'connected' || !this.ws) return;
    const buffer = TerminalBinaryCodec.encodeResize(slot, cols, rows);
    this.ws.send(buffer);
  }

  private sendRaw(text: string): void {
    if (this.ws && this.state === 'connected') {
      this.ws.send(text, (err) => {
        if (err) {
          Logger.error('Failed to send raw ws frame: %{public}s', JSON.stringify(err));
        }
      });
    }
  }

  private scheduleReconnect(): void {
    if (this.state === 'disconnected') return;
    this.setState('reconnecting');
    this.clearTimers();

    this.reconnectTimerId = setTimeout(() => {
      if (this.currentUrl) {
        Logger.info('Attempting reconnect to %{public}s', this.currentUrl);
        this.connect(this.currentUrl);
      }
    }, AppConstants.RECONNECT_DELAY_MS);
  }

  private setState(newState: ConnectionState): void {
    if (this.state !== newState) {
      this.state = newState;
      this.notifyConnectionChange(newState);
    }
  }

  private clearPingTimer(): void {
    if (this.pingTimerId !== -1) {
      clearInterval(this.pingTimerId);
      this.pingTimerId = -1;
    }
  }

  private clearTimers(): void {
    this.clearPingTimer();
    if (this.reconnectTimerId !== -1) {
      clearTimeout(this.reconnectTimerId);
      this.reconnectTimerId = -1;
    }
  }

  private notifyConnectionChange(state: ConnectionState): void {
    this.listeners.forEach((l) => l.onConnectionChange?.(state));
  }

  private notifyServerInfo(info: ServerInfoPayload): void {
    this.listeners.forEach((l) => l.onServerInfo?.(info));
  }

  private notifySessionMessage(msg: SessionMessage): void {
    this.listeners.forEach((l) => l.onSessionMessage?.(msg));
  }

  private notifyTerminalFrame(frame: TerminalFrame): void {
    this.listeners.forEach((l) => l.onTerminalFrame?.(frame));
  }
}
