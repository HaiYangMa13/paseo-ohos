import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { AppConstants } from '../constants/AppConstants';
import { Logger } from '../utils/Logger';

export interface HostProfile {
  id: string;
  name: string;
  url: string; // e.g. "ws://192.168.1.50:6767" or "wss://relay.example.com/ws/..."
  isRelay: boolean;
  relayToken?: string;
  lastConnected: number;
}

export class HostConfigStore {
  private static instance: HostConfigStore | null = null;
  private pref: preferences.Preferences | null = null;
  private hosts: HostProfile[] = [];
  private activeHostId: string = '';

  private constructor() {}

  public static getInstance(): HostConfigStore {
    if (!HostConfigStore.instance) {
      HostConfigStore.instance = new HostConfigStore();
    }
    return HostConfigStore.instance;
  }

  public async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(context, AppConstants.PREF_NAME);
      const jsonStr = (await this.pref.get(AppConstants.KEY_HOSTS, '[]')) as string;
      this.hosts = JSON.parse(jsonStr) as HostProfile[];

      this.activeHostId = (await this.pref.get(AppConstants.KEY_LAST_CONNECTED_HOST, '')) as string;

      if (this.hosts.length === 0) {
        // Add default local host
        const defaultHost: HostProfile = {
          id: 'default_local',
          name: 'Local Dev Machine',
          url: `ws://${AppConstants.DEFAULT_LOCAL_HOST}:${AppConstants.DEFAULT_DAEMON_PORT}`,
          isRelay: false,
          lastConnected: Date.now()
        };
        this.hosts.push(defaultHost);
        this.activeHostId = defaultHost.id;
        await this.save();
      }
    } catch (err) {
      Logger.error('Failed to init HostConfigStore: %{public}s', JSON.stringify(err));
    }
  }

  public getHosts(): HostProfile[] {
    return this.hosts;
  }

  public getActiveHost(): HostProfile | undefined {
    return this.hosts.find((h) => h.id === this.activeHostId) || this.hosts[0];
  }

  public async setActiveHost(hostId: string): Promise<void> {
    this.activeHostId = hostId;
    if (this.pref) {
      await this.pref.put(AppConstants.KEY_LAST_CONNECTED_HOST, hostId);
      await this.pref.flush();
    }
  }

  public async addOrUpdateHost(host: HostProfile): Promise<void> {
    const idx = this.hosts.findIndex((h) => h.id === host.id);
    if (idx >= 0) {
      this.hosts[idx] = host;
    } else {
      this.hosts.push(host);
    }
    await this.save();
  }

  public async deleteHost(hostId: string): Promise<void> {
    this.hosts = this.hosts.filter((h) => h.id !== hostId);
    if (this.activeHostId === hostId && this.hosts.length > 0) {
      this.activeHostId = this.hosts[0].id;
    }
    await this.save();
  }

  private async save(): Promise<void> {
    if (!this.pref) return;
    try {
      await this.pref.put(AppConstants.KEY_HOSTS, JSON.stringify(this.hosts));
      await this.pref.put(AppConstants.KEY_LAST_CONNECTED_HOST, this.activeHostId);
      await this.pref.flush();
    } catch (err) {
      Logger.error('Failed to save hosts: %{public}s', JSON.stringify(err));
    }
  }
}
