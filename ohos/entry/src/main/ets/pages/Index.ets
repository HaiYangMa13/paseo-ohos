import webview from '@ohos.web.webview';
import common from '@ohos.app.ability.common';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { BusinessError } from '@ohos.base';
import { UIContext } from '@ohos.arkui.UIContext';
import { LiveViewService } from '../common/services/LiveViewService';
import { AgentModel, AgentStatus } from '../common/models/Agent';
import { Logger } from '../common/utils/Logger';

class NativeHarmonyBridge {
  private liveViewService: LiveViewService = LiveViewService.getInstance();
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

  aboutToAppear() {
    // Enable webview debugging for local inspection
    webview.WebviewController.setWebDebuggingAccess(true);
    this.bridge.setController(this.webviewController);
    const context = getContext(this) as common.UIAbilityContext;
    this.bridge.setContext(context);
    this.bridge.setUIContext(this.getUIContext());
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
      Web({ src: $rawfile('index.html'), controller: this.webviewController })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(true)
        .imageAccess(true)
        .databaseAccess(true)
        .mixedMode(MixedMode.All)
        .zoomAccess(false)
        .backgroundColor('#181B1A')
        .javaScriptProxy({
          object: this.bridge,
          name: 'HarmonyBridge',
          methodList: ['updateAgentStatus', 'notifyPermission', 'scanPairingQr'],
          controller: this.webviewController
        })
        .onProgressChange((event) => {
          if (event) {
            this.progress = event.newProgress;
            if (this.progress >= 100) {
              this.isLoading = false;
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
    .backgroundColor('#181B1A')
  }
}
