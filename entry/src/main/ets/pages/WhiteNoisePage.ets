/**
 * 白噪音/环境音页面
 * 雨声：粉红噪声（Pink Noise）— 经过低通滤波的随机噪声，接近真实雨声
 * 咖啡馆：棕色噪声（Brown Noise）— 低频主导的温暖噪声，接近咖啡馆背景音
 * 使用 @ohos.multimedia.audio 的 AudioRenderer 实时合成，不依赖外部文件
 */
import router from '@ohos.router'
import curves from '@ohos.curves'
import audio from '@ohos.multimedia.audio'

const SAMPLE_RATE = 44100
const BUFFER_DURATION_MS = 100

@Entry
@Component
struct WhiteNoisePage {
  @State currentSound: number = -1
  @State isPlaying: boolean = false
  @State volume: number = 70
  @State timerSeconds: number = 0
  @State rendererReady: boolean = false
  @State errorMsg: string = ''

  @State headerScale: number = 0
  @State headerOpacity: number = 0
  @State cardScale: number = 0
  @State cardOpacity: number = 0
  @State waveOffset: number = 0

  // 音频渲染器
  private audioRenderer: audio.AudioRenderer | null = null
  private timerId: number = -1
  private renderTaskId: number = -1

  // 噪声生成状态
  private pinkB0: number = 0; private pinkB1: number = 0; private pinkB2: number = 0
  private pinkB3: number = 0; private pinkB4: number = 0; private pinkB5: number = 0; private pinkB6: number = 0
  private brownValue: number = 0

  aboutToAppear(): void {
    this.playEntranceAnimation()
  }

  aboutToDisappear(): void {
    this.stopPlayback()
    this.stopTimer()
  }

  // 初始化音频渲染器
  private async initRenderer(): Promise<boolean> {
    try {
      let rendererOptions: audio.AudioRendererOptions = {
        streamInfo: {
          samplingRate: SAMPLE_RATE,
          channels: 1,
          sampleFormat: 1,
          encodingType: 0
        },
        rendererInfo: {
          usage: 1,
          rendererFlags: 0
        },
        audioStreamOutputChangeCallback: undefined
      }

      this.audioRenderer = await audio.createAudioRenderer(rendererOptions)
      this.rendererReady = true
      return true
    } catch (e) {
      this.errorMsg = '音频引擎初始化失败'
      this.rendererReady = false
      return false
    }
  }

  // 启动播放
  private async startPlayback(soundType: number): Promise<void> {
    if (!this.audioRenderer) {
      let ok = await this.initRenderer()
      if (!ok) return
    }

    try {
      let renderer = this.audioRenderer
      await renderer.start()
      this.currentSound = soundType
      this.isPlaying = true
      this.errorMsg = ''
      this.scheduleNextRender()
    } catch (e) {
      this.errorMsg = '音频播放失败'
      this.isPlaying = false
    }
  }

  // 停止播放
  private async stopPlayback(): Promise<void> {
    this.isPlaying = false
    if (this.renderTaskId !== -1) {
      clearTimeout(this.renderTaskId)
      this.renderTaskId = -1
    }
    if (this.audioRenderer) {
      try {
        let renderer = this.audioRenderer
        await renderer.stop()
      } catch (e) {
        // ignore
      }
    }
  }

  // 释放渲染器
  private async releaseRenderer(): Promise<void> {
    if (this.audioRenderer) {
      try {
        let renderer = this.audioRenderer
        await renderer.release()
      } catch (e) {
        // ignore
      }
      this.audioRenderer = null
      this.rendererReady = false
    }
  }

  // 生成粉红噪声（雨声）
  private generatePinkNoise(): number {
    let white = Math.random() * 2 - 1
    this.pinkB0 = 0.99886 * this.pinkB0 + white * 0.0555179
    this.pinkB1 = 0.99332 * this.pinkB1 + white * 0.0750759
    this.pinkB2 = 0.96900 * this.pinkB2 + white * 0.1538520
    this.pinkB3 = 0.86650 * this.pinkB3 + white * 0.3104856
    this.pinkB4 = 0.55000 * this.pinkB4 + white * 0.5329522
    this.pinkB5 = -0.7616 * this.pinkB5 - white * 0.0168980
    let pink = this.pinkB0 + this.pinkB1 + this.pinkB2 + this.pinkB3 + this.pinkB4 + this.pinkB5 + this.pinkB6 + white * 0.5362
    this.pinkB6 = white * 0.115926
    return pink * 0.11 * (this.volume / 100)
  }

