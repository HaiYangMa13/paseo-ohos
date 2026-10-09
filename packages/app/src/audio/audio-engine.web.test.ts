import { afterEach, describe, expect, it, vi } from "vitest";
import { createAudioEngine } from "./audio-engine.web";

vi.mock("@/desktop/host", () => ({ isElectronRuntime: () => false }));

afterEach(() => {
  vi.unstubAllGlobals();
});

function createCaptureFixture(secure: boolean, harmony: boolean) {
  const stop = vi.fn();
  const close = vi.fn(async () => {});
  const stream = { getTracks: () => [{ stop }] };
  class CaptureContext {
    state = "running";
    destination = {};
    sampleRate = 48000;
    close = close;
    createMediaStreamSource() {
      return { connect: vi.fn(), disconnect: vi.fn() };
    }
    createScriptProcessor() {
      return { connect: vi.fn(), disconnect: vi.fn(), onaudioprocess: null };
    }
    createGain() {
      return { gain: { value: 1 }, connect: vi.fn(), disconnect: vi.fn() };
    }
  }
  vi.stubGlobal("window", {
    isSecureContext: secure,
    location: { origin: secure ? "https://example.com" : "null" },
    AudioContext: CaptureContext,
  });
  vi.stubGlobal("HarmonyBridge", harmony ? {} : undefined);
  const onError = vi.fn();
  const engine = createAudioEngine({ onCaptureData: vi.fn(), onVolumeLevel: vi.fn(), onError });
  return { engine, stream, stop, close, onError };
}

describe("web audio capture", () => {
  it("prefers the modern API and releases microphone resources", async () => {
    const { engine, stream, stop, close } = createCaptureFixture(true, false);
    const modern = vi.fn(async () => stream);
    const legacy = vi.fn();
    vi.stubGlobal("navigator", { mediaDevices: { getUserMedia: modern }, getUserMedia: legacy });

    await engine.startCapture();
    expect(modern).toHaveBeenCalledOnce();
    expect(legacy).not.toHaveBeenCalled();
    await engine.stopCapture();
    expect(stop).toHaveBeenCalledOnce();
    expect(close).toHaveBeenCalledOnce();
  });

  it("uses the legacy ArkWeb API with its navigator receiver on a rawfile origin", async () => {
    const { engine, stream } = createCaptureFixture(false, true);
    const legacy = vi.fn(function (
      this: unknown,
      _constraints: MediaStreamConstraints,
      success: (stream: unknown) => void,
    ) {
      expect(this).toBe(navigator);
      success(stream);
    });
    vi.stubGlobal("navigator", { webkitGetUserMedia: legacy });

    await engine.startCapture();
    expect(legacy).toHaveBeenCalledOnce();
    await engine.stopCapture();
  });

  it("does not relax secure-context checks for an ordinary browser", async () => {
    const { engine, stream } = createCaptureFixture(false, false);
    const modern = vi.fn(async () => stream);
    vi.stubGlobal("navigator", { mediaDevices: { getUserMedia: modern } });

    await expect(engine.startCapture()).rejects.toThrow("requires HTTPS or localhost");
    expect(modern).not.toHaveBeenCalled();
  });

  it("propagates permission denial without trying a legacy API", async () => {
    const { engine, onError, close } = createCaptureFixture(false, true);
    const denied = new Error("Permission denied");
    const modern = vi.fn(async () => {
      throw denied;
    });
    const legacy = vi.fn();
    vi.stubGlobal("navigator", { mediaDevices: { getUserMedia: modern }, getUserMedia: legacy });

    await expect(engine.startCapture()).rejects.toThrow("Permission denied");
    expect(legacy).not.toHaveBeenCalled();
    expect(onError).toHaveBeenCalledWith(denied);
    expect(close).toHaveBeenCalledOnce();
  });
});
