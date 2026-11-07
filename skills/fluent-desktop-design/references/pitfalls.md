# 踩过的坑

每条：现象 → 原因 → 做法。来源包括 WindBellEcho 的实际问题、源码核对和待实机确认项；后两类在对应条目标明，不视为已经复现。

## 视觉

- **标题、数值显得很粗** → 雅黑没有 Semibold，`w600` 被渲染成 Bold → 主题里把 title / subtitle 等设为 `FontWeight.normal`，强调用 `bodyStrong`。
- **切换选中时瓦片闪一下灰** → `Color.lerp(白, Colors.transparent)` 中途是半透明灰 → 选中的白底单独一层，只做透明度过渡（`AnimatedOpacity`）；悬停底色本身很淡，直接过渡看不出问题。
- **侧栏瓦片缩成内容宽** → `Stack` 给子组件松约束 → 外层 `Column(crossAxisAlignment: stretch)`，或用 `Positioned(left: 0, right: 0)`。
- **页面上的短内容（搜索框、页脚）跑到中间** → `Align` 也给松约束，`PageWidth` 里短内容被缩小后居中 → `PageWidth` 用 `LayoutBuilder` 算出宽度后 `SizedBox(width: ...)` 定宽，内容在列里左对齐。
- **页头按钮在窄窗口溢出** → `PageHeader` 的 commandBar 最多只占一半宽度 → 页头只放 2–3 个按钮；搜索框放到内容区第一行。
- **色条 / 分隔条不显示** → `Row` 里没有子组件的 `ColoredBox` 高度为 0 → `Row(crossAxisAlignment: CrossAxisAlignment.stretch)` 并给外层定高。
- **弹窗里的 TextBox 被纵向撑满** → `ContentDialog` 内容区不限高 → `SizedBox(height: 32, child: TextBox(maxLines: 1))`。
- **长昵称挤掉后面的「抽中 xx」** → 整行一起截断 → 名字单独截断（`ellipsize` 按字符簇，不拆 emoji），HTML 里名字放进单独的 `<span>` 设 `max-width` + `text-overflow`。

## 行为

- **NumberBox 输入后直接点保存，拿到旧值** → NumberBox 失焦或回车才提交 → 用 `TextBox` + `digitsOnly`，保存时解析校验。
- **切页时报「ScrollController attached to more than one ScrollPosition」** → 过渡期间新旧两页同在树上，共用 `PrimaryScrollController`，Fluent 常显滚动条要求单一位置 → 每页包一个自己的 `PrimaryScrollController`（见 `page_switcher.dart` 的 `_OwnScroll`）。
- **NavigationView 自带的切页没有交叉淡化** → 它的 `AnimatedSwitcher` 只布局当前页 → 用 `paneBodyBuilder` 返回固定 key 的 `PageSwitcher`，由它负责过渡。
- **`customPane` 下 `ScaffoldPage` 背景变成不透明** → `ScaffoldPage` 不在 `NavigationView` 里时画 `micaBackgroundColor` → 保持在 `NavigationView` 里；**不要**全局把 `micaBackgroundColor` 改透明（`ContentDialog` 底栏也在用）。
- **`PaneItem.title` 让 Windows 读屏刷屏** → 会套 Tooltip，AXTree 不停更新 → 不设 title，文字画在自绘侧栏里。
- **后台启动和用户点击打架** → 启动卡片超时后服务仍在后台启动，用户又点了「启动 / 停止」 → `start()` 返回同一个进行中的 Future；`stop()` 用 epoch 作废进行中的启动，不等它的网络请求。
- **弹出层（取色器等）贴着窗口顶部、盖住了点开它的按钮** → `FlyoutPlacementMode.auto` 用 `LayoutBuilder` 量弹出层，量到的是整个窗口，每个方向都「放不下」，总是退回 `topCenter` 再夹进窗口 → 明确给 `placementMode`；取色器放在按钮左边（`leftCenter`），960×640 下也放得下。
- **读屏只读出「按钮」，不知道是做什么的（色块、图标按钮）** → 包在 `Button` 外面的 `Tooltip` 的标签落在按钮自己的语义节点外面 → 在按钮的 child 里包 `Semantics(label: ...)`，`Tooltip` 设 `excludeFromSemantics: true` 免得读两遍。
- **读屏读滑块只有「75%」** → fluent_ui 的 `Slider` 把 `label` 当作语义标签，那就是数值 → `MergeSemantics(child: Semantics(label: '不透明度', child: Slider(...)))`，旁边显示数值的文字用 `ExcludeSemantics`。
- **拖动预览中途退出，改动丢了** → 预览只改内存、松手 / 关闭弹出层才写盘；取色器开着时从托盘退出，就没有「关闭」 → 设置里记一个「有未保存的预览」标记，退出流程里 `flush()`。

## 窗口

