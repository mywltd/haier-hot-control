import 'package:fluent_ui/fluent_ui.dart';

import '../../widgets/settings_card.dart';
import '../../widgets/text_utils.dart';
import '../../widgets/toast.dart';

/// 示例列表页：页头操作 + 搜索框 + 懒加载列表 + 空状态 + 新增弹窗。
class ListPage extends StatefulWidget {
  const ListPage({super.key});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final _search = TextEditingController();
  final _items = ['第一项', '第二项', '一个名字特别特别特别长的条目会被截断'];
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _AddDialog(),
    );
    if (name == null || !mounted) {
      return;
    }
    setState(() => _items.insert(0, name));
    await showToast(context, '已添加「${ellipsize(name)}」', severity: InfoBarSeverity.success);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final gutter = PageHeader.horizontalPadding(context);
    final shown = [for (final i in _items) if (i.contains(_query.trim())) i];
    return ScaffoldPage(
      header: PageWidth(
        child: PageHeader(
          title: const Text('列表'),
          commandBar: FilledButton(
            onPressed: _add,
            child: const IconLabel(
              icon: WindowsIcons.add,
              fallbackIcon: FluentIcons.add,
              label: '新增',
            ),
          ),
        ),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 搜索框放在内容区，不放页头：页头的 commandBar 最多只占一半宽度，窄窗口会溢出。
          PageWidth(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox(
                  width: 280,
                  child: TextBox(
                    controller: _search,
                    maxLines: 1,
                    placeholder: '搜索',
                    onChanged: (v) => setState(() => _query = v),
                    prefix: const Padding(
                      padding: EdgeInsetsDirectional.only(start: 8),
                      child: WindowsIcon(
                        WindowsIcons.search,
                        size: 14,
                        fallbackIcon: FluentIcons.search,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                // 空状态：居中一句话，不堆装饰。
                ? Center(child: Text('没有匹配的条目', style: theme.typography.body))
                : LayoutBuilder(
                    builder: (context, constraints) => ListView.separated(
                      padding: pageListPadding(context, constraints.maxWidth, bottom: 24),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(height: kCardSpacing),
                      itemBuilder: (context, i) => SettingsCard(
                        leading: const WindowsIcon(
                          WindowsIcons.document,
                          fallbackIcon: FluentIcons.document,
                        ),
                        header: NameText(shown[i]),
                        description: Text('第 ${i + 1} 条'),
                        trailing: Button(
                          onPressed: () => setState(() => _items.remove(shown[i])),
                          child: const Text('删除'),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 弹窗：InfoLabel + 单行 TextBox（外包 SizedBox(height: 32)）；取消在左，主操作在右。
class _AddDialog extends StatefulWidget {
  const _AddDialog();

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请填写名称');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ContentDialog(
      title: const Text('新增条目'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoLabel(
            label: '名称',
            child: SizedBox(
              height: 32,
              child: TextBox(
                controller: _name,
                maxLines: 1,
                autofocus: true,
                onSubmitted: (_) => _save(),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.systemFillColorCritical,
              ),
            ),
          ],
        ],
      ),
      actions: [
        Button(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}
