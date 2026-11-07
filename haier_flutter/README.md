# 海尔采暖控制台

仓库介绍、界面预览与首次运行步骤见 [根目录 README](../README.md)，完整协议及维护说明见 [开发说明](../docs/development.md)。

Windows 桌面客户端，使用 Flutter + fluent_ui。按 `fluent-desktop-shell` 对齐：

- 440×320 启动卡片、1280×720 主窗口、960×640 最小尺寸。
- 48 高标题栏、72 宽 Store 式侧栏、拉伸选中指示条和独立滚动的切页过渡。
- 设备 / 控制 / 账号 / 设置四个页面；亮暗主题与系统强调色。
- Windows 11 云母与可调毛玻璃，Windows 10 自动使用毛玻璃；关闭透明效果时使用纯色背景。
- 托盘恢复、关闭确认、记住关闭行为、按用户开机自启动。

未登录时展示明确标记的演示数据；浏览演示设备不访问网络、不写入能耗历史。
登录后替换演示设备。设备卡片的快捷开关只控制该卡片对应的设备。
目标温度先拖动预览，再点击「应用温度」；密码仅用于当前会话，不保存到本地。

## 开发与验证

当前验证环境：Flutter 3.47.9 / Dart 3.13.7，依赖版本见 `pubspec.lock`。

```powershell
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter build windows --release
```

默认运行或构建可浏览演示数据。连接真实设备前，复制 `config/haier.example.json` 为 `config/haier.local.json`，填写签名配置后执行：

```powershell
flutter run -d windows --dart-define-from-file=config/haier.local.json
flutter build windows --release --dart-define-from-file=config/haier.local.json
```

本地签名文件不提交；账号密码在界面输入，令牌仅保留在当前进程内存中。

构建产物为 `build/windows/x64/runner/Release/haier_heat.exe`，运行时需保留整个 Release 目录。

独立运行截图检查：

```powershell
flutter test tool/capture_ui_test.dart --reporter expanded
```

截图位于 `artifacts/ui/`，包括亮暗两套、两种尺寸与 Windows 10/11 材质设置。
截图使用真实系统字体和模拟背景；真实云母、失焦及托盘恢复需使用独立窗口探针验证。
`tool/prepare_window_probe.py` 可复制隔离演示工程：独立应用身份、内存演示数据，不读取真实账号或能耗记录。

## Windows 安装包

已安装 Flutter、Visual Studio C++ 工具链及 Inno Setup 6 后，在本目录运行：

```powershell
flutter analyze
flutter test --reporter expanded
powershell -NoProfile -File windows/packaging/build.ps1
```

脚本默认使用 `config/haier.local.json` 注入接口签名配置；也可传入 `-DartDefineFile <路径>`，仅浏览演示数据时使用 `-Demo`。
构建工具路径可用 `-FlutterPath` 和 `-InnoSetupPath` 覆盖。版本和构建号读取 `pubspec.yaml`，每次发版递增构建号。
产物为 `dist/HaierHeat-Setup-<版本>.exe`，旁边提供 `.sha256` 校验文件。完整 Release 文件和 Visual C++ 运行库随包分发，不包含 PDB 或本地配置 JSON 文件。

安装按当前用户进行，无需管理员权限。D 盘为固定磁盘时默认使用 `D:\HaierHeat`，否则使用 `%LOCALAPPDATA%\Programs\HaierHeat`；可在向导中更换目录。
升级前请从托盘菜单正常退出应用，让正在写入的能耗记录完成保存。同目录支持覆盖升级；从名为 `HaierHeat` 的目录迁往独立目录时，会先检查旧版卸载结果。
旧版使用自定义目录名或新旧目录相互包含时，向导会提示使用原目录升级或先手动卸载，避免交叉删除。
安装不自动开启开机自启动；已经开启的设置会更新到新路径。卸载只删除安装文件、快捷方式及本应用自启动项，保留配置与能耗数据。

`windows/packaging/setup.iss` 的 `AppId` 是固定升级标识；后续发版必须保留。打包脚本与安装脚本使用 UTF-8 BOM。
安装包仅完成编译和静态检查，实际安装、覆盖升级、换目录及卸载可在隔离 Windows 环境中验收。

## 维护入口

- `lib/shell/app_shell.dart`：导航与标题栏，设置始终放在侧栏底部。
- `lib/pages/`：业务页使用 `ScaffoldPage`、`PageWidth`、`PageBody` 与设置卡。
- `lib/app/`：主题、窗口材质、启动、托盘与外壳配置。
- `lib/haier/`：原有云接口、状态和能耗采样；退出前等待能耗写盘完成。
- `assets/app_icon.svg`：采暖图标源；`python tool/render_icon.py` 生成两处多尺寸 ICO（需要 Pillow）。

应用支持目录仍使用 `com.haier.heat/haier_heat`，保留既有配置路径；能耗记录仍位于文档目录的 `haier_energy.json`。
外壳设置与业务数据独立保存。真实海尔账号登录与设备控制需要连接实际设备另行联调。
