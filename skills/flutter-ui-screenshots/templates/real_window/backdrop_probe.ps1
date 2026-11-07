# Window material probe for a DEMO build only (never the real app). ASCII only on purpose:
# PowerShell 5.1 reads BOM-less files as the ANSI code page.
#   powershell -NoProfile -File backdrop_probe.ps1 -Exe <demo>\build\windows\x64\runner\Debug\<name>.exe
#   [-Steps "shot:start;material:acrylic;shot:glass;..."] [-WindowsBuild 19045]
# Puts a card of wide red/green vertical stripes behind the demo window, then measures
# along an empty row of the title bar (or the splash card):
#   split = |R(red stripe) - R(green stripe)|: >= ~10 means the stripes show through
#           (frosted glass); ~0 means opaque (Mica samples the wallpaper, not windows).
#   edge  = 10-90% width in px of the red/green boundary: <= 4 sharp (see-through but NOT
#           blurred), >= 20 blurred. n/a when split is too small to measure.
# Startup frames are sampled for -StartupMs from the first visible frame, then -Steps run:
#   shot:<name>  material:mica|acrylic  acrylic:k=v,k=v[,persist=false]  theme
#   blur  focus  hide  show  move (keyboard move, captures <n>_moving mid-move)
param(
  [Parameter(Mandatory = $true)][string]$Exe,
  [string]$Steps = 'shot:start;theme;shot:theme;theme;material:acrylic;shot:glass;acrylic:opacity=30,persist=false;shot:preview30;acrylic:opacity=75;blur;shot:inactive;focus;hide;show;shot:restored;move;shot:moved;material:mica;shot:mica',
  [int]$WindowsBuild = 0,
  [int]$StartupMs = 1800,
  [string]$Out = (Join-Path $env:TEMP 'backdrop_probe_out')
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
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
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
  static Color Mean(Bitmap b, int x0, int x1, int y0, int y1) {
    long r = 0, g = 0, bl = 0, n = 0;
    for (int y = Math.Max(0, y0); y < Math.Min(b.Height, y1); y++)
      for (int x = Math.Max(0, x0); x < Math.Min(b.Width, x1); x++) {
        Color c = b.GetPixel(x, y); r += c.R; g += c.G; bl += c.B; n++;
      }
    return n == 0 ? Color.Black : Color.FromArgb((int)(r / n), (int)(g / n), (int)(bl / n));
  }
  static string Hex(Color c) { return string.Format("#{0:X2}{1:X2}{2:X2}", c.R, c.G, c.B); }
  public static string MeanHex(Bitmap b, Rectangle r) { return Hex(Mean(b, r.Left, r.Right, r.Top, r.Bottom)); }
  // Stripes start at screen x = cardLeft, period 2*w (red, green). winLeft: window's screen x.
  public static string Metrics(Bitmap b, int winLeft, int cardLeft, int w, int y, int h, int xFrom, int xTo) {
    for (int x = xFrom + w; x + w <= xTo; x++) {
      if (((x + winLeft - cardLeft) % w + w) % w != 0) continue;
      Color l = Mean(b, x - w * 3 / 4, x - w / 4, y, y + h), r = Mean(b, x + w / 4, x + w * 3 / 4, y, y + h);
      int split = Math.Abs(l.R - r.R);
      string edge = "n/a";
      if (split >= 8) {
        double lo = Math.Min(l.R, r.R) + split * 0.1, hi = Math.Min(l.R, r.R) + split * 0.9;
        int first = -1, last = -1;
        // Column means over the whole band: acrylic noise would otherwise widen the edge.
        for (int xx = x - w / 2; xx < x + w / 2; xx++) {
          double v = Mean(b, xx, xx + 1, y, y + h).R;
          if (v > lo && v < hi) { if (first < 0) first = xx; last = xx; }
        }
        edge = first < 0 ? "0px" : (last - first + 1) + "px";
      }
      return string.Format("split={0,3} edge={1,-5} l={2} r={3}", split, edge, Hex(l), Hex(r));
    }
    return "no stripe boundary in range";
  }
}
"@
[void][W]::SetProcessDpiAwarenessContext([IntPtr](-4))

