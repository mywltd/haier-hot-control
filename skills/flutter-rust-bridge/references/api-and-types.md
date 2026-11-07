# API 与类型

用于设计跨语言边界。先保持 Rust 内部逻辑可独立测试，再暴露 Flutter 实际需要的操作。下述代码是便于改写的业务例子；导入路径和生成签名以目标工程的输出为准。

## 普通函数与数据

假设 Rust 模块为 `crate::api::metrics`，且 crate 已依赖 `anyhow`：

```rust
pub struct MeasureResult {
    pub count: u32,
    pub mean: f64,
}

pub fn measure(values: Vec<f64>) -> anyhow::Result<MeasureResult> {
    anyhow::ensure!(!values.is_empty(), "至少提供一个数值");
    let count = u32::try_from(values.len())?;
    let mean = values.iter().sum::<f64>() / f64::from(count);
    Ok(MeasureResult { count, mean })
}
```

生成后从 Dart API 文件调用，而不是手动操作 wire：

```dart
import 'dart:typed_data';
import 'src/rust/api/metrics.dart';

Future<double> exampleMean() async {
  final result = await measure(values: Float64List.fromList([2, 6]));
  return result.mean;
}
```

调用前需初始化桥接。Rust `snake_case` 通常转为 Dart `camelCase`；公开 wrapper 与内部 `RustLibApi` 方法名不同，不猜测内部方法名。

## 常用映射与选择

| Rust | Dart / 使用要点 |
|---|---|
| `bool`、`f32/f64`、`String` | `bool`、`double`、`String` |
| 小整数 | 通常为 `int`，仍受 Rust 目标类型范围限制 |
| `i64/u64`、128 位整数、指针宽度整数 | 按类型、配置和平台映射到 `int` 或 `BigInt`；检查生成签名，测试大值 |
| `Option<T>` | 可空 `T?` |
| `Vec<u8>` / `Vec<f64>` | `Uint8List` / `Float64List` 等 typed data |
| `Vec<T>`、`HashMap<K,V>`、`HashSet<T>` | 通常对应 `List`、`Map`、`Set`；元素类型仍需可桥接 |
| 可转换 `struct` | 带字段的 Dart 类，默认字段通常为 final |
| 无负载 `enum` | Dart enum |
| 带负载 `enum` | Freezed / sealed class 路径，需相关生成依赖 |
| tuple | Dart 3 record 路径；目标配置关闭 Dart 3 时需另查 |
| `Result<T,E>` | 成功得到 T；错误走 Dart 异常通道，不是返回一个 Dart Result |
| 不宜复制的 Rust 类型 | opaque 句柄，数据仍在 Rust |

`type_64bit_int: true` 或相应属性改变 64 位整数表示，不能消除 Web 数值精度限制。ID、计数和时间戳要以真实最大值测试，不随意把所有整数强制成 `int`。

带数据枚举适合互斥状态；不要为了绕过生成器改成缺乏约束的字符串 JSON。需要 JSON 时可查 `#[frb(json_serializable)]`，它与普通跨语言传输是不同用途。

## 公开面与属性

| 需求 | 可用手段与注意点 |
|---|---|
| 排除某个 API | `#[frb(ignore)]`；保持桥接入口窄小 |
| 未被函数引用的类型也要生成 | `#[frb(unignore)]`；默认会省略未使用类型 |
| 指定 Dart 名字 | `#[frb(name = "...")]`；核对该位置是否受目标版本支持 |
| 可变 Dart DTO 字段 | 字段上 `#[frb(non_final)]`；这不会自动修改 Rust 中另一个对象 |
| 保留 Rust 内部状态 | `#[frb(opaque)]` |
| 强制可转换数据 | `#[frb(non_opaque)]`；不适用于必须保留身份或 `&mut` 语义的情况 |
| 同步 Dart 调用 | `#[frb(sync)]`；只用于短操作，参见并发页 |

Rust 模块必须注册到模块树，公共 API 必须在 `rust_input` 覆盖范围内。一个未输出的函数不应靠手补 Dart wrapper“修复”。

## Opaque 与所有权

数据量大、含文件/数据库句柄、不可序列化或需保持对象身份时，让 Dart 持有 opaque 对象。FRB 会推断很多 opaque 类型，也可显式标注：

```rust
use flutter_rust_bridge::frb;

#[frb(opaque)]
pub struct ByteStore {
    bytes: Vec<u8>,
}

impl ByteStore {
    pub fn new(bytes: Vec<u8>) -> Self {
        Self { bytes }
    }

    pub fn replace(&mut self, bytes: Vec<u8>) {
        self.bytes = bytes;
    }

    pub fn snapshot(&self) -> Vec<u8> {
        self.bytes.clone()
    }

    pub fn into_bytes(self) -> Vec<u8> {
        self.bytes
    }
}
```

`&self` 是借用，`&mut self` 是可变借用，`self` 是消费所有权。调用消费方法后，不能继续使用原 Dart 句柄。不要把 Rust 借用语义误解成 Dart 对象可任意并发访问；跨边界的借用冲突可能成为运行时错误或等待，按生成的锁行为检查。

Dart opaque 对象的 `dispose()` 会释放其持有的引用；GC 也有释放机制，但不保证立刻执行。文件、连接和大块内存应在业务生命周期结束时主动释放。仍有 Rust 引用时不意味着底层对象已立即析构；`dispose` 也不是取消工作线程的协议。

可转换 struct 内直接含 opaque 的 `T` 字段可能在传参时消费该值。需要多次复用时，根据生成器提示评估 `RustAutoOpaque<T>` 等共享包装，而不是盲目 clone Dart 容器。

## 错误

业务失败返回 `anyhow::Result<T>` 或自定义 `Result<T,E>`，在 Dart 捕获并转换成界面状态。避免将 panic 当作验证用户输入的方式。

只有可展开的 panic 才能通过相应处理转成 `PanicException`；`panic = "abort"` 会终止进程，Web 也有不同限制。不能承诺所有 Rust 崩溃都可被 Dart `try/catch` 恢复。

来源：官方 Types、Functions、Return Types、RustAutoOpaque 指南，以及同版本 `pure_dart` API/测试；[链接与源码入口](sources.md)。
