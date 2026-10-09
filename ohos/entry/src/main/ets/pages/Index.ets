import webview from '@ohos.web.webview';
import common from '@ohos.app.ability.common';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { BusinessError } from '@ohos.base';
import { UIContext } from '@ohos.arkui.UIContext';
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { AppLifecycleService, HarmonyAppLifecycleState } from '../common/services/AppLifecycleService';
import { LiveViewService } from '../common/services/LiveViewService';
import { FoldDisplayService, HarmonyDisplayMetrics } from '../common/services/FoldDisplayService';
import { AgentModel, AgentStatus } from '../common/models/Agent';
import { Logger } from '../common/utils/Logger';
import { PushService } from '../common/services/PushService';

class NativeHarmonyBridge {
  private liveViewService: LiveViewService = LiveViewService.getInstance();
  private foldDisplayService: FoldDisplayService = FoldDisplayService.getInstance();
  private webviewController: webview.WebviewController | null = null;
  private context: common.UIAbilityContext | null = null;
  private uiContext: UIContext | null = null;
  private scanInFlight: boolean = false;

  public setController(controller: webview.WebviewController): void {
    this.webviewController = controller;
  }

  public setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  public setUIContext(uiContext: UIContext): void {
    this.uiContext = uiContext;
  }

  private isTrustedPage(): boolean {
    if (!this.webviewController) return false;
    try {
      return this.webviewController.getUrl().toLowerCase().startsWith('resource://rawfile/');
    } catch (error) {
      return false;
    }
  }

  public getPushState(): string {
    if (!this.isTrustedPage()) return '{"status":"error","code":-1}';
    return PushService.getInstance().getState();
  }

  public requestPushPermission(): void {
    if (!this.isTrustedPage() || !this.context) return;
    PushService.getInstance().requestPermission(this.context);
  }

  public consumePushClick(): string {
    if (!this.isTrustedPage()) return '';
    return PushService.getInstance().consumeClick();
  }

  public dispatchPushState(): void {
    if (!this.isTrustedPage() || !this.uiContext) return;
    this.uiContext.runScopedTask(() => {
      try {
        this.webviewController?.runJavaScript(
          "window.dispatchEvent(new Event('paseo:harmony-push-state'));"
        ).catch(() => Logger.warn('Push bridge event dispatch failed'));
      } catch (error) {
        Logger.warn('Push bridge is not attached');
      }
    });
  }

  public updateAgentStatus(title: string, status: string, provider: string, model: string): void {
    Logger.info('NativeHarmonyBridge updateAgentStatus: %{public}s, %{public}s', title, status);
    const agent: AgentModel = {
      id: 'active_agent',
      title: title,
      status: status as AgentStatus,
      provider: provider,
      model: model,
      workspaceId: 'default',
      cwd: '',
      createdAt: Date.now(),
      updatedAt: Date.now()
    };
    this.liveViewService.updateLiveView(agent);
  }

  public notifyPermission(toolName: string, description: string): void {
    Logger.info('NativeHarmonyBridge notifyPermission: %{public}s', toolName);
    this.liveViewService.notifyPermissionRequired(toolName, description);
  }

  public getDisplayMetrics(): string {
    return JSON.stringify(this.foldDisplayService.getMetrics());
  }

  public dispatchDisplayMetrics(): void {
    if (!this.webviewController) return;
    const metricsJson = JSON.stringify(this.foldDisplayService.getMetrics());
    const script = `window.__onHarmonyDisplayMetricsChange && window.__onHarmonyDisplayMetricsChange(${metricsJson});`;
    if (this.uiContext) {
      this.uiContext.runScopedTask(() => {
        try {
          this.webviewController?.runJavaScript(script)
            .then(() => undefined)
            .catch(() => undefined);
        } catch (e) {
          // Ignore
        }
      });
    }
  }

  public dispatchAppState(state: HarmonyAppLifecycleState): void {
    if (!this.webviewController || !this.uiContext) return;
    const stateJson = JSON.stringify(state);
    const script = `window.__PASEO_HARMONY_APP_STATE__=${stateJson};` +
      `window.dispatchEvent(new CustomEvent('paseo:harmony-app-state',{detail:{state:${stateJson}}}));`;
    this.uiContext.runScopedTask(() => {
      try {
        this.webviewController?.runJavaScript(script)
          .then(() => {
            Logger.info('Dispatched Harmony app state: %{public}s', state);
          })
          .catch((error: Object) => {
            Logger.warn('Harmony app state dispatch rejected: %{public}s', JSON.stringify(error));
          });
      } catch (error) {
        Logger.warn('Harmony app state dispatch failed: %{public}s', JSON.stringify(error));
      }
    });
  }

  /**
   * Opens the HarmonyOS Scan Kit system scanner and hands the scanned pairing
   * URL back to the official Paseo web client via `__paseoHarmonyScanResult`.
   */
  public scanPairingQr(): void {
    if (this.scanInFlight) return;
    if (!this.context || !this.webviewController) {
      Logger.error('NativeHarmonyBridge scanPairingQr: missing context or webview');
      return;
    }
    this.scanInFlight = true;

    const options: scanBarcode.ScanOptions = {
      scanTypes: [scanCore.ScanType.QR_CODE],
      enableAlbum: false,
      enableMultiMode: false
    };

    scanBarcode.startScanForResult(this.context, options)
      .then((result: scanBarcode.ScanResult) => {
        const raw = result.originalValue ?? '';
        Logger.info('NativeHarmonyBridge scan result: %{public}s', raw);
        this.dispatchScanResult(raw);
      })
      .catch((error: BusinessError) => {
        Logger.error('NativeHarmonyBridge scan error: %{public}s', JSON.stringify(error));
        // 1000500002 means the user cancelled the scanner.
        this.dispatchScanResult('');
      })
      .finally(() => {
        this.scanInFlight = false;
      });
  }

