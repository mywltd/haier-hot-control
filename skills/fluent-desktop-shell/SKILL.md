---
name: fluent-desktop-shell
description: 用现成模板给 Flutter Windows 桌面应用搭一套 Windows 11 Fluent 外壳：云母窗口（Windows 10 自动改用毛玻璃，Windows 11 可在设置里切换，毛玻璃可调色调和不透明度）、48 高标题栏、Store 式侧栏（拉伸指示条）、切页过渡、启动卡片、失焦变暗（含托盘恢复后的云母）、主题切换、托盘与开机自启、关闭确认、设置页。在新建 Windows 桌面应用、或要把现有 Flutter 桌面应用改成这套样式时使用。
---

# Fluent 桌面外壳

模板在 `templates/`，按「风铃·回响（WindBellEcho）」1.1.0+5 核对，去掉了业务代码。需按下面步骤配置依赖、应用身份和 runner，再验证编译与测试。
界面规范（尺寸、颜色、组件取舍、坑）见 `fluent-desktop-design`，写页面前先看。

## 模板里有什么

```
templates/
  lib/main.dart                 启动：窗口设成启动卡片 → 读本地设置 → runApp(App(startup: ...))
  lib/app/
    app.dart                    FluentApp、主题、启动卡片 → 主界面
    theme.dart                  kAppTitle、字体、type ramp（大字常规体）、AppThemeController（跟随系统 ⇄ 相反模式）
    window_bootstrap.dart       启动卡片 / 主窗口大小与居中
    window_backdrop.dart        窗口材质：系统版本检测、设置 → 方案（planBackdrop）、云母交给 flutter_acrylic、毛玻璃走 FFI、
                                请求排队（只下最新的，失败下次重试）、Windows 10 拖动时临时换普通模糊、
                                系统关了透明效果 / 开了高对比度时改铺纯色（backdropOpaque、BackdropPlan.fill）
    window_material.dart        WindowMaterial / AcrylicBlur / AcrylicOptions（纯数据，可读写 JSON）
    window_activity.dart        focus / blur → 失焦时标题变灰（云母变暗由 DWM 做，要配 runner 补丁）
    splash_view.dart            启动卡片内容
    desktop_session.dart        托盘、关闭到托盘、退出、开机自启；onQuit 钩子
    shell_settings.dart         壳子设置：关闭行为、主题、窗口材质与毛玻璃参数（shell_settings.json）
    launch_at_startup.dart      HKCU Run 注册表
    dwm_corners.dart            Windows 11 圆角
  lib/shell/
    app_shell.dart              NavigationView + 标题栏 + 页面列表（在这里加页面）
    nav_sidebar.dart            自绘侧栏：瓦片三态、拉伸指示条、主体内容层
    page_switcher.dart          切页过渡（每页独立滚动控制器）
    close_prompt.dart           关闭确认弹窗（可记住选择）
  lib/widgets/                  SettingsCard / SettingsExpander / PageBody / PageWidth / StatTile / NameText / showToast / ErrorBanner
  lib/pages/                    示例：首页、列表、设置（外观：窗口材质 + 毛玻璃参数）
  assets/app_icon.ico           占位图标（换成自己的）
  test/shell_test.dart          960×640 下侧栏、切页、设置页的冒烟测试；Windows 10 / 11 的材质选项
```

## 新建应用

1. **建项目**：`flutter create --platforms=windows --org com.example <app_name>`。
2. **依赖**（核对环境 Flutter 3.47.0 / Dart 3.13.0，与 WindBellEcho 的依赖约束一致；升级版本后需重新验证）：
   ```yaml
   dependencies:
     fluent_ui: ^4.16.1
     window_manager: ^0.5.2
     flutter_acrylic: ^1.1.4
     tray_manager: ^0.5.3
     win32_registry: ^3.0.3
     screen_retriever: 0.2.2
     path_provider: ^2.1.6
     ffi: ^2.2.0
     win32: ^6.4.0
   flutter:
     uses-material-design: true # fluent_ui 依赖的图标字体；页面仍使用 Fluent 组件。
     assets:
       - assets/app_icon.ico
   ```
3. **复制模板**：把 `templates/lib`、`templates/assets`、`templates/test` 复制进项目（覆盖 `lib/main.dart`）。`test/shell_test.dart` 里的 `your_app` 换成 pubspec 的 `name`；新建工程默认的计数器测试 `test/widget_test.dart` 要替换或删除，避免继续引用旧的 `MyApp`。现有业务测试保留。
4. **改身份**：
   - `lib/app/theme.dart` 的 `kAppTitle`（标题栏、托盘、启动卡片）；
   - `lib/app/launch_at_startup.dart` 的 `_valueName`（英文名）；
   - `assets/app_icon.ico` 和 `windows/runner/resources/app_icon.ico` 换成应用图标（ico 里放 16–256 多尺寸）；
   - Windows 原生部分按 [references/windows-runner.md](references/windows-runner.md) 改：**必须关 Impeller**（否则没有云母），**必须把 `WM_NCACTIVATE` 交给 `DefWindowProc`**（否则失焦不变暗，从托盘恢复后云母消失），**必须拦下 `WM_DWMCOLORIZATIONCOLORCHANGED`**（否则改了强调色后深色边框跟着系统走，和应用主题对不上）。
