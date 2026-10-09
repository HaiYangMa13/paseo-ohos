export type HarmonyAppLifecycleState = 'active' | 'background';
export type HarmonyAppLifecycleListener = (state: HarmonyAppLifecycleState) => void;

/**
 * Bridges UIAbility lifecycle changes to the ArkWeb page without recreating
 * the page or losing its current route. The latest state is replayed when the
 * page registers so foreground events that happen during startup are not lost.
 */
export class AppLifecycleService {
  private static instance: AppLifecycleService | null = null;
  private state: HarmonyAppLifecycleState = 'active';
  private listener: HarmonyAppLifecycleListener | null = null;

  private constructor() {}

  public static getInstance(): AppLifecycleService {
    if (!AppLifecycleService.instance) {
      AppLifecycleService.instance = new AppLifecycleService();
    }
    return AppLifecycleService.instance;
  }

  public getState(): HarmonyAppLifecycleState {
    return this.state;
  }

  public setListener(listener: HarmonyAppLifecycleListener): void {
    this.listener = listener;
    listener(this.state);
  }

  public clearListener(): void {
    this.listener = null;
  }

  public publish(state: HarmonyAppLifecycleState): void {
    this.state = state;
    this.listener?.(state);
  }
}
