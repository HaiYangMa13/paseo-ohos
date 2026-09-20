/**
 * Lightweight ANSI escape sequence parser for HarmonyOS ArkUI Text/Span rendering
 */

export interface AnsiSpan {
  text: string;
  color?: string;
  bgColor?: string;
  bold?: boolean;
}

export class AnsiParser {
  private static readonly COLOR_MAP: Record<number, string> = {
    30: '#000000', // Black
    31: '#EF4444', // Red
    32: '#10B981', // Green
    33: '#F59E0B', // Yellow
    34: '#3B82F6', // Blue
    35: '#EC4899', // Magenta
    36: '#06B6D4', // Cyan
    37: '#E5E7EB', // White
    90: '#6B7280', // Bright Black / Gray
    91: '#F87171', // Bright Red
    92: '#34D399', // Bright Green
    93: '#FBBF24', // Bright Yellow
    94: '#60A5FA', // Bright Blue
    95: '#F472B6', // Bright Magenta
    96: '#22D3EE', // Bright Cyan
    97: '#FFFFFF'  // Bright White
  };

  private static readonly BG_COLOR_MAP: Record<number, string> = {
    40: '#000000',
    41: '#7F1D1D',
    42: '#064E3B',
    43: '#78350F',
    44: '#1E3A8A',
    45: '#701A75',
    46: '#164E63',
    47: '#374151'
  };

  /**
   * Parse an ANSI string into an array of styled spans
   */
  public static parse(input: string): AnsiSpan[] {
    const spans: AnsiSpan[] = [];
    // Regex matching ANSI escape codes like \x1b[32m or \x1b[1;31m
    const ansiRegex = /\x1b\[([0-9;]*)m/g;

    let currentColor: string | undefined = undefined;
    let currentBgColor: string | undefined = undefined;
    let isBold: boolean = false;
    let lastIndex = 0;
    let match: RegExpExecArray | null = null;

    while ((match = ansiRegex.exec(input)) !== null) {
      const plainText = input.substring(lastIndex, match.index);
      if (plainText.length > 0) {
        spans.push({
          text: plainText,
          color: currentColor,
          bgColor: currentBgColor,
          bold: isBold
        });
      }

      const codes = match[1] ? match[1].split(';').map((c) => parseInt(c, 10)) : [0];
      for (const code of codes) {
        if (code === 0) {
          // Reset
          currentColor = undefined;
          currentBgColor = undefined;
          isBold = false;
        } else if (code === 1) {
          isBold = true;
        } else if (code === 22) {
          isBold = false;
        } else if (code >= 30 && code <= 37 || code >= 90 && code <= 97) {
          currentColor = AnsiParser.COLOR_MAP[code];
        } else if (code === 39) {
          currentColor = undefined; // Default fg
        } else if (code >= 40 && code <= 47) {
          currentBgColor = AnsiParser.BG_COLOR_MAP[code];
        } else if (code === 49) {
          currentBgColor = undefined; // Default bg
        }
      }

      lastIndex = ansiRegex.lastIndex;
    }

    if (lastIndex < input.length) {
      spans.push({
        text: input.substring(lastIndex),
        color: currentColor,
        bgColor: currentBgColor,
        bold: isBold
      });
    }

    // Clean remaining non-color ANSI control sequences (e.g. cursor moves \x1b[?25h, etc.)
    for (const span of spans) {
      span.text = span.text.replace(/\x1b\[[0-9;?]*[a-zA-Z]/g, '');
    }

    return spans;
  }
}
