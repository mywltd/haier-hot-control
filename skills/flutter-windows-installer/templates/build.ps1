$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

$flutter = "E:\FlutterSDK\flutter\bin\flutter.bat"
$iscc = "D:\Program Files (x86)\Inno Setup 6\ISCC.exe"
$iss = Join-Path $PSScriptRoot "setup.iss"

if (-not (Test-Path $flutter)) {
  throw "未找到 Flutter：$flutter"
}
if (-not (Test-Path $iscc)) {
  throw "未找到 Inno Setup：$iscc"
}

# 版本号以 pubspec.yaml 为准：version: 1.0.1+2 → 程序版本 1.0.1.2，安装包 1.0.1。
$pubspec = Get-Content (Join-Path $root "pubspec.yaml") -Raw -Encoding UTF8
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)') {
  throw "pubspec.yaml 里没有 version"
}
$version = $Matches[1]
Write-Host "打包版本 $version"

& $flutter build windows --release
if ($LASTEXITCODE -ne 0) {
  throw "Flutter Windows 构建失败"
}

New-Item -ItemType Directory -Force -Path (Join-Path $root "dist") | Out-Null
& $iscc "/DMyAppVersion=$version" $iss
if ($LASTEXITCODE -ne 0) {
  throw "Inno Setup 编译失败"
}

Get-ChildItem (Join-Path $root "dist\*-$version.exe") | ForEach-Object {
  Write-Host "安装包: $($_.FullName) ($([math]::Round($_.Length / 1MB, 1)) MB)"
}
