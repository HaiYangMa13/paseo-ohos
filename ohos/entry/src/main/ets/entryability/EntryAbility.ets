import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { sensor } from '@kit.SensorServiceKit';

interface AmbientLightSample {
  intensity: number;
}

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  private ambientLightCallback: ((data: AmbientLightSample) => void) | null = null;

  private applyImmersiveWindow(light: boolean): void {
    const win = this.mainWindow;
    if (!win) return;
    try {
      win.setWindowLayoutFullScreen(true).catch((error: Object) => {
        hilog.warn(0x0000, 'PaseoAbility', 'setWindowLayoutFullScreen failed: %{public}s', JSON.stringify(error));
      });
      win.setWindowSystemBarEnable(['status', 'navigation']).catch((error: Object) => {
        hilog.warn(0x0000, 'PaseoAbility', 'setWindowSystemBarEnable failed: %{public}s', JSON.stringify(error));
      });
      // Transparent system bars let ArkWeb paint the Paseo surface underneath
      // both bars; icon contrast follows the ambient-light reading.
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        isStatusBarLightIcon: light,
        isNavigationBarLightIcon: light
      });
      win.setImmersiveModeEnabledState(true);
    } catch (error) {
      hilog.warn(0x0000, 'PaseoAbility', 'immersive window setup failed: %{public}s', JSON.stringify(error));
    }
  }

  private startAmbientLightAdaptation(): void {
    this.ambientLightCallback = (data: AmbientLightSample): void => {
      // Dark surroundings need light system icons; bright surroundings need
      // dark icons. Clamp the threshold to avoid flicker around the boundary.
      this.applyImmersiveWindow(data.intensity < 80);
    };
    try {
      sensor.on(sensor.SensorId.AMBIENT_LIGHT, this.ambientLightCallback, { interval: 500000000 });
    } catch (error) {
      hilog.warn(0x0000, 'PaseoAbility', 'ambient light unavailable: %{public}s', JSON.stringify(error));
    }
  }

  private stopAmbientLightAdaptation(): void {
    if (!this.ambientLightCallback) return;
    try {
      sensor.off(sensor.SensorId.AMBIENT_LIGHT, this.ambientLightCallback);
    } catch (error) {
      hilog.warn(0x0000, 'PaseoAbility', 'ambient light stop failed: %{public}s', JSON.stringify(error));
    }
    this.ambientLightCallback = null;
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'PaseoAbility', 'Ability onCreate');
  }

  onDestroy(): void {
    this.stopAmbientLightAdaptation();
    hilog.info(0x0000, 'PaseoAbility', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'PaseoAbility', 'Ability onWindowStageCreate');

    // Enable full-screen immersive experience
    let windowClass: window.Window | undefined = undefined;
    windowStage.getMainWindow((err, data) => {
      if (err.code) {
        hilog.error(0x0000, 'PaseoAbility', 'Failed to get main window: %{public}s', JSON.stringify(err));
        return;
      }
      windowClass = data;
      this.mainWindow = data;
      this.applyImmersiveWindow(false);
      this.startAmbientLightAdaptation();
    });

    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        hilog.error(0x0000, 'PaseoAbility', 'Failed to load content: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'PaseoAbility', 'Succeeded loading content');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'PaseoAbility', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, 'PaseoAbility', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, 'PaseoAbility', 'Ability onBackground');
  }
}
