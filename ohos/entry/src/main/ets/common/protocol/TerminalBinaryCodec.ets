import util from '@ohos.util';
import { Logger } from '../utils/Logger';

export enum TerminalOpcode {
  Output = 0x01,
  Input = 0x02,
  Resize = 0x03,
  Snapshot = 0x04
}

export interface TerminalFrame {
  opcode: TerminalOpcode;
  slot: number;
  payloadText: string;
  resizeCols?: number;
  resizeRows?: number;
}

export class TerminalBinaryCodec {
  private static readonly textDecoder = util.TextDecoder.create('utf-8');
  private static readonly textEncoder = new util.TextEncoder('utf-8');

  /**
   * Decode an incoming binary ArrayBuffer frame from Paseo daemon
   */
  public static decode(buffer: ArrayBuffer): TerminalFrame | null {
    if (buffer.byteLength < 2) {
      Logger.warn('Terminal frame too short: %{public}d bytes', buffer.byteLength);
      return null;
    }

    const uint8Array = new Uint8Array(buffer);
    const opcode = uint8Array[0] as TerminalOpcode;
    const slot = uint8Array[1];
    const payloadBytes = uint8Array.subarray(2);

    let payloadText = '';
    try {
      payloadText = TerminalBinaryCodec.textDecoder.decodeWithStream(payloadBytes);
    } catch (err) {
      Logger.error('Failed to decode UTF-8 terminal payload: %{public}s', JSON.stringify(err));
    }

    const frame: TerminalFrame = {
      opcode,
      slot,
      payloadText
    };

    if (opcode === TerminalOpcode.Resize && payloadText) {
      try {
        const resizeObj = JSON.parse(payloadText) as Record<string, number>;
        frame.resizeCols = resizeObj['cols'];
        frame.resizeRows = resizeObj['rows'];
      } catch (err) {
        Logger.error('Failed to parse terminal resize json: %{public}s', JSON.stringify(err));
      }
    }

    return frame;
  }

  /**
   * Encode user input into a binary frame to send to Paseo daemon
   */
  public static encodeInput(slot: number, text: string): ArrayBuffer {
    const encodedPayload = TerminalBinaryCodec.textEncoder.encodeInto(text);
    const buffer = new ArrayBuffer(2 + encodedPayload.byteLength);
    const view = new Uint8Array(buffer);
    view[0] = TerminalOpcode.Input;
    view[1] = slot & 0xFF;
    view.set(encodedPayload, 2);
    return buffer;
  }

  /**
   * Encode terminal resize event
   */
  public static encodeResize(slot: number, cols: number, rows: number): ArrayBuffer {
    const jsonStr = JSON.stringify({ cols, rows });
    const encodedPayload = TerminalBinaryCodec.textEncoder.encodeInto(jsonStr);
    const buffer = new ArrayBuffer(2 + encodedPayload.byteLength);
    const view = new Uint8Array(buffer);
    view[0] = TerminalOpcode.Resize;
    view[1] = slot & 0xFF;
    view.set(encodedPayload, 2);
    return buffer;
  }
}
