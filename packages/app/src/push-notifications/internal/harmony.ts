import AsyncStorage from "@react-native-async-storage/async-storage";
import type { DaemonClient } from "@getpaseo/client/internal/daemon-client";
import { create } from "zustand";
import { z } from "zod";
import { readValidatedString } from "@/storage/validated-storage";
import { getHarmonyPushBridge, HARMONY_PUSH_EVENT, NativePushStateSchema } from "./harmony-bridge";
import type { RevokePushNotificationsInput } from "./types";

export type HarmonySubscriptionClient = Pick<
  DaemonClient,
  "isConnected" | "registerPushToken" | "unregisterPushToken" | "subscribeConnectionStatus"
> & {
  getLastServerInfoMessage(): Pick<
    NonNullable<ReturnType<DaemonClient["getLastServerInfoMessage"]>>,
    "features"
  > | null;
};
type Storage = Pick<typeof AsyncStorage, "getItem" | "setItem" | "removeItem">;
export type HarmonyPushState =
  | { status: "ready" | "loading" | "permission-required" | "denied" | "unavailable" }
  | { status: "error"; code: number };
export interface HarmonyPushEntry {
  state: HarmonyPushState;
  retry: () => void;
  stop: () => void;
}
interface PushStore {
  entries: Record<string, HarmonyPushEntry>;
}
export const useHarmonyPushStore = create<PushStore>(() => ({ entries: {} }));
const TokenSchema = z.string().trim().min(1);
const STORAGE_PREFIX = "@paseo:huawei-push-token:";

export function startHarmonySubscription(input: {
  client: HarmonySubscriptionClient;
  serverId: string;
  storage?: Storage;
}): () => void {
  if (typeof window === "undefined") return () => undefined;
  const storage = input.storage ?? AsyncStorage;
  const key = `${STORAGE_PREFIX}${input.serverId}`;
  let stopped = false;
  let queue = Promise.resolve();

  function publish(state: HarmonyPushState): void {
    if (stopped) return;
    const entries = useHarmonyPushStore.getState().entries;
    useHarmonyPushStore.setState({
      entries: { ...entries, [input.serverId]: { state, retry, stop } },
    });
  }

  async function synchronize(): Promise<void> {
    if (stopped || !input.client.isConnected) return;
    const bridge = getHarmonyPushBridge();
    if (!bridge) return;
    // COMPAT(huaweiPushNotifications): added in v0.11.1-ohos, remove gate after 2027-04-08 once host floor supports Huawei.
    if (input.client.getLastServerInfoMessage()?.features?.huaweiPushNotifications !== true) {
      publish({ status: "unavailable" });
      return;
    }
    const raw: unknown = JSON.parse(bridge.getPushState());
    const state = NativePushStateSchema.parse(raw);
    if (state.status !== "ready") {
      publish(state);
      return;
    }
    const oldToken = await readValidatedString(storage, key, TokenSchema);
    if (stopped || !input.client.isConnected) return;
    if (oldToken && oldToken !== state.token)
      await input.client.unregisterPushToken(oldToken, "huawei");
    await storage.setItem(key, state.token);
    if (stopped || !input.client.isConnected) return;
    input.client.registerPushToken(state.token, "huawei");
    publish({ status: "ready" });
  }

  function sync(): void {
    queue = queue.then(synchronize).catch(() => publish({ status: "error", code: -1 }));
  }

  function retry(): void {
    if (stopped || !input.client.isConnected) return;
    if (input.client.getLastServerInfoMessage()?.features?.huaweiPushNotifications !== true) {
      sync();
      return;
    }
    try {
      getHarmonyPushBridge()?.requestPushPermission();
      sync();
    } catch {
      publish({ status: "error", code: -1 });
    }
  }

  const unsubscribe = input.client.subscribeConnectionStatus((state) => {
    if (state.status === "connected") sync();
  });
  window.addEventListener(HARMONY_PUSH_EVENT, sync);
  sync();

  function stop(): void {
    stopped = true;
    unsubscribe();
    window.removeEventListener(HARMONY_PUSH_EVENT, sync);
    const entries = useHarmonyPushStore.getState().entries;
    if (entries[input.serverId]?.retry !== retry) return;
    const next = { ...entries };
    delete next[input.serverId];
    useHarmonyPushStore.setState({ entries: next });
  }
  return stop;
}

export async function revokeHarmonySubscription(
  input: RevokePushNotificationsInput,
): Promise<void> {
  useHarmonyPushStore.getState().entries[input.serverId]?.stop();
  const key = `${STORAGE_PREFIX}${input.serverId}`;
  const token = await readValidatedString(AsyncStorage, key, TokenSchema);
  const capable =
    input.client?.getLastServerInfoMessage()?.features?.huaweiPushNotifications === true;
  if (token && capable && input.client?.isConnected)
    await input.client.unregisterPushToken(token, "huawei");
  await AsyncStorage.removeItem(key);
}
