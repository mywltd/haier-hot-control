import 'package:fluent_ui/fluent_ui.dart';

import '../../shell/app_shell.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/toast.dart';

/// 示例首页：页头 + 提示条 + 统计卡 + 分组设置卡。照着这个结构替换成业务内容。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _enabled = true;

  @override
  Widget build(BuildContext context) {
    final res = FluentTheme.of(context).resources;
    return ScaffoldPage(
      // 页头必须包 PageWidth，标题才和下面居中的内容列左缘对齐。
      header: PageWidth(
        child: PageHeader(
          title: const Text('首页'),
          commandBar: FilledButton(
            onPressed: () => showToast(
              context,
              '主操作：每屏只放一个 FilledButton',
              severity: InfoBarSeverity.success,
            ),
            child: const IconLabel(
              icon: WindowsIcons.play,
              fallbackIcon: FluentIcons.play,
              label: '开始',
            ),
          ),
        ),
      ),
      content: PageBody(
        children: [
          InfoBar(
            title: const Text('欢迎'),
            content: const Text('这是基于 Fluent 壳子的示例页，替换成自己的内容即可。'),
            severity: InfoBarSeverity.info,
            action: Button(
              onPressed: () => ShellNavScope.of(context).goTo(ShellPage.settings),
              child: const Text('去设置'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '连接',
                  value: '已连接',
                  caption: '远程服务',
                  icon: WindowsIcons.completed,
                  fallbackIcon: FluentIcons.completed,
                  iconColor: res.systemFillColorSuccess,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: StatTile(label: '今日', value: '128', caption: '处理的条目'),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: StatTile(label: '最近', value: '暂无', caption: '还没有记录'),
              ),
            ],
          ),
          const SettingsSectionHeader('功能'),
          SettingsCard(
            leading: const WindowsIcon(
              WindowsIcons.sync,
              fallbackIcon: FluentIcons.sync,
            ),
            header: const Text('自动刷新'),
            description: Text(_enabled ? '已开启 · 每 5 分钟刷新一次' : '已关闭'),
            trailing: ToggleSwitch(
              checked: _enabled,
              leadingContent: true,
              semanticLabel: '自动刷新',
              content: Text(_enabled ? '开' : '关'),
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ),
          const SizedBox(height: kCardSpacing),
          SettingsCard(
            leading: const WindowsIcon(
              WindowsIcons.bulleted_list,
              fallbackIcon: FluentIcons.bulleted_list,
            ),
            header: const Text('列表示例'),
            description: const Text('搜索、空状态、新增弹窗的写法'),
            trailing: Button(
              onPressed: () => ShellNavScope.of(context).goTo(ShellPage.list),
              child: const Text('打开'),
            ),
          ),
        ],
      ),
    );
  }
}
