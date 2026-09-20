import { TimelineItem } from '../common/models/TimelineItem';
import { AgentModel } from '../common/models/Agent';
import { PaseoStore } from '../common/store/PaseoStore';

@Component
export struct AgentChatView {
  @Prop agentId: string;
  @State timelineItems: TimelineItem[] = [];
  @State inputText: string = '';
  @State currentAgent: AgentModel | undefined = undefined;

  private store: PaseoStore = PaseoStore.getInstance();
  private scroller: Scroller = new Scroller();

  aboutToAppear() {
    this.refreshData();
    this.store.subscribe(() => {
      this.refreshData();
    });
  }

  private refreshData(): void {
    if (this.agentId) {
      this.currentAgent = this.store.agents.get(this.agentId);
      const list = this.store.timelineMap.get(this.agentId) || [];
      this.timelineItems = [...list];
      // Scroll to bottom on new updates
      setTimeout(() => {
        this.scroller.scrollEdge(Edge.Bottom);
      }, 50);
    }
  }

  private sendMessage(): void {
    if (!this.inputText.trim() || !this.agentId) return;
    const text = this.inputText;
    this.inputText = '';
    this.store.sendAgentMessage(this.agentId, text);
  }

  @Builder
  renderItem(item: TimelineItem) {
    if (item.type === 'user_prompt') {
      Row() {
        Blank()
        Text(item.content)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#2563EB')
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .borderRadius(14)
          .constraintSize({ maxWidth: '80%' })
      }
      .width('100%')
      .margin({ top: 6, bottom: 6 })
    } else if (item.type === 'assistant_text') {
      Column() {
        Row() {
          Text(item.content)
            .fontSize(14)
            .fontColor('#E5E7EB')
            .lineHeight(20)

          if (item.isStreaming) {
            Circle({ width: 6, height: 6 })
              .fill('#38BDF8')
              .margin({ left: 4 })
          }
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .backgroundColor('#181A20')
      .padding(12)
      .borderRadius(12)
      .border({ width: 1, color: '#272A34' })
      .margin({ top: 6, bottom: 6 })
    } else if (item.type === 'tool_use') {
      Column() {
        Row() {
          Text('⚡ Tool Execution: ')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F59E0B')

          Text(item.toolName || 'command')
            .fontSize(12)
            .fontColor('#60A5FA')
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')

        if (item.toolInput) {
          Text(JSON.stringify(item.toolInput, null, 2))
            .fontSize(11)
            .fontColor('#9CA3AF')
            .fontFamily('monospace')
            .backgroundColor('#121316')
            .padding(8)
            .borderRadius(6)
            .margin({ top: 6 })
            .width('100%')
        }
      }
      .width('100%')
      .padding(10)
      .backgroundColor('#1A1D24')
      .borderRadius(10)
      .border({ width: 1, color: '#2A2E3D' })
      .margin({ top: 4, bottom: 4 })
    } else if (item.type === 'tool_result') {
      Column() {
        Text('Output')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(item.toolError ? '#EF4444' : '#10B981')
          .margin({ bottom: 4 })

        Text(item.toolOutput || item.content)
          .fontSize(11)
          .fontColor('#D1D5DB')
          .fontFamily('monospace')
          .maxLines(15)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding(10)
      .backgroundColor('#111317')
      .borderRadius(8)
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 4, bottom: 4 })
    }
  }

  build() {
    Column() {
      // Timeline Messages List
      List({ scroller: this.scroller }) {
        ForEach(this.timelineItems, (item: TimelineItem) => {
          ListItem() {
            this.renderItem(item)
          }
        }, (item: TimelineItem) => item.id)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .edgeEffect(EdgeEffect.Spring)

      // Bottom Input Composer
      Row({ space: 8 }) {
        TextInput({
          placeholder: 'Message agent or enter prompt...',
          text: this.inputText
        })
          .placeholderColor('#6B7280')
          .fontColor('#F3F4F6')
          .backgroundColor('#1F222B')
          .borderRadius(20)
          .layoutWeight(1)
          .height(44)
          .onChange((val: string) => {
            this.inputText = val;
          })
          .onSubmit(() => {
            this.sendMessage();
          })

        Button() {
          Text('Send')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .backgroundColor('#2563EB')
        .height(40)
        .width(64)
        .borderRadius(20)
        .onClick(() => {
          this.sendMessage();
        })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 12 })
      .backgroundColor('#121419')
      .border({ width: { top: 1 }, color: '#21242D' })
    }
    .width('100%')
    .height('100%')
  }
}
