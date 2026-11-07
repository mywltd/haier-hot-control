# 开发 Skills 快照

此目录保存了 2026-11-07 本地用户安装的 7 个 skills，包含 `SKILL.md`、模板和参考资料。所有文件均为实际副本，不依赖原机器的符号链接。系统内置和插件缓存中的 skills 未包含在此目录。

| 入口 | 主要内容 | 与当前项目的关系 |
| --- | --- | --- |
| [fluent-desktop-design](fluent-desktop-design/SKILL.md) | Fluent 设计语言、组件、页面配方、常见问题 | 界面维护参考 |
| [fluent-desktop-shell](fluent-desktop-shell/SKILL.md) | Windows 外壳模板、窗口原生通道说明 | 当前桌面外壳的基础 |
| [flutter-ui-screenshots](flutter-ui-screenshots/SKILL.md) | Widget 截图与真实窗口探针 | 预览及窗口验证 |
| [flutter-windows-installer](flutter-windows-installer/SKILL.md) | Inno Setup 脚本和构建模板 | 后续打包参考 |
| [flutter-rust-bridge](flutter-rust-bridge/SKILL.md) | FRB API、生成绑定、构建和排错 | 备用，当前未接入 |
| [shadcn-flutter](shadcn-flutter/SKILL.md) | 组件、主题、布局、图标文档 | 备用，当前使用 fluent_ui |
| [find-skills](find-skills/SKILL.md) | 查找与安装 skills 的工作流 | 开发工具参考 |

## 使用方式

在支持 skills 的开发工具中指定对应 `SKILL.md`，或把所需 skill 的整个文件夹放到该工具配置的 skills 目录中。请连同 `templates/`、`references/`、`guides/` 等子目录一起复制。

这些文件是备份快照，不会随本机原始目录自动更新。模板中的应用名称、包名、路径及示例工程需要按目标项目调整；复制模板前先阅读对应入口说明。原文中的项目背景和第三方引用予以保留。

本项目的截图工具可以直接引用仓库内副本。例如，在 `haier_flutter/` 下准备独立的原生窗口演示工程：

```powershell
python tool/prepare_window_probe.py "$env:TEMP/haier-shell-probe" ../skills/flutter-ui-screenshots
```

目标目录必须尚不存在。窗口探针的后续操作见对应 skill，输出目录不要指向源码目录。
