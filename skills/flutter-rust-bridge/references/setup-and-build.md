# 接入与构建

适用于新建、迁移或维护 FRB 工程。版本基线见 [来源](sources.md)；参数以目标版本的 `--help` 和源码为准。

## 先判断边界

FRB 适合在 Flutter 中复用 Rust 库、将计算或长期状态放在 Rust，或为已有 Rust 系统提供 Flutter 界面。它生成语言边界，不自动提供业务层架构、任务取消或平台原生 UI。

| 层次 | 输入与产物 | 主要入口 |
|---|---|---|
| API 与绑定生成 | Rust 模块 → Dart API、Dart/Rust wire 代码 | `flutter_rust_bridge_codegen generate` |
| 原生构建与分发 | Rust crate → 各目标平台库，随应用打包 | Cargokit、Native Assets 或已有构建系统 |
| 运行时初始化 | 装载匹配的库，初始化通信与 Rust 服务 | 生成的 `RustLib.init()` |

先分清当前故障在哪一层。生成代码与编译 Rust 是不同步骤；Flutter 的 Dart 热重载不能替代重新编译 Rust。

## 工具与版本

读取实际 SDK、Rust toolchain、三方锁文件和 codegen 版本。v2.13.0 的 Dart 运行时与 hooks 包声明 Dart `>=3.9.2 <4.0.0`；Native Assets 还需 SDK 支持 build hooks/code assets，不能只凭版本范围判断集成可用。

新项目选择 2.13.0 基线时，可安装固定版本的生成器：

```shell
cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked
flutter_rust_bridge_codegen --version
```

已有项目把版本换成其锁定值。若不适合替换全局生成器，可用 `cargo install ... --root <工具目录>` 安装隔离副本，再通过完整路径调用。`--locked` 控制生成器本身的依赖解析，不会锁定业务项目的全部依赖。

普通应用中的依赖形状如下，具体 features 和其他依赖沿用工程：

```yaml
# pubspec.yaml 的 dependencies 下
flutter_rust_bridge: 2.13.0
```

```toml
# Rust crate 的 Cargo.toml
[lib]
crate-type = ["cdylib", "staticlib"]

[dependencies]
flutter_rust_bridge = "=2.13.0"
```

不要把上游示例中的 `local: true`、`../../../frb_rust` 或 workspace 开发路径复制到普通应用。

## 新项目与后端选择

以下是可替换名字的命令示例，只执行用户需要的分支。

```shell
flutter_rust_bridge_codegen create my_app
flutter_rust_bridge_codegen create my_app --integration-backend native-assets
flutter_rust_bridge_codegen create my_package --template plugin
```

| 后端 | 何时选 | 要检查的文件 |
|---|---|---|
| Cargokit | v2.13.0 的默认路径；沿用已工作的工程，或兼容较旧 SDK | app 的 `rust_builder/`、其中的 Cargokit 与平台构建文件；plugin 的对应脚手架 |
| Native Assets | SDK 支持 hooks，且项目明确采用此方式 | `hook/build.dart`、`flutter_rust_bridge_hooks`、Rust toolchain 和 code asset 的装载 |
| 自定义 | 已有原生编译、预编译库或发布体系需要保留 | 编译目标、库名、符号、产物位置，以及 `RustLib.init(externalLibrary: ...)` |

`--platforms windows` 等参数用于限制脚手架平台，不能代替验证 Rust crate 是否支持目标平台。不要把 Windows 项目自动扩展到移动端和 Web。

## 现有应用

v2.13.0 的 `integrate` 并非只追加依赖：它叠加模板、修改 pubspec，默认执行 Dart fix/format；对已有 app 的 `main.dart` 会把旧内容注释并写入自包含示例。已有 plugin 的入口也有类似处理。

有复杂启动、登录、原生窗口或自定义构建时，优先在独立临时目录创建同版本、同后端的最小工程，再对照合并 Rust crate、构建脚手架、配置、依赖和初始化代码。保持原有入口与 UI，不把临时模板整包覆盖到项目。

若任务适合直接执行 `integrate`，先记录工作树，按目标版本帮助选择 `--no-integration-test`、`--no-dart-fix`、`--no-dart-format` 等参数，并逐项检查差异。

特别注意 **`--no-write-lib`**：v2.13.0 的 `filter_file` 不仅跳过 Dart `lib/`，还跳过模板中的 Rust crate、FRB YAML 与部分平台目录（`rust_builder/` 有例外）。使用后必须自己补齐这些内容；它不能保证“入口保留且其余接入全部完成”。依据：`integration/integrator/overlay.rs`，见 [源码导览](source-map.md)。

已有 FRB 工程通常只需 `generate`，不必重复 `integrate`。

