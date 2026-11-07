# 并发与生命周期

## 选择执行模式

以下是默认 handler 的语义，自定义 runtime/handler 或 Web 可改变具体执行方式。

| Rust 声明 | Dart 形状 | 执行与选择 |
|---|---|---|
| 普通 `fn` | 默认 `Future<T>` | Rust 线程池；适合 CPU 工作和一般调用 |
| `async fn` | `Future<T>` | Rust async runtime；适合异步 I/O，不要塞入长时间阻塞代码 |
| `#[frb(sync)] fn` | 直接返回 T | 同步占用调用线程；适合短小查询，重工作会卡界面 |
| 包含 `StreamSink<T>` 参数 | 常见形状为 `Stream<T>` | 一次调用多次传值；生命周期由 sink、订阅和业务停止协议共同决定 |

不要为了“Rust 不阻塞 Flutter”再套一层 Dart isolate，默认异步桥接通常已经满足这个目的。如果应用确实在多个 isolate 使用桥接，分别处理 `RustLib.init()` / `dispose()`，不要假设一个 isolate 的初始化自动作用于另一个。

默认异步不代表调用顺序自动串行。两个 Future 同时启动可能在 Rust 并发执行；依赖先后次序就按顺序 `await`，共享状态按 Rust 所有权和同步机制设计。

## 初始化与关闭

Rust 启动逻辑可放在输入模块中的初始化函数：

```rust
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
```

现有模板往往已有它，先检查再添加。`RustLib.init()` 会调用生成的初始化链；初始化函数不在扫描范围内就不会被纳入。每个入口实例不要重复初始化，v2.13.0 会报错。

应用服务有明确启动/停止状态：先完成桥接初始化，再启动订阅和后台任务；关闭时先请求停止并等待任务退出，再释放对象和桥接。普通单进程应用不必在每次页面切换调用 `RustLib.dispose()`。

`#[frb(init_dart_code = ...)]` 是往生成初始化流程插入 Dart 语句，与调用 Rust 的 `#[frb(init)]` 不同。只有确有跨语言启动需求时使用，并分析插入的 Dart 代码；生成器不会替你完成语义验证。

## Stream

v2 使用生成模块提供的 sink，而非从旧教程抄根 crate 导入：

```rust
use crate::frb_generated::StreamSink;

pub fn progress(total: u32, sink: StreamSink<u32>) -> anyhow::Result<()> {
    for completed in 0..=total {
        if sink.add(completed).is_err() {
            break;
        }
    }
    Ok(())
}
```

这是有限序列的协议例子。真实计算在每批工作结束后报告进度，并检查取消状态；不使用无间隔的无限循环，也不把每个字节或像素都变成一个事件。

- Dart 通常直接获得 `Stream<T>`，不等 Rust 函数先执行完。确实需要等待建立过程时查 `#[frb(stream_dart_await)]`，并检查生成签名。
- sink 可被 Rust 长期保存，函数返回不等于所有发送者都销毁；最后一个 sink/closer 引用释放才会触发相应关闭路径。
- `sink.add(...)` 返回发送结果。连接关闭后应结束或清理生产者，而不是忽略错误继续循环。
- 需要向流发送错误可查 `add_error`，但错误事件、关闭流和停止后台任务是三件不同的事。
- Dart 侧处理数据、错误、完成和 `StreamSubscription.cancel()`；Rust 侧自行规定中止 I/O、取消计算、清理全局 sink 的方式。

## 取消与背压

不要把 Future 被忽略、Dart timeout 或取消订阅视作 Rust 任务已经停止。为长期任务设计显式 stop/cancel API 与可观察的退出状态；CPU 任务定期读取取消标记，async 任务可使用适配其 runtime 的取消机制。

取消标记必须能在任务执行期间被修改。例如，任务持有某 opaque 对象的长时间独占借用时，另一个需要相同锁的 `cancel(&mut self)` 可能无法及时执行；可将取消状态做成独立共享信号，缩短临界区。回调 Dart 前同样避免持有它再次调用 Rust 所需的锁。

FRB Stream 不替业务定义容量或背压策略。高频进度可节流、合批、保留最新状态；日志或可靠消息需明确缓冲上限与丢弃/重试策略，按实际需求选择。

## Rust 回调 Dart

需要真实可编译的异步闭包签名，而非介绍页里的简写 `Fn(String) -> String`：

```rust
use flutter_rust_bridge::DartFnFuture;

pub async fn ask_label(
    callback: impl Fn(String) -> DartFnFuture<String>,
) -> String {
    callback("ready".to_owned()).await
}
```

生成后 Dart 可传闭包，例如 `await askLabel(callback: (text) => text.toUpperCase())`。检查目标版本的回调参数和返回类型，异步 runtime 与相关 feature 应满足要求。

Rust 长期保存回调会延长关联 Dart 对象的生命周期；明确何时解除注册。`DartOpaque` 适合让 Rust 持有并传回 Dart 对象引用，不代表 Rust 可直接解读 Flutter Widget 或任意 Dart 对象的内存。

来源：官方 Concurrency、Stream、Cancellation、Rust calls Dart、Initialization、Isolates；源码 `frb_rust/src/handler`、`stream`，`frb_dart/lib/src/main_components/entrypoint.dart`。入口见 [来源](sources.md)。
