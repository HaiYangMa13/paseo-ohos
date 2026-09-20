import BackupExtensionAbility, { BundleVersion } from '@ohos.application.BackupExtensionAbility';
import { hilog } from '@kit.PerformanceAnalysisKit';

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup(): Promise<void> {
    hilog.info(0x0000, 'PaseoBackup', 'onBackup ok');
  }

  async onRestore(bundleVersion: BundleVersion): Promise<void> {
    hilog.info(0x0000, 'PaseoBackup', 'onRestore ok %{public}s', JSON.stringify(bundleVersion));
  }
}
