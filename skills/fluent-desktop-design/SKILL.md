---
name: fluent-desktop-design
description: Windows 11 Fluent 风格 Flutter 桌面应用的设计语言与 fluent_ui 组件规范（云母 / 毛玻璃分层、Store 式窄侧栏、卡片、可展开设置卡、动效、常见坑）。在用 fluent_ui 新增或修改页面、组件、弹窗、样式，或评审 Windows 桌面界面是否「像 Windows 11」时使用。
---

# Fluent 桌面设计语言

来源：「风铃·回响（WindBellEcho）」桌面端；本次按 1.1.0+5 的代码、Flutter 3.47.0 / Dart 3.13.0 / fluent_ui 4.16.1 核对。Windows 11 界面有截图与原生验证记录；Windows 10 的分支测试不等同于实机验证。
新建应用的壳子见 `fluent-desktop-shell`；要看实际渲染效果用 `flutter-ui-screenshots`。

本 skill 约束 Flutter 客户端。项目的 OBS 转盘 / 九宫格是 `assets/overlay/lottery/` 下的 HTML 展示页，使用自己的五套主题，不套用 Fluent 卡片和字体；验证方式见 `flutter-ui-screenshots` 的「本项目展示页」。

## 原则

1. **只用 fluent_ui**：`FluentApp → NavigationView → ScaffoldPage`。不引入 Material `Scaffold` / `AppBar` 当主壳。
2. **分层靠透明度，不靠阴影**：标题栏 + 侧栏完全透出窗口材质（Windows 11 默认云母；Windows 10 或用户选了毛玻璃时是毛玻璃，分层不变）；主体内容区叠一层半透明填充（比侧栏亮）；卡片再叠一层。颜色一律取 `FluentTheme.of(context).resources.*`，亮 / 暗自动适配，不写死色值。
3. **状态 = 彩色图标 + 文字**，不能只靠颜色。颜色取 `systemFillColorSuccess / Caution / Critical / Neutral`。
4. **每屏只有一个 `FilledButton`**（主操作），其余用 `Button`。弹窗：取消在左，主操作在右。
5. **大字用常规体**：雅黑没有 Semibold，600 会渲染成粗体，页面标题、数值显得很重。强调用 `bodyStrong`。
6. **动效短、减速、可关闭**：150–460ms，减速曲线；`MediaQuery.disableAnimationsOf` 为 true 时直接跳到终态。
7. **中文文案**，观众昵称等用户输入一律截断（超 12 字加「…」，悬停看全名）。

## 关键尺寸（逻辑像素）

| 区域 | 规格 |
|------|------|
| 标题栏 | 高 48；图标 20，距左 26（与侧栏图标列对齐）；标题 `body`，距图标 12；系统按钮 32 高贴顶；失焦时标题变 `textFillColorTertiary` |
| 侧栏 | 宽 72；瓦片 64×58、间距 4、圆角 6；图标 20、图文间距 4、文字 `caption` |
| 选中指示条 | 3×16、圆角 1.5、主题色，骑在瓦片左缘 |
| 主体内容层 | `layerFillColorDefault` + `cardStrokeColorDefault` 描边 + 左上圆角 8 |
| 内容列 | 最大宽 1000，**居中**，左右 gutter 24；页头包 `PageWidth` 与内容左缘对齐 |
| 分组 | `SettingsSectionHeader`（bodyStrong，上 24 下 8）；同组卡片间距 4；并排卡片间距 12 |
| 设置卡 | `SettingsCard` 最小高 68（内边距 16/12）；图标 20 → 标题 body + 说明 caption → 右侧控件 |
| 弹窗 | `ContentDialog` 默认宽 368，三个按钮时放宽到 440；输入框外包 `SizedBox(height: 32)` |
| 窗口 | 主窗口 1280×720、最小 960×640；启动卡片 440×320 |

侧栏三态（对照 Microsoft Store）：

