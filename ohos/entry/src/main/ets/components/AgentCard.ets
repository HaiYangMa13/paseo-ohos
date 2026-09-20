import { AgentModel, AgentStatus } from '../common/models/Agent';

@Component
export struct AgentCard {
  @Prop agent: AgentModel;
  public onSelect?: () => void;

  private getStatusColor(status: AgentStatus): string {
    switch (status) {
      case 'running':
        return '#10B981'; // Green
      case 'idle':
        return '#6B7280'; // Gray
      case 'error':
        return '#EF4444'; // Red
      case 'initializing':
        return '#F59E0B'; // Yellow
      case 'closed':
      default:
        return '#4B5563';
    }
  }

  private getProviderBadge(provider: string): string {
    if (provider.includes('claude')) return 'Claude';
    if (provider.includes('codex')) return 'Codex';
    if (provider.includes('copilot')) return 'Copilot';
    if (provider.includes('pi')) return 'Pi';
    if (provider.includes('opencode')) return 'OpenCode';
    if (provider.includes('cursor')) return 'Cursor';
    return provider;
  }

  build() {
    Row() {
      // Status indicator circle
      Circle({ width: 10, height: 10 })
        .fill(this.getStatusColor(this.agent.status))
        .margin({ right: 12 })

      Column() {
        Row() {
          Text(this.agent.title || 'Untitled Agent')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#F3F4F6')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(this.getProviderBadge(this.agent.provider))
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#38BDF8')
            .backgroundColor('#0F2942')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(4)
        }
        .width('100%')

        Row() {
          Text(this.agent.status.toUpperCase())
            .fontSize(12)
            .fontColor(this.getStatusColor(this.agent.status))
            .margin({ right: 8 })

          if (this.agent.model) {
            Text(`•  ${this.agent.model}`)
              .fontSize(12)
              .fontColor('#9CA3AF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
        }
        .margin({ top: 4 })
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#181A20')
    .borderRadius(12)
    .border({ width: 1, color: '#272A34' })
    .onClick(() => {
      this.onSelect?.();
    })
  }
}