5. **验证**：`flutter pub get` → `flutter analyze`（应无告警）→ `flutter test` → 用 `flutter-ui-screenshots` 截亮 / 暗两套图看效果；改过 runner 的，再用它的「真窗口取色」确认失焦、托盘恢复后的云母；动过窗口材质的，用同一 skill 的「窗口材质探针」看毛玻璃是否透出、是否模糊（`-WindowsBuild 19045` 走 Windows 10 分支）。
6. **打包**：用 `flutter-windows-installer`。

## 改造现有应用

逐个替换而不是整包覆盖：先接 `window_bootstrap` + `app.dart` + runner 补丁（主题、云母、失焦），再换 `app_shell` + `nav_sidebar` + `page_switcher`，最后把旧页面改成 `ScaffoldPage(header: PageWidth(PageHeader), content: PageBody)`。每步跑一次测试和截图。

## 接业务

| 需求 | 改哪里 |
|------|--------|
| 加页面 | `app_shell.dart`：`ShellPage` 下标 + `_pages` 一项；设置页保持最后（在侧栏底部） |
| 启动时登录 / 连接 | `main.dart` 的 `_startup()`；启动卡片最多等 3 秒，之后在后台继续，首页显示「连接中」 |
| 退出前停服务、写盘 | `DesktopSession.maybeInstance?.onQuit = () async { ... }`；`ShellSettings` 的预览改动由 `quit()` 自己 `flush()` |
| 业务设置 | 另建自己的设置存储；页面放进 `SettingsPage` 前面的分组；**不要**塞进 `ShellSettings` |
| 账号密码 | 用 `fluent-desktop-design/templates/secret_box.dart`（DPAPI）加密后再写盘 |
| 窗口大小 | `window_bootstrap.dart` 的 `kSplashSize` / `kMainWindowSize` / `kMainWindowMinSize` |
| 关闭行为 | `ShellSettings.closeAction`；设置页已有「关闭主窗口时」下拉 |
| 窗口材质 | `ShellSettings.windowMaterial` / `acrylic`；设置页「外观」已有。Windows 10 没有云母，下拉框禁用、固定毛玻璃；毛玻璃默认色调取窗口底色（浅 #F3F3F3 / 深 #202020）、不透明度 75，在 `window_material.dart` 改 |
| 业务设置放在自己的存储里、又要用材质 | 把 `windowMaterial` / `acrylic` 两个字段、`setAcrylic(persist:)` 和 `flush()` 搬过去，`App` 的 `_planFor` / `_backdropInputs` 改读那份设置，退出时调它的 `flush()`（WindBellEcho 放在 `AppSettings`） |
| 测试里看窗口材质下发了什么 | `debugBackdropApplier` 换掉真正的下发，`debugWindowsBuildOverride`、`debugBackdropOpaqueOverride` 模拟系统；widget 测试开头先 `debugResetBackdrop()`（见 `fluent-desktop-design` 的 pitfalls） |

回同步模板时只带通用实现：本项目的 `lib/core/store/window_material.dart` 在模板里放于 `lib/app/window_material.dart`，需要调整导入；`AppContext`、`AppSettings` 和转盘 / 直播服务不能直接复制进壳子。模板用 `ShellSettings`、`onQuit` 接入这些能力；侧栏示例仍为「首页 / 列表 / 设置」。

## 不要做

- 在 `runApp` 之前调用 `windowManager.show()`：窗口会先在左上角露出空白。
- 把窗口材质挪到 `runApp` 之前（窗口显示前）设：启动卡片的毛玻璃不模糊、窗口拿不到焦点。保持在 `App` 的第一帧之后设。
- 毛玻璃改用 `flutter_acrylic` 的 `WindowEffect.acrylic`：Windows 11 22H2 起它换成系统材质，色调、不透明度都不生效；`WindowEffect.aero`（普通模糊）在 Windows 11 上是黑的。
- 在 `App` 里按「上次请求的方案」去重：下发失败一次就再也不发。去重交给 `applyBackdrop`（对比已生效的）。
- 去掉 `App` 里那层 `ColoredBox`：系统关了透明效果时，毛玻璃靠它显示纯色。它平时是透明的，不挡云母。
- 在窗口隐藏时改大小：Flutter 停止出帧，拿不到新尺寸的画面。
- 给 `PaneItem` 设 `title`；用 NavigationView 自带的 compact 侧栏代替自绘侧栏（选中样式、指示条动画都做不出来）。
- 改 `Runner.rc` 的 CompanyName / ProductName 而不迁移数据：应用数据目录会变。
