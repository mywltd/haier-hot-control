import 'package:fluent_ui/fluent_ui.dart';

import '../../haier/haier_state.dart';
import '../../shell/app_shell.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/ff_responsive_grid.dart';
import '../../widgets/ff_status_badge.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/text_utils.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});
  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  double? _temperature;
  String? _deviceId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = HaierScope.of(context).currentDeviceId;
    if (id != _deviceId) {
      _deviceId = id;
      _temperature = null;
    }
  }

  Future<void> _applyTemperature() async {
    final value = _temperature;
    if (value == null) return;
    final ok = await HaierScope.of(context).setTemp(value.round());
    if (mounted && ok) setState(() => _temperature = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = HaierScope.of(context);
    final device = state.currentDevice;
    final theme = FluentTheme.of(context);
    if (device == null) {
      return ScaffoldPage(
        padding: kAppPagePadding,
        header: const PageWidth(child: PageHeader(title: Text('控制'))),
        content: PageBody(
          children: [
            SettingsCard(
              leading: const WindowsIcon(
                WindowsIcons.devices3,
                fallbackIcon: FluentIcons.devices3,
              ),
              header: const Text('未选择设备'),
              description: const Text('先从设备页选择一台采暖设备，查看温度、运行状态和用电情况。'),
              trailing: FilledButton(
                onPressed: () =>
                    ShellNavScope.of(context).goTo(ShellPage.devices),
                child: const Text('选择设备'),
              ),
            ),
          ],
        ),
      );
    }
    final snap = state.snapshot;
    final power = snap['onOffStatus'] == 'true';
    final target = (double.tryParse(snap['targetTemperature'] ?? '') ?? 45)
        .clamp(30.0, 80.0);
    final shownTemperature = _temperature ?? target;
    final mode = snap['operationMode'] ?? '';
    final canControl = !state.isDemo && !state.busy && device.online;
    final modes = {if (mode.isNotEmpty) mode, '制热', '制冷', '送风', '除湿', '自动'};
    return ScaffoldPage(
      padding: kAppPagePadding,
      header: PageWidth(
        child: PageHeader(
          title: const Text('控制'),
          commandBar: ButtonRow(
            children: [
              Button(
                onPressed: state.isDemo || state.busy
                    ? null
                    : state.refreshSnapshot,
                child: Text(state.refreshing ? '刷新中…' : '刷新状态'),
              ),
              FilledButton(
                onPressed:
                    canControl && _temperature != null && _temperature != target
                    ? _applyTemperature
                    : null,
                child: Text(state.sendingControl ? '应用中…' : '应用温度'),
              ),
            ],
          ),
        ),
      ),
      content: PageBody(
        children: [
          if (state.isDemo) ...[
            InfoBar(
              title: const Text('演示模式'),
              content: const Text('当前展示示例状态与能耗，登录后可控制真实设备。'),
              action: Button(
                onPressed: () =>
                    ShellNavScope.of(context).goTo(ShellPage.account),
                child: const Text('去登录'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ErrorBanner(title: '操作未完成', error: state.error),
          SettingsCard(
            leading: const WindowsIcon(
              WindowsIcons.devices3,
              fallbackIcon: FluentIcons.devices3,
            ),
            header: NameText(device.name),
            description: Text(
              '${device.productName.isEmpty ? device.type : device.productName} · ${device.id}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: ButtonRow(
              children: [
                FfStatusBadge(
                  label: device.online ? '在线' : '离线',
                  status: device.online ? FfStatus.success : FfStatus.neutral,
                ),
                Button(
                  onPressed: () =>
                      ShellNavScope.of(context).goTo(ShellPage.devices),
                  child: const Text('切换设备'),
                ),
              ],
            ),
          ),
          const SettingsSectionHeader('温度与运行'),
          FfResponsiveGrid(
            minItemWidth: 180,
            maxColumns: 4,
            children: [
              StatTile(
                label: '当前温度',
                value: '${snap['currentTemperature'] ?? '--'} ℃',
                caption: '设备温度读数',
              ),
              StatTile(
                label: '目标温度',
                value: '${snap['targetTemperature'] ?? '--'} ℃',
                caption: '设备当前设定值',
              ),
              StatTile(
                label: '运行模式',
                value: mode.isEmpty ? '--' : mode,
                caption: '当前工作模式',
              ),
              StatTile(
                label: '运行状态',
                value: power ? '运行中' : '已停止',
                caption: power ? '电源已开启' : '电源已关闭',
                icon: power
                    ? WindowsIcons.power_button
                    : WindowsIcons.circle_ring,
                fallbackIcon: FluentIcons.power_button,
                iconColor: power
                    ? theme.resources.systemFillColorSuccess
                    : theme.resources.textFillColorSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SettingsCard(
            leading: const WindowsIcon(
              WindowsIcons.power_button,
              fallbackIcon: FluentIcons.power_button,
            ),
            header: const Text('设备电源'),
            description: const Text('控制当前采暖设备的开关机状态'),
            trailing: ToggleSwitch(
              checked: power,
              leadingContent: true,
              semanticLabel: '${device.name}电源',
              content: Text(power ? '开' : '关'),
              onChanged: canControl ? state.setPower : null,
            ),
          ),
          const SizedBox(height: kCardSpacing),
          SettingsCard(
            leading: const WindowsIcon(
              WindowsIcons.brightness,
              fallbackIcon: FluentIcons.brightness,
            ),
            header: const Text('目标温度'),
            description: Text(
              _temperature == null
                  ? '30–80 ℃，调整后点击「应用温度」'
                  : '待应用 ${shownTemperature.round()} ℃',
            ),
            trailing: SizedBox(
              width: 290,
              child: Row(
                children: [
                  Expanded(
                    child: MergeSemantics(
                      child: Semantics(
                        label: '目标温度',
                        child: Slider(
                          key: const ValueKey('target-temperature'),
                          min: 30,
                          max: 80,
                          divisions: 50,
                          value: shownTemperature,
                          label: '${shownTemperature.round()} ℃',
                          onChanged: canControl
                              ? (value) => setState(() => _temperature = value)
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 48,
                      child: Text(
                        '${shownTemperature.round()} ℃',
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: kCardSpacing),
          SettingsCard(
            leading: const WindowsIcon(
              WindowsIcons.brightness,
              fallbackIcon: FluentIcons.sunny,
            ),
            header: const Text('运行模式'),
            description: const Text('选择后应用到当前设备'),
            trailing: ComboBox<String>(
              value: mode.isEmpty ? null : mode,
              placeholder: const Text('选择模式'),
              items: [
                for (final value in modes)
                  ComboBoxItem(value: value, child: Text(value)),
              ],
              onChanged: canControl
                  ? (value) {
                      if (value != null) state.setMode(value);
                    }
                  : null,
            ),
          ),
          const SettingsSectionHeader('电力与能耗'),
          FfResponsiveGrid(
            minItemWidth: 180,
            maxColumns: 4,
            children: [
              StatTile(
                label: '运行功率',
                value: '${snap['runPower'] ?? '--'} W',
                caption: '当前功率',
              ),
              StatTile(
                label: '今日用电',
                value: state.todayKwh == null
                    ? '--'
                    : '${state.todayKwh!.toStringAsFixed(1)} kWh',
                caption: state.isDemo ? '演示数据' : '按累计电量采样估算',
              ),
              StatTile(
                label: '累计电量',
                value: '${snap['energySaved'] ?? '--'} kWh',
                caption: '设备累计读数',
              ),
              StatTile(
                label: '水流量',
                value: '${snap['waterFlux'] ?? '--'} L/min',
                caption: '当前循环水流量',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('近 7 天用电', style: theme.typography.bodyStrong),
                const SizedBox(height: 4),
                Text(
                  state.isDemo ? '演示数据 · 单位 kWh' : '单位 kWh · 缺少采样的日期显示为 —',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _DailyChart(data: state.dailyKwh),
              ],
            ),
          ),
          const SettingsSectionHeader('设备状态'),
          SettingsCard(
            leading: const WindowsIcon(
              WindowsIcons.brightness,
              fallbackIcon: FluentIcons.sunny,
            ),
            header: const Text('运行环境'),
            description: Text(
              '环境温度 ${snap['envTemperature'] ?? '--'} ℃ · 运行时长 ${snap['systemRunTime'] ?? '--'} 分钟',
            ),
            trailing: Wrap(
              spacing: 8,
              children: [
                FfStatusBadge(
                  label:
                      '电辅热${snap['electricHeatingStatus'] == 'true' ? '开启' : '关闭'}',
                  status: snap['electricHeatingStatus'] == 'true'
                      ? FfStatus.success
                      : FfStatus.neutral,
                ),
                FfStatusBadge(
                  label:
                      '泵加热${snap['pumpHeatingStatus'] == 'true' ? '开启' : '关闭'}',
                  status: snap['pumpHeatingStatus'] == 'true'
                      ? FfStatus.success
                      : FfStatus.neutral,
                ),
              ],
            ),
          ),
          const SizedBox(height: kCardSpacing),
          SettingsExpander(
            key: PageStorageKey('device-details-${device.id}'),
            leading: const WindowsIcon(
              WindowsIcons.info,
              fallbackIcon: FluentIcons.info,
            ),
            header: const Text('状态明细'),
            description: Text('${snap.length} 项设备属性'),
            items: [
              for (final item in snap.entries)
                SettingsExpanderItem(
                  header: Text(
                    _attributeLabels[item.key] ?? item.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: SelectableText(item.value),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

const _attributeLabels = {
  'onOffStatus': '电源状态',
  'currentTemperature': '当前温度',
  'targetTemperature': '目标温度',
  'operationMode': '运行模式',
  'outWaterTemp': '出水温度',
  'backWaterTemp': '回水温度',
  'runPower': '运行功率',
  'energySaved': '累计电量',
  'waterFlux': '水流量',
  'envTemperature': '环境温度',
  'systemRunTime': '运行时长',
  'electricHeatingStatus': '电辅热状态',
  'pumpHeatingStatus': '泵加热状态',
  'workStatus': '工作状态',
};

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.data});
  final List<Map<String, dynamic>> data;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final values = data
        .map((e) => (e['kwh'] as num?)?.toDouble() ?? 0)
        .toList();
    final maximum = values.fold<double>(1, (a, b) => a > b ? a : b);
    final accent = theme.accentColor.defaultBrushFor(theme.brightness);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < data.length; i++)
          Expanded(
            child: Semantics(
              label:
                  '${data[i]['date']}，${data[i]['kwh'] == null ? '暂无采样' : '${values[i].toStringAsFixed(1)} 千瓦时'}',
              child: ExcludeSemantics(
                child: Column(
                  children: [
                    Text(
                      data[i]['kwh'] == null
                          ? '—'
                          : values[i].toStringAsFixed(1),
                      style: theme.typography.caption,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 88,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 32,
                          height: values[i] / maximum * 84 + 2,
                          decoration: BoxDecoration(
                            color: data[i]['kwh'] == null
                                ? theme.resources.cardStrokeColorDefault
                                : accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${data[i]['date']}',
                      style: theme.typography.caption?.copyWith(
                        color: theme.resources.textFillColorSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
