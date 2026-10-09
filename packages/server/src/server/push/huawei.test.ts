import { constants, generateKeyPairSync, verify } from "node:crypto";
import { describe, expect, test } from "vitest";
import { createHuaweiPushDelivery } from "./huawei.js";

const keys = generateKeyPairSync("rsa", { modulusLength: 2048 });
const credentials = {
  project_id: "test-project",
  key_id: "test-key",
  sub_account: "test-account",
  private_key: keys.privateKey.export({ type: "pkcs8", format: "pem" }).toString(),
};

describe("Huawei notification delivery", () => {
  test("uses PS256 and V3, and sends only generic text and navigation identifiers", async () => {
    const requests: Request[] = [];
    const deliver = createHuaweiPushDelivery({
      credentials,
      category: "MARKETING",
      testMessage: true,
      now: () => Date.parse("2026-10-08T12:00:00Z"),
      request: async (url, init) => {
        requests.push(new Request(url, init));
        return Response.json({ code: "80000000", msg: "Success" });
      },
    });
    await deliver(["phone-token"], {
      title: "secret agent name",
      body: "secret shell command",
      data: { serverId: "host", workspaceId: "workspace", agentId: "agent", cwd: "secret path" },
    });
    // Terminal attention is out of scope until the shell routes it explicitly.
    await deliver(["phone-token"], {
      title: "Terminal",
      body: "Needs input",
      data: { serverId: "host", workspaceId: "workspace", terminalId: "term" },
    });
    expect(requests).toHaveLength(1);
    expect(requests).toHaveLength(1);
    const request = requests[0];
    expect(request.url).toBe("https://push-api.cloud.huawei.com/v3/test-project/messages:send");
    expect(request.headers.get("push-type")).toBe("0");
    const jwt = request.headers.get("authorization")!.slice("Bearer ".length);
    const [header, payload, signature] = jwt.split(".");
    expect(JSON.parse(Buffer.from(header, "base64url").toString())).toEqual({
      alg: "PS256",
      typ: "JWT",
      kid: "test-key",
    });
    expect(JSON.parse(Buffer.from(payload, "base64url").toString())).toEqual({
      iss: "test-account",
      aud: "https://oauth-login.cloud.huawei.com/oauth2/v3/token",
      iat: 1791460800,
      exp: 1791464400,
    });
    expect(
      verify(
        "sha256",
        Buffer.from(`${header}.${payload}`),
        {
          key: keys.publicKey,
          padding: constants.RSA_PKCS1_PSS_PADDING,
          saltLength: 32,
        },
        Buffer.from(signature, "base64url"),
      ),
    ).toBe(true);
    expect(await request.json()).toEqual({
      payload: {
        notification: {
          category: "MARKETING",
          title: "Paseo",
          body: "任务状态有更新，请打开应用查看。",
          foregroundShow: false,
          clickAction: {
            actionType: 0,
            data: { serverId: "host", workspaceId: "workspace", agentId: "agent" },
          },
        },
      },
      target: { token: ["phone-token"] },
      pushOptions: { testMessage: true, ttl: 3600 },
    });
  });
});
