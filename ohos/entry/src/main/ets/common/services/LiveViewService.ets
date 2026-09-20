import notificationManager from '@ohos.notificationManager';
import { AgentModel } from '../models/Agent';
import { Logger } from '../utils/Logger';

export class LiveViewService {
  private static instance: LiveViewService | null = null;
  private currentNotificationId: number = 1001;
  private isLiveViewActive: boolean = false;

  private constructor() {}

  public static getInstance(): LiveViewService {
    if (!LiveViewService.instance) {
      LiveViewService.instance = new LiveViewService();
    }
    return LiveViewService.instance;
  }

  /**
   * Update HarmonyOS Live View state based on active Agent status
   */
  public async updateLiveView(agent: AgentModel): Promise<void> {
    try {
      if (agent.status === 'running') {
        const normalContent: notificationManager.NotificationBasicContent = {
          title: `Paseo: ${agent.title || 'Agent'} Running`,
          text: `Provider: ${agent.provider} | Model: ${agent.model || 'auto'}`,
          additionalText: 'Active Turn'
        };

        const request: notificationManager.NotificationRequest = {
          id: this.currentNotificationId,
          notificationSlotType: notificationManager.SlotType.LIVE_VIEW,
          content: {
            notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
            normal: normalContent
          }
        };

        await notificationManager.publish(request);
        this.isLiveViewActive = true;
        Logger.info('HarmonyOS Live View updated: Running agent %{public}s', agent.id);
      } else if (this.isLiveViewActive && (agent.status === 'idle' || agent.status === 'closed')) {
        await notificationManager.cancel(this.currentNotificationId);
        this.isLiveViewActive = false;
        Logger.info('HarmonyOS Live View ended for agent %{public}s', agent.id);
      }
    } catch (err) {
      Logger.warn('Failed to publish HarmonyOS Live View notification: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * Post immediate high-priority banner for tool permission request
   */
  public async notifyPermissionRequired(toolName: string, description: string): Promise<void> {
    try {
      const normalContent: notificationManager.NotificationBasicContent = {
        title: `Paseo: Permission Needed (${toolName})`,
        text: description,
        additionalText: 'Action Required'
      };

      const request: notificationManager.NotificationRequest = {
        id: 2002,
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: normalContent
        }
      };
      await notificationManager.publish(request);
    } catch (err) {
      Logger.warn('Failed to publish permission notification: %{public}s', JSON.stringify(err));
    }
  }
}
