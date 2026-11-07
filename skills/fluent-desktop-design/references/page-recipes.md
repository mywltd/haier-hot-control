# 页面写法

示例代码可直接运行的版本在 `fluent-desktop-shell/templates/lib/pages/`（首页、列表、设置）。

## 新页面接入侧栏

1. 新建 `lib/pages/<feature>/<feature>_page.dart`，类名 `<Feature>Page`，`const` 构造。
2. `lib/shell/app_shell.dart`：
   - `ShellPage` 加下标常量（设置页始终是最后一个，在侧栏底部）；
   - `_pages` 加 `(NavEntry(label: '两字', icon: WindowsIcons.x, fallbackIcon: FluentIcons.x), XxxPage())`。
3. 标签用两个汉字（侧栏 64 宽，四个字会挤）。
4. 跨页跳转：`ShellNavScope.of(context).goTo(ShellPage.xxx)`。

## 设置页 / 配置页

```dart
ScaffoldPage(
  header: const PageWidth(child: PageHeader(title: Text('设置'))),
  content: PageBody(children: [
    ErrorBanner(title: '设置保存失败', error: store.saveError), // 无错误时不占位，后面的输入框不会因此重建失焦
    const SettingsSectionHeader('远程服务器'),
    SettingsCard(..., trailing: SizedBox(width: 320, child: TextBox(controller: _url, maxLines: 1))),
    const SizedBox(height: kCardSpacing),
    // 最后一张卡放状态 + 「还原」Button + 「保存」FilledButton
  ]),
)
```

- 多个字段一起保存时，字段卡片在上、状态卡片在下；保存按钮是本页唯一 `FilledButton`。
- 单个开关 / 下拉立即生效，不需要保存按钮。
- 一组从属设置（如「毛玻璃效果」的色调、不透明度）用 `SettingsExpander`，只在上级选项选中时出现（「窗口材质」选毛玻璃才显示）；系统不支持的选项禁用并在说明里写原因（「系统云母需要 Windows 11」），不要藏起来让用户找。
- 滑块、取色器拖动时即时预览、松手才写盘，见 `components.md`「拖动即预览的控件」。
- 改了会影响外部的设置（端口、地址），保存后 toast 提示需要同步修改哪里。

## 列表页

- 页头：标题 + 主操作（新增 / 导出）。
- 内容第一行：`PageWidth` 里放搜索框（宽 280，`prefix` 放搜索图标）。
- 列表：`LayoutBuilder` + `ListView.separated(padding: pageListPadding(context, maxWidth), separatorBuilder: SizedBox(height: kCardSpacing))`，每行 `SettingsCard`。
- 空状态：`Center(child: Text('还没有…，xx 后会出现在这里'))`，一句话；搜索无结果另给一句「没有匹配的…」。
- 页脚：`PageWidth` + `Padding(fromLTRB(gutter, 12, gutter, 24))` 放统计文字（次要色）。
- 破坏性操作（清空）用 `ContentDialog` 确认，文案写清数量和不可恢复。

## 首页 / 概览

- 顶部：未配置、异常用 `InfoBar`（warning / error），带「去设置」按钮。
- 主状态卡：`SettingsCard` + 右侧主操作（启动 / 停止；进行中禁用并显示「启动中…」）。
- 统计行：`Row` 里 3–4 个 `Expanded(StatTile(...))`，间距 12。
- 下面按功能分组：`SettingsSectionHeader` + 若干 `SettingsCard`（开关 + 「配置」按钮跳转）。

## 表单弹窗

见 `list_page.dart` 的 `_AddDialog`：

- 每个字段 `InfoLabel` + `SizedBox(height: 32, child: TextBox(maxLines: 1))`，字段间距 12。
- 说明文字 caption 次要色；错误红字放在最后。
- 保存时整体校验，失败只显示第一条错误；成功 `Navigator.pop(context, 结果)`。

## 状态与反馈

| 情况 | 做法 |
|------|------|
| 操作成功 | `showToast(..., severity: success)`；导出文件可带「打开」按钮 |
| 操作失败 | `showToast(..., severity: error)`，文案给原因（网络错误先翻译成人话） |
| 页面级持续状态 | 页顶 `InfoBar` |
| 写盘失败 | `ErrorBanner` |
| 加载中 | 局部 `ProgressRing`；不要整屏遮罩 |
