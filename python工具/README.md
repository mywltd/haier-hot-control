# Python 调试工具

`haier_heat_ctl.py` 提供海尔智家 U+ 云接口的命令行调试，`mitm_haier_capture.py` 是 mitmproxy 插件。建议使用 Python 3.10 或更新版本。

## CLI

从本目录运行：

```powershell
python -m pip install websocket-client
python haier_heat_ctl.py --help
python haier_heat_ctl.py login --phone 你的手机号 --password 你的密码
python haier_heat_ctl.py devices
python haier_heat_ctl.py status '设备名称或ID'
python haier_heat_ctl.py attrs '设备名称或ID'
```

CLI 已内置与 Flutter 相同的固定签名参数，无需先设置环境变量。如需覆盖，可设置 `HAIER_APP_ID` / `HAIER_APP_KEY`，或读取 Flutter 的本地覆盖文件：

```powershell
$haierConfig = Get-Content ../haier_flutter/config/haier.local.json -Raw | ConvertFrom-Json
$env:HAIER_APP_ID = $haierConfig.HAIER_APP_ID
$env:HAIER_APP_KEY = $haierConfig.HAIER_APP_KEY
```

控制命令会直接作用于选中的真实设备：

```powershell
python haier_heat_ctl.py on '设备名称或ID'
python haier_heat_ctl.py set-temp '设备名称或ID' 45
python haier_heat_ctl.py off '设备名称或ID'
python haier_heat_ctl.py logout
```

会话保存到本目录的 `haier_session.json`，包含手机号和访问令牌，已被 Git 忽略。命令行登录参数可能出现在终端历史中。此 CLI 保留原始调试实现，其 HTTP 请求关闭了证书校验，使用前应了解这一限制。

## 抓包插件

```powershell
python -m pip install mitmproxy
mitmdump -s mitm_haier_capture.py
```

需要自行完成测试设备的代理和证书配置。插件会将匹配到的海尔接口请求、响应与令牌写入当前目录下的 `haier_captures/`。这些文件可能包含账号、密码、设备标识和 token，已加入忽略规则，仅保留在本地。