## 配置与修改循环

项目根的常见最小配置：

```yaml
rust_input: crate::api
rust_root: rust/
dart_output: lib/src/rust
```

- `rust_input` 是模块命名空间，不是 v1 的 `api.rs` 文件路径。多个入口用逗号分隔，如 `crate::api,crate::shared`。
- `rust_root` 指向含 `Cargo.toml` 的 crate；`dart_output` 是输出目录。
- Rust 新模块要出现在模块树中，例如 `rust/src/api/mod.rs` 加 `pub mod metrics;`。独立放一个 `.rs` 文件不会自动成为 Rust 模块。
- YAML 字段是 snake_case 正向名称：CLI 的 `--no-web` 对应 `web: false`。只对明确不需要 Web 的项目关闭 Web。
- 维护锁定依赖时可加 `auto_upgrade_dependency: false`；希望解析失败立即报错时可加 `stop_on_error: true`。
- 默认优先寻找专用配置文件，再找 pubspec 顶层的 `flutter_rust_bridge` 配置。不要把配置写进 `dependencies.flutter_rust_bridge`。
- v2.13.0 的 `commands_parser.rs` 会合并 CLI 与文件配置，CLI 显式值优先；部分 `--config-file` 帮助文案仍称其他参数会忽略。为减少歧义，持久配置集中在 YAML，遇到疑问查看 dump，而不是依赖旧帮助句子。

```shell
flutter_rust_bridge_codegen generate
flutter_rust_bridge_codegen generate --watch
```

执行后检查 API 是否真正生成、运行时版本是否改变、自动格式化是否扩大差异，以及 `lib.rs` 是否包含生成模块。生成工具会在需要时运行 build_runner；业务自有 builder 位于 FRB 输出目录之外时，应另跑项目的构建命令。

初始化放入现有启动流程，确保第一次调用桥接前完成：

```dart
import 'src/rust/frb_generated.dart';

Future<void> initializeRust() async {
  await RustLib.init();
}
```

不要在 Widget 的 `build` 中重复初始化。类名由 `dart_entrypoint_class_name` 决定，默认 `RustLib`。

## Native Assets 与迁移

官方 v2.13.0 hook 用 `FlutterRustBridgeNativeAssetsBuilder(cratePath: 'rust')` 构建，由 hooks 包包装 `native_toolchain_rust`。跟随同版本模板，避免另写第二套 Cargo 调用。Rust crate 需可产生 `staticlib` 和 `cdylib`；`rust-toolchain.toml` 固定具体版本或日期及所需 targets，不使用浮动 `stable`。

从 Cargokit 迁移是构建方式调整。先生成并审阅 hook、补全 toolchain，再移除已被替代的 Cargokit 接入；保留 Rust API 和生成绑定。app 检查 `rust_builder` 路径依赖与 analyzer exclusion，plugin 检查 `cargokit/` 和仅为旧 `ffiPlugin` 使用的平台条目。采用前述临时工程对照方式，避免迁移命令改写入口。完成后刷新依赖、重新生成、构建并测试所有实际支持的平台。

## 平台与 workspace

**Windows**：核对 MSVC 工具链、Windows SDK、Flutter 与 Rust 目标架构一致。检查 Release 目录里实际打包的 DLL及其依赖，不要仅以 `cargo check` 成功证明安装包可用。LLVM/ffigen 是所选生成模式的依赖，并非所有 FRB 工程的固定前置条件。

**Web**：v2.13.0 的官方流程仍单独执行 `flutter_rust_bridge_codegen build-web`，再构建/运行 Flutter Web。默认多线程能力涉及 `SharedArrayBuffer` 和跨源隔离；服务器需配置 COOP `same-origin`、COEP `require-corp` 等相应响应头，并检查第三方资源兼容性。Native Assets 接入成功不意味着 WASM 已生成。只在需要 Web 时查当前浏览器与 Rust crate 的限制。

**Cargo workspace**：`--rust-crate-dir ../bridge_crate` 可定位 crate。检查 workspace members、根锁文件、features、`cargo metadata` 的 target directory 和库装载位置；不要假设产物在 `rust/target`。只在确认成员锁文件是冗余生成物时清理它。

**纯 Dart / 共享包**：参考同版本 `frb_example/dart_minimal`、`pure_dart`、`flutter_package*`，区分示例内部开发 glue 与可发布依赖。共享包需用消费方工程验证实际编译和装载，不能只验证包自身。

来源：官方 Quickstart、Integration / Native Assets / Cargo workspaces 文档；v2.13.0 的 `Config`、`commands_parser.rs`、`integration/integrator`、`frb_hooks` 与对应示例。入口链接见 [来源索引](sources.md)。
