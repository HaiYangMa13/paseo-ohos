import notificationManager from '@ohos.notificationManager';
import { BusinessError } from '@ohos.base';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { liveViewManager } from '@kit.LiveViewKit';
import { AgentModel } from '../models/Agent';
import { Logger } from '../utils/Logger';

export class LiveViewService {
  private static instance: LiveViewService | null = null;
  private readonly liveViewId: number = 1001;
  private isLiveViewActive: boolean = false;
  private sequence: number = 0;
  private activeAgent: AgentModel | null = null;
  private clickAction: WantAgent | null = null;

  private constructor() {}

  public static getInstance(): LiveViewService {
    if (!LiveViewService.instance) {
      LiveViewService.instance = new LiveViewService();
    }
    return LiveViewService.instance;
  }

  /**
   * Creates the native HarmonyOS Live View payload. The PROGRESS scenario is
   * the closest supported public template for a long-running AI agent turn.
   * Live View Kit access for this scenario still has to be enabled for the
   * application in AppGallery Connect.
   */
  private async getClickAction(): Promise<WantAgent> {
    if (this.clickAction) {
      return this.clickAction;
    }
    this.clickAction = await wantAgent.getWantAgent({
      wants: [
        {
          bundleName: 'sh.paseo.client',
          abilityName: 'EntryAbility'
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: this.liveViewId,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    });
    return this.clickAction;
  }

  private async createLiveView(agent: AgentModel, capsuleStatus: number): Promise<liveViewManager.LiveView> {
    const title = agent.title.trim() || 'Agent';
    const provider = agent.provider.trim() || 'Agent';
    const model = agent.model?.trim() || 'automatic model';
    this.sequence += 1;

    return {
      id: this.liveViewId,
      event: 'PROGRESS',
      sequence: this.sequence,
      isMute: true,
      liveViewData: {
        primary: {
          title: `Paseo · ${title}`,
          content: [
            {
              text: `${provider} · ${model}`,
              textColor: '#99000000'
            }
          ],
          keepTime: capsuleStatus === 1 ? 0 : 300,
          clickAction: await this.getClickAction(),
          layoutData: {
            layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_DEFAULT
          }
        },
        capsule: {
          type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT,
          status: capsuleStatus,
          icon: 'pwa-icon-192.png',
          title: 'Paseo',
          content: capsuleStatus === 1 ? 'Agent is working' : 'Turn finished',
          backgroundColor: '#FF20744A'
        }
      }
    };
  }

  /** Update the native status-bar capsule and lock-screen Live View. */
  public async updateLiveView(agent: AgentModel): Promise<void> {
    try {
      if (agent.status === 'running') {
        const enabled = await liveViewManager.isLiveViewEnabled();
        if (!enabled) {
          Logger.warn('HarmonyOS Live View is disabled for Paseo in system settings');
          return;
        }

        this.activeAgent = agent;
        const liveView = await this.createLiveView(agent, 1);
        if (this.isLiveViewActive) {
          const result = await liveViewManager.updateLiveView(liveView);
          Logger.info('HarmonyOS Live View updated, result=%{public}d', result.resultCode);
        } else {
          try {
            const result = await liveViewManager.startLiveView(liveView);
            this.isLiveViewActive = result.resultCode === 0;
            Logger.info('HarmonyOS Live View started, result=%{public}d', result.resultCode);
          } catch (error) {
            const businessError = error as BusinessError;
            if (businessError.code !== 1003500006) {
              Logger.warn('HarmonyOS Live View start failed: %{public}s', JSON.stringify(businessError));
              return;
            }
            // A previous process can leave a live view alive. Reconcile only
            // the explicit "already exists" response for the stable ID.
            const result = await liveViewManager.updateLiveView(liveView);
            this.isLiveViewActive = result.resultCode === 0;
            Logger.info('HarmonyOS Live View reconciled, result=%{public}d', result.resultCode);
          }
        }
      } else if (this.isLiveViewActive && this.activeAgent &&
        (agent.status === 'idle' || agent.status === 'closed' || agent.status === 'error')) {
        const result = await liveViewManager.stopLiveView(await this.createLiveView(this.activeAgent, -1));
        this.isLiveViewActive = false;
        this.activeAgent = null;
        Logger.info('HarmonyOS Live View stopped, result=%{public}d', result.resultCode);
      }
    } catch (err) {
      Logger.warn('HarmonyOS Live View Kit call failed: %{public}s', JSON.stringify(err));
    }
  }

  /** Post an immediate notification when an agent is waiting for approval. */
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
