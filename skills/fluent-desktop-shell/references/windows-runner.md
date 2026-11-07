# Windows 原生部分（windows/）

`flutter create` 生成的 runner 每个 Flutter 版本略有不同，所以这里只给要改的几处，不提供整文件替换。C++ 注释只用 ASCII（MSVC 代码页 936 会对中文注释报 C4819）。改完 C++ 必须完整重新构建，热重载无效。

## 1. 关 Impeller（必须）

`windows/runner/main.cpp`，在 `flutter::DartProject project(L"data");` 之后：

```cpp
// Impeller paints an opaque surface that hides Mica; keep Skia on Windows.
project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);
```

不关的话云母和毛玻璃都会被不透明底挡住。

毛玻璃（`window_backdrop.dart` 用 `SetWindowCompositionAttribute`）不需要再改 runner：它和云母共用这里的 Impeller 开关和下面的 `WM_NCACTIVATE` 补丁。

## 2. 云母跟随激活状态（必须）

`windows/runner/flutter_window.cpp` 的 `MessageHandler`，插件处理过消息后的分支里：

```cpp
    if (result) {
      // window_manager swallows WM_NCACTIVATE when the title bar is hidden, so
      // DWM never sees activation changes: Mica does not dim on blur, and after
      // hide-to-tray it stays in the inactive (solid) state for good. Let
      // DefWindowProc record the new state; lParam -1 skips the non-client
      // repaint. The focus / blur events have already been emitted.
      if (message == WM_NCACTIVATE) {
        return DefWindowProc(hwnd, message, wparam, -1);
      }
      return *result;
    }
```

原因：`TitleBarStyle.hidden`（或无边框）时 window_manager 收到 `WM_NCACTIVATE` 只发 focus / blur 事件，然后 `return 1`，不交给 `DefWindowProc`。不打补丁的表现：

- 失焦后云母不变暗（DWM 一直当窗口是激活的）；
- 隐藏到托盘再恢复后，云母变成失焦的纯色，点回窗口也不恢复（隐藏时 DWM 记成了失焦，之后的激活都被吞掉）。

打了补丁后由 DWM 自己在云母和纯色（浅 #F3F3F3 / 深 #202020）之间过渡，与系统窗口一致。只放在 `if (result)` 分支里：插件没处理时消息本来就会走到 `DefWindowProc`，不影响有系统标题栏的窗口。`lParam = -1` 让 `DefWindowProc` 不重画非客户区，自绘标题栏不会闪出系统标题栏。

这是原生行为，widget 测试测不到，改完用 `flutter-ui-screenshots` 的「真窗口取色」在演示工程里验证。

## 2b. 深色边框只由应用主题决定（必须）

同一个 `MessageHandler`，插件分支之后的 `switch` 里：

```cpp
    // Win32Window answers this (accent color or transparency changed) by
    // resetting DWMWA_USE_IMMERSIVE_DARK_MODE to the system theme. The Dart
    // side sets it from the app theme, which can differ (light app on a dark
    // system), so the frame and Mica tint would flip. Leave it to Dart.
    case WM_DWMCOLORIZATIONCOLORCHANGED:
      return 0;
```

原因：模板的 `Win32Window::MessageHandler` 收到这条消息（用户改了强调色或「透明效果」）就调 `UpdateTheme`，按系统的亮 / 暗重设 `DWMWA_USE_IMMERSIVE_DARK_MODE`。应用主题和系统不一致时（比如系统深色、应用选了浅色），边框和云母的底色会跟着变错，直到下次切主题。Dart 侧在 `window_backdrop.dart` 里按应用主题设这个属性，runner 不要再碰。窗口创建时那一次 `UpdateTheme` 留着：第一帧之后 Dart 就会改成应用主题。

只编译验证过（`flutter build windows`），没在真窗口上复现过原问题；验证方法：应用选浅色、系统深色，打开 Windows 设置改强调色，看边框和云母底色是否保持浅色。

## 3. 窗口标题

`main.cpp` 里 `window.Create(L"<应用名>", origin, size)`。原点 / 尺寸无所谓：Dart 侧在第一帧前会改成屏幕中央的启动卡片。**不要删** `flutter_window.cpp` 里 `SetNextFrameCallback` 的 `this->Show()`：窗口就靠它在第一帧画好后才显示。

## 4. 单实例（推荐）

托盘应用重复启动时应激活已有窗口，而不是再开一个。在 `main.cpp` 的 `wWinMain` 开头、创建窗口前：

```cpp
constexpr wchar_t kMutexName[] = L"Local\\<EnglishName>.SingleInstance.Mutex";

HANDLE mutex = CreateMutexW(nullptr, TRUE, kMutexName);
if (mutex != nullptr && GetLastError() == ERROR_ALREADY_EXISTS) {
  CloseHandle(mutex);
  // Find the existing top-level window of the same exe and bring it to front:
  // EnumWindows + QueryFullProcessImageNameW, then ShowWindow(SW_RESTORE) + SetForegroundWindow.
  return EXIT_SUCCESS;
}
```

窗口被藏到托盘时 `ShowWindow` 无法让它出现（任务栏按钮也被隐藏了），所以再注册一个窗口消息让已有实例自己恢复：

```cpp
// main.cpp：PostMessageW(hwnd, RegisterWindowMessageW(L"<EnglishName>.ShowExistingInstance"), 0, 0);
// flutter_window.cpp 的 MessageHandler 开头：收到这个消息就 ShowWindow(SW_SHOW) + SetForegroundWindow。
```

完整实现可参考 WindBellEcho 的 `windows/runner/main.cpp` 与 `flutter_window.cpp`（`FindExistingWindow`、`ActivateExistingInstance`）。

## 5. 版本信息与可执行文件名

- `windows/CMakeLists.txt`：`project(<EnglishName> LANGUAGES CXX)`、`set(BINARY_NAME "<EnglishName>")` → 生成 `<EnglishName>.exe`。
- `windows/runner/Runner.rc`：
  - `FileDescription`、`ProductName`：中文名（任务管理器、属性里显示）；
  - `InternalName`、`OriginalFilename`：英文名 / `<EnglishName>.exe`；
  - `CompanyName`：发布者。
- **`CompanyName` + `ProductName` 决定应用数据目录** `%APPDATA%\<CompanyName>\<ProductName>`（path_provider）。发布后不要再改；要改就在启动时从旧目录复制缺失文件（只复制、不删除、不覆盖）。
- 版本号来自 `pubspec.yaml` 的 `version: x.y.z+n`，构建时自动写入 `FILEVERSION`。

## 6. 图标

`windows/runner/resources/app_icon.ico`：exe、任务栏、安装包图标。ico 里放 16 / 32 / 48 / 64 / 128 / 256 多个尺寸。Dart 侧的标题栏、托盘、启动卡片用 `assets/app_icon.ico`（可以是同一个文件）。
