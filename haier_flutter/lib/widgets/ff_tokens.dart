import 'package:fluent_ui/fluent_ui.dart';

/// 只集中跨组件的尺寸与动效；颜色始终从当前 FluentTheme 获取。
abstract final class FfTokens {
  static const double pageMaxWidth = 1000;
  static const double sectionGap = 24;
  static const double itemGap = 12;
  static const double controlGap = 8;
  static const double cardRadius = 4;
  static const double panelRadius = 8;
  static const double controlHeight = 32;
  static const fast = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 250);
  static const curve = Curves.easeOutCubic;

  // 标题栏与页面共用一段导航节奏，避免按钮已归位而正文还在切换。
  static const navigation = Duration(milliseconds: 560);
  static const pageExit = Duration(milliseconds: 300);
  static const navigationCurve = Curves.easeInOutCubic;

  static Duration duration(BuildContext context, Duration preferred) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : preferred;
}