# Only ever clear a folder this script created (marker file): a wrong -Out, or a demo
# project that happens to sit at the same path, must not be wiped.
$marker = Join-Path $Out '.backdrop_probe_out'
if (Test-Path $Out) {
  if (-not (Test-Path $marker)) { throw "$Out exists but is not a backdrop_probe output folder; pass another -Out" }
  Remove-Item $Out -Recurse -Force
}
New-Item -ItemType Directory -Force $Out | Out-Null
Set-Content -Path $marker -Value 'backdrop_probe.ps1 output' -Encoding ASCII
[Environment]::SetEnvironmentVariable('BACKDROP_PROBE_DIR', $Out, 'Process')
[Environment]::SetEnvironmentVariable('PROBE_WINDOWS_BUILD', $(if ($WindowsBuild) { "$WindowsBuild" } else { $null }), 'Process')

function Pump([int]$ms) {
  $end = (Get-Date).AddMilliseconds($ms)
  while ((Get-Date) -lt $end) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 15 }
}
function Wait-File([string]$name, [int]$sec = 30) {
  $f = Join-Path $Out $name
  $deadline = (Get-Date).AddSeconds($sec)
  while (-not (Test-Path $f)) {
    if ((Get-Date) -gt $deadline) { throw "timeout waiting for $name" }
    Pump 50
  }
}
function Log([string]$line) { Add-Content (Join-Path $Out 'capture.log') $line; $line }
$script:n = 0
function Send-Cmd([hashtable]$c) {
  $script:n++
  $tmp = Join-Path $Out "tmp_$($script:n)"
  Set-Content -Path $tmp -Value ($c | ConvertTo-Json -Compress -Depth 4) -Encoding ASCII
  Move-Item $tmp (Join-Path $Out "cmd_$($script:n).json")
  Wait-File "done_$($script:n)" 20
}

# Red/green stripe card over the whole primary work area (not topmost). It is
# activated before the demo starts, so the demo opens above it.
$StripeW = 160
$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$img = [System.Drawing.Bitmap]::new($wa.Width, $wa.Height)
$g = [System.Drawing.Graphics]::FromImage($img)
$red = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 230, 30, 30))
$green = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 30, 180, 30))
for ($x = 0; $x -lt $wa.Width; $x += $StripeW) {
  $brush = if ((($x / $StripeW) % 2) -eq 0) { $red } else { $green }
  $g.FillRectangle($brush, $x, 0, $StripeW, $wa.Height)
}
$g.Dispose()
$card = New-Object System.Windows.Forms.Form
$card.FormBorderStyle = 'None'
$card.StartPosition = 'Manual'
$card.ShowInTaskbar = $false
$card.Location = $wa.Location
$card.Size = $wa.Size
$card.BackgroundImage = $img
$card.BackgroundImageLayout = 'None'
$card.Show()
# Something to lose focus to (and a foreground process that can hand focus back).
$blur = New-Object System.Windows.Forms.Form
$blur.FormBorderStyle = 'None'
$blur.StartPosition = 'Manual'
$blur.Location = $wa.Location
$blur.Size = [System.Drawing.Size]::new(40, 40)
$blur.TopMost = $true
$blur.ShowInTaskbar = $false
$blur.BackColor = [System.Drawing.Color]::Magenta
$blur.Show()
Pump 200
[void][W]::Activate($card.Handle)
Pump 200

