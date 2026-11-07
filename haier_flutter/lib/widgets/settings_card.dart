import 'package:fluent_ui/fluent_ui.dart';

import 'ff_tokens.dart';

/// 内页内容最大宽度，超出后居中、两侧等宽留白。
const double kPageContentMaxWidth = FfTokens.pageMaxWidth;

/// 4.17 起 ScaffoldPage 的边距作用于整页；水平留白由内容列负责，避免重复缩进并让滚动条贴边。
const kAppPagePadding = EdgeInsetsDirectional.only(
  top: kPageDefaultVerticalPadding,
);

/// 内容列居中时滚动区的左右内边距；滚动条仍贴窗口右缘。
EdgeInsetsDirectional pageListPadding(double maxWidth, {double bottom = 0}) {
  // 按页面实际可用宽度适配，侧栏占宽不应算进页面的断点。
  final gutter = maxWidth <= 640
      ? kPageCompactHorizontalPadding
      : kPageDefaultHorizontalPadding;
  final extra = (maxWidth - gutter * 2 - kPageContentMaxWidth) / 2;
  final side = gutter + (extra > 0 ? extra : 0);
  return EdgeInsetsDirectional.only(start: side, end: side, bottom: bottom);
}

/// 同组卡片之间的间距。
const double kCardSpacing = 4;

/// 单行设置卡片：左图标 → 标题 + 说明 → 右侧控件。
///
/// 尺寸取自 Windows 设置页 SettingsCard：内边距 16、最小高度 68、
/// 图标 20、图标与文字间距 16、文字与右侧控件间距 16。
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.header,
    this.leading,
    this.description,
    this.trailing,
  });

  final Widget? leading;
  final Widget header;
  final Widget? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Card(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: ConstrainedBox(
        // 12 + 42 + 12 + 1px 描边 ×2 = 68
        constraints: const BoxConstraints(minHeight: 42),
        child: Row(
          children: [
            if (leading != null) ...[
              IconTheme.merge(
                data: const IconThemeData(size: 20),
                child: leading!,
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                    style: theme.typography.body,
                    child: header,
                  ),
                  if (description != null)
                    DefaultTextStyle.merge(
                      style: theme.typography.caption?.copyWith(
                        color: theme.resources.textFillColorSecondary,
                      ),
                      child: description!,
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 16), trailing!],
          ],
        ),
      ),
    );
  }
}

/// 可展开的设置卡片（Windows 设置页 SettingsExpander）：标题行与 [SettingsCard] 同尺寸，
/// 展开后是一组 [SettingsExpanderItem]，行间 1px 分隔线。
///
/// fluent_ui 的 [Expander] 标题行矮（46）、圆角 6，这里改成卡片的 68 高、圆角 4。
class SettingsExpander extends StatelessWidget {
  const SettingsExpander({
    super.key,
    required this.header,
    required this.items,
    this.leading,
    this.description,
    this.trailing,
    this.initiallyExpanded = false,
  });

  final Widget? leading;
  final Widget header;
  final Widget? description;

  /// 放在展开箭头左边，折叠时也可点。
  final Widget? trailing;
  final List<Widget> items;
  final bool initiallyExpanded;

  static const _radius = Radius.circular(4);

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final res = theme.resources;
    final stroke = BorderSide(color: res.cardStrokeColorDefault);
    return Expander(
      initiallyExpanded: initiallyExpanded,
      headerShape: (open) => RoundedRectangleBorder(
        side: stroke,
        borderRadius: BorderRadius.vertical(
          top: _radius,
          bottom: open ? Radius.zero : _radius,
        ),
      ),
      // Expander 用 ShapeDecoration 画内容区，Border 当 ShapeBorder 用时没有圆角；
      // 这里让它透明，底色和边框改由下面的 Container 画。
      contentShape: (open) => const RoundedRectangleBorder(),
      contentBackgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      // 标题行左边距 16 由 Expander 给；图标与文字间距补到 16，右侧控件与箭头间距同 SettingsCard。
      leading: leading == null
          ? null
          : Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: IconTheme.merge(
                data: const IconThemeData(size: 20),
                child: leading!,
              ),
            ),
      header: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 42),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DefaultTextStyle.merge(
                style: theme.typography.body,
                child: header,
              ),
              if (description != null)
                DefaultTextStyle.merge(
                  style: theme.typography.caption?.copyWith(
                    color: res.textFillColorSecondary,
                  ),
                  child: description!,
                ),
            ],
          ),
        ),
      ),
      trailing: trailing,
      // 不画上边线，免得和标题行的下边线叠成 2px。
      content: Container(
        decoration: BoxDecoration(
          color: res.cardBackgroundFillColorSecondary,
          border: Border(left: stroke, right: stroke, bottom: stroke),
          borderRadius: const BorderRadius.vertical(bottom: _radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                SizedBox(
                  height: 1,
                  child: ColoredBox(color: res.cardStrokeColorDefault),
                ),
              items[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// [SettingsExpander] 里的一行：文字与标题行的文字左对齐（16 + 图标 20 + 16）；
/// 右侧控件与标题行的控件右对齐，让出展开箭头的 44。
class SettingsExpanderItem extends StatelessWidget {
  const SettingsExpanderItem({
    super.key,
    required this.header,
    this.description,
    this.trailing,
  });

  final Widget header;
  final Widget? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(52, 8, 44, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                    style: theme.typography.body,
                    child: header,
                  ),
                  if (description != null)
                    DefaultTextStyle.merge(
                      style: theme.typography.caption?.copyWith(
                        color: theme.resources.textFillColorSecondary,
                      ),
                      child: description!,
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 16), trailing!],
          ],
        ),
      ),
    );
  }
}

/// 分组标题：Body Strong，上 24 / 下 8。
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 24, bottom: 8),
      child: Text(text, style: FluentTheme.of(context).typography.bodyStrong),
    );
  }
}

/// 横排按钮组，按钮间距 8。
class ButtonRow extends StatelessWidget {
  const ButtonRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: children);
  }
}

/// 把页头、页脚等非滚动区限制到与 [PageBody] 相同的宽度并居中，保证左右边缘对齐。
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: pageListPadding(constraints.maxWidth),
          // 撑满内容列，短搜索框和页脚文字仍从列的左缘开始。
          child: SizedBox(width: double.infinity, child: child),
        );
      },
    );
  }
}

/// 居中并限制最大宽度的内页滚动区；滚动条贴窗口右缘。
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          padding: pageListPadding(constraints.maxWidth, bottom: 24),
          children: children,
        );
      },
    );
  }
}

/// 图标 + 文字的按钮内容，图标 16、间距 8。
class IconLabel extends StatelessWidget {
  const IconLabel({
    super.key,
    required this.icon,
    required this.fallbackIcon,
    required this.label,
  });

  final IconData icon;
  final IconData fallbackIcon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WindowsIcon(icon, size: 16, fallbackIcon: fallbackIcon),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
