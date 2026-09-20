import { ToolPermissionRequest } from '../common/models/Agent';

@CustomDialog
export struct PermissionDialog {
  controller: CustomDialogController;
  public request?: ToolPermissionRequest;
  public onResolve?: (decision: 'allow' | 'deny') => void;

  private getRiskColor(risk?: string): string {
    if (risk === 'high') return '#EF4444';
    if (risk === 'medium') return '#F59E0B';
    return '#10B981';
  }

  build() {
    Column() {
      // Header
      Row() {
        Circle({ width: 8, height: 8 })
          .fill(this.getRiskColor(this.request?.riskLevel))
          .margin({ right: 8 })

        Text('Tool Execution Permission')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F9FAFB')
          .layoutWeight(1)

        Text(this.request?.riskLevel?.toUpperCase() || 'MEDIUM')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getRiskColor(this.request?.riskLevel))
          .backgroundColor('#261C14')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(4)
      }
      .width('100%')
      .margin({ bottom: 12 })

      // Tool and description
      Column() {
        Text(`Tool: ${this.request?.tool || 'unknown'}`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#60A5FA')
          .margin({ bottom: 6 })

        Text(this.request?.description || 'Agent wants to execute an action on your system.')
          .fontSize(13)
          .fontColor('#D1D5DB')
          .lineHeight(18)
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#1E212B')
      .borderRadius(8)
      .alignItems(HorizontalAlign.Start)
      .margin({ bottom: 16 })

      // Action Buttons
      Row({ space: 12 }) {
        Button('Deny')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#EF4444')
          .backgroundColor('#2C1C20')
          .borderRadius(8)
          .layoutWeight(1)
          .height(40)
          .onClick(() => {
            this.onResolve?.('deny');
            this.controller.close();
          })

        Button('Allow')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor('#2563EB')
          .borderRadius(8)
          .layoutWeight(1)
          .height(40)
          .onClick(() => {
            this.onResolve?.('allow');
            this.controller.close();
          })
      }
      .width('100%')
    }
    .padding(20)
    .backgroundColor('#14161C')
    .borderRadius(16)
    .width('90%')
  }
}
