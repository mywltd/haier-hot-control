---
name: flutter-rust-bridge
description: 使用 flutter_rust_bridge（FRB）连接 Flutter/Dart 与 Rust。用于新建或接入 Rust、设计跨语言 API、生成绑定、处理异步与资源生命周期、构建发布、迁移版本和排查 FFI 问题，也用于阅读或修改 FRB 源码；纯 Flutter UI 或不使用 FRB 的普通 FFI 任务不适用。
---

# Flutter Rust Bridge

将普通 Rust API 暴露给 Dart，并保持生成代码、运行时和原生库一致。优先沿用目标项目的目录、构建后端和已锁定版本。

本技能于 **2026-11-04** 核对官方教程与 **v2.13.0** 源码，提交为 `8631db91a90c699439c9ce2a1fb4164ae8661da9`。这是可复查的知识基线，不代表以后使用时的最新版。在线文档与主分支可能先于项目依赖变化；遇到差异，查目标版本的配置解析、生成产物和测试。[来源与更新方法](references/sources.md)。

## 开始工作

1. 读取目标仓库约定、`git status`、`pubspec.yaml` / `pubspec.lock`、Rust crate 与 workspace 的 `Cargo.toml` / `Cargo.lock`、`flutter_rust_bridge.yaml`、`rust-toolchain.toml`。没有 FRB 时，再按任务选择接入方式。
2. 核对 `flutter_rust_bridge_codegen --version`、Dart 包与 Rust crate 的 FRB 版本，以及生成文件头的版本。检查 Flutter/Dart、Rust 和实际目标平台；不因为本技能基线较新就升级旧项目。
3. 区分两件事：`generate` 负责跨语言绑定；Cargokit、Native Assets 或自定义构建负责编译和打包 Rust。生成成功不能证明 DLL、so、dylib 或 WASM 已更新。
4. 按下面的任务入口只读相关参考页，完成实现，再验证生成、语言层逻辑和实际装载路径。

## 按任务读取

| 当前任务 | 参考页 |
|---|---|
| 了解适用场景，新建、接入现有应用，选择构建后端，Windows / Web / workspace | [接入与构建](references/setup-and-build.md) |
| 函数、结构体、枚举、错误、opaque 对象，Rust 与 Dart 类型映射 | [API 与类型](references/api-and-types.md) |
| Future、同步调用、Rust async、Stream、取消、回调、初始化与释放 | [并发与生命周期](references/async-and-lifecycle.md) |
| 第三方 crate、trait、生命周期、codec、性能与定制 | [进阶选择](references/advanced.md) |
| 阅读或修改生成器、运行时，定位调用链和测试 | [源码导览](references/source-map.md) |
| 生成缺失、版本不一致、库加载失败、测试、升级 | [排错与验证](references/troubleshooting.md) |

## 实施时保持的约束

- 修改 Rust API 和配置，再重新生成；不要手修 `frb_generated*`、生成的 `api/*.dart`、`.freezed.dart` 或 `.g.dart`。检查生成差异是否包含预期接口。
- 给现有应用接入前先读 [接入注意事项](references/setup-and-build.md#现有应用)。v2.13.0 的 `integrate` 会把旧入口注释后写入示例入口；`--no-write-lib` 又会跳过 Rust 源码和 FRB 配置等文件，不能视作完整接入的一键开关。
- 代码生成默认允许自动调整 FRB 依赖。普通维护先选与锁文件匹配的 codegen；需要保持版本时使用 `auto_upgrade_dependency: false`。版本不匹配仍应修复，不靠关闭版本检查解决。
- 普通 Rust `fn` 默认生成 Dart `Future`，通常已在 Rust 线程池执行。`#[frb(sync)]` 会阻塞调用方，只用于短小、有明确耗时上界的工作。
- 资源密集对象保留在 Rust，用 opaque 句柄与窄 API 操作；明确所有权、关闭时机和取消协议。丢弃 Future 或取消 Dart 订阅不能代替 Rust 任务的停止逻辑。
- 保留项目现有 UI 框架、启动流程、测试隔离和平台范围。官方示例的 Material 页面、全平台脚手架和 `flutter run` 命令只是示例，不覆盖目标仓库约定。

## 完成标准

先满足目标仓库要求，再按改动覆盖：Rust 逻辑测试、Dart/Flutter 分析与测试、绑定重新生成、目标平台构建和真实桥接冒烟测试。纯 Dart mock 只证明上层行为，不能证明 FFI 能加载；详见 [验证层次](references/troubleshooting.md#验证层次)。

交付时说明采用的 FRB 版本、构建后端、手写与生成文件的变化、已执行检查，以及没有验证的平台。只做资料整理或源码解释时，无需改动应用依赖或启动真实应用。
