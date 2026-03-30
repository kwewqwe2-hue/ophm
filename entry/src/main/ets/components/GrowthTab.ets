/**
 * 成长系统 Tab 组件
 * 功能：生命之树展示、积分统计、历史记录
 * 数据来源：AppStorage 响应式共享（完成专注后立即更新，无需切换 Tab 触发）
 */
import curves from '@ohos.curves'
import router from '@ohos.router'
import { PreferencesUtil } from '../utils/PreferencesUtil'
import { FocusSession, TreeStageInfo, UserGrowth } from '../model/DataModels'
import { TreeView } from './TreeView'

const DEFAULT_GROWTH: UserGrowth = {
  totalPoints: 0,
  treeStage: 0,
  totalFocusMinutes: 0,
  currentStreak: 0,
  longestStreak: 0,
  lastActiveDate: ''
}

@Component
export struct GrowthTab {
  @State sharedGrowth: UserGrowth = DEFAULT_GROWTH
  @State isRefreshing: boolean = false
  @Consume('refreshCounter') @Watch('refreshData') refreshCounter: number
  @Consume('__refresh_trigger') @Watch('refreshData') refreshTrigger: number

  aboutToAppear(): void {
    let raw = AppStorage.get<string>('shared_growth')
    if (raw && typeof raw === 'string') {
      try {
        this.sharedGrowth = JSON.parse(raw) as UserGrowth
      } catch (e) {
        this.sharedGrowth = DEFAULT_GROWTH
      }
    }
    this.loadRecentSessions()
    this.playEntranceAnimation()
  }

  private async refreshData(): Promise<void> {
    this.isRefreshing = true
    let raw = AppStorage.get<string>('shared_growth')
    if (raw && typeof raw === 'string') {
      try {
        this.sharedGrowth = JSON.parse(raw) as UserGrowth
      } catch (e) {
        this.sharedGrowth = DEFAULT_GROWTH
      }
    }
    await this.loadRecentSessions()
    this.isRefreshing = false
  }

  private async loadRecentSessions(): Promise<void> {
    let allSessions = await PreferencesUtil.getFocusSessions()
    allSessions.sort((a: FocusSession, b: FocusSession) => b.startTime - a.startTime)
    this.recentSessions = allSessions.slice(0, 10)
  }

  private recentSessions: FocusSession[] = []

  private playEntranceAnimation(): void {
    setTimeout(() => {
      animateTo({
        duration: 900,
        curve: curves.springCurve(0, 1, 280, 26)
      }, () => {
        this.treeAreaScale = 1
        this.treeAreaOpacity = 1
      })
    }, 100)

    setTimeout(() => {
      animateTo({
        duration: 700,
        curve: curves.springCurve(0, 1, 300, 30)
      }, () => {
        this.statsScale = 1
        this.statsOpacity = 1
      })
    }, 350)

    setTimeout(() => {
      animateTo({
        duration: 600,
        curve: curves.springCurve(0, 1, 300, 30)
      }, () => {
        this.historyScale = 1
        this.historyOpacity = 1
      })
    }, 550)
  }

  private getNextStageName(): string {
    return TreeStageInfo.getStageConfig(this.sharedGrowth.treeStage + 1).name
  }

  private getNextStageMinPoints(): number {
    return TreeStageInfo.getStageConfig(this.sharedGrowth.treeStage + 1).minPoints
  }

  private getProgressValue(): number {
    return this.sharedGrowth.totalPoints - TreeStageInfo.getStageConfig(this.sharedGrowth.treeStage).minPoints
  }

  private getProgressTotal(): number {
    return TreeStageInfo.getStageConfig(this.sharedGrowth.treeStage + 1).minPoints -
      TreeStageInfo.getStageConfig(this.sharedGrowth.treeStage).minPoints
  }

