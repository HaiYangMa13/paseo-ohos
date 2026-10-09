import { afterEach, describe, expect, test, vi } from "vitest";
import { bindHarmonyPushClicks, HARMONY_PUSH_EVENT } from "./harmony-bridge";

afterEach(() => vi.unstubAllGlobals());

describe("Harmony notification clicks", () => {
  test("consumes a pending cold-start click once and handles later warm clicks", () => {
    const events = new EventTarget();
    const pending = [
      JSON.stringify({
        serverId: "host",
        workspaceId: "workspace",
        agentId: "agent",
        approve: true,
      }),
    ];
    const open = vi.fn();
    vi.stubGlobal("window", {
      HarmonyBridge: {
        getPushState: () => "",
        requestPushPermission: () => undefined,
        consumePushClick: () => pending.shift() ?? "",
      },
      addEventListener: events.addEventListener.bind(events),
      removeEventListener: events.removeEventListener.bind(events),
    });
    const stop = bindHarmonyPushClicks({
      isKnownHost: (id) => id === "host" || id === "123",
      open,
    });
    expect(open).toHaveBeenCalledWith({
      serverId: "host",
      workspaceId: "workspace",
      agentId: "agent",
    });
    events.dispatchEvent(new Event(HARMONY_PUSH_EVENT));
    expect(open).toHaveBeenCalledTimes(1);
    pending.push(JSON.stringify({ serverId: "host", workspaceId: "workspace", agentId: "next" }));
    events.dispatchEvent(new Event(HARMONY_PUSH_EVENT));
    // Huawei delivers notification data as raw platform strings.
    pending.push(JSON.stringify({ serverId: 123, workspaceId: "workspace", agentId: "numeric" }));
    events.dispatchEvent(new Event(HARMONY_PUSH_EVENT));
    expect(open).toHaveBeenLastCalledWith({
      serverId: "123",
      workspaceId: "workspace",
      agentId: "numeric",
    });
    stop();
    pending.push(JSON.stringify({ serverId: "host" }));
    events.dispatchEvent(new Event(HARMONY_PUSH_EVENT));
    expect(open).toHaveBeenCalledTimes(3);
  });

  test.each([
    "not-json",
    JSON.stringify({ serverId: "unpaired" }),
    JSON.stringify({ serverId: 123 }),
  ])("rejects invalid or unpaired targets: %s", (raw) => {
    const events = new EventTarget();
    const open = vi.fn();
    vi.stubGlobal("window", {
      HarmonyBridge: {
        getPushState: () => "",
        requestPushPermission: () => undefined,
        consumePushClick: () => raw,
      },
      addEventListener: events.addEventListener.bind(events),
      removeEventListener: events.removeEventListener.bind(events),
    });
    const stop = bindHarmonyPushClicks({ isKnownHost: (id) => id === "host", open });
    expect(open).not.toHaveBeenCalled();
    stop();
  });
});
