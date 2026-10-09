import { z } from "zod";
import { isWeb } from "@/constants/platform";

export const HARMONY_PUSH_EVENT = "paseo:harmony-push-state";
export const NativePushStateSchema = z.discriminatedUnion("status", [
  z.object({ status: z.literal("ready"), token: z.string().trim().min(1) }),
  z.object({ status: z.literal("loading") }),
  z.object({ status: z.literal("permission-required") }),
  z.object({ status: z.literal("denied") }),
  z.object({ status: z.literal("not-activated"), code: z.number().int() }),
  z.object({ status: z.literal("error"), code: z.number().int() }),
]);
// Huawei notification data reaches the app as raw platform strings, so accept digits here.
const ClickSchema = z.object({
  serverId: z.coerce.string().trim().min(1).max(256),
  workspaceId: z.coerce.string().trim().min(1).max(256).optional(),
  agentId: z.coerce.string().trim().min(1).max(256).optional(),
  terminalId: z.coerce.string().trim().min(1).max(256).optional(),
});
export type HarmonyNotificationClick = z.infer<typeof ClickSchema>;

interface HarmonyPushBridge {
  getPushState(): string;
  requestPushPermission(): void;
  consumePushClick(): string;
}

declare global {
  interface Window {
    HarmonyBridge?: HarmonyPushBridge;
  }
}

export function getHarmonyPushBridge(): HarmonyPushBridge | null {
  if (!isWeb || typeof window === "undefined") return null;
  const bridge = window.HarmonyBridge;
  return typeof bridge?.getPushState === "function" ? bridge : null;
}

export function bindHarmonyPushClicks(input: {
  isKnownHost: (serverId: string) => boolean;
  open: (data: HarmonyNotificationClick) => void;
}): () => void {
  if (!isWeb || typeof window === "undefined") return () => undefined;
  function consume(): void {
    const raw = getHarmonyPushBridge()?.consumePushClick();
    if (!raw) return;
    let value: unknown;
    try {
      value = JSON.parse(raw);
    } catch {
      return;
    }
    const parsed = ClickSchema.safeParse(value);
    if (parsed.success && input.isKnownHost(parsed.data.serverId)) input.open(parsed.data);
  }
  window.addEventListener(HARMONY_PUSH_EVENT, consume);
  consume();
  return () => window.removeEventListener(HARMONY_PUSH_EVENT, consume);
}
