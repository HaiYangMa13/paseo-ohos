import display from '@ohos.display';
import window from '@ohos.window';
import { Logger } from '../utils/Logger';

export interface HarmonySafeAreaInsets {
  top: number;
  bottom: number;
  left: number;
  right: number;
}

export interface HarmonyDisplayMetrics {
  foldStatus: number; // 0: UNKNOWN/NOT_FOLDABLE, 1: EXPANDED, 2: FOLDED, 3: HALF_FOLDED
  isFoldExpanded: boolean;
  isFolded: boolean;
  isHalfFolded: boolean;
  isFoldable: boolean;
  rotation: number; // 0: 0, 1: 90, 2: 180, 3: 270
  orientation: number;
  widthVp: number;
  heightVp: number;
  isLandscape: boolean;
  safeAreaInsets: HarmonySafeAreaInsets;
}

class DefaultSafeAreaInsets implements HarmonySafeAreaInsets {
  top: number = 0;
  bottom: number = 0;
  left: number = 0;
  right: number = 0;
}

class DefaultDisplayMetrics implements HarmonyDisplayMetrics {
  foldStatus: number = 0;
  isFoldExpanded: boolean = false;
  isFolded: boolean = false;
  isHalfFolded: boolean = false;
  isFoldable: boolean = false;
  rotation: number = 0;
  orientation: number = 0;
  widthVp: number = 0;
  heightVp: number = 0;
  isLandscape: boolean = false;
  safeAreaInsets: HarmonySafeAreaInsets = new DefaultSafeAreaInsets();
}

export class FoldDisplayService {
  private static instance: FoldDisplayService | null = null;
  private currentMetrics: HarmonyDisplayMetrics = new DefaultDisplayMetrics();
  private listeners: Array<(metrics: HarmonyDisplayMetrics) => void> = [];
  private mainWindow: window.Window | null = null;
  private isListening: boolean = false;

  private constructor() {}

  public static getInstance(): FoldDisplayService {
    if (!FoldDisplayService.instance) {
      FoldDisplayService.instance = new FoldDisplayService();
    }
    return FoldDisplayService.instance;
  }

  public init(win: window.Window): void {
    this.mainWindow = win;
    this.updateMetrics();
    this.startListening();
  }

  public getMetrics(): HarmonyDisplayMetrics {
    return this.currentMetrics;
  }

  public addListener(listener: (metrics: HarmonyDisplayMetrics) => void): void {
    this.listeners.push(listener);
    listener(this.currentMetrics);
  }