- **窗口先在屏幕左上角闪一下** → 原生窗口在 (10,10) 创建；在 `runApp` 前调了 `windowManager.show()` → 原生第一帧回调才显示窗口；`runApp` 前只设大小、位置，不 show。
- **隐藏窗口时改大小，再显示是旧画面** → 所有窗口隐藏时 Flutter 进入 hidden 生命周期、停止出帧，改大小最多等 100ms 就放弃 → 启动卡片 → 主窗口全程保持可见，一次 `setBounds` 放大居中。
- **失焦后云母不变暗；从托盘恢复后云母没了，再点窗口也回不来** → `TitleBarStyle.hidden`（或无边框）时 window_manager 处理 `WM_NCACTIVATE` 只发 focus / blur 事件就 `return 1`，不交给 `DefWindowProc`，DWM 收不到激活变化；隐藏到托盘时 DWM 走别的路径记成失焦，之后的激活又都被吞掉，云母一直停在失焦的纯色 → runner 的 `MessageHandler` 里插件处理过 `WM_NCACTIVATE` 后补一句 `return DefWindowProc(hwnd, message, wparam, -1);`（见 `fluent-desktop-shell/references/windows-runner.md`），失焦变暗交给 DWM。**不要**在 Dart 里按 focus / blur 盖一层 `micaBackgroundColor` 模拟：和 DWM 的状态一对不上，就会挡住云母。原生问题只能在真窗口上验证（`flutter-ui-screenshots` 的「真窗口取色」）。
- **云母完全不显示** → Impeller 画不透明底 → `windows/runner/main.cpp` 里 `project.set_impeller_switch(flutter::ImpellerSwitch::Disabled)`，改完要完整重新构建。
- **不可调整大小的窗口是直角** → 去掉 `WS_THICKFRAME` 后 DWM 可能不画圆角 → `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)`（Windows 10 会失败，忽略即可）。
- **小屏幕上主窗口超出屏幕** → 写死 1280×720 → 用 `screen_retriever` 取可用区域，四周留 24，最小尺寸也按可用区域收缩。
- **C++ 注释里的中文导致 MSVC 告警 C4819** → 代码页 936 → `main.cpp` 等注释只用 ASCII。

## 窗口材质（云母 / 毛玻璃）

以下除注明的外，都在 Windows 11 24H2（26100）真窗口上用 `flutter-ui-screenshots` 的材质探针测过；Windows 10 没有实机验证。

