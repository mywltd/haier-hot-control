import 'package:fluent_ui/fluent_ui.dart';

/// 列表、提示里观众昵称的最大显示字数，超出部分用省略号代替。
const int kNameMaxChars = 12;

/// 按字符（含表情）截断，超出 [max] 时末尾加「…」。
String ellipsize(String text, {int max = kNameMaxChars}) {
  final chars = text.characters;
  if (chars.length <= max) {
    return text;
  }
  return '${chars.take(max - 1)}…';
}

/// 观众昵称：过长截断，悬停显示全名；空昵称显示「未命名」。
class NameText extends StatelessWidget {
  const NameText(this.name, {super.key, this.style});

  final String name;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final full = name.trim().isEmpty ? '未命名' : name;
    final shown = ellipsize(full);
    final text = Text(
      shown,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    return shown == full ? text : Tooltip(message: full, child: text);
  }
}
