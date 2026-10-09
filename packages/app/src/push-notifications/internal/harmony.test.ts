import { afterEach, describe, expect, test, vi } from "vitest";
import {
  startHarmonySubscription,
  useHarmonyPushStore,
  type HarmonySubscriptionClient,
} from "./harmony";

function setup(capable = true) {
  const events = new EventTarget();
  const cache = new Map<string, string>();
  const registerPushToken = vi.fn();
  const unregisterPushToken = vi.fn(async () => undefined);
  const listeners: Array<Parameters<HarmonySubscriptionClient["subscribeConnectionStatus"]>[0]> =
    [];
  const client: HarmonySubscriptionClient = {
    isConnected: true,
    registerPushToken,
    unregisterPushToken,
    getLastServerInfoMessage: () => ({ features: { huaweiPushNotifications: capable } }),
    subscribeConnectionStatus: (listener) => {
      listeners.push(listener);
      return () => undefined;
    },
  };
  const bridge = {
    getPushState: () => JSON.stringify({ status: "ready", token: "huawei-token" }),
    requestPushPermission: vi.fn(),
    consumePushClick: () => "",
  };
  vi.stubGlobal("window", {
    HarmonyBridge: bridge,
    addEventListener: events.addEventListener.bind(events),
    removeEventListener: events.removeEventListener.bind(events),
  });
  const storage = {
    getItem: async (key: string) => cache.get(key) ?? null,
    setItem: async (key: string, value: string) => {
      cache.set(key, value);
    },
    removeItem: async (key: string) => {
      cache.delete(key);
    },
  };
  return {
    client,
    bridge,
    storage,
    registerPushToken,
    unregisterPushToken,
    listeners,
    cache,
    events,
  };
}

afterEach(() => {
  vi.unstubAllGlobals();
  useHarmonyPushStore.setState({ entries: {} });
});

describe("Harmony push subscription", () => {
  test("does not send Huawei tokens or prompt for permission with an unsupported host", async () => {
    const fixture = setup(false);
    const stop = startHarmonySubscription({
      client: fixture.client,
      serverId: "host",
      storage: fixture.storage,
    });
    await vi.waitFor(() =>
      expect(useHarmonyPushStore.getState().entries.host.state).toEqual({ status: "unavailable" }),
    );
    expect(fixture.registerPushToken).not.toHaveBeenCalled();
    expect(fixture.bridge.requestPushPermission).not.toHaveBeenCalled();
    expect(fixture.cache.size).toBe(0);
    stop();
  });

  test("requests notification permission only after the user chooses Enable", async () => {
    const fixture = setup();
    fixture.bridge.getPushState = () => JSON.stringify({ status: "permission-required" });
    const stop = startHarmonySubscription({
      client: fixture.client,
      serverId: "host",
      storage: fixture.storage,
    });
    await vi.waitFor(() =>
      expect(useHarmonyPushStore.getState().entries.host.state).toEqual({
        status: "permission-required",
      }),
    );
    expect(fixture.bridge.requestPushPermission).not.toHaveBeenCalled();
    expect(fixture.registerPushToken).not.toHaveBeenCalled();
    useHarmonyPushStore.getState().entries.host.retry();
    expect(fixture.bridge.requestPushPermission).toHaveBeenCalledTimes(1);
    stop();
  });

  test("revokes a rotated token before registering its replacement", async () => {
    const fixture = setup();
    fixture.cache.set("@paseo:huawei-push-token:host", "old-token");
    const stop = startHarmonySubscription({
      client: fixture.client,
      serverId: "host",
      storage: fixture.storage,
    });
    await vi.waitFor(() =>
      expect(fixture.registerPushToken).toHaveBeenCalledWith("huawei-token", "huawei"),
    );
    expect(fixture.unregisterPushToken).toHaveBeenCalledWith("old-token", "huawei");
    expect(fixture.unregisterPushToken.mock.invocationCallOrder[0]).toBeLessThan(
      fixture.registerPushToken.mock.invocationCallOrder[0],
    );
    expect(fixture.cache.get("@paseo:huawei-push-token:host")).toBe("huawei-token");
    stop();
  });

  test("keeps a visible retryable failure when old-token revocation fails", async () => {
    const fixture = setup();
    fixture.cache.set("@paseo:huawei-push-token:host", "old-token");
    fixture.unregisterPushToken.mockRejectedValue(new Error("Host unavailable"));
    const stop = startHarmonySubscription({
      client: fixture.client,
      serverId: "host",
      storage: fixture.storage,
    });
    await vi.waitFor(() =>
      expect(useHarmonyPushStore.getState().entries.host.state).toEqual({
        status: "error",
        code: -1,
      }),
    );
    expect(fixture.registerPushToken).not.toHaveBeenCalled();
    expect(fixture.cache.get("@paseo:huawei-push-token:host")).toBe("old-token");
    stop();
  });

  test("recovers when ArkWeb installs the native proxy after subscription startup", async () => {
    const fixture = setup();
    window.HarmonyBridge = undefined;
    const stop = startHarmonySubscription({
      client: fixture.client,
      serverId: "host",
      storage: fixture.storage,
    });
    await Promise.resolve();
    expect(fixture.registerPushToken).not.toHaveBeenCalled();
    window.HarmonyBridge = fixture.bridge;
    fixture.events.dispatchEvent(new Event("paseo:harmony-push-state"));
    await vi.waitFor(() =>
      expect(fixture.registerPushToken).toHaveBeenCalledWith("huawei-token", "huawei"),
    );
    stop();
  });

  test("does not register after a pending storage read is stopped", async () => {
    const fixture = setup();
    let release: (value: string | null) => void = () => undefined;
    const read = vi.fn(
      () =>
        new Promise<string | null>((resolve) => {
          release = resolve;
        }),
    );
    fixture.storage.getItem = read;
    const stop = startHarmonySubscription({
      client: fixture.client,
      serverId: "host",
      storage: fixture.storage,
    });
    await vi.waitFor(() => expect(read).toHaveBeenCalledTimes(1));
    stop();
    release(null);
    await new Promise<void>((resolve) => setImmediate(resolve));
    expect(fixture.registerPushToken).not.toHaveBeenCalled();
    expect(fixture.cache.size).toBe(0);
  });

  test("registers Huawei tokens only with a capable host and renews on reconnect", async () => {
    const fixture = setup();
    const stop = startHarmonySubscription({
      client: fixture.client,
      serverId: "host",
      storage: fixture.storage,
    });
    await vi.waitFor(() =>
      expect(fixture.registerPushToken).toHaveBeenCalledWith("huawei-token", "huawei"),
    );
    fixture.listeners[0]({ status: "connected" });
    await vi.waitFor(() => expect(fixture.registerPushToken).toHaveBeenCalledTimes(2));
    expect(useHarmonyPushStore.getState().entries.host.state).toEqual({ status: "ready" });
    stop();
  });
});