  private dispatchScanResult(raw: string): void {
    if (!this.webviewController) return;
    const script = `window.__paseoHarmonyScanResult && window.__paseoHarmonyScanResult(${JSON.stringify(raw)});`;
    const dispatch = (): void => {
      try {
        this.webviewController?.runJavaScript(script)
          .then(() => undefined)
          .catch((error: Object) => {
            Logger.error('NativeHarmonyBridge dispatchScanResult rejected: %{public}s', JSON.stringify(error));
          });
      } catch (error) {
        Logger.error('NativeHarmonyBridge dispatchScanResult failed: %{public}s', JSON.stringify(error));
      }
    };
    // ArkWeb requires runJavaScript to be invoked on the ArkUI UI thread.
    // Scan Kit resolves its promise on a worker thread, so never call it
    // directly from the Scan Kit callback.
    if (this.uiContext) {
      this.uiContext.runScopedTask(dispatch);
    } else {
      Logger.error('NativeHarmonyBridge dispatchScanResult: missing UI context');
    }
  }
}

@Entry
@Component
struct Index {
  private webviewController: webview.WebviewController = new webview.WebviewController();
  private bridge: NativeHarmonyBridge = new NativeHarmonyBridge();
  @State isLoading: boolean = true;
  @State progress: number = 0;
  @State keyboardInsetVp: number = 0;

  aboutToAppear() {
    // Enable webview debugging for local inspection
    webview.WebviewController.setWebDebuggingAccess(true);
    this.bridge.setController(this.webviewController);
    const context = getContext(this) as common.UIAbilityContext;
    this.bridge.setContext(context);
    this.bridge.setUIContext(this.getUIContext());
    PushService.getInstance().setListener(() => this.bridge.dispatchPushState());
    AppLifecycleService.getInstance().setListener((state: HarmonyAppLifecycleState) => {
      this.bridge.dispatchAppState(state);
    });

    FoldDisplayService.getInstance().addListener((metrics: HarmonyDisplayMetrics) => {
      const nextInset = metrics.keyboardHeightVp > 0 ? metrics.keyboardHeightVp : 0;
      if (this.keyboardInsetVp !== nextInset) {
        this.keyboardInsetVp = nextInset;
      }
      this.bridge.dispatchDisplayMetrics();
    });
  }

  aboutToDisappear() {
    PushService.getInstance().setListener(null);
    AppLifecycleService.getInstance().clearListener();
  }

  onBackPress(): boolean {
    if (this.webviewController.accessBackward()) {
      this.webviewController.backward();
      return true;
    }
    return false;
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Web({
        src: $rawfile('index.html'),
        controller: this.webviewController,
        renderMode: RenderMode.ASYNC_RENDER
      })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(true)
        .imageAccess(true)
        .databaseAccess(true)
        .mixedMode(MixedMode.All)
        .zoomAccess(false)
        .layoutMode(WebLayoutMode.NONE)
        .keyboardAvoidMode(WebKeyboardAvoidMode.OVERLAYS_CONTENT)
        .backgroundColor('#F7F7F8')
        .javaScriptProxy({
          object: this.bridge,
          name: 'HarmonyBridge',
          methodList: ['updateAgentStatus', 'notifyPermission', 'scanPairingQr', 'getDisplayMetrics',
            'getPushState', 'requestPushPermission', 'consumePushClick'],
          controller: this.webviewController
        })
        .onPermissionRequest((event) => {
          const request = event.request;
          const audioResources = request.getAccessibleResource()
            .filter((resource: string) => resource === 'TYPE_AUDIO_CAPTURE');
          if (audioResources.length === 0) {
            request.deny();
            return;
          }

          const context = getContext(this) as common.UIAbilityContext;
          const permissions: Array<Permissions> = ['ohos.permission.MICROPHONE'];
          abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, permissions)
            .then((result) => {
              if (result.authResults.length > 0 &&
                result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
                request.grant(audioResources);
                Logger.info('ArkWeb microphone permission granted for %{public}s', request.getOrigin());
              } else {
                request.deny();
                Logger.warn('ArkWeb microphone permission denied for %{public}s', request.getOrigin());
              }
            })
            .catch((error: Object) => {
              request.deny();
              Logger.error('ArkWeb microphone permission request failed: %{public}s', JSON.stringify(error));
            });
        })
        .onProgressChange((event) => {
          if (event) {
            this.progress = event.newProgress;
            if (this.progress >= 100) {
              this.isLoading = false;
              // Replay native state after the page has installed its event listeners.
              this.bridge.dispatchDisplayMetrics();
              this.bridge.dispatchAppState(AppLifecycleService.getInstance().getState());
              this.bridge.dispatchPushState();
            }
          }
        })
        .onErrorReceive((event) => {
          if (event) {
            Logger.error('ArkWeb load error: %{public}s', event.error.getErrorInfo());
          }
        })
        .width('100%')
        .height('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .translate({ y: -this.keyboardInsetVp })

      if (this.isLoading && this.progress < 100) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color('#20744A')
          .margin({ top: '40%' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F7F8')
    .clip(true)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
