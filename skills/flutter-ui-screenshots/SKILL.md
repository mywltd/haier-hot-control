---
name: flutter-ui-screenshots
description: 不启动应用，用 flutter_test 加载真实字体把 Flutter 桌面界面渲染成 PNG（亮/暗两套、悬停态、局部放大、动画中间帧），用来对照设计稿、检查溢出和动效；云母、毛玻璃、失焦、托盘恢复、启动帧、拖动窗口这类原生窗口效果用演示工程 + 屏幕取色脚本在真窗口上验证。改完 Flutter 界面要看实际效果、用户给了参考图要对齐、或改了 runner / 窗口材质 / 窗口行为时使用。
---

# 截图看界面

模板按 WindBellEcho 1.1.0+5 的 `App` / `window_backdrop.dart` 接口核对；默认适用于同组 `fluent-desktop-shell`，其他应用需适配入口、材质钩子和资源路径。

## 为什么不直接运行应用

- 运行应用可能登录真实账号、占用端口、和用户正在运行的实例冲突（单实例互斥）。
- `flutter test` 默认字体是 Ahem（全是方块），必须手动加载系统字体，截图才可读。
- 截图能精确停在动画的某一帧，肉眼运行做不到。

## 步骤

1. 复制 `templates/ui_shots_test.dart` 到项目的 `test/zz_scratch_ui_shots_test.dart`。
2. 替换 `your_app` 导入；`_pages` 列出要截的侧栏标签；`_appIcon` 指向已登记的图标资源。
   - WindBellEcho：包名 `wind_bell_echo`，图标 `assets/tray_icon.ico`，侧栏为首页 / 用户 / 转盘 / 记录 / 设置；另导入 `core/app_context.dart`，在 `_capture` 的 `pumpWidget` 前调 `AppContext.debugCreate()`，按需准备内存示例数据。
   - 不调用真实 `main()`、`bootstrap()`、`load()`、`startServices()`；截图也不点击「保存并连接」「启动」等网络动作。截图模板默认 `App()` 不传 startup，直接显示主界面。
3. 运行：`flutter test test/zz_scratch_ui_shots_test.dart`，输出在 `%TEMP%\ui_shots\*.png`。
4. 用可查看本地图片的工具打开 PNG（Codex 用 `view_image`）。对照参考图时注意比例，不要逐像素硬套：参考图的缩放比例常常不同。
5. 改代码 → 重新运行 → 再看，直到满意。
6. **删掉** `test/zz_scratch_ui_shots_test.dart`（每次 `flutter test` 都会跑它）。模板可以留在 `%TEMP%` 下次用。

## 常用写法

- **悬停**：`tester.createGesture(kind: PointerDeviceKind.mouse)` → `addPointer` → `moveTo(...)` → `pumpAndSettle`。
- **局部放大**：`_crop(tester, 'name', Rect.fromLTWH(x, y, w, h))`，3 倍像素，看图标、文字对齐。
- **动画中间帧**：`tap` 后 `pump()` 一次让动画开始，再 `pump(Duration(milliseconds: 60))` 逐段推进，每段截一张。注意 `pump(d)` 的时间是累加的。
- **弹窗**：调 `showDialog` 的函数后 `pumpAndSettle` 再截；截完点「取消」关掉。
- **失焦 / 其他状态**：直接调状态对象（如 `WindowActivity.onWindowBlur()`）再截。
- **图片资源**：`.ico` / `.png` 第一次解码是异步的，截图前在 `tester.runAsync` 里 `precacheImage(...)`，否则第一张图里没有图标。
- **启动卡片**：`App(startup: Completer().future)` 截，结束前 `pump` 过最长等待时间，避免留计时器。
- **窗口尺寸**：`tester.view.physicalSize = 逻辑尺寸 × devicePixelRatio`；检查溢出时用最小窗口（如 960×640，dpr 1）。

## 注意

