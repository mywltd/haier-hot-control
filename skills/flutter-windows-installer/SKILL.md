---
name: flutter-windows-installer
description: 用 Inno Setup 6 给 Flutter Windows 桌面应用打安装包：按用户安装（不需要管理员）、可选安装位置（默认 D 盘）、覆盖升级与换目录升级、升级时关闭旧进程、改名后的目录 / exe / 开机自启 / 快捷方式迁移、安全卸载。在要发布新版本、出安装包、或修改安装脚本时使用。
---

# Windows 安装包

模板在 `templates/`：`setup.iss`（安装脚本）和 `build.ps1`（读版本 → Release 构建 → 编译安装包），已与 WindBellEcho 1.1.0+5 的打包脚本核对。`setup.iss` 中的 1.0.1 是直接调用 ISCC 时的缺省值；正常构建由 pubspec 传入版本。

复用到新应用时，替换应用名、发布者、exe 名、输出文件名、自启项、默认目录及旧目录名判断，**为新应用生成自己的 AppId**；维护 WindBellEcho 时保留原 AppId。没有改名历史时一并移除 `Legacy*` 引用、旧快捷方式和旧路径分支，不能只删定义。放到项目的 `windows/packaging/`。

## 前提

- Inno Setup 6（`ISCC.exe`，常见路径 `C:\Program Files (x86)\Inno Setup 6\` 或 `D:\Program Files (x86)\Inno Setup 6\`）；`build.ps1` 顶部的 `$flutter`、`$iscc` 改成本机路径。
- 两个脚本都含中文，**必须存成 UTF-8 带 BOM**：PowerShell 5.1 和 Inno Setup 遇到不带 BOM 的文件会按 GBK 读，中文乱码或解析失败。用 Write 工具写完后补 BOM：
  ```bash
  python -c "import sys;p=sys.argv[1];b=open(p,'rb').read();open(p,'wb').write(b if b.startswith(b'\xef\xbb\xbf') else b'\xef\xbb\xbf'+b)" windows/packaging/setup.iss
  ```

## 发版步骤

1. 改 `pubspec.yaml`：`version: x.y.z+n`，`n` 每次加一（写进 exe 的 FILEVERSION 第四段）。
2. 改了 Dart 包名、exe 名或 CMake 项目名时先 `flutter clean`，避免 Release 目录里遗留的旧 exe 被打进包；完成 `flutter analyze` 和 `flutter test`。
3. 运行 `powershell -NoProfile -File windows/packaging/build.ps1`（RemoteSigned 策略下本地脚本可以直接跑，不需要 `-ExecutionPolicy Bypass`）。
   - 脚本从 pubspec 读出 `x.y.z`，用 `/DMyAppVersion=x.y.z` 传给 ISCC；setup.iss 里的版本只是缺省值。
   - 在 Git Bash 里直接调 ISCC 时 `/D` 会被当成路径改写，**用 PowerShell 调**。
4. 检查产物：`dist/<Name>-Setup-x.y.z.exe` 存在；`(Get-Item build\windows\x64\runner\Release\<Name>.exe).VersionInfo` 版本正确。不要在用户机器上直接运行安装包测试（会改动已装的版本），把测试步骤交给用户。

只改了 setup.iss 时先单独编译检查，不动 `dist/`：`& $iscc "/O$env:TEMP\iss_check" "/DMyAppVersion=x.y.z" windows\packaging\setup.iss`。`[Code]` 里的路径判断、`ExpandConstant` 结果可以写个探针脚本验证：只有 `[Setup]` 最小项 + 要测的函数，在 `InitializeSetup` 里 `Log(...)` 后返回 `False`（什么都不装），用 `probe.exe /VERYSILENT /SUPPRESSMSGBOXES /LOG="probe.log"` 运行后看日志。

## setup.iss 规则

- **`AppId` 永远不变**：它决定是覆盖升级还是装出第二份。新应用用 `[guid]::NewGuid()` 生成一次，写死。`[Code]` 里拼卸载注册表键要 `ExpandConstant('...\{#MyAppId}_is1')`，`{{` 才会变成 `{`。
- `PrivilegesRequired=lowest`：按用户安装，不弹 UAC；开机自启用 HKCU。
- 安装位置：模板沿用 WindBellEcho 的默认策略：`DefaultDirName={code:DefaultInstallDir}`，D 盘是本地固定磁盘（`GetDriveTypeW = 3`）就默认 `D:\<EnglishName>`，否则 `{localappdata}\Programs\<EnglishName>`。这不检查目录写权限，不能保证所有 D 盘都可写；由目录页选择当前用户可写的位置。其他应用可按自己的安装约定调整默认策略。
- `DisableDirPage=no` + `UsePreviousAppDir=yes`：每次都显示目录页，升级时预填上次的目录，用户可以换。默认值 `auto` 在升级时跳过目录页，就没法换位置了。
- 换目录升级：`PrepareToInstall` 读 HKCU 卸载键的 `InstallLocation` / `UninstallString`。模板仅在新旧目录互不包含、旧卸载程序存在，且旧目录末级名为 `WindBellEcho` 或 `EntranceEffect` 时静默卸载；否则跳过，可能留下旧程序。卸载前记下自启项，`ssPostInstall` 写回新路径。当前脚本最多等待旧卸载文件消失 10 秒，未检查卸载退出码，不能据此宣称所有换目录升级都已可靠完成。
- **不要 `[UninstallDelete] filesandordirs {app}`**：用户能自选目录后，选了 `D:\Tools` 这种共用目录，卸载会把里面别的文件一起删掉。Inno 默认只删自己装的文件和变空的目录，够用了。旧版带过这一条的，自动卸载前要确认旧目录名是本程序的。
- `CloseApplications=yes`：Restart Manager 关闭占用 `{app}` 里文件的进程（拦了关闭的托盘程序关不掉，见下）。
- `[Run]` 带 `postinstall skipifsilent`：装完可勾选立即启动。
- `[Registry]` 用 `ValueType: none` + `uninsdeletevalue`：只在卸载时删开机自启项，安装时不写。
- 用户数据在 `%APPDATA%\<CompanyName>\<ProductName>`，安装、卸载、换目录都不碰。

## 托盘程序与改名升级（exe、目录、自启项名换了）

托盘程序拦了关闭（`setPreventClose`），Restart Manager 发的关闭请求只会让它躲进托盘；Restart Manager 也只认 `{app}` 里要被覆盖的文件，改了 exe 名或安装目录后认不出旧进程，旧版的单实例互斥量也不同，新旧两个会同时运行（抢端口）。模板 `[Code]` 段已处理：

- `InitializeWizard`：上次装在旧的默认目录时，改成新默认目录；用户自选的目录不动。
- `PrepareToInstall`：发现旧卸载注册表键时，按新旧 exe 名执行 `taskkill /F /IM`，会匹配所有同名进程；记下自启项，并按上述条件卸载旧版。强制结束不会执行 Dart 的退出 / `flush()` 钩子，尚在预览或等待写盘的改动仍可能丢失；升级前正常退出应用，不能把强杀写成「保证不丢数据」。
- `CurStepChanged(ssPostInstall)`：原来开了自启动的，写回指向新 exe 的值（带引号，与应用自己写的一致），删掉旧名字的值。
- `[InstallDelete]`：删旧名字的开始菜单 / 桌面快捷方式、`{app}` 里旧名字的 exe。

应用侧同样要兜底：开机自启写入时顺手删掉旧名字的值；`Runner.rc` 的 CompanyName / ProductName 变了的话，启动时从旧数据目录复制缺失文件。
