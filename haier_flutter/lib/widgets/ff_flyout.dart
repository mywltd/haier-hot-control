import 'package:fluent_ui/fluent_ui.dart';

import 'popup_surface.dart';

/// 页面内的亚克力浮层。亮度取主题资源，投影只画在面板外，避免模糊采到自身阴影。
class FfFlyoutContent extends StatelessWidget {
  const FfFlyoutContent({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(8),
    this.constraints = kFlyoutMinConstraints,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxConstraints constraints;

  static const _radius = BorderRadius.all(Radius.circular(8));
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return PopupShadow(
      borderRadius: _radius,
      child: PopupSurface(
        borderRadius: _radius,
        child: Container(
          constraints: constraints,
          padding: padding,
          child: DefaultTextStyle.merge(
            style: theme.typography.body,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 单层命令菜单，复用 Fluent 菜单项的焦点、键盘激活和自动关闭行为。
/// 同组命令的 leading 应保持一致；级联菜单仍使用 Fluent 的 MenuFlyout。
class FfMenuFlyout extends StatelessWidget {
  const FfMenuFlyout({super.key, required this.items});

  final List<MenuFlyoutItem> items;

  @override
  Widget build(BuildContext context) => IntrinsicWidth(
    child: FfFlyoutContent(
      padding: kDefaultMenuPadding,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                key: item.key,
                padding: kDefaultMenuItemMargin,
                child: Builder(builder: item.build),
              ),
          ],
        ),
      ),
    ),
  );
}
