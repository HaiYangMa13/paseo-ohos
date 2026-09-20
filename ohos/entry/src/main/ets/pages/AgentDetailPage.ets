import router from '@ohos.router';
import { PaseoStore } from '../common/store/PaseoStore';
import { AgentModel } from '../common/models/Agent';
import { AgentChatView } from '../components/AgentChatView';
import { TerminalView } from '../components/TerminalView';
import { DiffViewer } from '../components/DiffViewer';

@Entry
@Component
struct AgentDetailPage {
  @State agentId: string = '';
  @State currentAgent: AgentModel | undefined = undefined;
  @State activeTab: number = 0;

  private store: PaseoStore = PaseoStore.getInstance();

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params && params['agentId']) {
      this.agentId = params['agentId'];
      this.currentAgent = this.store.agents.get(this.agentId);
    }

    this.store.subscribe(() => {
      if (this.agentId) {
        this.currentAgent = this.store.agents.get(this.agentId);
      }
    });
  }

  private toggleAgentRun(): void {
    if (!this.currentAgent) return;
    if (this.currentAgent.status === 'running') {
      this.store.stopAgent(this.agentId);
    } else {
      this.store.resumeAgent(this.agentId);
    }
  }

  build() {
    Column() {
      // Top Navigation Bar
      Row() {
        Button() {
          Text('‹ Back')
            .fontSize(15)
            .fontColor('#38BDF8')
        }
        .backgroundColor('#00000000')
        .onClick(() => {
          router.back();
        })

        Text(this.currentAgent?.title || 'Agent Session')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F3F4F6')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ left: 8, right: 8 })

        // Stop / Resume Action
        Button(this.currentAgent?.status === 'running' ? 'Stop' : 'Resume')
          .fontSize(12)
          .height(28)
          .backgroundColor(this.currentAgent?.status === 'running' ? '#7F1D1D' : '#064E3B')
          .fontColor(this.currentAgent?.status === 'running' ? '#F87171' : '#34D399')
          .borderRadius(6)
          .onClick(() => {
            this.toggleAgentRun();
          })
      }
      .width('100%')
      .height(50)
      .padding({ left: 12, right: 12 })
      .backgroundColor('#101115')
      .border({ width: { bottom: 1 }, color: '#1E212A' })

      // Tabs: Chat, Terminal, Changes
      Tabs({ barPosition: BarPosition.Start }) {
        TabContent() {
          AgentChatView({ agentId: this.agentId })
        }.tabBar('Chat')

        TabContent() {
          TerminalView({ slotId: 0 })
        }.tabBar('Terminal')

        TabContent() {
          DiffViewer()
        }.tabBar('Changes')
      }
      .barMode(BarMode.Fixed)
      .barWidth('100%')
      .barHeight(42)
      .backgroundColor('#12141A')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0E11')
  }
}
