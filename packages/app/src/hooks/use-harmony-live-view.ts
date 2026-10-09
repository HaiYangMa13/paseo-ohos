import { useEffect, useRef, useState } from "react";
import { useAggregatedAgents } from "@/hooks/use-aggregated-agents";

interface HarmonyLiveViewBridge {
  updateAgentStatus(title: string, status: string, provider: string, model: string): void;
  notifyPermission(toolName: string, description: string): void;
}

function getHarmonyBridge(): HarmonyLiveViewBridge | null {
  if (typeof globalThis === "undefined") return null;
  return (
    (
      globalThis as typeof globalThis & {
        HarmonyBridge?: HarmonyLiveViewBridge;
      }
    ).HarmonyBridge ?? null
  );
}

/**
 * Mirrors the most important Paseo agent state into the native HarmonyOS
 * shell. The shell owns Live View Kit and notification APIs; the web client
 * only supplies current agent state.
 */
export function useHarmonyLiveView(): void {
  // ArkWeb can install a JavaScript proxy just after the first application
  // modules have evaluated, so do not rely on the module-level isHarmony
  // constant here. Wait for the live bridge itself and then subscribe.
  const [bridgeReady, setBridgeReady] = useState(() => getHarmonyBridge() !== null);
  const { agents } = useAggregatedAgents({ demand: bridgeReady });
  const lastLiveViewKeyRef = useRef("");
  const lastPermissionKeyRef = useRef("");

  useEffect(() => {
    if (bridgeReady) return;
    const timer = setInterval(() => {
      if (getHarmonyBridge()) {
        setBridgeReady(true);
      }
    }, 250);
    return () => clearInterval(timer);
  }, [bridgeReady]);

  useEffect(() => {
    if (!bridgeReady) return;
    const bridge = getHarmonyBridge();
    if (!bridge) return;

    const runningAgent = agents.find((agent) => agent.status === "running");
    const liveViewKey = runningAgent
      ? `${runningAgent.serverId}:${runningAgent.id}:${runningAgent.status}:${runningAgent.title ?? ""}`
      : "idle";

    if (liveViewKey !== lastLiveViewKeyRef.current) {
      lastLiveViewKeyRef.current = liveViewKey;
      if (runningAgent) {
        bridge.updateAgentStatus(
          runningAgent.title?.trim() || "Agent",
          "running",
          runningAgent.provider || "agent",
          "",
        );
      } else {
        bridge.updateAgentStatus("", "idle", "", "");
      }
    }
  }, [agents, bridgeReady]);

  useEffect(() => {
    if (!bridgeReady) return;
    const bridge = getHarmonyBridge();
    if (!bridge) return;

    const permissionAgent = agents.find(
      (agent) => (agent.pendingPermissionCount ?? 0) > 0 || agent.requiresAttention,
    );
    const permissionKey = permissionAgent
      ? `${permissionAgent.serverId}:${permissionAgent.id}:${permissionAgent.pendingPermissionCount ?? 0}:${permissionAgent.attentionTimestamp?.getTime?.() ?? ""}`
      : "";

    if (permissionAgent && permissionKey && permissionKey !== lastPermissionKeyRef.current) {
      lastPermissionKeyRef.current = permissionKey;
      bridge.notifyPermission(
        "Agent approval",
        `${permissionAgent.title?.trim() || "Agent"} is waiting for your input`,
      );
    } else if (!permissionKey) {
      lastPermissionKeyRef.current = "";
    }
  }, [agents, bridgeReady]);
}