  // 生成棕色噪声（咖啡馆）
  private generateBrownNoise(): number {
    let white = Math.random() * 2 - 1
    this.brownValue = (this.brownValue + (0.02 * white)) / 1.02
    return this.brownValue * 3.5 * (this.volume / 100)
  }

  // 填充一个批次音频
  private fillBuffer(): void {
    if (!this.audioRenderer || !this.isPlaying) return

    try {
      let sampleCount = Math.floor(SAMPLE_RATE * BUFFER_DURATION_MS / 1000)
      let byteCount = sampleCount * 2
      let buffer = new ArrayBuffer(byteCount)
      let view = new DataView(buffer)

      for (let i = 0; i < sampleCount; i++) {
        let sample: number
        if (this.currentSound === 0) {
          sample = this.generatePinkNoise()
        } else {
          sample = this.generateBrownNoise()
        }
        sample = Math.max(-0.95, Math.min(0.95, sample))
        let sampleInt = Math.round(sample * 32767)
        view.setInt16(i * 2, sampleInt, true)
      }

      let renderer = this.audioRenderer
      renderer.write(buffer)
    } catch (e) {
      // ignore
    }

    this.scheduleNextRender()
  }

  private scheduleNextRender(): void {
    if (this.isPlaying) {
      this.renderTaskId = setTimeout(() => {
        this.fillBuffer()
      }, BUFFER_DURATION_MS - 5)
    }
  }

  // 选择声音
  private async selectSound(index: number): Promise<void> {
    if (this.currentSound === index && this.isPlaying) {
      await this.stopPlayback()
      this.stopTimer()
    } else {
      await this.stopPlayback()
      this.currentSound = index
      this.startTimer()
      await this.startPlayback(index)
    }
  }

  private changeVolume(vol: number): void {
    this.volume = vol
  }

  private startTimer(): void {
    this.stopTimer()
    this.timerId = setInterval(() => {
      this.timerSeconds++
    }, 1000)
  }

