import { constants, createPrivateKey, sign } from "node:crypto";
import { readFileSync } from "node:fs";
import { z } from "zod";
import type { PushPayload } from "./push-service.js";

const CredentialsSchema = z.object({
  project_id: z.string().trim().min(1),
  key_id: z.string().trim().min(1),
  sub_account: z.string().trim().min(1),
  private_key: z.string().min(1),
});
const RouteDataSchema = z.object({
  serverId: z.string().min(1).max(256),
  workspaceId: z.string().min(1).max(256),
  agentId: z.string().min(1).max(256),
});
const ResponseSchema = z.object({ code: z.string().regex(/^\d{8}$/) });
const CategorySchema = z.string().trim().min(1).max(64);

export type HuaweiPushDelivery = (tokens: string[], payload: PushPayload) => Promise<void>;

export class HuaweiPushError extends Error {
  constructor(public readonly code: string) {
    super(`Huawei push request failed (${code})`);
    this.name = "HuaweiPushError";
  }
}

interface HuaweiPushOptions {
  credentials: unknown;
  category: string;
  testMessage: boolean;
  now?: () => number;
  request?: typeof fetch;
}

export function createHuaweiPushDelivery(options: HuaweiPushOptions): HuaweiPushDelivery {
  const credentials = CredentialsSchema.parse(options.credentials);
  const category = CategorySchema.parse(options.category);
  const key = createPrivateKey(credentials.private_key);
  const isRsaKey = key.asymmetricKeyType === "rsa" || key.asymmetricKeyType === "rsa-pss";
  if (!isRsaKey) throw new HuaweiPushError("INVALID_RSA_KEY");
  const now = options.now ?? Date.now;
  const request = options.request ?? fetch;
  const url = `https://push-api.cloud.huawei.com/v3/${encodeURIComponent(credentials.project_id)}/messages:send`;

  function authorization(): string {
    const iat = Math.floor(now() / 1000);
    const header = Buffer.from(
      JSON.stringify({ alg: "PS256", typ: "JWT", kid: credentials.key_id }),
    ).toString("base64url");
    const claims = Buffer.from(
      JSON.stringify({
        iss: credentials.sub_account,
        aud: "https://oauth-login.cloud.huawei.com/oauth2/v3/token",
        iat,
        exp: iat + 3600,
      }),
    ).toString("base64url");
    const input = `${header}.${claims}`;
    const signature = sign("sha256", Buffer.from(input), {
      key,
      padding: constants.RSA_PKCS1_PSS_PADDING,
      saltLength: 32,
    }).toString("base64url");
    return `Bearer ${input}.${signature}`;
  }

  return async (tokens, payload) => {
    if (tokens.length === 0) return;
    // Initial HarmonyOS scope is agent completion/approval, not terminal attention.
    if (payload.data?.agentId === undefined) return;
    const data = RouteDataSchema.parse(payload.data);
    const notification = {
      category,
      title: "Paseo",
      body: "任务状态有更新，请打开应用查看。",
      foregroundShow: false,
      clickAction: { actionType: 0, data },
    };
    const pushOptions = { testMessage: options.testMessage, ttl: 3600 };
    // Token bytes are excluded from Huawei's 4096-byte message limit.
    const messageBytes = Buffer.byteLength(
      JSON.stringify({ payload: { notification }, pushOptions }),
    );
    if (messageBytes > 4096) throw new HuaweiPushError("MESSAGE_TOO_LARGE");
    // Test messages allow at most 10 tokens. Serial batches bound request pressure.
    for (let start = 0; start < tokens.length; start += 10) {
      const body = {
        payload: { notification },
        target: { token: tokens.slice(start, start + 10) },
        pushOptions,
      };
      const response = await request(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: authorization(),
          "push-type": "0",
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(10_000),
        redirect: "error",
      }).catch(() => {
        throw new HuaweiPushError("TRANSPORT_ERROR");
      });
      if (!response.ok) throw new HuaweiPushError(`HTTP_${response.status}`);
      const result: unknown = await response.json().catch(() => {
        throw new HuaweiPushError("INVALID_RESPONSE");
      });
      const parsed = ResponseSchema.safeParse(result);
      if (!parsed.success) throw new HuaweiPushError("INVALID_RESPONSE");
      if (parsed.data.code !== "80000000") throw new HuaweiPushError(parsed.data.code);
    }
  };
}

export function loadHuaweiPushDelivery(
  environment: NodeJS.ProcessEnv,
): HuaweiPushDelivery | undefined {
  const file = environment.PASEO_HUAWEI_PUSH_KEY_FILE;
  if (!file) return undefined;
  const category = environment.PASEO_HUAWEI_PUSH_CATEGORY ?? "MARKETING";
  const testSetting = environment.PASEO_HUAWEI_PUSH_TEST_MESSAGE ?? "true";
  const testMessage = z.enum(["true", "false"]).parse(testSetting) === "true";
  if (!testMessage && !environment.PASEO_HUAWEI_PUSH_CATEGORY) {
    throw new HuaweiPushError("PRODUCTION_CATEGORY_REQUIRED");
  }
  const credentials: unknown = JSON.parse(readFileSync(file, "utf8"));
  return createHuaweiPushDelivery({ credentials, category, testMessage });
}
