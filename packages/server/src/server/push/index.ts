import type pino from "pino";
import type { PushProvider } from "@getpaseo/protocol/messages";
import type { HuaweiPushDelivery } from "./huawei.js";
import { PushService, type PushPayload } from "./push-service.js";
import { PushTokenStore } from "./token-store.js";

export type { PushPayload };
const PUSH_TOKEN_LEASE_MS = 48 * 60 * 60 * 1000;

export interface PushNotifications {
  huaweiAvailable?: boolean;
  renew(token: string, provider?: PushProvider): void;
  revoke(token: string, provider?: PushProvider): void;
  send(payload: PushPayload): Promise<void>;
}
export type PushNotificationSender = Pick<PushNotifications, "send">;

export function createPushNotifications(options: {
  logger: pino.Logger;
  filePath: string;
  now?: () => number;
  deliver?: (tokens: string[], payload: PushPayload) => Promise<void>;
  huaweiDeliver?: HuaweiPushDelivery;
}): PushNotifications {
  const now = options.now ?? Date.now;
  const stores: Record<PushProvider, PushTokenStore> = {
    expo: new PushTokenStore(options.logger, options.filePath, now, PUSH_TOKEN_LEASE_MS),
    // Separate files also prevent a rolled-back Expo-only daemon from uploading Huawei tokens.
    huawei: new PushTokenStore(
      options.logger,
      `${options.filePath}.huawei`,
      now,
      PUSH_TOKEN_LEASE_MS,
    ),
  };
  const service = new PushService(options.logger, (token) => stores.expo.revokeToken(token));
  const expoDeliver =
    options.deliver ??
    ((tokens: string[], payload: PushPayload) => service.sendPush(tokens, payload));

  return {
    huaweiAvailable: options.huaweiDeliver !== undefined,
    renew(token, provider = "expo") {
      // A token from a provider this daemon cannot deliver to is still stored: enabling that
      // provider later does not require every device to re-register.
      if (provider === "huawei" && !options.huaweiDeliver) {
        options.logger.warn("Received a Huawei push token without Huawei push configured");
      }
      stores[provider].renewToken(token);
    },
    revoke(token, provider = "expo") {
      stores[provider].revokeToken(token);
    },
    async send(payload) {
      const deliveries: Promise<void>[] = [];
      const expoTokens = stores.expo.getActiveTokens();
      if (expoTokens.length > 0) deliveries.push(expoDeliver(expoTokens, payload));
      const huaweiTokens = stores.huawei.getActiveTokens();
      if (huaweiTokens.length > 0) {
        if (options.huaweiDeliver) deliveries.push(options.huaweiDeliver(huaweiTokens, payload));
        else
          options.logger.warn({ tokenCount: huaweiTokens.length }, "Huawei push is not configured");
      }
      const results = await Promise.allSettled(deliveries);
      const errors = results
        .filter((result) => result.status === "rejected")
        .map((result) => result.reason);
      if (errors.length > 0) throw new AggregateError(errors, "Push notification delivery failed");
    },
  };
}
