# 排错与验证

## 先收集最小证据

记录目标平台/架构、Flutter/Dart 与 Rust 版本、codegen 版本、Dart/Rust FRB 锁定版本、生成文件头、构建后端、复现命令和第一条相关错误。将问题分到生成、编译、加载或运行阶段，不先全量升级依赖。

需要详细生成日志时，PowerShell 可临时设置环境并恢复：

```powershell
$frbPreviousLog = $env:RUST_LOG
try {
    $env:RUST_LOG = 'debug'
    flutter_rust_bridge_codegen generate --dump config hir mir
} finally {
    $env:RUST_LOG = $frbPreviousLog
}
```

## 症状与处理

| 症状 | 核查顺序 |
|---|---|
| 提示尚未初始化 | 所用 isolate/入口是否完成 `await RustLib.init()`；不要在初始化 Future 结束前调用 API |
| 提示重复初始化 | 是否由多个页面或服务重复启动；统一启动责任，测试 teardown 正确 dispose |
| codegen 与 runtime 版本不同 | 核对 CLI、pubspec.lock、Cargo.lock 和生成文件版本；选择同版本生成器，重新生成和编译 |
| Dart/Rust content hash 不同 | 生成代码与已加载原生库不同步；重新生成、重编 Rust、重启目标进程；检查是否加载了旧 DLL |
| hash 相同但行为仍旧 | hash 是一致性辅助检查，不覆盖所有 Rust 实现变化；确认实际库路径、时间和构建日志 |
| API 没生成但命令结束 | `pub`、模块声明、`rust_input` 范围、`#[frb(ignore)]`、类型支持和前面的跳过警告；必要时开启 `stop_on_error: true` |
| YAML 未知字段或选项无效 | 查同版本 `Config`；YAML 使用正向 snake_case，布尔值/列表类型正确，不照搬 CLI 的 `no_` 名字 |
| `.freezed.dart` / `.g.dart` 缺失 | 核对 Freezed/json_serializable 注解与依赖、build_runner、`build_runner` 配置；FRB 自动生成可能只过滤自身输出目录 |
| `frb_expand` unexpected cfg 警告 | 按当前 Rust 配置加入相应 `check-cfg` 声明；不要全局关闭所有编译警告 |
| `libclang` / LLVM 找不到 | 先确认是否走 full dependencies / ffigen；需要时配置 `llvm_path` 字符串列表并检查所用工具架构 |
| DLL/so/dylib 找不到 | 后端是否执行、产物名与架构、打包清单、传递依赖、Release/Debug 路径、Cargo workspace target directory |
| 符号找不到 | 是否编译了生成的 Rust 模块、是否加载同版本产物、链接/裁剪设置；按实际平台排查 |
| 接入后原 UI 消失 | 检查 integrate 是否把入口注释并替换为示例；基于原工作树和差异恢复应用启动，合入必要初始化 |
| 使用 `--no-write-lib` 后无 Rust/config | 该开关在此版本也跳过这些模板；按最小示例补全，不重复运行默认 integrate 覆盖入口 |
| 配置/锁文件意外变化 | 看 polisher 的自动依赖升级、Dart fix/format、build_runner；恢复仅本次无关改动并固定所需工具版本 |
| UI 在调用期间卡住 | 查 `#[frb(sync)]`、巨大参数编码、Dart 同步处理；普通重计算使用异步 Dart 调用，必要时测量各阶段 |
| 回调或并发调用等待不结束 | 查持锁期间反向回调、同对象长时间可变借用、任务依赖和关闭顺序；不要靠延时碰运气 |
| Stream 取消后 CPU 仍忙 | 订阅取消不等于业务取消；让生产者响应发送失败或显式取消信号，并有可验证的退出路径 |
| opaque 已释放/已移动错误 | 追踪消费 `self`、dispose、共享容器和异步操作顺序；复用需合理的共享所有权 |
| Web 加载/多线程失败 | WASM 是否重新生成、URL 前缀和资源、跨源隔离响应头、浏览器能力；查目标 Rust crate 的 WASM 支持 |
| 仅发布包失败 | 构建实际 Release/安装包，检查库是否被打包、依赖库、架构和符号保留；Debug 成功不足以证明发布成功 |

如确实需要 ffigen：

```yaml
llvm_path:
  - 'C:\Program Files\LLVM'
```

如使用当前 Rust 的 lint 配置：

```toml
[lints.rust]
unexpected_cfgs = { level = "warn", check-cfg = ['cfg(frb_expand)'] }
```

## 验证层次

按改动选择有意义的验证，同时满足目标仓库规定的检查：

1. **生成层**：运行匹配版本的 `generate`；确认预期函数/类型、配置、相关 Freezed/JSON 文件存在，审阅生成差异。生成文件是否提交遵循项目惯例；若忽略它们，CI 必须能重新生成。构建脚手架应保留在版本控制中。
2. **Rust 层**：用实际 crate 路径执行 `cargo check`、相关 `cargo test`；需要时跑 clippy。覆盖业务错误、边界输入、并发状态与取消，不只测试 happy path。
3. **Dart/Flutter 上层**：运行 analyzer 与测试。需要完全不加载 Rust 的测试，使用生成的 `RustLib.initMock(api: mockApi)`，结束时 `RustLib.dispose()`；mock 的方法名从实际 `RustLibApi` 读取。该模式不执行真实 Rust 初始化，要由测试提供所需状态。
4. **真实桥接**：构建原生库并调用代表性 API，覆盖返回值、错误、流关闭和 opaque 生命周期。`RustLib.init(api: mockApi)` 仍会装载库并做一致性检查，不能当作完全离线 mock。
5. **分发层**：验证实际支持的平台和发布配置能找到正确库。受仓库约定限制不能启动真实应用时，用隔离样例或已有集成测试，明确未验证的部分。

典型检查命令，路径和平台按工程调整：

```shell
cargo check --manifest-path rust/Cargo.toml
cargo test --manifest-path rust/Cargo.toml
flutter analyze
flutter test
flutter build windows
```

没有 Rust runtime 的 widget mock 测试不能替代真实桥接测试；只运行 `cargo check` 也不能验证 Dart 生成签名与 DLL 装载。

## 升级与旧教程

升级时把 codegen、Dart FRB 包、Rust FRB crate 和生成文件作为一组处理，并重新编译原生产物；Native Assets 项目还需核对 hooks 的兼容版本。先看目标版本 SDK 要求和 release notes。依赖自动升级可以在明确的升级任务中使用，不把关闭版本或内容 hash 检查当修复。

识别 v1 或旧模板痕迹：单个 `api.rs` 文件输入、手建全局 `api`、旧 `SyncReturn` / `ZeroCopyBuffer` 示例、旧版 `StreamSink` 导入。不要做全仓字符串替换；先比较 v2 模板、配置、初始化、生成文件布局和类型语义，再迁移业务调用。

官方 manual 中仍可能有历史 NDK 版本建议、工具链重装命令和旧 CLI 语法。仅在平台、版本与错误都匹配时采用；优先查当前目标版本的实现及维护中的构建后端。无需为了排错直接卸载 Rust 或删除整个全局缓存。

来源：官方 Testing、Upgrading、Troubleshooting 与 Git Ignore；v2.13.0 的 `entrypoint.dart`、`polisher/auto_upgrade.rs`、`overlay.rs` 和生成的 `RustLib`。详见 [来源索引](sources.md)。
