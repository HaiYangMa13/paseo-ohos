import { revokeHarmonySubscription, startHarmonySubscription } from "./internal/harmony";
import type { RevokePushNotificationsInput, StartPushNotificationsInput } from "./internal/types";

export function startPushNotifications(input: StartPushNotificationsInput): () => void {
  return startHarmonySubscription(input);
}

export async function revokePushNotifications(input: RevokePushNotificationsInput): Promise<void> {
  await revokeHarmonySubscription(input);
}
