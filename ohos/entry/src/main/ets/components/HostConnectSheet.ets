import { HostConfigStore, HostProfile } from '../common/store/HostConfigStore';
import { PaseoStore } from '../common/store/PaseoStore';

@CustomDialog
export struct HostConnectSheet {
  controller: CustomDialogController;
  @State hosts: HostProfile[] = [];
  @State newHostName: string = '';
  @State newHostUrl: string = '';
  @State isAdding: boolean = false;

  private hostStore: HostConfigStore = HostConfigStore.getInstance();
  private paseoStore: PaseoStore = PaseoStore.getInstance();

  aboutToAppear() {
    this.hosts = this.hostStore.getHosts();
  }

  private connectToHost(host: HostProfile): void {
    this.hostStore.setActiveHost(host.id);
    this.paseoStore.connect(host.url);
    this.controller.close();
  }

  private async addNewHost(): Promise<void> {
    if (!this.newHostUrl.trim()) return;
    let url = this.newHostUrl.trim();
    if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      url = 'ws://' + url;
    }

    const newHost: HostProfile = {
      id: 'host_' + Date.now(),
      name: this.newHostName.trim() || 'Custom Host',
      url: url,
      isRelay: url.includes('relay'),
      lastConnected: Date.now()
    };

    await this.hostStore.addOrUpdateHost(newHost);
    this.hosts = this.hostStore.getHosts();
    this.isAdding = false;
    this.newHostName = '';
    this.newHostUrl = '';
  }

  build() {
    Column() {
      // Header
      Row() {
        Text('Paseo Hosts & Daemons')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F3F4F6')

        Blank()

        Button(this.isAdding ? 'Cancel' : '+ Add Host')
          .fontSize(12)
          .height(28)
          .backgroundColor('#1F222B')
          .fontColor('#38BDF8')
          .onClick(() => {
            this.isAdding = !this.isAdding;
          })
      }
      .width('100%')
      .margin({ bottom: 14 })

      if (this.isAdding) {
        Column({ space: 8 }) {
          TextInput({ placeholder: 'Host Name (e.g. Work PC)', text: this.newHostName })
            .placeholderColor('#6B7280')
            .fontColor('#F3F4F6')
            .backgroundColor('#1C1E26')
            .borderRadius(8)
            .height(40)
            .onChange((v) => this.newHostName = v)

          TextInput({ placeholder: 'ws://192.168.1.100:6767', text: this.newHostUrl })
            .placeholderColor('#6B7280')
            .fontColor('#F3F4F6')
            .backgroundColor('#1C1E26')
            .borderRadius(8)
            .height(40)
            .onChange((v) => this.newHostUrl = v)

          Button('Save & Connect')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#2563EB')
            .fontColor('#FFFFFF')
            .height(36)
            .width('100%')
            .borderRadius(8)
            .onClick(() => {
              this.addNewHost();
            })
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#16181F')
        .borderRadius(10)
        .margin({ bottom: 12 })
      }

      // Saved Hosts List
      List({ space: 8 }) {
        ForEach(this.hosts, (host: HostProfile) => {
          ListItem() {
            Row() {
              Column() {
                Text(host.name)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#F3F4F6')

                Text(host.url)
                  .fontSize(12)
                  .fontColor('#9CA3AF')
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Button('Connect')
                .fontSize(12)
                .height(30)
                .backgroundColor('#2563EB')
                .fontColor('#FFFFFF')
                .borderRadius(6)
                .onClick(() => {
                  this.connectToHost(host);
                })
            }
            .width('100%')
            .padding(12)
            .backgroundColor('#191B22')
            .borderRadius(10)
          }
        })
      }
      .width('100%')
      .constraintSize({ maxHeight: 300 })
    }
    .width('92%')
    .padding(18)
    .backgroundColor('#121317')
    .borderRadius(16)
  }
}