function Measure-Window([IntPtr]$h, [string]$name, [bool]$save) {
  $r = New-Object 'W+RECT'
  [void][W]::DwmGetWindowAttribute($h, 9, [ref]$r, 16)
  $w = $r.R - $r.L; $hh = $r.B - $r.T
  if ($w -le 0 -or $hh -le 0) { return }
  $bmp = [System.Drawing.Bitmap]::new($w, $hh)
  $gg = [System.Drawing.Graphics]::FromImage($bmp)
  $gg.CopyFromScreen($r.L, $r.T, 0, 0, [System.Drawing.Size]::new($w, $hh))
  $gg.Dispose()
  $s = [W]::GetDpiForWindow($h) / 96.0
  $splash = ($w / $s) -lt 700
  # Empty rows: splash card above the logo; main window title bar between title and buttons.
  if ($splash) { $y = 22; $x0 = 20; $x1 = ($w / $s) - 20 } else { $y = 14; $x0 = 220; $x1 = ($w / $s) - 160 }
  $m = [Px]::Metrics($bmp, $r.L, $wa.X, $StripeW, [int]($y * $s), [int](16 * $s), [int]($x0 * $s), [int]($x1 * $s))
  $side = if ($splash) { '' } else { ' side=' + [Px]::MeanHex($bmp, [System.Drawing.Rectangle]::new([int](12 * $s), [int](340 * $s), [int](48 * $s), [int](160 * $s))) }
  if ($save) { $bmp.Save((Join-Path $Out "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png) }
  $bmp.Dispose()
  [void](Log ('{0,-16} {1,-6} fg={2,-5} {3}{4}' -f $name, $(if ($splash) { 'splash' } else { 'main' }), ([W]::GetForegroundWindow() -eq $h), $m, $side))
}

$proc = Start-Process -FilePath $Exe -PassThru
$cursor = $null
try {
  $deadline = (Get-Date).AddSeconds(60)
  $hwnd = [IntPtr]::Zero
  while ($hwnd -eq [IntPtr]::Zero) {
    if ((Get-Date) -gt $deadline) { throw 'window never became visible' }
    $proc.Refresh(); $hwnd = $proc.MainWindowHandle
  }
  $t = [Diagnostics.Stopwatch]::StartNew()
  $k = 0
  while ($t.ElapsedMilliseconds -lt $StartupMs) {
    Measure-Window $hwnd ('t{0:D4}ms' -f $t.ElapsedMilliseconds) ($k % 4 -eq 0)
    $k++
    Start-Sleep -Milliseconds 100
  }
  Wait-File 'ready' 90

  foreach ($step in ($Steps -split ';')) {
    $op, $arg = $step -split ':', 2
    switch ($op) {
      'shot' { Pump 800; Measure-Window $hwnd $arg $true }
      'material' { Send-Cmd @{ op = 'material'; value = $arg } }
      'acrylic' {
        $value = @{}; $persist = $true
        foreach ($kv in ($arg -split ',')) {
          $key, $v = $kv -split '=', 2
          if ($key -eq 'persist') { $persist = $v -ne 'false'; continue }
          $num = 0
          $value[$key] = if ([int]::TryParse($v, [ref]$num)) { $num } else { $v }
        }
        Send-Cmd @{ op = 'acrylic'; value = $value; persist = $persist }
      }
      'theme' { Send-Cmd @{ op = 'theme' } }
      'blur' { [void][W]::Activate($blur.Handle) }
      'focus' { [void][W]::Activate($hwnd) }
      'hide' { Send-Cmd @{ op = 'hide' }; Pump 600 }
      'show' {
        # Like a tray click: the foreground process lets the demo take the foreground.
        [void][W]::Activate($blur.Handle)
        [void][W]::AllowSetForegroundWindow($proc.Id)
        Send-Cmd @{ op = 'show' }
      }
      'move' {
        # Keyboard move (SC_MOVE + arrows), posted to the demo window only: window_manager
        # sends move on WM_MOVING and moved on WM_EXITSIZEMOVE. The cursor jumps to the
        # window while moving and is put back afterwards.
        $cursor = New-Object 'W+POINT'
        [void][W]::GetCursorPos([ref]$cursor)
        [void][W]::Activate($hwnd)
        [void][W]::PostMessage($hwnd, 0x0112, [IntPtr]0xF010, [IntPtr]::Zero)
        Pump 400
        for ($i = 0; $i -lt 3; $i++) {
          [void][W]::PostMessage($hwnd, 0x0100, [IntPtr]0x27, [IntPtr]::Zero)
          [void][W]::PostMessage($hwnd, 0x0101, [IntPtr]0x27, [IntPtr]::Zero)
          Pump 150
        }
        Pump 500; Measure-Window $hwnd ("{0:D2}_moving" -f $script:n) $true
        [void][W]::PostMessage($hwnd, 0x0100, [IntPtr]0x0D, [IntPtr]::Zero)
        [void][W]::PostMessage($hwnd, 0x0101, [IntPtr]0x0D, [IntPtr]::Zero)
        Pump 400
        [void][W]::SetCursorPos($cursor.X, $cursor.Y); $cursor = $null
      }
      default { throw "unknown step: $step" }
    }
  }
  Send-Cmd @{ op = 'exit' }
  if (-not $proc.WaitForExit(8000)) { Stop-Process -Id $proc.Id -Force }
} finally {
  if (-not $proc.HasExited) {
    # Leave a keyboard move loop if a step failed mid-move.
    [void][W]::PostMessage($proc.MainWindowHandle, 0x0100, [IntPtr]0x1B, [IntPtr]::Zero)
    Stop-Process -Id $proc.Id -Force
  }
  if ($cursor) { [void][W]::SetCursorPos($cursor.X, $cursor.Y) }
  $card.Close(); $card.Dispose()
  $blur.Close(); $blur.Dispose()
  $log = Join-Path $Out 'driver.log'
  if (Test-Path $log) { Get-Content $log }
}
