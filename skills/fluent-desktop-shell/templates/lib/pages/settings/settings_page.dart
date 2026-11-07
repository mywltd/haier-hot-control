import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../../app/desktop_session.dart';
import '../../app/shell_settings.dart';
import '../../app/window_backdrop.dart';
import '../../app/window_material.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/toast.dart';

/// 示例「设置」页：窗口材质 + 开机自启动 + 关闭主窗口时的行为。业务设置按同样的卡片加在前面。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = ShellSettings.instance;
    final session = DesktopSession.maybeInstance;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, ?session, backdropOpaque]),
      builder: (context, _) => ScaffoldPage(
        header: const PageWidth(child: PageHeader(title: Text('设置'))),
        content: PageBody(
          children: [
            const SettingsSectionHeader('外观'),
            ..._appearanceCards(settings),
            const SettingsSectionHeader('常规'),
            if (session != null) ...[
              SettingsCard(
                leading: const WindowsIcon(
                  WindowsIcons.power_button,
                  fallbackIcon: FluentIcons.power_button,
                ),
                header: const Text('开机自启动'),
                description: const Text('登录 Windows 后自动运行，并常驻托盘'),
                trailing: ToggleSwitch(
                  checked: session.launchAtStartupEnabled,
                  leadingContent: true,
                  semanticLabel: '开机自启动',
                  content: Text(session.launchAtStartupEnabled ? '开' : '关'),
                  onChanged: (value) async {
                    try {
                      await session.setLaunchAtStartup(value);
                    } catch (e) {
                      if (context.mounted) {
                        await showToast(
                          context,
                          '设置失败：$e',
                          severity: InfoBarSeverity.error,
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: kCardSpacing),
            ],
            SettingsCard(
              leading: const WindowsIcon(
                WindowsIcons.chrome_close,
                fallbackIcon: FluentIcons.chrome_close,
              ),
              header: const Text('关闭主窗口时'),
              description: Text(
                settings.closeAction == CloseAction.ask
                    ? '点击右上角关闭按钮时询问要退出还是最小化到托盘'
                    : '已记住你的选择；改回「每次询问」即可恢复弹窗',
              ),
              trailing: ComboBox<CloseAction>(
                value: settings.closeAction,
                items: [
                  for (final a in CloseAction.values)
                    ComboBoxItem(value: a, child: Text(a.label)),
                ],
                onChanged: (a) {
                  if (a != null) {
                    unawaited(settings.setCloseAction(a));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 窗口材质：Windows 11 可在云母与毛玻璃之间切换；Windows 10 没有云母，下拉框禁用并固定为毛玻璃。
  List<Widget> _appearanceCards(ShellSettings settings) {
    final mica = micaSupported;
    final material = mica ? settings.windowMaterial : WindowMaterial.acrylic;
    return [
      SettingsCard(
        leading: const WindowsIcon(
          WindowsIcons.personalize,
          fallbackIcon: FluentIcons.personalize,
        ),
        header: const Text('窗口材质'),
        description: Text(
          mica
              ? '云母从桌面壁纸取色；毛玻璃透出窗口后面的内容，可调色调和不透明度'
              : '系统云母需要 Windows 11，当前系统使用毛玻璃',
        ),
        trailing: ComboBox<WindowMaterial>(
          value: material,
          items: [
            for (final m in WindowMaterial.values)
              ComboBoxItem(value: m, child: Text(m.label)),
          ],
          onChanged: mica
              ? (m) {
                  if (m != null) {
                    unawaited(settings.setWindowMaterial(m));
                  }
                }
              : null,
        ),
      ),
      if (material == WindowMaterial.acrylic) ...[
        const SizedBox(height: kCardSpacing),
        _AcrylicExpander(settings: settings),
      ],
    ];
  }
}

/// 毛玻璃参数：模糊方式（仅 Windows 10）、色调、不透明度。改动立即作用到窗口；
/// 拖动滑块、在取色器里拖动时只预览，松手 / 关闭取色器后才写盘。
class _AcrylicExpander extends StatefulWidget {
  const _AcrylicExpander({required this.settings});

  final ShellSettings settings;

  @override
  State<_AcrylicExpander> createState() => _AcrylicExpanderState();
}

class _AcrylicExpanderState extends State<_AcrylicExpander> {
  final _tintFlyout = FlyoutController();

  ShellSettings get _settings => widget.settings;

  @override
  void dispose() {
    _tintFlyout.dispose();
    super.dispose();
  }

  void _preview(AcrylicOptions options) =>
      unawaited(_settings.setAcrylic(options, persist: false));

  void _save(AcrylicOptions options) =>
      unawaited(_settings.setAcrylic(options));

  bool get _dark => FluentTheme.of(context).brightness == Brightness.dark;

  Future<void> _pickTint() async {
    var picked = _settings.acrylic.tintFor(dark: _dark);
    await _tintFlyout.showFlyout<void>(
      barrierColor: Colors.transparent,
      // 不用 auto：它按整个窗口的大小判断放不放得下，总是退回 topCenter，被夹到窗口顶部还会盖住色块。
      // 色块在行的右侧，左边留得出取色器的宽度。
      placementMode: FlyoutPlacementMode.leftCenter,
      builder: (context) => FlyoutContent(
        // 同 Windows 11「自定义颜色」：色环、亮度条、十六进制；不放 RGB 三个输入框，弹出层矮一些。
        child: ColorPicker(
          color: Color(0xFF000000 | picked),
          isAlphaEnabled: false,
          isMoreButtonVisible: false,
          isColorChannelTextInputVisible: false,
          onChanged: (c) {
            picked = c.toARGB32() & 0xFFFFFF;
            _preview(_settings.acrylic.withTint(picked));
          },
        ),
      ),
    );
    _save(_settings.acrylic.withTint(picked));
  }

  @override
  Widget build(BuildContext context) {
    final options = _settings.acrylic;
    final custom = options.tint != null;
    final selectable = blurStyleSelectable;
    final summary = [
      if (selectable) options.blur.label,
      custom ? '自定义色调' : '色调跟随主题',
      '不透明度 ${options.opacity}%',
    ].join(' · ');
    // 只看界面上有的项：Windows 11 没有「模糊方式」，存着的值不该让「重置」亮起来。
    final resettable =
        custom ||
        options.opacity != AcrylicOptions.defaultOpacity ||
        (selectable && options.blur != AcrylicBlur.acrylic);
    return SettingsExpander(
      key: const PageStorageKey('acrylic-options'),
      initiallyExpanded: true,
      leading: const WindowsIcon(
        WindowsIcons.color,
        fallbackIcon: FluentIcons.color,
      ),
      header: const Text('毛玻璃效果'),
      description: Text(summary),
      items: [
        if (selectable)
          SettingsExpanderItem(
            header: const Text('模糊方式'),
            description: const Text('亚克力更朦胧，拖动窗口时临时换成普通模糊以免卡顿；普通模糊更通透'),
            trailing: ComboBox<AcrylicBlur>(
              value: options.blur,
              items: [
                for (final b in AcrylicBlur.values)
                  ComboBoxItem(value: b, child: Text(b.label)),
              ],
              onChanged: (b) {
                if (b != null) {
                  _save(_settings.acrylic.copyWith(blur: b));
                }
              },
            ),
          ),
        SettingsExpanderItem(
          header: const Text('色调'),
          description: Text(
            custom ? '自定义 ${_hex(options.tint!)}' : '浅色主题偏白、深色主题偏黑',
          ),
          trailing: ButtonRow(
            children: [
              if (custom)
                FlyoutTarget(
                  controller: _tintFlyout,
                  child: Tooltip(
                    message: '选择颜色',
                    // Tooltip 的标签落在按钮外面，读屏只读出「按钮」；改在按钮里标注。
                    excludeFromSemantics: true,
                    child: Button(
                      onPressed: _pickTint,
                      child: Semantics(
                        label: '选择颜色',
                        child: Container(
                          width: 24,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Color(0xFF000000 | options.tint!),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: FluentTheme.of(context)
                                  .resources
                                  .controlStrokeColorDefault,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ComboBox<bool>(
                value: custom,
                items: const [
                  ComboBoxItem(value: false, child: Text('跟随主题')),
                  ComboBoxItem(value: true, child: Text('自定义')),
                ],
                onChanged: (value) {
                  if (value == null || value == custom) {
                    return;
                  }
                  // 从当前看到的颜色开始自定义，切换时窗口不跳色。
                  _save(
                    _settings.acrylic.withTint(
                      value ? _settings.acrylic.tintFor(dark: _dark) : null,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        SettingsExpanderItem(
          header: const Text('不透明度'),
          description: Text(
            backdropOpaque.value
                ? '系统关闭了透明效果或开着高对比度，窗口暂时显示为纯色'
                : '越高越接近纯色，越低越透出窗口后面的内容',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 200,
                // 滑块自己只报数值（label 就是「75%」），读屏不知道调的是什么。
                child: MergeSemantics(
                  child: Semantics(
                    label: '不透明度',
                    child: Slider(
                      value: options.opacity.toDouble(),
                      max: 100,
                      divisions: 100,
                      label: '${options.opacity}%',
                      onChanged: (v) => _preview(
                        _settings.acrylic.copyWith(opacity: v.round()),
                      ),
                      onChangeEnd: (v) =>
                          _save(_settings.acrylic.copyWith(opacity: v.round())),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                child: ExcludeSemantics(
                  child: Text(
                    '${options.opacity}%',
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            ],
          ),
        ),
        SettingsExpanderItem(
          header: const Text('恢复默认'),
          description: Text(
            '${selectable ? '亚克力、' : ''}'
            '色调跟随主题、不透明度 ${AcrylicOptions.defaultOpacity}%',
          ),
          trailing: Button(
            onPressed: resettable ? () => _save(const AcrylicOptions()) : null,
            child: const Text('重置'),
          ),
        ),
      ],
    );
  }

  static String _hex(int rgb) =>
      '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
