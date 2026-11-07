import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../../haier/haier_state.dart';
import '../../shell/app_shell.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/ff_status_badge.dart';
import '../../widgets/settings_card.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _validation;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final phone = _phone.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(phone) || _password.text.isEmpty) {
      setState(() => _validation = '请输入 11 位手机号和密码。');
      return;
    }
    setState(() => _validation = null);
    final ok = await HaierScope.of(context).login(phone, _password.text);
    if (!mounted) return;
    if (ok) {
      _password.clear();
      ShellNavScope.of(context).goTo(ShellPage.devices);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = HaierScope.of(context);
    final theme = FluentTheme.of(context);
    final phone = state.api.phone;
    final masked = phone.length == 11
        ? '${phone.substring(0, 3)}****${phone.substring(7)}'
        : '海尔智家账号';
    return ScaffoldPage(
      padding: kAppPagePadding,
      header: const PageWidth(child: PageHeader(title: Text('账号'))),
      content: PageBody(
        children: [
          if (!state.isDemo) ...[
            SettingsCard(
              leading: const WindowsIcon(
                WindowsIcons.contact,
                fallbackIcon: FluentIcons.contact,
              ),
              header: Text(masked),
              description: const Text('已登录海尔智家，设备与状态来自云端'),
              trailing: const FfStatusBadge(
                label: '已登录',
                status: FfStatus.success,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ButtonRow(
                children: [
                  FilledButton(
                    onPressed: () =>
                        ShellNavScope.of(context).goTo(ShellPage.devices),
                    child: const Text('查看设备'),
                  ),
                  Button(
                    onPressed: state.busy ? null : state.logout,
                    child: const Text('退出登录'),
                  ),
                ],
              ),
            ),
          ] else ...[
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: WindowsIcon(
                          WindowsIcons.contact,
                          size: 32,
                          fallbackIcon: FluentIcons.contact,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('登录海尔智家', style: theme.typography.subtitle),
                      const SizedBox(height: 8),
                      Text(
                        '使用海尔智家账号，查看和控制已绑定的采暖设备。',
                        style: theme.typography.body?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ErrorBanner(
                        title: '无法登录',
                        error: _validation ?? state.error,
                      ),
                      InfoLabel(
                        label: '手机号',
                        child: SizedBox(
                          height: 32,
                          child: TextBox(
                            key: const ValueKey('login-phone'),
                            controller: _phone,
                            placeholder: '请输入手机号',
                            maxLines: 1,
                            enabled: !state.loading,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InfoLabel(
                        label: '密码',
                        child: SizedBox(
                          height: 32,
                          child: PasswordBox(
                            key: const ValueKey('login-password'),
                            controller: _password,
                            placeholder: '请输入密码',
                            enabled: !state.loading,
                            revealMode: PasswordRevealMode.peek,
                            onSubmitted: state.loading ? null : (_) => _login(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: state.loading ? null : _login,
                        child: Text(state.loading ? '正在登录…' : '登录'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '密码仅用于本次登录，不会保存在本地。',
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
        ],
      ),
    );
  }
}