  public removeListener(listener: (metrics: HarmonyDisplayMetrics) => void): void {
    const idx = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  private startListening(): void {
    if (this.isListening || !this.mainWindow) return;
    this.isListening = true;

    try {
      if (display.isFoldable()) {
        display.on('foldStatusChange', (status: display.FoldStatus) => {
          Logger.info('FoldDisplayService foldStatusChange: %{public}d', status);
          this.updateMetrics();
        });
      }
    } catch (e) {
      Logger.warn('FoldDisplayService listen foldStatus failed: %{public}s', JSON.stringify(e));
    }

    try {
      this.mainWindow.on('windowSizeChange', (size: window.Size) => {
        Logger.info('FoldDisplayService windowSizeChange: %{public}d x %{public}d', size.width, size.height);
        this.updateMetrics();
      });
    } catch (e) {
      Logger.warn('FoldDisplayService listen windowSize failed: %{public}s', JSON.stringify(e));
    }

    try {
      this.mainWindow.on('avoidAreaChange', (options: window.AvoidAreaOptions) => {
        if (options.type === window.AvoidAreaType.TYPE_SYSTEM ||
            options.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR ||
            options.type === window.AvoidAreaType.TYPE_KEYBOARD) {
          Logger.info('FoldDisplayService avoidAreaChange type: %{public}d', options.type);
          this.updateMetrics();
        }
      });
    } catch (e) {
      Logger.warn('FoldDisplayService listen avoidArea failed: %{public}s', JSON.stringify(e));
    }
  }

  public updateMetrics(): void {
    try {
      let isFoldable = false;
      let foldStatus = display.FoldStatus.FOLD_STATUS_UNKNOWN;
      try {
        isFoldable = display.isFoldable();
        if (isFoldable) {
          foldStatus = display.getFoldStatus();
        }
      } catch (e) {
        // Fallback for non-foldable devices or unsupported APIs
      }

      let rotation = 0;
      let orientation = 0;
      let densityPixels = 1.0;
      try {
        const defDisplay = display.getDefaultDisplaySync();
        rotation = defDisplay.rotation;
        orientation = defDisplay.orientation;
        densityPixels = defDisplay.densityPixels > 0 ? defDisplay.densityPixels : 1.0;
      } catch (e) {
        // Ignore
      }

      let widthPx = 0;
      let heightPx = 0;
      let systemAvoidArea: window.AvoidArea | null = null;
      let navAvoidArea: window.AvoidArea | null = null;
      let keyboardAvoidArea: window.AvoidArea | null = null;

      if (this.mainWindow) {
        try {
          const winProps = this.mainWindow.getWindowProperties();
          widthPx = winProps.windowRect.width;
          heightPx = winProps.windowRect.height;
          systemAvoidArea = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
          navAvoidArea = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
          keyboardAvoidArea = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD);
        } catch (e) {
          // Ignore
        }
      }

      const widthVp = Math.round(widthPx / densityPixels);
      const heightVp = Math.round(heightPx / densityPixels);

      const topPx = Math.max(systemAvoidArea?.topRect?.height ?? 0, 0);
      const bottomPx = Math.max(
        systemAvoidArea?.bottomRect?.height ?? 0,
        navAvoidArea?.bottomRect?.height ?? 0,
        keyboardAvoidArea?.bottomRect?.height ?? 0
      );
      const leftPx = Math.max(systemAvoidArea?.leftRect?.width ?? 0, 0);
      const rightPx = Math.max(systemAvoidArea?.rightRect?.width ?? 0, 0);

      const topVp = Math.round(topPx / densityPixels);
      const bottomVp = Math.round(bottomPx / densityPixels);
      const leftVp = Math.round(leftPx / densityPixels);
      const rightVp = Math.round(rightPx / densityPixels);

      const isLandscape = widthVp > heightVp;
      const isFoldExpanded = foldStatus === display.FoldStatus.FOLD_STATUS_EXPANDED;
      const isFolded = foldStatus === display.FoldStatus.FOLD_STATUS_FOLDED;
      const isHalfFolded = foldStatus === display.FoldStatus.FOLD_STATUS_HALF_FOLDED;

      const safeInsets = new DefaultSafeAreaInsets();
      safeInsets.top = topVp;
      safeInsets.bottom = bottomVp;
      safeInsets.left = leftVp;
      safeInsets.right = rightVp;

      const nextMetrics = new DefaultDisplayMetrics();
      nextMetrics.foldStatus = foldStatus as number;
      nextMetrics.isFoldExpanded = isFoldExpanded;
      nextMetrics.isFolded = isFolded;
      nextMetrics.isHalfFolded = isHalfFolded;
      nextMetrics.isFoldable = isFoldable;
      nextMetrics.rotation = rotation;
      nextMetrics.orientation = orientation;
      nextMetrics.widthVp = widthVp;
      nextMetrics.heightVp = heightVp;
      nextMetrics.isLandscape = isLandscape;
      nextMetrics.safeAreaInsets = safeInsets;

      this.currentMetrics = nextMetrics;

      for (let listener of this.listeners) {
        listener(this.currentMetrics);
      }
    } catch (e) {
      Logger.error('FoldDisplayService updateMetrics error: %{public}s', JSON.stringify(e));
    }
  }
}