  private stopTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
    this.timerSeconds = 0
  }

  private formatTime(seconds: number): string {
    let m = Math.floor(seconds / 60).toString().padStart(2, '0')
    let s = (seconds % 60).toString().padStart(2, '0')
    return `${m}:${s}`
  }

  private playEntranceAnimation(): void {
    setTimeout(() => {
      animateTo({ duration: 700, curve: curves.springCurve(0, 1, 328, 34) }, () => {
        this.headerScale = 1; this.headerOpacity = 1
      })
    }, 100)
    setTimeout(() => {
      animateTo({ duration: 800, curve: curves.springCurve(0, 1, 300, 28) }, () => {
        this.cardScale = 1; this.cardOpacity = 1
      })
    }, 250)
    setTimeout(() => {
      animateTo({ duration: 3000, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
        this.waveOffset = 10
      })
    }, 500)
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Button('返回')
          .width(40).height(40)
          .fontSize(14)
          .backgroundColor($r('app.color.bg_surface'))
          .fontColor($r('app.color.text_primary'))
          .borderRadius(20)
          .onClick(() => {
            this.stopPlayback()
            this.stopTimer()
            router.back()
          })
        Text('白噪音')
          .fontSize(20).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 12 }).layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .scale({ x: this.headerScale, y: this.headerScale })
      .opacity(this.headerOpacity)

      Scroll() {
        Column() {

          // 播放状态显示
          Column() {
            if (this.isPlaying) {
              // 波形动画
              Row() {
                ForEach([16, 24, 32, 20, 28, 36, 22, 30, 18, 26], (h: number, i: number) => {
                  Row()
                    .width(4)
                    .height(h + (i % 2 === 0 ? this.waveOffset : -this.waveOffset))
                    .borderRadius(2)
                    .backgroundColor(this.currentSound === 0 ? '#42A5F5' : '#8D6E63')
                    .margin({ left: 3, right: 3 })
                    .opacity(0.7)
                })
              }
              .margin({ bottom: 16 })

              Text(this.currentSound === 0 ? '雨声播放中' : '咖啡馆音播放中')
                .fontSize(18).fontColor($r('app.color.text_primary')).fontWeight(FontWeight.Bold)

              Text(this.formatTime(this.timerSeconds))
                .fontSize(40).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.primary_blue')).margin({ top: 8 })

              if (this.errorMsg !== '') {
                Text(this.errorMsg)
                  .fontSize(12).fontColor('#FF9800').margin({ top: 8 })
              }
            } else {
              Text('')
                .fontSize(60).margin({ bottom: 8 })
              Text('选择一种环境音开始放松')
                .fontSize(16).fontColor($r('app.color.text_secondary'))
            }
          }
          .width('100%').padding({ top: 40, bottom: 40 })
          .alignItems(HorizontalAlign.Center)

          // 声音选择卡片
          Row() {
            // 雨声卡片
            Column() {
              Text('')
                .fontSize(40).margin({ bottom: 8 })
              Text('雨声')
                .fontSize(16).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text('静谧雨夜')
                .fontSize(12).fontColor($r('app.color.text_secondary')).margin({ top: 4 })

              if (this.currentSound === 0 && this.isPlaying) {
                Text('播放中')
                  .fontSize(11).fontColor('#42A5F5')
                  .fontWeight(FontWeight.Bold).margin({ top: 8 })
              }
            }
            .layoutWeight(1)
            .padding(24)
            .backgroundColor(this.currentSound === 0 && this.isPlaying ? '#E3F2FD' : $r('app.color.bg_card'))
            .borderRadius(20)
            .alignItems(HorizontalAlign.Center)
            .border({ width: this.currentSound === 0 && this.isPlaying ? 2 : 0, color: '#42A5F5' })
            .shadow({ radius: 6, color: $r('app.color.shadow_color'), offsetY: 2 })
            .onClick(() => { this.selectSound(0) })

            Column().width(12)

            // 咖啡馆卡片
            Column() {
              Text('')
                .fontSize(40).margin({ bottom: 8 })
              Text('咖啡馆')
                .fontSize(16).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text('舒适嘈杂')
                .fontSize(12).fontColor($r('app.color.text_secondary')).margin({ top: 4 })

              if (this.currentSound === 1 && this.isPlaying) {
                Text('播放中')
                  .fontSize(11).fontColor('#8D6E63')
                  .fontWeight(FontWeight.Bold).margin({ top: 8 })
              }
            }
            .layoutWeight(1)
            .padding(24)
            .backgroundColor(this.currentSound === 1 && this.isPlaying ? '#EFEBE9' : $r('app.color.bg_card'))
            .borderRadius(20)
            .alignItems(HorizontalAlign.Center)
            .border({ width: this.currentSound === 1 && this.isPlaying ? 2 : 0, color: '#8D6E63' })
            .shadow({ radius: 6, color: $r('app.color.shadow_color'), offsetY: 2 })
            .onClick(() => { this.selectSound(1) })
          }
          .width('100%').padding({ left: 16, right: 16 })

          // 音量控制
          Column() {
            Row() {
              Text('音量')
                .fontSize(14).fontColor($r('app.color.text_secondary'))
              Blank()
              Text(`${this.volume}%`)
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .fontWeight(FontWeight.Bold)
            }.width('100%').margin({ bottom: 8 })

            Slider({ value: this.volume, min: 0, max: 100, step: 5 })
              .blockColor($r('app.color.primary_blue'))
              .trackColor($r('app.color.progress_track'))
              .selectedColor($r('app.color.primary_blue'))
              .onChange((value: number) => {
                this.changeVolume(Math.round(value))
              })
          }
          .width('100%')
          .padding(20)
          .margin({ left: 16, right: 16, top: 16 })
          .backgroundColor($r('app.color.bg_card')).borderRadius(20)
          .shadow({ radius: 6, color: $r('app.color.shadow_color'), offsetY: 2 })

          // 停止按钮
          if (this.isPlaying) {
            Button('停止播放')
              .width('60%').height(48).fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.error_red')).borderRadius(24)
              .margin({ top: 24 })
              .onClick(() => {
                this.stopPlayback()
                this.stopTimer()
              })
          }

          // 说明文字
          Text('提示：使用程序化合成音频，无需联网即可播放')
            .fontSize(11).fontColor($r('app.color.text_hint'))
            .margin({ top: 20, bottom: 40 }).textAlign(TextAlign.Center)
        }.width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
    }
    .width('100%').height('100%').backgroundColor($r('app.color.bg_page'))
  }
}
