import router from '@ohos.router';
import { PaseoStore } from '../common/store/PaseoStore';
import { ServerInfoPayload } from '../common/models/ProtocolMessages';
import { HostConfigStore, HostProfile } from '../common/store/HostConfigStore';
import { AppConstants } from '../common/constants/AppConstants';

@Entry
@Component
struct SettingsPage {
  @State serverInfo: ServerInfoPayload | null = null;
  @State connectionState: string = 'disconnected';
  @State hosts: HostProfile[] = [];

  private store: PaseoStore = PaseoStore.getInstance();
  private hostStore: HostConfigStore = HostConfigStore.getInstance();

  aboutToAppear() {
    this.serverInfo = this.store.serverInfo;
    this.connectionState = this.store.connectionState;
    this.hosts = this.hostStore.getHosts();

    this.store.subscribe(() => {
      this.serverInfo = this.store.serverInfo;
      this.connectionState = this.store.connectionState;
    });
  }

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

        Text('Settings & Diagnostics')
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

      Scroll() {
        Column({ space: 16 }) {
          // Section: Daemon Connection Status
          Column() {
            Text('DAEMON CONNECTION')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#6B7280')
              .margin({ bottom: 8 })

            Column({ space: 8 }) {
              Row() {
                Text('Status')
                  .fontSize(14)
                  .fontColor('#9CA3AF')
                Blank()
                Text(this.connectionState.toUpperCase())
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.connectionState === 'connected' ? '#10B981' : '#EF4444')
              }
              .width('100%')

              if (this.serverInfo) {
                Divider().color('#262934')

                Row() {
                  Text('Server ID')
                    .fontSize(14)
                    .fontColor('#9CA3AF')
                  Blank()
                  Text(this.serverInfo.serverId)
                    .fontSize(13)
                    .fontColor('#F3F4F6')
                    .fontFamily('monospace')
                }
                .width('100%')

                Divider().color('#262934')

                Row() {
                  Text('Hostname')
                    .fontSize(14)
                    .fontColor('#9CA3AF')
                  Blank()
                  Text(this.serverInfo.hostname)
                    .fontSize(14)
                    .fontColor('#F3F4F6')
                }
                .width('100%')

                Divider().color('#262934')

                Row() {
                  Text('Daemon Version')
                    .fontSize(14)
                    .fontColor('#9CA3AF')
                  Blank()
                  Text(this.serverInfo.version)
                    .fontSize(14)
                    .fontColor('#F3F4F6')
                }
                .width('100%')
              }
            }
            .padding(14)
            .backgroundColor('#181A20')
            .borderRadius(12)
            .border({ width: 1, color: '#272A34' })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          // Section: Client Info
          Column() {
            Text('HARMONYOS CLIENT')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#6B7280')
              .margin({ bottom: 8 })

            Column({ space: 8 }) {
              Row() {
                Text('App Name')
                  .fontSize(14)
                  .fontColor('#9CA3AF')
                Blank()
                Text(AppConstants.APP_NAME)
                  .fontSize(14)
                  .fontColor('#F3F4F6')
              }
              .width('100%')

              Divider().color('#262934')

              Row() {
                Text('App Version')
                  .fontSize(14)
                  .fontColor('#9CA3AF')
                Blank()
                Text(AppConstants.APP_VERSION)
                  .fontSize(14)
                  .fontColor('#F3F4F6')
              }
              .width('100%')

              Divider().color('#262934')

              Row() {
                Text('HarmonyOS Live View')
                  .fontSize(14)
                  .fontColor('#9CA3AF')
                Blank()
                Text('Enabled')
                  .fontSize(14)
                  .fontColor('#10B981')
              }
              .width('100%')
            }
            .padding(14)
            .backgroundColor('#181A20')
            .borderRadius(12)
            .border({ width: 1, color: '#272A34' })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
        }
        .padding(16)
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0E11')
  }
}
