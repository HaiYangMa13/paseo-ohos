import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import type pino from "pino";
import { afterEach, describe, expect, test } from "vitest";

import { createPushNotifications } from "./index.js";

function createLogger(): pino.Logger {
  const logger = {
    child: () => logger,
    debug: () => undefined,
    info: () => undefined,
    warn: () => undefined,
    error: () => undefined,
  };
  return logger as unknown as pino.Logger;
}

describe("push notifications", () => {
  const homes: string[] = [];

  afterEach(() => {
    for (const home of homes.splice(0)) {
      rmSync(home, { recursive: true, force: true });
    }
  });

  test("an offline device stops receiving notifications after 48 hours", async () => {
    const home = mkdtempSync(path.join(tmpdir(), "paseo-push-notifications-"));
    homes.push(home);
    const filePath = path.join(home, "push-tokens.json");
    let now = Date.parse("2026-08-10T00:00:00.000Z");
    const deliveries: string[][] = [];
    const pushNotifications = createPushNotifications({
      logger: createLogger(),
      filePath,
      now: () => now,
      deliver: async (tokens) => deliveries.push(tokens),
    });

    pushNotifications.renew("ExponentPushToken[offline-device]");
    now += 48 * 60 * 60 * 1000;
    await pushNotifications.send({ title: "Agent finished", body: "Done" });

    expect(deliveries).toEqual([]);
    expect(JSON.parse(readFileSync(filePath, "utf8"))).toEqual({ subscriptions: [] });
  });

  test("Huawei tokens use separate storage and delivery, including renewal after restart", async () => {
    const home = mkdtempSync(path.join(tmpdir(), "paseo-push-providers-"));
    homes.push(home);
    const filePath = path.join(home, "push-tokens.json");
    const expoDeliveries: string[][] = [];
    const huaweiDeliveries: string[][] = [];
    const options = {
      logger: createLogger(),
      filePath,
      deliver: async (tokens: string[]) => {
        expoDeliveries.push(tokens);
      },
      huaweiDeliver: async (tokens: string[]) => {
        huaweiDeliveries.push(tokens);
      },
    };
    const first = createPushNotifications(options);
    first.renew("expo-device");
    first.renew("huawei-device", "huawei");
    const restarted = createPushNotifications(options);
    await restarted.send({ title: "Done", body: "Task completed" });
    expect(expoDeliveries).toEqual([["expo-device"]]);
    expect(huaweiDeliveries).toEqual([["huawei-device"]]);
    expect(readFileSync(filePath, "utf8")).not.toContain("huawei-device");
    restarted.revoke("huawei-device", "huawei");
    await restarted.send({ title: "Done", body: "Task completed" });
    expect(expoDeliveries).toEqual([["expo-device"], ["expo-device"]]);
    expect(huaweiDeliveries).toEqual([["huawei-device"]]);
  });

  test("a token stored before Huawei push is configured is delivered after a restart", async () => {
    const home = mkdtempSync(path.join(tmpdir(), "paseo-push-late-huawei-"));
    homes.push(home);
    const filePath = path.join(home, "push-tokens.json");
    const huaweiDeliveries: string[][] = [];
    const withoutHuawei = createPushNotifications({
      logger: createLogger(),
      filePath,
      deliver: async () => undefined,
    });
    expect(withoutHuawei.huaweiAvailable).toBe(false);
    withoutHuawei.renew("huawei-device", "huawei");
    withoutHuawei.renew("expo-device");
    await withoutHuawei.send({ title: "Done", body: "Task completed" });
    const configured = createPushNotifications({
      logger: createLogger(),
      filePath,
      deliver: async () => undefined,
      huaweiDeliver: async (tokens) => {
        huaweiDeliveries.push(tokens);
      },
    });
    await configured.send({ title: "Done", body: "Task completed" });
    expect(huaweiDeliveries).toEqual([["huawei-device"]]);
  });

  test("online revocation stops notifications immediately", async () => {
    const home = mkdtempSync(path.join(tmpdir(), "paseo-push-notifications-"));
    homes.push(home);
    const deliveries: string[][] = [];
    const pushNotifications = createPushNotifications({
      logger: createLogger(),
      filePath: path.join(home, "push-tokens.json"),
      now: () => Date.parse("2026-08-10T00:00:00.000Z"),
      deliver: async (tokens) => deliveries.push(tokens),
    });

    pushNotifications.renew("ExponentPushToken[online-device]");
    pushNotifications.revoke("ExponentPushToken[online-device]");
    await pushNotifications.send({ title: "Agent finished", body: "Done" });

    expect(deliveries).toEqual([]);
  });
});
