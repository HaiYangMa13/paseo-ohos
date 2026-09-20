import { PaseoStore } from '../common/store/PaseoStore';
import { AnsiParser, AnsiSpan } from '../common/utils/AnsiParser';

@Component
export struct TerminalView {
  @Prop slotId: number = 0;
  @State terminalText: string = '';
  @State parsedSpans: AnsiSpan[] = [];
  @State terminalInput: string = '';

  private store: PaseoStore = PaseoStore.getInstance();
  private scroller: Scroller = new Scroller();

  aboutToAppear() {
    this.refreshTerminal();
    this.store.subscribe(() => {
      this.refreshTerminal();
    });
  }

  private refreshTerminal(): void {
    const raw = this.store.terminalBuffers.get(this.slotId) || '';
    if (raw !== this.terminalText) {
      this.terminalText = raw;
      this.parsedSpans = AnsiParser.parse(raw);
      setTimeout(() => {
        this.scroller.scrollEdge(Edge.Bottom);
      }, 30);
    }
  }

  private sendInput(cmd: string): void {
    if (!cmd) return;
    this.store.sendTerminalInput(this.slotId, cmd);
  }

  build() {
    Column() {
      // Terminal Header & Status
      Row() {
        Circle({ width: 8, height: 8 })
          .fill('#10B981')
          .margin({ right: 6 })

        Text(`Terminal (Slot ${this.slotId})`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#9CA3AF')

        Blank()

        Button('Clear')
          .fontSize(11)
          .height(26)
          .backgroundColor('#21242C')
          .fontColor('#9CA3AF')
          .borderRadius(6)
          .onClick(() => {
            this.store.terminalBuffers.set(this.slotId, '');
            this.refreshTerminal();
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor('#101114')
      .border({ width: { bottom: 1 }, color: '#1F222A' })

      // Terminal Output Area
      Scroll(this.scroller) {
        Text() {
          if (this.parsedSpans.length === 0) {
            Span('Terminal idle. Awaiting command output...\n')
              .fontColor('#6B7280')
              .fontSize(12)
          } else {
            ForEach(this.parsedSpans, (span: AnsiSpan) => {
              Span(span.text)
                .fontColor(span.color || '#E5E7EB')
                .fontSize(12)
                .fontWeight(span.bold ? FontWeight.Bold : FontWeight.Normal)
            })
          }
        }
        .width('100%')
        .fontFamily('monospace')
        .padding(10)
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor('#0A0B0D')
      .align(Alignment.TopStart)

      // Quick Key Toolbar
      Row({ space: 8 }) {
        Button('Ctrl+C')
          .fontSize(11)
          .height(28)
          .backgroundColor('#1E212A')
          .fontColor('#F87171')
          .borderRadius(6)
          .onClick(() => {
            this.sendInput('\x03');
          })

        Button('Tab')
          .fontSize(11)
          .height(28)
          .backgroundColor('#1E212A')
          .fontColor('#D1D5DB')
          .borderRadius(6)
          .onClick(() => {
            this.sendInput('\t');
          })

        Button('↑')
          .fontSize(12)
          .height(28)
          .width(36)
          .backgroundColor('#1E212A')
          .fontColor('#D1D5DB')
          .borderRadius(6)
          .onClick(() => {
            this.sendInput('\x1b[A');
          })

        Button('↓')
          .fontSize(12)
          .height(28)
          .width(36)
          .backgroundColor('#1E212A')
          .fontColor('#D1D5DB')
          .borderRadius(6)
          .onClick(() => {
            this.sendInput('\x1b[B');
          })
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor('#121419')

      // Terminal Command Input
      Row({ space: 6 }) {
        TextInput({
          placeholder: 'Type terminal command...',
          text: this.terminalInput
        })
          .placeholderColor('#4B5563')
          .fontColor('#34D399')
          .fontFamily('monospace')
          .fontSize(13)
          .backgroundColor('#1A1D24')
          .borderRadius(8)
          .layoutWeight(1)
          .height(38)
          .onChange((val: string) => {
            this.terminalInput = val;
          })
          .onSubmit(() => {
            if (this.terminalInput) {
              this.sendInput(this.terminalInput + '\n');
              this.terminalInput = '';
            }
          })

        Button('Run')
          .fontSize(12)
          .height(36)
          .width(56)
          .backgroundColor('#10B981')
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .onClick(() => {
            if (this.terminalInput) {
              this.sendInput(this.terminalInput + '\n');
              this.terminalInput = '';
            }
          })
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 6, bottom: 10 })
      .backgroundColor('#121419')
      .border({ width: { top: 1 }, color: '#1E212A' })
    }
    .width('100%')
    .height('100%')
  }
}
