# 组件取舍

`SettingsCard`、`SettingsExpander`、`SettingsExpanderItem`、`SettingsSectionHeader`、`PageWidth`、`PageBody`、`pageListPadding`、`ButtonRow`、`IconLabel`、`StatTile`、`NameText`、`showToast`、`ErrorBanner` 是壳子自带的组件，源码在 `fluent-desktop-shell/templates/lib/widgets/`。其余为 fluent_ui 自带组件。

## 选哪个

| 场景 | 用 | 不要 |
|------|----|------|
| 一行设置 / 列表项 | `SettingsCard` | 自己拼 `Card` + `Row` |
| 一组从属设置（展开 / 收起） | `SettingsExpander` + `SettingsExpanderItem` | fluent_ui 的 `Expander` 直接用（矮、圆角不同） |
| 连续数值（不透明度等） | `Slider`（宽 200）+ 右侧 44 宽的数值文字 | `NumberBox` |
| 选颜色 | 色块 `Button` + `FlyoutTarget` 弹出 `ColorPicker` | 自绘调色板 |
| 一组信息聚合 | `Card(padding: EdgeInsets.all(16))` | 阴影、渐变 |
| 统计数字 | `StatTile`（标签 / 数值 / 说明三行） | 大号粗体数字 |
| 主操作 | `FilledButton`（每屏一个） | 多个 FilledButton |
| 次要操作、行内操作 | `Button` | `HyperlinkButton` 当按钮 |
| 图标按钮 | `IconButton` + `Tooltip` | 无提示的纯图标 |
| 开关 | `ToggleSwitch(leadingContent: true, content: Text(开/关))` | `Checkbox` 当开关 |
| 单选几项 | `ComboBox` | 一排 `RadioButton`（项少时可以） |
| 文本输入 | `TextBox(maxLines: 1)`；密码 `PasswordBox(revealMode: peek)` | 多行默认值 |
| 数字输入 | `TextBox` + `FilteringTextInputFormatter.digitsOnly`，保存时自己解析校验 | `NumberBox`（失焦才提交，点保存时可能拿不到刚输的值） |
| 字段标签 | `InfoLabel(label: ..., child: ...)` | 自己写 Text + 间距 |
| 页面级提示 / 错误 | `InfoBar`；保存失败用 `ErrorBanner`（无错误时不占位） | 弹窗打断 |
| 操作结果 | `showToast(context, msg, severity: ...)`，可带一个操作按钮 | `ContentDialog` |
| 确认 / 表单 | `ContentDialog`：取消 `Button` 在左，主操作 `FilledButton` 在右 | Material Dialog |
| 加载 | `ProgressRing`（局部）、`ProgressBar`（整页 / 启动卡片） | 自绘 spinner |
| 用户昵称 | `NameText(name)` / `ellipsize(name)` | 直接 `Text(name)` |

## 用法要点

### SettingsCard

```dart
SettingsCard(
  leading: const WindowsIcon(WindowsIcons.globe, fallbackIcon: FluentIcons.globe),
  header: const Text('端口'),
  description: Text('当前 ${server.url}'),
  trailing: ButtonRow(children: [
    SizedBox(width: 120, child: TextBox(controller: _port, maxLines: 1)),
    Button(onPressed: _apply, child: const Text('应用')),
  ]),
)
```

- 右侧输入框给固定宽度（120 / 240 / 320），不要 `Expanded`。
- 说明可以是 `Column(mainAxisSize: min)`：第一行 `SelectableText(url)`，第二行状态。

### 图片与主题预览

- Flutter 客户端的奖品图标使用 `prize_icon.dart`：内置图标读 `assets/lottery_ui/icons/<id>.png`，自定义图片从 `LotteryStore.mediaFile` 取；不要直接把展示页 SVG 交给 `Image.asset`。
- 主题预览使用 `assets/lottery_ui/themes/<theme>_<mode>.png`。展示页外观或内置图标变更后，在 `tool/overlay` 执行 `node render-assets.js`，保持配置页与实际展示一致。
- 导入图片的格式、大小和尺寸校验由 `LotteryStore.importMedia` 负责；界面显示失败原因，避免自行拼任意文件路径。此约定适用于 WindBellEcho，通用外壳不自带奖品业务。

### SettingsExpander

```dart
SettingsExpander(
  key: const PageStorageKey('acrylic-options'), // 切页回来保持展开状态
  initiallyExpanded: true,
  leading: const WindowsIcon(WindowsIcons.color, fallbackIcon: FluentIcons.color),
  header: const Text('毛玻璃效果'),
  description: Text(summary), // 收起时也能看到当前值：「色调跟随主题 · 不透明度 75%」
  items: [
    SettingsExpanderItem(header: const Text('色调'), description: ..., trailing: ComboBox(...)),
    SettingsExpanderItem(header: const Text('不透明度'), trailing: ...),
    SettingsExpanderItem(header: const Text('恢复默认'), description: Text('色调跟随主题、不透明度 75%'),
        trailing: Button(onPressed: changed ? reset : null, child: const Text('重置'))),
  ],
)
```

- 标题行 68 高、圆角 4，与 `SettingsCard` 一致；行内文字与标题文字左对齐（52），行内控件与标题行控件右对齐（右边让出展开箭头 44）。
- 标题行右侧（`trailing`）不放按钮：和展开箭头挤在一起，容易点错。「恢复默认」做成最后一行。
- 「重置」只看界面上有的项是否改过；当前系统不显示的项（比如 Windows 11 没有的「模糊方式」）不算。

### 拖动即预览的控件（滑块、取色器）

- 拖动中只改内存、立即作用（`setX(..., persist: false)`），`Slider.onChangeEnd` / 弹出层关闭后再写盘；退出流程里 `flush()`，免得中途退出丢改动。
- 取色器：`FlyoutContent(child: ColorPicker(isAlphaEnabled: false, isMoreButtonVisible: false, isColorChannelTextInputVisible: false))`；`showFlyout` 明确给 `placementMode`（色块在行右侧时 `leftCenter`），不要用 auto。
- 读屏：色块按钮在 child 里包 `Semantics(label: '选择颜色')`（`Tooltip` 设 `excludeFromSemantics: true`）；滑块包 `MergeSemantics(child: Semantics(label: '不透明度', child: Slider(...)))`。

### 状态显示

```dart
final (icon, fallback, color, text) = switch (status) {
  Status.ok => (WindowsIcons.completed, FluentIcons.completed, res.systemFillColorSuccess, '已连接'),
  Status.busy => (WindowsIcons.sync, FluentIcons.sync, res.systemFillColorCaution, '连接中…'),
  Status.off => (WindowsIcons.error_badge, FluentIcons.error_badge, res.systemFillColorNeutral, '未连接'),
};
```

### 进行中的按钮

请求进行中禁用并换文字：`FilledButton(onPressed: null, child: IconLabel(icon: WindowsIcons.sync, ..., label: '启动中…'))`；或在按钮里放 `SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2))`。

### 弹窗

- 弹窗用独立的 `StatefulWidget`，在 `dispose` 里释放 `TextEditingController`。
- 校验失败在弹窗内显示红字（`systemFillColorCritical` + caption），不要关闭弹窗。
- 返回值用 record，如 `Navigator.pop(context, (CloseAction.tray, remember))`。

### 敏感信息

账号密码等用 DPAPI 加密后再写盘：见 `templates/secret_box.dart`（需要 `ffi`、`win32`）。设置页的密码框不回填明文，留空表示不修改。