  build() {
    Scroll() {
      Column() {
        // 标题
        Row() {
          Text('成长之路')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text('刷新')
            .fontSize(14)
            .fontColor($r('app.color.primary_blue'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .onClick(() => { this.refreshData() })
          Text('|')
            .fontSize(14)
            .fontColor($r('app.color.divider'))
          Text('设置')
            .fontSize(14)
            .fontColor($r('app.color.primary_blue'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/SettingsPage' })
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 8 })

        // 生命之树区域
        Column() {
          TreeView({
            treeStage: this.sharedGrowth.treeStage,
            totalPoints: this.sharedGrowth.totalPoints
          })

          Text(TreeStageInfo.getStageConfig(this.sharedGrowth.treeStage).name)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary_green'))
            .margin({ top: 8 })

          Text(TreeStageInfo.getStageConfig(this.sharedGrowth.treeStage).description)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })

          if (this.sharedGrowth.treeStage < 5) {
            Column() {
              Row() {
                Text(`距离「${this.getNextStageName()}」`)
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                Blank()
                Text(`${this.sharedGrowth.totalPoints}/${this.getNextStageMinPoints()}`)
                  .fontSize(12)
                  .fontColor($r('app.color.accent_orange'))
              }
              .width('100%')

              Progress({
                value: this.getProgressValue(),
                total: this.getProgressTotal(),
                type: ProgressType.Linear
              })
                .width('100%')
                .height(8)
                .color($r('app.color.primary_green'))
                .backgroundColor($r('app.color.progress_track'))
                .borderRadius(4)
                .margin({ top: 8 })
            }
            .width('100%')
            .padding({ left: 24, right: 24, top: 16 })
          }
        }
        .width('100%')
        .padding({ top: 8, bottom: 20 })
        .margin({ left: 16, right: 16 })
        .backgroundColor($r('app.color.bg_card'))
        .borderRadius(24)
        .shadow({ radius: 12, color: $r('app.color.shadow_color'), offsetY: 4 })
        .scale({ x: this.treeAreaScale, y: this.treeAreaScale })
        .opacity(this.treeAreaOpacity)

        // 数据统计
        Row() {
          Column() {
            Text(`${this.sharedGrowth.totalPoints}`)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.accent_orange'))
            Text('总积分')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .padding(16)
          .backgroundColor($r('app.color.bg_card'))
          .borderRadius(16)
          .shadow({ radius: 6, color: $r('app.color.shadow_color'), offsetY: 2 })

          Column() {
            Text(PreferencesUtil.formatDuration(this.sharedGrowth.totalFocusMinutes))
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_green'))
            Text('总时长')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .padding(16)
          .margin({ left: 10, right: 10 })
          .backgroundColor($r('app.color.bg_card'))
          .borderRadius(16)
          .shadow({ radius: 6, color: $r('app.color.shadow_color'), offsetY: 2 })

          Column() {
            Text(`${this.sharedGrowth.currentStreak}天`)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_blue'))
            Text('连续打卡')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .padding(16)
          .backgroundColor($r('app.color.bg_card'))
          .borderRadius(16)
          .shadow({ radius: 6, color: $r('app.color.shadow_color'), offsetY: 2 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .margin({ top: 16 })
        .scale({ x: this.statsScale, y: this.statsScale })
        .opacity(this.statsOpacity)

        // 最近记录
        Column() {
          Text('最近专注记录')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ bottom: 12 })

          if (this.recentSessions.length === 0) {
            Text('暂无专注记录')
              .fontSize(14)
              .fontColor($r('app.color.text_hint'))
              .padding(20)
          } else {
            ForEach(this.recentSessions, (session: FocusSession) => {
              Row() {
                Column() {
                  Text(session.projectName)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.text_primary'))
                  Text(PreferencesUtil.formatDateTime(session.startTime))
                    .fontSize(11)
                    .fontColor($r('app.color.text_hint'))
                    .margin({ top: 2 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Column() {
                  Text(`${session.duration}分钟`)
                    .fontSize(14)
                    .fontColor($r('app.color.primary_green'))
                  Text(`+${session.points}分`)
                    .fontSize(12)
                    .fontColor($r('app.color.accent_orange'))
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.End)
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
              .border({
                width: { bottom: 0.5 },
                color: $r('app.color.divider')
              })
            })
          }
        }
        .width('100%')
        .padding(20)
        .margin({ left: 16, right: 16, top: 16, bottom: 20 })
        .backgroundColor($r('app.color.bg_card'))
        .borderRadius(20)
        .shadow({ radius: 8, color: $r('app.color.shadow_color'), offsetY: 2 })
        .scale({ x: this.historyScale, y: this.historyScale })
        .opacity(this.historyOpacity)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
  }

  @State treeAreaScale: number = 0
  @State treeAreaOpacity: number = 0
  @State statsScale: number = 0
  @State statsOpacity: number = 0
  @State historyScale: number = 0
  @State historyOpacity: number = 0
}
