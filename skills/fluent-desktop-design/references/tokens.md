# 设计变量

全部取自 fluent_ui 4.16 的 `ResourceDictionary`（与 WinUI 3 同名资源一致）。代码里用 `FluentTheme.of(context).resources.<名字>`，**不要写死色值**；这里列出数值只为方便对照设计稿。

## 颜色

| 资源 | 浅色 | 深色 | 用途 |
|------|------|------|------|
| `layerFillColorDefault` | `#80FFFFFF` | `#4C3A3A3A` | 主体内容层（叠在云母上） |
| `cardBackgroundFillColorDefault` | `#B3FFFFFF` | `#0DFFFFFF` | 卡片、浅色侧栏选中瓦片 |
| `cardStrokeColorDefault` | `#0F000000` | `#19000000` | 卡片 / 内容层描边 |
| `subtleFillColorSecondary` | `#09000000` | `#0FFFFFFF` | 悬停 |
| `subtleFillColorTertiary` | `#06000000` | `#0AFFFFFF` | 按下 |
| `solidBackgroundFillColorBase`（= `micaBackgroundColor`） | `#F3F3F3` | `#202020` | 不透云母处的底色（弹窗底栏等）；窗口失焦时 DWM 画的就是这个色，界面不用自己盖。毛玻璃的默认色调也取它（`AcrylicOptions.lightTint` / `darkTint`），默认不透明度 75% |
| `textFillColorPrimary` | `#E4000000` | `#FFFFFFFF` | 正文、悬停字色 |
| `textFillColorSecondary` | `#9E000000` | `#C5FFFFFF` | 说明、未选中侧栏 |
| `textFillColorTertiary` | `#72000000` | `#87FFFFFF` | 失焦标题、占位 |
| `systemFillColorSuccess / Caution / Critical / Neutral` | — | — | 状态图标、错误文字 |
| 主题色 | `Colors.blue` | | `accentColor.defaultBrushFor(brightness)` 取亮 / 暗对应的实际色 |

深色侧栏选中瓦片用 `Color(0x1AFFFFFF)`：深色 `cardBackgroundFillColorDefault` 太淡，与悬停分不开。

## 字体与字号

- 字体：`Microsoft YaHei UI`，回退 `Microsoft YaHei`、`Segoe UI`、`sans-serif`。
- 字号沿用 Windows 11 type ramp：caption 12、body 14、bodyStrong 14、bodyLarge 18、subtitle 20、title 28、titleLarge 40、display 68。
- `title`、`titleLarge`、`subtitle`、`display` **改为常规体**（雅黑无 Semibold）；caption 设为 normal（fluent_ui 默认 w300 过细）。
- 用法：页面标题 `title`（由 `PageHeader` 提供）；分组标题 `bodyStrong`；卡片标题 `body`；说明 `caption` 次要色；统计数值 `subtitle`。

## 间距（4 的倍数）

| 位置 | 值 |
|------|----|
| 页面左右 gutter | 24（窗口 < 640 宽时 12） |
| 内容列最大宽 | 1000，居中 |
| 页头下边距 | 18（`PageHeader` 自带） |
| 分组标题 | 上 24 / 下 8 |
| 同组卡片 | 4（`kCardSpacing`） |
| 并排卡片 / 区块之间 | 12 |
| 按钮之间 | 8（`ButtonRow`） |
| 卡片内边距 | 横 16、纵 12（统计卡 16/14） |
| 图标与文字 | 16（卡片）/ 8（行内）/ 4（侧栏上下） |

## 圆角

| 元素 | 半径 |
|------|------|
| 卡片、按钮、输入框 | 4（fluent_ui 默认） |
| 侧栏瓦片 | 6 |
| 主体内容层左上角、Windows 11 窗口 | 8 |
| 弹窗 | 8（fluent_ui 默认） |

## 动效

| 名称 | 时长 | 曲线 |
|------|------|------|
| 颜色过渡（悬停 / 选中） | 150ms | `Curves.easeOut` |
| 指示条拉伸 | 460ms | 前沿 `Interval(0, 0.62, easeOutCubic)`，后沿 `Interval(0.18, 1, easeInOutCubic)` |
| 指示条跨组 | 380ms | 收缩 `Interval(0, .45, easeInCubic)`，展开 `Interval(.45, 1, easeOutCubic)` |
| 切页进入 | 380ms | 位移 `Cubic(0.1, 0.9, 0.2, 1)`（Fluent 2 Decelerate Max）40px；透明度 `Interval(.15, .6, easeOut)` |
| 切页离开 | 120ms | 透明度同上曲线倒放，不位移 |
| 启动卡片 Logo | 520ms | `Cubic(0.1, 0.9, 0.2, 1)`，上浮 12px 淡入 |

尊重系统「减少动画」：`MediaQuery.disableAnimationsOf(context)` 为 true 时时长设 0。
