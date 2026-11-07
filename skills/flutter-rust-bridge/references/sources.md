# 来源与版本边界

核对日期：**2026-11-04（Asia/Shanghai）**。本技能是任务指南与源码索引，不是官方文档镜像。

## 采用的基线

- 稳定版：`flutter_rust_bridge` **2.13.0**。核对了 pub.dev 的包信息、crates.io 元数据和上游标签中的 Cargo/pubspec。
- 上游标签：`v2.13.0`，提交 **`8631db91a90c699439c9ce2a1fb4164ae8661da9`**。
- 当日主分支与 crates.io 的新版本元数据已出现 `2.14.0-beta.2`。本技能没有把其行为作为稳定版能力，也不建议现有项目自动切到预发布版。
- 阅读范围：README/Quickstart、集成方式、类型/函数/并发、生命周期、第三方 crate、traits、配置与定制、排错/测试/升级，以及生成器、Rust/Dart runtime、hooks 和代表性示例。不是对所有上游文件逐行审计，也不代表所有平台实测。

## 官方阅读入口

| 主题 | 来源 |
|---|---|
| 项目介绍 | [官方网站](https://cjycode.com/flutter_rust_bridge/) · [标签 README](https://github.com/fzyzcjy/flutter_rust_bridge/blob/v2.13.0/README.md) |
| 发布版本 | [pub.dev](https://pub.dev/packages/flutter_rust_bridge) · [crates.io](https://crates.io/crates/flutter_rust_bridge) · [v2.13.0 release](https://github.com/fzyzcjy/flutter_rust_bridge/releases/tag/v2.13.0) |
| 最短接入流程 | [Quickstart](https://cjycode.com/flutter_rust_bridge/quickstart) |
| 集成方案 | [Overview](https://cjycode.com/flutter_rust_bridge/manual/integrate/overview) · [内置命令](https://cjycode.com/flutter_rust_bridge/manual/integrate/builtin) |
| 构建后端 | [Cargokit](https://cjycode.com/flutter_rust_bridge/manual/integrate/cargokit) · [Native Assets](https://cjycode.com/flutter_rust_bridge/manual/integrate/native-assets) · [后端迁移](https://cjycode.com/flutter_rust_bridge/manual/integrate/migrate-cargokit-to-native-assets) |
| 参数 | [配置输入](https://cjycode.com/flutter_rust_bridge/guides/custom/codegen/inputs) · [完整属性列表](https://cjycode.com/flutter_rust_bridge/guides/custom/attributes/full-list) |
| 数据与类型 | [类型概览](https://cjycode.com/flutter_rust_bridge/guides/types/overview) · [类型对应](https://cjycode.com/flutter_rust_bridge/guides/types/translatable/simple-correspondence) · [错误](https://cjycode.com/flutter_rust_bridge/guides/types/translatable/return) |
| 对象身份 | [RustAutoOpaque](https://cjycode.com/flutter_rust_bridge/guides/types/arbitrary/rust-auto-opaque) |
| 并发与回调 | [并发模式](https://cjycode.com/flutter_rust_bridge/guides/concurrency/overview) · [Rust 调用 Dart](https://cjycode.com/flutter_rust_bridge/guides/direction/rust-call-dart) |
| 生命周期 | [Stream](https://cjycode.com/flutter_rust_bridge/guides/types/translatable/stream) · [初始化](https://cjycode.com/flutter_rust_bridge/guides/how-to/init) · [取消](https://cjycode.com/flutter_rust_bridge/guides/how-to/cancel) |
| 进阶 | [第三方 crate](https://cjycode.com/flutter_rust_bridge/guides/third-party/overview) · [Traits](https://cjycode.com/flutter_rust_bridge/guides/traits/overview) · [Lifetimes](https://cjycode.com/flutter_rust_bridge/guides/lifetimes/overview) · [Codec](https://cjycode.com/flutter_rust_bridge/guides/miscellaneous/codec) |
| 平台与加载 | [Cargo workspace](https://cjycode.com/flutter_rust_bridge/guides/how-to/cargo-workspaces) · [自定义加载](https://cjycode.com/flutter_rust_bridge/guides/how-to/load-library) · [Web 跨源隔离](https://cjycode.com/flutter_rust_bridge/guides/how-to/cross-origin) |
| 测试与维护 | [测试](https://cjycode.com/flutter_rust_bridge/guides/how-to/test) · [升级](https://cjycode.com/flutter_rust_bridge/guides/miscellaneous/upgrade/regular) · [排错](https://cjycode.com/flutter_rust_bridge/manual/troubleshooting) |
| 上游架构 | [贡献者总览](https://cjycode.com/flutter_rust_bridge/guides/contributing/overview) · [标签文档目录](https://github.com/fzyzcjy/flutter_rust_bridge/tree/v2.13.0/website/docs) |

在线站点会更新；复查旧项目时使用对应标签的 `website/docs`，路径中的章节编号在网站 URL 中通常被省略。

## 文档需要结合源码判断的地方

| 事项 | 本技能采用的证据 |
|---|---|
| full_dep=false 的真实 codec 默认值 | [内部配置解析](https://github.com/fzyzcjy/flutter_rust_bridge/blob/v2.13.0/frb_codegen/src/library/codegen/config/internal_config_parser/mod.rs)，及 `generator/codec/structs.rs` / `frb_dart/lib/src/codec/pde.dart` |
| CLI 与配置文件的优先级 | [commands_parser.rs](https://github.com/fzyzcjy/flutter_rust_bridge/blob/v2.13.0/frb_codegen/src/binary/commands_parser.rs) 的合并逻辑与测试 |
| integrate 修改入口，no-write-lib 跳过范围 | [overlay.rs](https://github.com/fzyzcjy/flutter_rust_bridge/blob/v2.13.0/frb_codegen/src/library/integration/integrator/overlay.rs) |
| generate 自动调整依赖 | [auto_upgrade.rs](https://github.com/fzyzcjy/flutter_rust_bridge/blob/v2.13.0/frb_codegen/src/library/codegen/polisher/auto_upgrade.rs) |
| 真正不加载 FFI 的 mock 初始化 | [entrypoint.dart](https://github.com/fzyzcjy/flutter_rust_bridge/blob/v2.13.0/frb_dart/lib/src/main_components/entrypoint.dart) 与 [生成入口示例](https://github.com/fzyzcjy/flutter_rust_bridge/blob/v2.13.0/frb_example/flutter_via_create/lib/src/rust/frb_generated.dart) |
| Native Assets 的实际配置 | [hooks 包](https://github.com/fzyzcjy/flutter_rust_bridge/tree/v2.13.0/frb_hooks) 与 [完整示例](https://github.com/fzyzcjy/flutter_rust_bridge/tree/v2.13.0/frb_example/flutter_via_create_native_assets) |

## 后续更新方法

先确认任务项目的版本，再查发布信息。需要更新本技能时，在独立目录取相应标签，比较 CLI/config、默认值、模板、运行时检查和相关测试；不要只更新文中的版本号。

复核一次正常异步调用、错误映射、Stream 结束、opaque 释放、mock 与实际库装载；涉及后端变化时验证对应模板。把实际验证平台与未验证范围写入当次交付。修改记录在项目正常版本控制中维护，不另建重复的技能 changelog。
