# 开发与维护说明

本文按当前源码整理，替代原始交接材料中的旧目录说明和个人设备记录。

## 维护入口

| 文件 | 职责 |
| --- | --- |
| `haier_flutter/lib/haier/haier_api.dart` | HTTP、SHA-256 签名、登录、设备模型和 WebSocket 控制 |
| `haier_flutter/lib/haier/haier_state.dart` | 会话、演示设备、状态快照、控制与刷新 |
| `haier_flutter/lib/haier/energy_tracker.dart` | 累计电量采样、今日及每日用电计算、异步落盘 |
| `haier_flutter/lib/pages/` | 设备、控制、账号、设置页 |
| `haier_flutter/lib/shell/` | 自绘侧栏、标题栏、切页和关闭确认 |
| `haier_flutter/lib/app/` | 窗口、主题、托盘、桌面会话和外壳设置 |
| `haier_flutter/windows/runner/` | 原生窗口、材质与桌面事件通道 |
| `haier_flutter/windows/packaging/` | Inno Setup 安装脚本与打包入口 |
| `haier_flutter/tool/` | 截图、独立窗口探针和图标生成 |

## 接口协议

下面描述当前实现，云端接口可能变化；以实际响应为准。

```text
sign = SHA256(path + 去除空白的 JSON body + appId + appKey + 毫秒时间戳)
```

签名输出小写十六进制。当前 Dart 实现对 `Uri.path` 签名，请求头包括 `accessToken`、`appId`、`appKey`、`clientId`、`sequenceId`、`sign`、`timestamp`、`timezone` 和 `language`。

固定的 `HAIER_APP_ID` / `HAIER_APP_KEY` 已写入 Dart、Python 源码和 `config/haier.example.json`，无需额外配置即可登录。Dart 仍支持编译参数覆盖，Python 仍支持环境变量覆盖。本地覆盖文件、账号密码和会话不提交。

