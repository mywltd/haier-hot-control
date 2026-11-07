"""Create an isolated shell demo for native-window validation; never run real services."""
import argparse
from pathlib import Path
import shutil

parser = argparse.ArgumentParser()
parser.add_argument('destination', type=Path)
parser.add_argument('screenshot_skill', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
destination = args.destination.resolve()
destination.mkdir(parents=True, exist_ok=False)
for name in ('lib', 'assets', 'windows'):
    shutil.copytree(root / name, destination / name,
                    ignore=shutil.ignore_patterns('ephemeral', '.plugin_symlinks'))
shutil.copy2(root / 'pubspec.lock', destination / 'pubspec.lock')
(destination / 'pubspec.yaml').write_text(
    (root / 'pubspec.yaml').read_text(encoding='utf-8').replace('name: haier_heat', 'name: haier_shell_probe'),
    encoding='utf-8')

for name, substitutions in {
    'windows/CMakeLists.txt': [('haier_heat', 'haier_shell_probe')],
    'windows/runner/Runner.rc': [('com.haier.heat', 'CodexShellProbe'), ('haier_heat', 'haier_shell_probe')],
    'lib/app/launch_at_startup.dart': [("'HaierHeat'", "'HaierShellProbe'")],
}.items():
    path = destination / name
    value = path.read_text(encoding='utf-8')
    for before, after in substitutions:
        value = value.replace(before, after)
    path.write_text(value, encoding='utf-8')

(destination / 'lib/main.dart').write_text('''
import 'package:flutter/widgets.dart';
import 'app/app.dart';
import 'app/shell_settings.dart';
import 'app/window_bootstrap.dart';
import 'window_probe_driver.dart';
import 'backdrop_probe_driver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapDesktopWindow();
  await ShellSettings.instance.load();
  await ShellSettings.instance.setThemeMode('light');
  runApp(App(startup: Future.value()));
  runWindowProbeDriver();
  runBackdropProbeDriver();
}
''', encoding='utf-8')

for name in ('window_probe_driver.dart', 'backdrop_probe_driver.dart'):
    source = args.screenshot_skill / 'templates/real_window' / name
    value = source.read_text(encoding='utf-8')
    value = value.replace("import 'package:window_manager/window_manager.dart';",
                          "import 'app/desktop_window.dart';")
    value = value.replace('windowManager.addListener(_EventLog(write));',
                          "desktopWindow.addListener((event) => write('event ${event.runtimeType}'));")
    value = value.replace('await windowManager.isFocused()', 'desktopWindow.isFocused')
    value = value.split('class _EventLog')[0]
    (destination / 'lib' / name).write_text(value, encoding='utf-8')

for name in ('capture.ps1', 'backdrop_probe.ps1'):
    value = (args.screenshot_skill / 'templates/real_window' / name).read_text(encoding='utf-8')
    value = value.replace('Start-Process -FilePath $Exe -PassThru',
                          'Start-Process -FilePath $Exe -WindowStyle Hidden -PassThru')
    if name == 'backdrop_probe.ps1':
        # Keep the stripe card directly behind the probe. Other desktop windows
        # can otherwise invalidate blur measurements even with a focused probe.
        value = value.replace("'shot' { Pump 800; Measure-Window $hwnd $arg $true }",
                              "'shot' { [void][W]::Activate($card.Handle); Pump 150; [void][W]::Activate($hwnd); Pump 800; Measure-Window $hwnd $arg $true }")
        value = value.replace("'focus' { [void][W]::Activate($hwnd) }",
                              "'focus' { [void][W]::Activate($card.Handle); Pump 150; [void][W]::Activate($hwnd) }")
    (destination / name).write_text(value, encoding='utf-8')

print(destination)
