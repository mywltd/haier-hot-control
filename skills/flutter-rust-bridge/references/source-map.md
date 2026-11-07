# 源码导览

以下路径相对上游 `fzyzcjy/flutter_rust_bridge` 仓库根，基于 `v2.13.0` / `8631db91a90c699439c9ce2a1fb4164ae8661da9`。它们不是宿主 Flutter 项目的路径。[固定标签源码](https://github.com/fzyzcjy/flutter_rust_bridge/tree/v2.13.0)。

## 三个阶段

```text
配置 + Rust API
  → codegen：配置解析 → preparer → parser → IR → generator → polisher
  → Dart API + Dart wire + Rust wire

Rust crate + 平台构建后端
  → Cargo / Cargokit / build hook
  → 原生库或 WASM，打包进消费方应用

Dart 调用
  → 生成的 API wrapper → Dart handler / codec / wire
  → 原生 dispatcher 或 Web 通道 → Rust handler / executor → 业务函数
  → 返回值、错误或 Stream 事件沿对应 codec 回传
```

先用 `frb_example/dart_minimal` 追踪一个函数，再读 `pure_dart` 的复杂类型与测试，避免直接从最大生成文件开始。

## 模块定位

| 模块 / 路径 | 负责什么 | 何时查看 |
|---|---|---|
| `frb_codegen/src/binary/commands.rs` | CLI 参数定义 | 参数名、默认项、后端选择 |
| `frb_codegen/src/binary/commands_parser.rs` | CLI 与文件配置合并 | 参数优先级、正反向布尔值 |
| `frb_codegen/src/library/codegen/config/config.rs` | 公开配置字段，拒绝未知字段 | YAML schema 与类型 |
| `frb_codegen/src/library/codegen/config/config_parser.rs` | 配置文件与 pubspec 查找 | 配置未生效、相对路径基准 |
| `frb_codegen/src/library/codegen/config/internal_config_parser/` | 默认值、路径、codec、生成器内部配置 | 文档与实际默认值不一致 |
| `frb_codegen/src/library/codegen/mod.rs` | 生成流水线总入口 | 哪个阶段失败、输出何时写入 |
| `frb_codegen/src/library/codegen/parser/` | Rust 解析、宏展开后的类型与函数处理 | 函数缺失、泛型、opaque 推断 |
| `frb_codegen/src/library/codegen/ir/` | HIR / MIR 数据结构 | 查看生成前的中间表示 |
| `frb_codegen/src/library/codegen/generator/api_dart/` | 面向业务的 Dart API | 方法名、Dart 类、公开 wrapper |
| `frb_codegen/src/library/codegen/generator/wire/` | Dart/Rust/C 的通信层 | 编解码、dispatcher、符号 |
| `frb_codegen/src/library/codegen/generator/codec/` | 编码模式和共享生成逻辑 | CST/DCO/SSE/PDE 差异 |
| `frb_codegen/src/library/codegen/polisher/` | 格式化、build_runner、模块声明、依赖升级 | 生成结束后出现额外文件变化 |
| `frb_codegen/src/library/integration/integrator/` | create/integrate 的模板接入 | 入口替换、文件过滤、依赖追加 |
| `frb_codegen/assets/integration_template/` | 各后端和 app/plugin 模板 | 新项目结构、迁移对照 |
| `frb_rust/src/handler/` | 任务包装、执行、错误与 panic 边界 | Rust 调度和异常路径 |
| `frb_rust/src/thread_pool/`、`rust_async/` | 平台线程池与 async runtime | 阻塞、并发与 Web 差异 |
| `frb_rust/src/stream/`、`rust_auto_opaque/`、`rust_opaque/` | sink、关闭、借用和对象句柄 | 生命周期与所有权问题 |
| `frb_macros/src/` | FRB 属性宏支持 | 属性识别、展开问题 |
| `frb_dart/lib/src/main_components/` | entrypoint、handler、API、port 管理 | 初始化、版本、内容 hash 与回调 |
| `frb_dart/lib/src/loader/` | 原生/Web 库加载 | 库路径、不同运行方式的装载 |
| `frb_dart/lib/src/codec/` | Dart 编解码实现 | 数据传输路径、PDE 调用 |
| `frb_dart/lib/src/misc/rust_opaque.dart`、`droppable/` | Dart 句柄与释放 | dispose、GC 与生命周期 |
| `frb_hooks/lib/src/native_assets_builder.dart` | Native Assets 构建 hook | Cargo 产物注册与代码资产 |
| `website/docs/` | 与标签同行的教程 | 复查版本化用法与旧内容 |

## 关键实现结论

1. `generate_once` 先 prepare / parse / generate，再写输出，最后 polish。末尾成功信息不替代 API 完整性和编译检查，尤其不能忽略前面的跳过警告。
2. parser 的主要步骤为 raw HIR → tree → naive flat → flat → early generator → MIR。定位类型推断时对照不同阶段的 dump。
3. `polisher/auto_upgrade.rs` 会检查 Dart 和 Rust FRB 依赖与 codegen 版本；启用默认自动升级时可能写 pubspec/Cargo。配置键是 **`auto_upgrade_dependency`**，不是日志中曾出现过的复数写法。
4. `integration/integrator/overlay.rs` 中的 `comment_out_existing_file_and_write_template` 解释入口改写；`filter_file` 解释 `--no-write-lib` 为什么连 Rust 模板和 YAML 都会跳过。
5. `entrypoint.dart` 先检查生成器与 Dart runtime 版本，再装载库并检查 Rust 内容 hash，最后执行初始化。`init(api: mockApi)` 仍走装载逻辑，`initMock` 才绕过真实 FFI。
6. `stream/stream_sink.rs` 的发送结果与 `closer.rs` 的释放行为，要和 Dart 订阅结束一起看；不能从某个发送成功推断整个业务任务可以自动取消。

## 源码检索与 dump

```shell
rg -n 'compute_force_codec_mode_pack|full_dep|enable_auto_upgrade' frb_codegen/src/library/codegen
rg -n 'initMockImpl|_sanityCheckContentHash|forceSameCodegenVersion' frb_dart/lib/src/main_components
rg -n 'comment_out_existing_file|fn filter_file' frb_codegen/src/library/integration
flutter_rust_bridge_codegen generate --dump config hir mir
```

v2.13.0 的 dump 默认写到 crate 下 `target/frb_dump`。它可能包含源码、路径和配置；用来本地排查，分享问题时只提供相关、已去除敏感内容的片段。库路径或函数 ID 发生问题时继续查看 generator-info/spec/text，而不是只看 Rust 业务代码。

## 修改上游时的验证入口

- 配置/解析/生成器：先看模块内测试及 `frb_codegen/test_fixtures/` 对应 fixture。
- 语言边界行为：`frb_example/pure_dart/rust/src/api/` 与 `frb_example/pure_dart/test/`；按现有正常/同步/序列化等覆盖习惯扩展。
- 初始化模板：对照 `flutter_via_create`、`flutter_via_integrate`、`flutter_package` 及其 `_native_assets` 变体。
- Dart 运行时：`frb_dart/test/`；Rust 运行时：对应模块的 Rust tests。
- 完整检查与生成流程：`.github/workflows/ci.yaml`、`tools/frb_internal/`。读取当前 checkout 的约定，不凭印象执行过时的内部任务名。

修改生成器需验证输入修改后输出真的重新出现。若上游把生成文件纳入版本控制，重新生成后审阅所有预期差异；不要只改 fixture 期待值而不验证消费方行为。