- `debugDefaultTargetPlatformOverride = TargetPlatform.windows` 必须在测试体内用 `try/finally` 还原，否则测试框架报「debug 变量未还原」。
- 弹出层、弹窗的阴影在 flutter_test 里默认画成粗黑框（`debugDisableShadows` 为 true）。模板已设为 false 并在 `finally` 还原原值。
- 按系统版本显示不同内容的界面（如 Windows 10 没有云母），用应用里的 build 覆盖开关（本项目是 `debugWindowsBuildOverride`）各截一套，`addTearDown` 里还原。
- 模板已在每个截图测试里 `debugResetBackdrop()`，设 `debugBackdropApplier = (_) async => true`、Windows build 26100 和 `debugBackdropOpaqueOverride = false`，结束前卸载 widget 并还原；只 mock MethodChannel 无法隔离材质的 FFI 路径。要看 Windows 10 改为 19045；要看「系统关了透明效果」设 opaque 覆盖为 true，再 `refreshBackdropOpaque()`。
- 测试环境没有 window_manager / flutter_acrylic / tray_manager 插件，模板已把这些 MethodChannel mock 成返回 null。
- 测试里没有云母，模板垫了一层近似的渐变底色；真实效果（云母颜色、失焦变暗、托盘恢复）用下面的「真窗口取色」确认。
- **失焦 / 其他状态**截出来的只是 Flutter 画的部分（标题变灰等），DWM 画的云母 / 纯色只在真窗口上有。
- 网页（OBS 浏览器源等）用 Playwright：`npm i playwright-core`，`chromium.launch({ executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' })`，用 mock 服务器推消息、`page.screenshot()`。

### 本项目展示页

`assets/overlay/lottery/` 是独立 HTML，不走 Flutter 截图模板。在 `tool/overlay` 执行 `npm ci`（锁定依赖要求 Node 20+，需本机 Edge），然后：

- `node shots.js`：五套主题 × 两种玩法的空闲、转动、中奖、小卡片；`node shots.js sakura grid` 可限定范围。
- `node run-tests.js`：mock WebSocket 的行为测试，约 4 分钟。
- `node dev-server.js sakura grid --demo`：手动预览，每 12 秒推送一次模拟抽奖。
- `node render-assets.js`：将内置 SVG 和真实展示页转成客户端图标 / 主题缩略图，输出到 `assets/lottery_ui/`。

前三项使用 17990，不要同时运行；资源渲染使用 17991。截图在 `tool/overlay/shots/`，不作为发布资源。改内置图标时先运行 `node build-icons.mjs`；验证协议见 `assets/overlay/lottery/js/main.js` 与 `tool/overlay/fixtures.js`，不连接真实后台。

## 真窗口取色（云母、失焦、托盘恢复）

原生行为（云母、DWM 失焦变暗、隐藏到托盘再恢复）widget 测试测不到，要截真窗口的屏幕像素。**不要拿真应用跑**：用 `fluent-desktop-shell` 模板建一个演示工程，runner 打同样的补丁。

1. PowerShell：`flutter create --platforms=windows --project-name probe_demo "$env:TEMP\probe_demo"`，按 `fluent-desktop-shell` 复制模板、改 runner。演示工程使用独立的 CompanyName / ProductName、互斥量和自启项名，不沿用真实应用身份。
2. 复制 `templates/real_window/window_probe_driver.dart` 到演示工程 `lib/`，在 `main.dart` 的 `runApp(...)` 之后加一行 `runWindowProbeDriver();`。它只在环境变量 `WINDOW_PROBE_DIR` 存在时运行。
3. `flutter build windows --debug`（工程在 `%TEMP%` 下会报 MSB8029，可以忽略）。
4. 在本 skill 目录用 PowerShell 执行 `powershell -NoProfile -File templates/real_window/capture.ps1 -Exe "$env:TEMP\probe_demo\build\windows\x64\runner\Debug\probe_demo.exe"`。依次做：启动 → 切走 → 切回 → 隐藏到托盘 → 恢复 → 切走 → 切回，每步存 PNG，并在 `capture.log` 记前台状态和取样区域的平均色：
   ```
   1_start     fg=True  sidebar=#F9F0F0 title=#F9F0F1   ← 云母（带壁纸色调，每台机器不同）
   2_blur      fg=False sidebar=#F3F3F3 title=#F3F3F3   ← 失焦纯色（深色是 #202020）
   4_restored  fg=True  sidebar=#F3F3F3 ...             ← 前台却是纯色 = 云母状态卡住了
   ```
5. 对比修复前后：在 runner 里用环境变量开关补丁（`GetEnvironmentVariableW(L"NO_FIX", nullptr, 0) == 0` 时才走新代码），同一个 exe 跑两遍。
6. 用完删掉演示工程，只结束自己启动的进程。

