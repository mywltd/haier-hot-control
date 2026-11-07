# Real-window probe: launches a DEMO build (never the real app), drives it through
# focus -> blur -> refocus -> hide to tray -> show -> blur -> refocus, and logs the
# mean colour of sample regions for each step plus a PNG per step.
# ASCII only on purpose: PowerShell 5.1 reads BOM-less files as the ANSI code page.
#   powershell -NoProfile -File capture.ps1 -Exe <demo>\build\windows\x64\runner\Debug\<name>.exe
# -Samples: logical-pixel rects relative to the window, "name=x,y,w,h;name=x,y,w,h".
# The defaults are an empty strip of the shell's sidebar and the middle of the title bar.
param(
  [Parameter(Mandatory = $true)][string]$Exe,
  [string]$Out = (Join-Path $env:TEMP 'window_probe'),
  [string]$Samples = 'sidebar=12,340,48,180;title=400,10,400,28'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class W {
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool AllowSetForegroundWindow(int pid);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int size);
  // SetForegroundWindow from a background process is silently refused (foreground
  // lock); attaching to the foreground thread's input queue gets around it.
  public static bool Activate(IntPtr target) {
    IntPtr fg = GetForegroundWindow();
    if (fg == target) return true;
    uint me = GetCurrentThreadId();
    uint fgThread = GetWindowThreadProcessId(fg, IntPtr.Zero);
    uint tThread = GetWindowThreadProcessId(target, IntPtr.Zero);
    if (fgThread != 0 && fgThread != me) AttachThreadInput(me, fgThread, true);
    if (tThread != me) AttachThreadInput(me, tThread, true);
    BringWindowToTop(target);
    SetForegroundWindow(target);
    if (tThread != me) AttachThreadInput(me, tThread, false);
    if (fgThread != 0 && fgThread != me) AttachThreadInput(me, fgThread, false);
    return GetForegroundWindow() == target;
  }
}
"@
Add-Type -ReferencedAssemblies System.Drawing @"
using System;
using System.Drawing;
public static class Px {
  public static string Mean(Bitmap bmp, Rectangle r) {
    r.Intersect(new Rectangle(0, 0, bmp.Width, bmp.Height));
    if (r.Width <= 0 || r.Height <= 0) return "n/a";
    long sr = 0, sg = 0, sb = 0, n = 0;
    for (int y = r.Top; y < r.Bottom; y += 2)
      for (int x = r.Left; x < r.Right; x += 2) {
        Color c = bmp.GetPixel(x, y);
        sr += c.R; sg += c.G; sb += c.B; n++;
      }
    return string.Format("#{0:X2}{1:X2}{2:X2}", sr / n, sg / n, sb / n);
  }
}
"@
# Per-monitor DPI aware, so window rects and screen pixels agree.
[void][W]::SetProcessDpiAwarenessContext([IntPtr](-4))

# Only ever clear a folder this script created (marker file), never e.g. the demo project.
$marker = Join-Path $Out '.window_probe_out'
if (Test-Path $Out) {
  if (-not (Test-Path $marker)) { throw "$Out exists but is not a window_probe output folder; pass another -Out" }
  Remove-Item $Out -Recurse -Force
}
New-Item -ItemType Directory -Force $Out | Out-Null
Set-Content -Path $marker -Value 'capture.ps1 output' -Encoding ASCII
[Environment]::SetEnvironmentVariable('WINDOW_PROBE_DIR', $Out, 'Process')

function Pump([int]$ms) {
  $end = (Get-Date).AddMilliseconds($ms)
  while ((Get-Date) -lt $end) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 15 }
}
function Wait-File([string]$name, [int]$sec = 30) {
  $f = Join-Path $Out $name
  $deadline = (Get-Date).AddSeconds($sec)
  while (-not (Test-Path $f)) {
    if ((Get-Date) -gt $deadline) { throw "timeout waiting for $name" }
    Pump 100
  }
}
function Send-Cmd([string]$name) { Set-Content -Path (Join-Path $Out $name) -Value '1' }

function Capture([string]$name) {
  Pump 700  # let DWM finish its Mica crossfade
  $r = New-Object 'W+RECT'
  # DWMWA_EXTENDED_FRAME_BOUNDS: the visible frame, without the invisible resize border.
  [void][W]::DwmGetWindowAttribute($script:hwnd, 9, [ref]$r, 16)
  $w = $r.R - $r.L; $h = $r.B - $r.T
  $bmp = [System.Drawing.Bitmap]::new($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.L, $r.T, 0, 0, [System.Drawing.Size]::new($w, $h))
  $g.Dispose()
  $bmp.Save((Join-Path $Out "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $s = [W]::GetDpiForWindow($script:hwnd) / 96.0
  $parts = foreach ($spec in ($Samples -split ';')) {
    $label, $v = $spec -split '=', 2
    $n = $v -split ',' | ForEach-Object { [int]([double]$_ * $s) }
    '{0}={1}' -f $label, [Px]::Mean($bmp, [System.Drawing.Rectangle]::new($n[0], $n[1], $n[2], $n[3]))
  }
  $line = '{0,-11} fg={1,-5} {2}' -f $name, ([W]::GetForegroundWindow() -eq $script:hwnd), ($parts -join ' ')
  $bmp.Dispose()
  Add-Content (Join-Path $Out 'capture.log') $line
  $line
}

# A tiny topmost form of our own: something for the app to lose focus to, and a
# foreground process that can grant the app foreground rights (as the tray icon does).
$blur = New-Object System.Windows.Forms.Form
$blur.FormBorderStyle = 'None'
$blur.StartPosition = 'Manual'
$blur.Location = [System.Drawing.Point]::new(0, 0)
$blur.Size = [System.Drawing.Size]::new(40, 40)
$blur.TopMost = $true
$blur.ShowInTaskbar = $false
$blur.BackColor = [System.Drawing.Color]::Magenta
$blur.Show()

$proc = Start-Process -FilePath $Exe -PassThru
try {
  Wait-File 'ready' 90
  $script:hwnd = [IntPtr]::Zero
  for ($i = 0; $i -lt 50 -and $script:hwnd -eq [IntPtr]::Zero; $i++) {
    $proc.Refresh(); $script:hwnd = $proc.MainWindowHandle; Pump 100
  }
  if ($script:hwnd -eq [IntPtr]::Zero) { throw 'no main window' }
  [void][W]::Activate($script:hwnd); Capture '1_start'
  [void][W]::Activate($blur.Handle); Capture '2_blur'
  [void][W]::Activate($script:hwnd); Capture '3_refocus'
  Send-Cmd 'cmd_hide'; Wait-File 'done_hide'; Pump 600
  # Like a tray click: the foreground process lets the app take the foreground.
  [void][W]::Activate($blur.Handle)
  [void][W]::AllowSetForegroundWindow($proc.Id)
  Send-Cmd 'cmd_show'; Wait-File 'done_show'
  Capture '4_restored'
  [void][W]::Activate($blur.Handle); Capture '5_blur'
  [void][W]::Activate($script:hwnd); Capture '6_refocus'
  Send-Cmd 'cmd_exit'
  if (-not $proc.WaitForExit(8000)) { Stop-Process -Id $proc.Id -Force }
} finally {
  if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
  $blur.Close(); $blur.Dispose()
  $log = Join-Path $Out 'driver.log'
  if (Test-Path $log) { Get-Content $log }
}
