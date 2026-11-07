# 进阶选择

只在普通函数、DTO 和 opaque API 不能满足需求，或任务明确涉及底层行为时读取。保持方案与目标版本对应，不默认开启实验特性。

## 第三方 Rust crate

先决定是否需要把第三方公共面完整暴露给 Dart。

- 少量业务能力：在本地 `api` 模块写窄包装，转换输入、错误和返回值。这通常更容易稳定版本与测试。
- 希望复用已有类型：查 manual external types/methods、mirror 与对应示例，确保镜像字段和真实类型保持一致。
- 需要广泛暴露：自动扫描可把 crate 名放进 `rust_input`，例如 `crate::api,third_party_crate`。这是实验功能，先验证少数代表性函数、features、泛型和类型的生成结果，再扩大范围。

不要为了让解析通过伪造第三方类型布局，或给不满足条件的类型随意写 `unsafe impl Send/Sync`。若对象确实有线程亲和性，应选择适当的执行/消息模型；互斥锁本身不能让任意非 Send 对象自动变得可跨线程。

## Trait 与返回借用

FRB 支持 trait 定义、实现和 trait object 的若干映射，具体关联类型、泛型和方法组合以同版本例子及生成结果为准。先用一个最小接口验证，再将它作为应用公共契约；不能把“支持 traits”理解为所有 Rust trait 都可直接跨语言。

普通参数的 `&T` / `&mut T` 与返回借用是不同能力。返回带生命周期的值需要按目标版本评估 `enable_lifetime: true`；官方将此功能标为实验性。必须证明被借用 owner 的存活时间、Dart 使用顺序与释放行为。能用 owned DTO、复制小数据或 opaque owner 表达时，优先比较这些更简单的方案。

## Codec 与性能

先测量调用频率、编码耗时、复制字节数和 Rust 执行耗时，再调整 codec。大多数任务先减少细碎的跨边界调用，并让大状态留在 Rust。

| 路径 | 作用 | 使用判断 |
|---|---|---|
| CST / DCO | C 结构与 Dart CObject 相关传输路径 | 某些 typed data / 大数组场景有优势，需 full dependencies 支持 |
| SSE | 字节缓冲序列化 | 某些小对象场景有优势，不承诺所有场景更快 |
| PDE | v2.13.0 的 dispatcher 路径，复用 SSE 编解码 | 默认 `full_dep: false` 时，普通函数双向被配置为 PDE |
| NOM / MOI | opaque 对象的底层表示策略 | 与普通数据 codec 区分；多数业务无需手动选择 |

**源码与文档差异**：v2.13.0 的 `InternalConfig::parse` 默认 `full_dep` 为 false；`compute_force_codec_mode_pack` 选 PDE，默认 stream sink 选 SSE，默认 opaque codec 选 MOI。概念文档中“默认 CST+DCO”或“非 full_dep 用 SSE”的描述不能直接当作当前全部运行路径。`PDE` 如何使用 SSE 见 `generator/codec/structs.rs` 与 `frb_dart/lib/src/codec/pde.dart`。

需要 full dependency 路径时才核对 ffigen、LLVM 与 `full_dep: true`；需要显式序列化属性时查看目标版本 `#[frb(serialize)]` 的实现。不要为一个未测量的性能猜想改变整个项目配置。

“零拷贝”有方向、模式、平台和 codec 条件。原生平台特定 Rust→Dart typed data 路径可以利用 external typed data；不能据此承诺默认 PDE、Dart→Rust、同步调用和 Web 全部零拷贝。验证实际生成的 encoder/decoder，并用真实负载测量。

## 定制与可观测性

- **加载库**：已有打包体系可在 `RustLib.init(externalLibrary: ...)` 提供库，确认路径、架构、版本与符号，不绕过一致性检查。
- **Dart 调用观测**：通过 `BaseHandler` 子类观察耗时/错误，保留原来的编码和释放约定。
- **Rust 调度**：查 handler、executor、`BaseThreadPool`、`BaseAsyncRuntime`；自定义时验证 panic、任务完成和关闭路径。
- **日志与回溯**：先检查模板的 `setup_default_user_utils()`，避免重复安装全局 logger。Rust 进程环境与 Dart `--dart-define` 不是同一机制。
- **自动生成触发**：`generate --watch` 可缩短编辑循环，但不负责将变更后的 Rust 库热替换进运行进程。若用 `build.rs` 驱动生成，先查官方对应示例，防止生成与 Cargo 构建递归。

来源：官方 Third-party、Traits、Lifetimes、Codec、Performance、Customization；版本化实现见 [源码导览](source-map.md)，外部入口见 [来源](sources.md)。
