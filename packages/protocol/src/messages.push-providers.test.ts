import { describe, expect, test } from "vitest";
import { RegisterPushTokenMessageSchema, PushUnregisterRequestSchema } from "./messages.js";

describe("push provider wire compatibility", () => {
  test("keeps the existing Expo registration and revocation shapes unchanged", () => {
    const register = { type: "register_push_token", token: "ExponentPushToken[test]" };
    expect(RegisterPushTokenMessageSchema.parse(register)).toEqual(register);
    const revoke = {
      type: "push.unregister.request",
      token: "ExponentPushToken[test]",
      requestId: "request",
    };
    expect(PushUnregisterRequestSchema.parse(revoke)).toEqual(revoke);
  });
  test("preserves the explicit Huawei provider and rejects unknown providers", () => {
    const register = { type: "register_push_token", token: "huawei-token", provider: "huawei" };
    expect(RegisterPushTokenMessageSchema.parse(register)).toEqual(register);
    expect(
      RegisterPushTokenMessageSchema.safeParse({ ...register, provider: "unknown" }).success,
    ).toBe(false);
  });
});
