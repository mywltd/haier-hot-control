import 'package:fluent_ui/fluent_ui.dart';

import 'theme.dart';

/// 启动卡片：窗口缩成卡片大小居中显示 Logo，后台加载配置、连接服务器。
///
/// 圆角与阴影由系统窗口提供（见 window_bootstrap），这里只画内容。
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final res = theme.resources;
    return ColoredBox(
      // 与主体内容区同一层填充：比纯云母略实，像一张卡片。
      color: res.layerFillColorDefault,
      child: Center(
        // Logo 轻微上浮淡入。
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 520),
          curve: const Cubic(0.1, 0.9, 0.2, 1),
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - t)),
              child: child,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/app_icon.ico',
                  width: 88,
                  height: 88,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => const SizedBox.square(dimension: 88),
                ),
              ),
              const SizedBox(height: 20),
              Text(kAppTitle, style: theme.typography.title),
              const SizedBox(height: 6),
              Text(
                '正在启动…',
                style: theme.typography.caption?.copyWith(
                  color: res.textFillColorSecondary,
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(width: 160, child: ProgressBar()),
            ],
          ),
        ),
      ),
    );
  }
}
