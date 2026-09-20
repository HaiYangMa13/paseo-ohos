/**
 * Paseo HarmonyOS Native Client Constants
 */
export class AppConstants {
  public static readonly APP_NAME: string = 'Paseo';
  public static readonly APP_VERSION: string = '1.0.0';
  public static readonly PROTOCOL_VERSION: number = 1;
  public static readonly CLIENT_TYPE: string = 'mobile';

  // Default Daemon Port
  public static readonly DEFAULT_DAEMON_PORT: number = 6767;
  public static readonly DEFAULT_LOCAL_HOST: string = '127.0.0.1';

  // Heartbeat & Timeout
  public static readonly PING_INTERVAL_MS: number = 10000;
  public static readonly RECONNECT_DELAY_MS: number = 3000;
  public static readonly RPC_TIMEOUT_MS: number = 60000;

  // Preferences Storage Keys
  public static readonly PREF_NAME: string = 'paseo_preferences';
  public static readonly KEY_HOSTS: string = 'saved_hosts';
  public static readonly KEY_LAST_CONNECTED_HOST: string = 'last_connected_host';
}
