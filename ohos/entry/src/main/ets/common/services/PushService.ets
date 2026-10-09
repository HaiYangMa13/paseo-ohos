import { pushService } from '@kit.PushKit';
import { notificationManager } from '@kit.NotificationKit';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import { BusinessError } from '@ohos.base';
import UIAbility from '@ohos.app.ability.UIAbility';
import deviceInfo from '@ohos.deviceInfo';
import { Logger } from '../utils/Logger';

interface PushState {
  status: string;
  token?: string;
  code?: number;
}
interface PushClick {
  serverId: string;
  workspaceId?: string;
  agentId?: string;
  terminalId?: string;
}

export class PushService {
  private static instance: PushService | null = null;
  private token: string = '';
  private state: PushState = { status: 'loading' };
  private listener: (() => void) | null = null;
  private pendingClick: string = '';
  private initialized: boolean = false;
  private requestInFlight: boolean = false;
  private tokenUpdateRegistered: boolean = false;
  private onTokenUpdate = (token: string): void => {
    this.token = token;
    this.refreshPermission();
  };

  private constructor() {}

  public static getInstance(): PushService {
    if (!PushService.instance) PushService.instance = new PushService();
    return PushService.instance;
  }

  public initialize(ability: UIAbility): void {
    if (this.initialized) return;
    this.initialized = true;
    // Phone token-update events need newer systems; older phones refresh at cold launch.
    if (deviceInfo.sdkApiVersion >= 23 && typeof pushService.on === 'function') {
      try {
        pushService.on('tokenUpdate', ability, this.onTokenUpdate);
        this.tokenUpdateRegistered = true;
      } catch (error) {
        Logger.warn('Push token-update registration failed: %{public}d', (error as BusinessError).code);
      }
    }
    this.fetchToken();
  }

  public release(): void {
    if (this.tokenUpdateRegistered) {
      try {
        pushService.off('tokenUpdate', this.onTokenUpdate);
      } catch (error) {
        Logger.warn('Push token-update cleanup failed: %{public}d', (error as BusinessError).code);
      }
    }
    this.tokenUpdateRegistered = false;
    this.initialized = false;
    this.listener = null;
  }

  private async fetchToken(): Promise<void> {
    try {
      this.token = await pushService.getToken();
      await this.refreshPermission();
    } catch (error) {
      const code = (error as BusinessError).code;
      this.publish({ status: 'error', code: typeof code === 'number' ? code : -1 });
    }
  }

  public async refreshPermission(): Promise<void> {
    if (this.token.length === 0 || this.requestInFlight) return;
    try {
      const enabled = await notificationManager.isNotificationEnabled();
      if (enabled) this.publish({ status: 'ready', token: this.token });
      else if (this.state.status !== 'denied') this.publish({ status: 'permission-required' });
    } catch (error) {
      const code = (error as BusinessError).code;
      this.publish({ status: 'error', code: typeof code === 'number' ? code : -1 });
    }
  }

  public async requestPermission(context: common.UIAbilityContext): Promise<void> {
    if (this.requestInFlight) return;
    const wasDenied = this.state.status === 'denied';
    this.requestInFlight = true;
    this.publish({ status: 'loading' });
    try {
      if (wasDenied && typeof notificationManager.openNotificationSettings === 'function') {
        await notificationManager.openNotificationSettings(context);
      } else {
        await notificationManager.requestEnableNotification(context);
      }
      if (this.token.length === 0) this.token = await pushService.getToken();
      const enabled = await notificationManager.isNotificationEnabled();
      if (enabled) this.publish({ status: 'ready', token: this.token });
      else this.publish({ status: 'denied' });
    } catch (error) {
      const code = (error as BusinessError).code;
      if (code === 1600004) this.publish({ status: 'denied' });
      else this.publish({ status: 'error', code: typeof code === 'number' ? code : -1 });
    } finally {
      this.requestInFlight = false;
    }
  }

  public getState(): string {
    return JSON.stringify(this.state);
  }

  private publish(state: PushState): void {
    this.state = state;
    this.listener?.();
  }

  public setListener(listener: (() => void) | null): void {
    this.listener = listener;
  }

  public captureWant(want: Want): void {
    const parameters = want.parameters;
    if (!parameters) return;
    const serverId = parameters['serverId'];
    if (typeof serverId !== 'string' || serverId.length === 0 || serverId.length > 256) return;
    const click: PushClick = { serverId };
    const workspaceId = parameters['workspaceId'];
    const agentId = parameters['agentId'];
    const terminalId = parameters['terminalId'];
    if (typeof workspaceId === 'string' && workspaceId.length <= 256) click.workspaceId = workspaceId;
    if (typeof agentId === 'string' && agentId.length <= 256) click.agentId = agentId;
    if (typeof terminalId === 'string' && terminalId.length <= 256) click.terminalId = terminalId;
    this.pendingClick = JSON.stringify(click);
    this.listener?.();
  }

  public consumeClick(): string {
    const click = this.pendingClick;
    this.pendingClick = '';
    return click;
  }
}