固定值与公开参考实现中的 App 来源配置一致：[banto6/haier 的 APP_SOURCES](https://github.com/banto6/haier/blob/b8b98c6e6238ab8b86226d23bf1fd8940a747732/custom_components/haier/core/client.py#L25-L30)、[haier_win11_widgets 的 Sources](https://github.com/xxxifan/haier_win11_widgets/blob/86bb533b89161ee69e4c1e4244b50c66a295e776/HaierWidget/Haier/HaierApi.cs#L61-L65)。上述公开源码中的值已逐字核对；个人账号与访问令牌仍在运行时提供。

| 用途 | 请求 |
| --- | --- |
| 登录 | `POST zj.haier.net/api-gw/oauthserver/account/v1/login` |
| 刷新令牌 | `POST zj.haier.net/api-gw/oauthserver/account/v1/refreshToken` |
| 用户信息 | `GET account-api.haier.net/v2/haier/userinfo` |
| 设备列表 | `GET uws.haier.net/uds/v1/protected/deviceinfos` |
| 设备数字模型 | `POST uws.haier.net/shadow/v1/devdigitalmodels` |
| 网关分配 | `POST uws.haier.net/gmsWS/wsag/assign` |

控制通过网关 WebSocket 的 `BatchCmdReq` 下发，`cmdArgs` 中使用设备属性名与字符串值，例如：

```json
{"onOffStatus": "true"}
```

```json
{"targetTemperature": "45"}
```

常用字段包括 `currentTemperature`、`targetTemperature`、`operationMode`、`runPower`、`energySaved`、`waterFlux` 和 `envTemperature`。不同型号的字段、单位、范围需要逐一核对。

## 状态与本地数据

- 未登录时加载 `DEMO_HEATPUMP_01` / `DEMO_HEATPUMP_02` 两台虚构设备；演示浏览和控制尝试不会访问网络。
- 进入真实会话时清空演示设备与快照，卡片快捷开关使用该卡片自己的设备 ID。
- Flutter 登录令牌仅在内存中保存；退出登录清理会话。Python CLI 使用独立的 `haier_session.json`。
- 能耗数据保存在系统文档目录的 `haier_energy.json`，退出应用前等待待写入操作完成。
- 外壳设置使用应用支持目录，Windows 应用身份仍为 `com.haier.heat/haier_heat`。
- 能耗采样由手动刷新或设备控制后的刷新触发，未实现后台订阅、定时采样和按设备分别记账。

## 界面和原生窗口验证

常规验证在 `haier_flutter/` 下运行：

```powershell
flutter pub get --enforce-lockfile
flutter analyze
flutter test --reporter expanded
flutter test tool/capture_ui_test.dart --reporter expanded
flutter build windows --release
```

截图测试加载 Windows 系统字体，覆盖浅色 / 深色、960×640 / 1280×720，以及 Windows 10/11 材质设置分支。输出在忽略目录 `artifacts/ui/`，README 使用其中选取的脱敏图片副本。

Widget 截图不会展示真实 DWM 材质。原生效果需要使用独立应用身份的演示工程，避免读取真实账号和能耗记录：

```powershell
python tool/prepare_window_probe.py "$env:TEMP/haier-shell-probe" ../skills/flutter-ui-screenshots
```

再按 [截图 skill](../skills/flutter-ui-screenshots/SKILL.md) 的窗口探针步骤检查云母、毛玻璃、失焦、拖动与托盘恢复。在 Windows 11 上模拟 build 19045 仅验证代码分支，不等同于 Windows 10 实机验证。

### 2026-11-07 仓库发布前验证

以下为首次导入仓库时的验证记录，环境为 Flutter 3.47.9 / Dart 3.13.7。之后已按项目约定恢复内置固定签名参数，普通运行和构建不再依赖本地配置文件。

| 检查 | 结果 |
| --- | --- |
| 按锁文件恢复依赖 | 通过，未升级依赖 |
| `flutter analyze` | No issues found |
| `flutter test --reporter expanded` | 10 项全部通过 |
| 截图检查 | 4 组全部通过，生成 24 张截图 |
| Windows Release 构建 | 携带忽略的本地签名配置构建成功；构建产物未入库 |
| Python 工具 | 语法检查、缺少配置时阻止请求、模拟已配置请求均通过 |
| Skills 副本 | 7 个目录逐文件核对，与本地来源一致 |
| 发布内容 | 检查私有字段与常见密钥格式；本地配置、会话、原始交接材料和构建输出均被忽略 |

本次没有发起真实设备登录或控制，也没有重新运行原生窗口探针。README 中两张预览图已人工检查。

提交前合入了工作区新增的安装脚本与 `0.2.0+3` 版本标记，PowerShell 语法检查通过；该安装包的安装、升级和卸载流程不在本轮验证范围内。

### 固定签名参数恢复后的验证

- `flutter analyze` 通过；默认配置下 10 项测试通过，显式空配置测试按条件跳过。
- 使用 `--dart-define=HAIER_APP_KEY=` 单独运行 API 测试，验证演示构建在联网前拒绝登录。
- Dart 与 Python 的固定签名均通过同一参考向量验证；Python 的默认参数、环境变量覆盖和模拟请求检查通过。
- 无需本地配置的 Windows Release 构建成功。原输出目录的运行库被其他进程占用，因此将编译结果复制到独立目录完成 Inno Setup 编译，安装包版本为 `0.2.0.3`；未执行安装。

## 后续工作

- 真实账号登录 → 设备枚举 → 属性读取 → 设备控制的完整联调。
- 核对不同热泵型号的状态字段、单位和模式取值。
- 自动刷新、WebSocket 推送、会话过期后的刷新流程。
- 能耗记录按设备、账号分开，处理切换设备和计量重置。
- Windows 10 实机验证、安装包安装 / 升级 / 卸载验证。

运行 Release 程序时需要保留整个构建输出目录。图标源为 `haier_flutter/assets/app_icon.svg`，`tool/render_icon.py` 可生成 ICO（需要 Pillow）。
