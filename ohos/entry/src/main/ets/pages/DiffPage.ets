import router from '@ohos.router';
import { DiffViewer } from '../components/DiffViewer';

@Entry
@Component
struct DiffPage {
  build() {
    Column() {
      // Top Navigation
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

        Text('Working Tree Diff')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F3F4F6')
          .margin({ left: 8 })

        Blank()
      }
      .width('100%')
      .height(50)
      .padding({ left: 12, right: 12 })
      .backgroundColor('#101115')
      .border({ width: { bottom: 1 }, color: '#1E212A' })

      DiffViewer()
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0E11')
  }
}
