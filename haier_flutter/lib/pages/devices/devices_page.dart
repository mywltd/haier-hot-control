import 'package:fluent_ui/fluent_ui.dart';

import '../../haier/haier_api.dart';
import '../../haier/haier_state.dart';
import '../../shell/app_shell.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/ff_responsive_grid.dart';
import '../../widgets/ff_status_badge.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/text_utils.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key, required this.onSelect});
  final ValueChanged<HaierDevice> onSelect;

  @override
  Widget build(BuildContext context) {
    final state = HaierScope.of(context);
    return ScaffoldPage(
      padding: kAppPagePadding,
      header: PageWidth(
        child: PageHeader(
          title: const Text('设备'),
          commandBar: FilledButton(
            onPressed: state.busy
                ? null
                : state.isDemo
                ? () => ShellNavScope.of(context).goTo(ShellPage.account)
                : state.fetchDevices,
            child: IconLabel(
              icon: state.isDemo ? WindowsIcons.contact : WindowsIcons.refresh,
              fallbackIcon: state.isDemo
                  ? FluentIcons.contact
                  : FluentIcons.refresh,
              label: state.isDemo
                  ? '登录账号'
                  : state.refreshing
                  ? '刷新中…'
                  : '刷新设备',
            ),
          ),
        ),
      ),
      content: PageBody(
        children: [
          if (state.isDemo) ...[
            const InfoBar(
              title: Text('演示模式'),
              content: Text('先了解采暖设备与能耗信息，登录海尔智家账号后即可控制真实设备。'),
            ),
            const SizedBox(height: 12),
          ],
          ErrorBanner(title: '设备更新失败', error: state.error),
          if (state.refreshing) ...[
            const ProgressBar(),
            const SizedBox(height: 12),
          ],
          FfResponsiveGrid(
            minItemWidth: 200,
            maxColumns: 3,
            children: [
              StatTile(
                label: '全部设备',
                value: '${state.devices.length} 台',
                caption: state.isDemo ? '演示设备' : '账号绑定的设备',
              ),
              StatTile(
                label: '在线设备',
                value: '${state.devices.where((d) => d.online).length} 台',
                caption: '可连接的采暖设备',
              ),
              StatTile(
                label: '正在运行',
                value:
                    '${state.devices.where((d) => state.valueOf(d.id, 'onOffStatus') == 'true').length} 台',
                caption: '已开启电源',
              ),
            ],
          ),
          const SettingsSectionHeader('我的采暖设备'),
          if (state.devices.isEmpty)
            const SettingsCard(
              leading: WindowsIcon(
                WindowsIcons.devices3,
                fallbackIcon: FluentIcons.devices3,
              ),
              header: Text('暂无设备'),
              description: Text('请确认海尔智家账号已绑定设备，然后刷新设备列表。'),
            )
          else
            FfResponsiveGrid(
              minItemWidth: 340,
              maxColumns: 2,
              children: [
                for (final device in state.devices)
                  _DeviceCard(
                    device: device,
                    state: state,
                    onSelect: () => onSelect(device),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.state,
    required this.onSelect,
  });
  final HaierDevice device;
  final HaierState state;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final res = theme.resources;
    final snap = state.allSnapshots[device.id] ?? const <String, String>{};
    final power = snap['onOffStatus'] == 'true';
    final secondary = theme.typography.caption?.copyWith(
      color: res.textFillColorSecondary,
    );
    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WindowsIcon(
                WindowsIcons.devices3,
                size: 24,
                fallbackIcon: FluentIcons.devices3,
                color: theme.accentColor.defaultBrushFor(theme.brightness),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NameText(device.name, style: theme.typography.bodyStrong),
                    Text(
                      device.productName.isEmpty
                          ? device.type
                          : device.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FfStatusBadge(
                label: device.online ? '在线' : '离线',
                status: device.online ? FfStatus.success : FfStatus.neutral,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前温度', style: secondary),
                    const SizedBox(height: 4),
                    Text(
                      '${snap['currentTemperature'] ?? '--'} ℃',
                      style: theme.typography.title,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('目标温度', style: secondary),
                    const SizedBox(height: 4),
                    Text(
                      '${snap['targetTemperature'] ?? '--'} ℃',
                      style: theme.typography.subtitle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('运行模式：${snap['operationMode'] ?? '暂无数据'}', style: secondary),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ToggleSwitch(
                  key: ValueKey('device-power-${device.id}'),
                  checked: power,
                  leadingContent: false,
                  semanticLabel: '${device.name}电源',
                  content: Text(power ? '已开机' : '已关机'),
                  onChanged: state.isDemo || state.busy || !device.online
                      ? null
                      : (on) => state.controlDevice(device.id, {
                          'onOffStatus': '$on',
                        }),
                ),
              ),
              Button(onPressed: onSelect, child: const Text('查看控制')),
            ],
          ),
        ],
      ),
    );
  }
}