### 窗口材质探针（毛玻璃 / 云母、启动帧、拖动）

改了窗口材质（`window_backdrop.dart`）或启动顺序时用。比 `capture.ps1` 多三样：窗口后面垫一张红绿竖条卡片，能分出「透出后面的窗口」「模糊了没有」；从窗口第一帧开始连续取样；能按步骤切材质、改参数、按主题按钮、键盘移动窗口。

1. 演示工程同上（壳子模板 + runner 补丁）。复制 `templates/real_window/backdrop_probe_driver.dart` 到 `lib/`，`main.dart` 的 `runApp(...)` 之后加 `runBackdropProbeDriver();`。驱动经 `ShellSettings` 改设置（与设置页同一条路径），主题按钮通过 `AppThemeScope` 按。
2. `flutter build windows --debug`。
3. `powershell -NoProfile -File templates/real_window/backdrop_probe.ps1 -Exe <演示 exe>`，可加 `-Steps "shot:a;material:acrylic;acrylic:opacity=30,persist=false;shot:b;theme;shot:c;move;material:mica;shot:d"`、`-WindowsBuild 19045`（在 Windows 11 上走 Windows 10 的分支：云母不可用、拖动换普通模糊）。输出在 `%TEMP%\backdrop_probe_out`。
4. 看 `capture.log`。每行在标题栏（启动卡片则是卡片上方）的空白横条上量红绿条纹的交界：
   ```
   t0045ms  splash fg=True  split= 26 edge=46px ...   ← 毛玻璃：透出条纹（split 大）且模糊（edge 宽）
   start    main   fg=True  split=  0 edge=n/a  ...   ← 云母：只取壁纸色，不透出后面的窗口
   ...      main   fg=True  split=  8 edge=102px l=#030903 r=#0B0303   ← 普通模糊在 Windows 11 上是黑的
   ```
   `split` 是两侧红色通道差，≥ 10 说明透出后面的窗口；`edge` 是交界 10%–90% 的宽度，≤ 4px 是「透明但没模糊」，≥ 20px 是模糊了。启动阶段每 100ms 一行（`t0045ms` 等），每 4 行存一张 PNG。
5. 初始材质要测「上次保存的值」时跑两遍：第一遍用 `material:acrylic` 改设置（会写进演示工程的 `shell_settings.json`），第二遍看启动帧。

来历：WindBellEcho 1.0.2 做毛玻璃时用同样的方法（条纹卡片、启动帧取样、键盘移动）在真窗口上验证过；整理成这两个模板后，驱动在演示工程里编译通过，`split` / `edge` 的算法用当时的截图离线核对过，整个脚本还没有从头到尾跑过一遍，第一次用时留意。

注意：

- 条纹卡片铺满主屏工作区（不置顶），跑的几十秒里会挡住其他窗口；`move` 步骤会把光标临时移到窗口上，结束后放回。
- `move` 只往演示窗口发消息（`WM_SYSCOMMAND SC_MOVE` + 方向键 + 回车），不会把按键发给别的程序。
- 输出目录里有标记文件才会被清空：曾因默认输出目录与演示工程同名，开跑时把演示工程删了。`-Out` 不要指向工程目录。

脚本里处理过的坑：

- 后台进程调 `SetForegroundWindow` 会被前台锁静默拒绝 → `AttachThreadInput` 到前台线程再激活；恢复窗口前由脚本自己的小窗口占住前台并 `AllowSetForegroundWindow(pid)`，等同用户点托盘图标时系统给的前台权限。不这么做，「恢复后」那一步窗口根本不在前台，结论不可信。
- 切走用脚本自己的 40×40 置顶小窗口（左上角），不会挡住取样区域；不要切到别的应用，它可能盖住被测窗口。
- 坐标：先设 Per-Monitor DPI 感知，窗口范围用 `DWMWA_EXTENDED_FRAME_BOUNDS`（`GetWindowRect` 含不可见的缩放边框），取样区域按 `GetDpiForWindow / 96` 从逻辑像素换算。
- 取样区域选空白处（侧栏瓦片之间、标题栏中段），避开文字和图标；每步截图前等 700ms，让 DWM 的过渡做完。
