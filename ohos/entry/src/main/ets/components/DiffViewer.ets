import { GitDiffFile, DiffHunk, DiffHunkLine } from '../common/models/Workspace';
import { DiffParser } from '../common/utils/DiffParser';

@Component
export struct DiffViewer {
  @Prop rawDiff: string = '';
  @State diffFiles: GitDiffFile[] = [];

  aboutToAppear() {
    this.updateDiff();
  }

  private updateDiff(): void {
    if (this.rawDiff) {
      this.diffFiles = DiffParser.parseUnifiedDiff(this.rawDiff);
    }
  }

  @Builder
  renderLine(line: DiffHunkLine) {
    Row() {
      // Old line number
      Text(line.oldLineNumber !== undefined ? line.oldLineNumber.toString() : '')
        .width(36)
        .fontSize(11)
        .fontColor('#6B7280')
        .textAlign(TextAlign.End)
        .padding({ right: 6 })

      // New line number
      Text(line.newLineNumber !== undefined ? line.newLineNumber.toString() : '')
        .width(36)
        .fontSize(11)
        .fontColor('#6B7280')
        .textAlign(TextAlign.End)
        .padding({ right: 6 })

      // Diff prefix +/-
      Text(line.type === 'add' ? '+' : line.type === 'delete' ? '-' : ' ')
        .width(14)
        .fontSize(12)
        .fontColor(line.type === 'add' ? '#34D399' : line.type === 'delete' ? '#F87171' : '#9CA3AF')
        .fontWeight(FontWeight.Bold)

      // Line code content
      Text(line.content)
        .fontSize(12)
        .fontFamily('monospace')
        .fontColor(line.type === 'add' ? '#E5E7EB' : line.type === 'delete' ? '#FCA5A5' : '#D1D5DB')
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 2, bottom: 2 })
    .backgroundColor(
      line.type === 'add' ? '#064E3B44' : line.type === 'delete' ? '#7F1D1D44' : '#00000000'
    )
  }

  build() {
    Column() {
      if (this.diffFiles.length === 0) {
        Column() {
          Text('No changes detected in workspace')
            .fontSize(14)
            .fontColor('#6B7280')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.diffFiles, (file: GitDiffFile) => {
            ListItem() {
              Column() {
                // File Header
                Row() {
                  Text(file.newPath || file.oldPath)
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#F3F4F6')
                    .layoutWeight(1)

                  Text(`+${file.additions}`)
                    .fontSize(12)
                    .fontColor('#34D399')
                    .fontWeight(FontWeight.Medium)
                    .margin({ right: 6 })

                  Text(`-${file.deletions}`)
                    .fontSize(12)
                    .fontColor('#F87171')
                    .fontWeight(FontWeight.Medium)
                }
                .width('100%')
                .padding(10)
                .backgroundColor('#1A1C22')
                .borderRadius(8)
                .margin({ bottom: 4 })

                // Hunks
                ForEach(file.hunks, (hunk: DiffHunk) => {
                  Column() {
                    Text(hunk.header)
                      .fontSize(11)
                      .fontColor('#60A5FA')
                      .backgroundColor('#151E2E')
                      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                      .width('100%')

                    ForEach(hunk.lines, (line: DiffHunkLine) => {
                      this.renderLine(line)
                    })
                  }
                  .width('100%')
                  .margin({ bottom: 8 })
                  .borderRadius(6)
                  .backgroundColor('#101216')
                })
              }
              .width('100%')
              .margin({ bottom: 12 })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding(12)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0E11')
  }
}