| 状态 | 底色 | 图标 / 文字 |
|------|------|------|
| 未选中 | 透明 | `textFillColorSecondary`（灰） |
| 悬停 / 按下 | `subtleFillColorSecondary` / `subtleFillColorTertiary` | `textFillColorPrimary`（黑）/ 次要色 |
| 选中 | 浅色 `cardBackgroundFillColorDefault`（白）；深色 `0x1AFFFFFF` | 主题色 `accentColor.defaultBrushFor(brightness)` |

图标统一 Segoe Fluent 线性图标（`WindowsIcon(WindowsIcons.x, fallbackIcon: FluentIcons.x)`），选中只换颜色，不换实心。

完整色值、字号、动效参数见 [references/tokens.md](references/tokens.md)。

## 页面骨架

```dart
ScaffoldPage(
  header: PageWidth(child: PageHeader(title: Text('标题'), commandBar: /* 主操作 */)),
  content: PageBody(children: [
    const SettingsSectionHeader('分组'),
    SettingsCard(leading: ..., header: Text('标题'), description: Text('说明'), trailing: ...),
    const SizedBox(height: kCardSpacing),
    SettingsCard(...),
  ]),
)
```

- 设置页、列表页、统计卡、表单弹窗、空状态的完整写法见 [references/page-recipes.md](references/page-recipes.md)。
- 各组件的用法和取舍见 [references/components.md](references/components.md)。

## 动效

| 场景 | 参数 |
|------|------|
| 侧栏瓦片底色 / 字色 | 150ms easeOut；选中白底单独一层做透明度过渡 |
| 指示条同组移动 | 460ms：朝向目标一端 `Interval(0, .62, easeOutCubic)` 先走，另一端 `Interval(.18, 1, easeInOutCubic)` 跟上，先拉长再收回 |
| 指示条跨组（顶部 ↔ 底部） | 380ms：原位收缩到 0，再在新位置展开 |
| 切页 | 旧页 120ms 淡出；新页 380ms 从下方 40px 以 `Cubic(0.1, 0.9, 0.2, 1)` 滑入，透明度 `Interval(.15, .6)` |
| 失焦 | 云母 ⇄ 纯色（浅 #F3F3F3 / 深 #202020）由 DWM 自己过渡，前提是 runner 把 `WM_NCACTIVATE` 交给 `DefWindowProc`；界面只把标题变成 `textFillColorTertiary`。毛玻璃没有失焦态，保持原样 |
| 启动卡片 | 至少 1.2s、最多 3s；卡片 160ms 淡出 → 窗口放大居中 → 主界面 260ms 淡入 |

## 改界面前先读

[references/pitfalls.md](references/pitfalls.md)：已经踩过的坑（颜色插值发灰、Stack 松约束、窗口隐藏时改大小卡帧、失焦 / 托盘恢复后云母不对……），每条都有原因和解法。

## 自检清单

- [ ] 背景透明，云母可见；主体内容区比侧栏略亮
- [ ] 页头包了 `PageWidth`，标题与卡片左缘对齐
- [ ] 每屏一个 `FilledButton`；状态有图标 + 文字
- [ ] 弹窗输入框单行且限高 32；取消在左
- [ ] 用户输入的名字已截断；长文案有 `maxLines` + `ellipsis`
- [ ] 在 960×640 最小窗口下无溢出（widget 测试里 `tester.takeException()` 为 null）
- [ ] 亮 / 暗两套都截图看过（`flutter-ui-screenshots`）
- [ ] 动过 runner 或窗口行为的：真窗口上确认失焦变暗、托盘恢复后云母仍在
- [ ] 动过窗口材质的：Windows 10（`debugWindowsBuildOverride = 19045`）和 11 两套设置页都 pump 过；系统关透明效果时（`debugBackdropOpaqueOverride = true`）界面是纯色不是黑的
- [ ] 图标 / 色块按钮、滑块有读屏标签（`tester.ensureSemantics()` + `getSemantics` 断言）
- [ ] `flutter analyze` 无告警