- **Windows 10 上没有云母，侧栏、标题栏透明处不对** → `flutter_acrylic` 的 `WindowEffect.mica` 在 build < 22000 上什么都不做 → 不支持云母时改用毛玻璃（`window_backdrop.dart` 的 `planBackdrop`），设置页的材质下拉框禁用并固定为毛玻璃。
- **Windows 11 上毛玻璃的色调、不透明度不起作用** → `flutter_acrylic` 在 build ≥ 22523 把 `WindowEffect.acrylic` 换成系统材质 `DWMWA_SYSTEMBACKDROP_TYPE = 3`，不接受颜色 → 毛玻璃自己调 `SetWindowCompositionAttribute`（`ACCENT_ENABLE_ACRYLICBLURBEHIND`，flags 2，GradientColor 是 0xAABBGGRR）；从云母切过来前先把 `DWMWA_SYSTEMBACKDROP_TYPE` 设为 1（none）、边框扩展还原为 0。云母仍交给 `flutter_acrylic`，它切云母前会清掉 accent。
- **Windows 11 上「普通模糊」是黑的** → `ACCENT_ENABLE_BLURBEHIND` 在 24H2 上亮暗主题都画成近乎纯黑 → 模糊方式只在 Windows 10（1803 起）上可选，Windows 11 固定亚克力。
- **启动卡片上的毛玻璃不模糊、窗口拿不到焦点** → 为了避免第一帧黑屏，在 `runApp` 之前（窗口显示之前）就设了 accent；不可调整大小的启动卡片因此一直是「透明但不模糊」，窗口也没被激活 → 和云母一样在第一帧之后设（`App` 的 post-frame 回调）。实测这样不会有黑帧：Windows 11 首帧只有 DWM 的淡入。
- **浅色主题下拖不透明度滑块几乎看不出变化** → Windows 11 的亚克力自己叠了一层亮度，浅色色调时不透明度主要影响饱和度 → 系统行为；深色主题和自定义色调变化明显。说明文字只写「越高越接近纯色」，不承诺线性变化。
- **毛玻璃拖动窗口时跟不上鼠标（Windows 10，未实测）** → `flutter_acrylic` 的 README 写明 `WindowEffect.acrylic` 在 Windows 10 上拖动窗口会卡、Windows 11 已修复；同一个 accent 状态，自己调 FFI 也一样 → 拖动 / 缩放期间（window_manager 的 move / resize 到 moved / resized）临时换成普通模糊，松手换回。Windows 11 上实测拖动与云母同为每次移动一帧，且普通模糊是黑的，不做这个处理。
- **Windows 10 上毛玻璃窗口外沿可能有一圈 8px 的模糊（未实测）** → `flutter_acrylic` 的 README 提到 Windows 10 上模糊会漏到窗口边界外；隐藏标题栏后 window_manager 在 `WM_NCCALCSIZE` 里给左、右、下各留 8px 缩放边框，accent 可能把这圈也画上 → 1.0.2 先这样发布，等 Windows 10 实机确认；真有的话考虑 `setAsFrameless()` + `DragToResizeArea`，或拖动时之外也用纯色边。
- **系统关了「透明效果」或开了高对比度，毛玻璃窗口可能整窗发黑（Windows 10，未实测）** → accent 在这种设置下怎么画是未公开行为，可能什么都不画，露出 Flutter 透明的底 → 读 `HKCU\...\Themes\Personalize` 的 `EnableTransparency` 和 Flutter 的 `accessibilityFeatures.highContrast`，要求不透明时 `BackdropPlan.fill` 给出色调纯色、accent 设 0，由 `App` 在界面底下铺这一层；设置开关没有通知，窗口重新激活、无障碍设置变化时重读。这是「界面不要盖底色」的例外：盖的是 DWM 本来就不画的毛玻璃，云母不盖（DWM 自己换纯色）。
- **失焦后毛玻璃不变暗** → 老的 accent 毛玻璃没有失焦态，云母才会变纯色 → 保持原样；**不要**按 focus / blur 盖底色（与云母那条同理，状态对不上就挡住材质）。
- **快速切换云母 / 毛玻璃后窗口停在错误的材质** → 云母走 `flutter_acrylic` 的 method channel（异步），毛玻璃走 FFI（同步），先发的请求可能后生效 → 所有请求排进一个队列依次执行，只执行最新一次。去重要对比「已经生效的」方案：下发失败或云母还没初始化时不算生效，下次同样的请求会重试；`App` 自己不要再按「上次请求的」去重，否则失败一次就再也不发。
- **改了 Windows 强调色后，浅色应用的边框、云母变成深色（或反过来）（读代码发现，未在真窗口复现）** → Flutter 模板的 `Win32Window` 收到 `WM_DWMCOLORIZATIONCOLORCHANGED` 会按系统主题重设 `DWMWA_USE_IMMERSIVE_DARK_MODE`，盖掉 Dart 按应用主题设的值；1.0.1 起就有 → runner 的 `FlutterWindow::MessageHandler` 里拦下这条消息直接返回 0（见 `fluent-desktop-shell/references/windows-runner.md`），这个属性只由 Dart 设。
- **取色器弹出层太高，盖住标题栏** → `ColorPicker` 默认带 RGB 三个输入框，640 高的窗口放不下 → `isColorChannelTextInputVisible: false`，只留色环、亮度条和十六进制（同 Windows 11「自定义颜色」）。
- **直接用 `Expander` 做「可展开的设置卡」，和上下的卡片不齐** → fluent_ui 的标题行只有约 46 高、圆角 6 → 用壳子的 `SettingsExpander`（68 高、圆角 4，行内文字与标题文字对齐、行内控件与标题行控件右对齐）。
- **`SettingsExpander` 展开后底部是直角** → `Expander` 用 `ShapeDecoration` 画内容区，`Border` 当 `ShapeBorder` 用时忽略圆角 → `contentShape` 给无边框的 `RoundedRectangleBorder()`、`contentBackgroundColor` 透明，内容自己用 `BoxDecoration` 画底色和左右下三边（单色的不等边 `Border` 可以配 `borderRadius`）。
- **展开行里的控件比标题行的控件更靠右** → 标题行右边还有展开箭头（按钮 28 + 两侧 8） → 行的右内边距 44（加 1px 描边 = 45，与标题行控件右缘一致），不是 16。

## 数据与发布

- **改了 `Runner.rc` 的 CompanyName / ProductName，升级后配置「丢了」** → `path_provider` 的应用数据目录是 `%APPDATA%\<CompanyName>\<ProductName>` → 改名前想清楚；改了就在启动时从旧目录复制缺失的文件（只复制不删除）。
- **安装包升级后出现两份程序** → 换了 AppId 或安装目录 → AppId 永远不变；改目录用安装脚本迁移（见 `flutter-windows-installer`）。
- **测试里截图全是方块字** → flutter_test 默认用 Ahem 字体 → `FontLoader` 加载系统字体（见 `flutter-ui-screenshots`）。
- **widget 测试里窗口背景从来没下发（排队的回调不执行）** → 下发队列是模块级的 `Future` 链；上一个测试留下的已完成 Future 在它自己的 zone 里排回调，不归这个测试的 FakeAsync 管，`pump` 不会执行 → 测试开头先 `debugResetBackdrop()`，在本测试的 zone 里重建队列。
- **截图结果受本机材质设置影响（模板核对发现）** → 把目标平台设为 Windows 后，`App` 会读取透明效果并下发材质，仅 mock MethodChannel 没有覆盖 FFI 路径 → 每个截图测试先 `debugResetBackdrop()`，再设 `debugBackdropApplier`、Windows build 和不透明覆盖值，结束前卸载 widget 并还原；`flutter-ui-screenshots` 模板已包含这些步骤。
