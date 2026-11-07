[CmdletBinding()]
param(
    [string]$FlutterPath = 'E:\FlutterSDK\flutter\bin\flutter.bat',
    [string]$InnoSetupPath = 'D:\Program Files (x86)\Inno Setup 6\ISCC.exe',
    [string]$DartDefineFile = 'config\haier.local.json',
    [switch]$Demo
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$iss = Join-Path $PSScriptRoot 'setup.iss'

foreach ($toolPath in @($FlutterPath, $InnoSetupPath)) {
    if (-not (Test-Path -LiteralPath $toolPath -PathType Leaf)) {
        throw "找不到构建工具：$toolPath；可通过 -FlutterPath / -InnoSetupPath 指定。"
    }
}

$pubspec = Get-Content -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') -Raw -Encoding UTF8
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$') {
    throw 'pubspec.yaml 必须指定 version: x.y.z+n。'
}
$version = $Matches[1]
$buildNumber = $Matches[2]
$expectedFileVersion = "$version.$buildNumber"

$buildArgs = @('build', 'windows', '--release')
if ($Demo) {
    Write-Host '构建演示版：未注入海尔接口签名配置。'
} else {
    if (-not [System.IO.Path]::IsPathRooted($DartDefineFile)) {
        $DartDefineFile = Join-Path $projectRoot $DartDefineFile
    }
    if (-not (Test-Path -LiteralPath $DartDefineFile -PathType Leaf)) {
        throw '找不到本地签名配置。请用 -DartDefineFile 指定配置文件，或用 -Demo 构建演示版。'
    }
    $config = Get-Content -LiteralPath $DartDefineFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($key in @('HAIER_APP_ID', 'HAIER_APP_KEY')) {
        $property = $config.PSObject.Properties[$key]
        if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            throw "签名配置缺少 $key。"
        }
    }
    $buildArgs += "--dart-define-from-file=$DartDefineFile"
    Write-Host "使用本地签名配置：$DartDefineFile"
}

Push-Location $projectRoot
try {
    Write-Host "构建海尔采暖控制台 $version+$buildNumber"
    & $FlutterPath @buildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter Windows 构建失败，退出码 $LASTEXITCODE。"
    }

    $releaseDir = Join-Path $projectRoot 'build\windows\x64\runner\Release'
    $appExe = Join-Path $releaseDir 'haier_heat.exe'
    if (-not (Test-Path -LiteralPath $appExe -PathType Leaf)) {
        throw "构建产物缺失：$appExe"
    }
    $appVersion = (Get-Item -LiteralPath $appExe).VersionInfo
    $actualFileVersion = '{0}.{1}.{2}.{3}' -f $appVersion.FileMajorPart, $appVersion.FileMinorPart, $appVersion.FileBuildPart, $appVersion.FilePrivatePart
    if ($actualFileVersion -ne $expectedFileVersion) {
        throw "程序版本不匹配：期望 $expectedFileVersion，实际 $actualFileVersion。"
    }
    $otherExecutables = @(Get-ChildItem -LiteralPath $releaseDir -Filter '*.exe' -File | Where-Object Name -ne 'haier_heat.exe')
    if ($otherExecutables.Count -gt 0) {
        throw 'Release 目录含其他 EXE，请检查旧产物并在必要时 flutter clean 后重试。'
    }
    foreach ($required in @('flutter_windows.dll', 'data\app.so', 'data\icudtl.dat', 'data\flutter_assets\assets\app_icon.ico')) {
        if (-not (Test-Path -LiteralPath (Join-Path $releaseDir $required) -PathType Leaf)) {
            throw "Release 文件缺失：$required"
        }
    }

    # 使用当前 CMake 构建所选 Visual Studio 的可再发行运行库，随应用本地部署。
    $cache = Get-Content -LiteralPath 'build\windows\x64\CMakeCache.txt' -Raw -Encoding UTF8
    if ($cache -notmatch '(?m)^CMAKE_GENERATOR_INSTANCE:INTERNAL=([^\r\n]+)') {
        throw '无法从 CMakeCache.txt 找到 Visual Studio 路径。'
    }
    $redistBase = Join-Path $Matches[1] 'VC\Redist\MSVC'
    $redistVersions = @(Get-ChildItem -LiteralPath $redistBase -Directory |
        Where-Object Name -Match '^\d+\.\d+\.\d+$' |
        Sort-Object { [version]$_.Name } -Descending)
    if ($redistVersions.Count -eq 0) {
        throw "找不到 Visual C++ Redistributable：$redistBase"
    }
    $crtDirs = @(Get-ChildItem -LiteralPath (Join-Path $redistVersions[0].FullName 'x64') -Directory |
        Where-Object Name -Match '^Microsoft\.VC\d+\.CRT$')
    if ($crtDirs.Count -ne 1) {
        throw '无法唯一确定 x64 Visual C++ CRT 目录。'
    }
    $crtFiles = @(Get-ChildItem -LiteralPath $crtDirs[0].FullName -Filter '*.dll' -File)
    foreach ($required in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
        if (-not ($crtFiles.Name -contains $required)) {
            throw "Visual C++ 运行库缺失：$required"
        }
    }
    foreach ($crtFile in $crtFiles) {
        Copy-Item -LiteralPath $crtFile.FullName -Destination $releaseDir -Force
    }
    Write-Host "已附带 $($crtFiles.Count) 个 Visual C++ 运行库文件。"

    $distDir = Join-Path $projectRoot 'dist'
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
    & $InnoSetupPath "/DMyAppVersion=$version" "/DMyAppBuild=$buildNumber" $iss
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup 编译失败，退出码 $LASTEXITCODE。"
    }
    $installer = Get-Item -LiteralPath (Join-Path $distDir "HaierHeat-Setup-$version.exe")
    $setupVersion = $installer.VersionInfo
    $actualSetupVersion = '{0}.{1}.{2}.{3}' -f $setupVersion.FileMajorPart, $setupVersion.FileMinorPart, $setupVersion.FileBuildPart, $setupVersion.FilePrivatePart
    if ($actualSetupVersion -ne $expectedFileVersion -or $installer.Length -eq 0) {
        throw '安装包版本或大小校验失败。'
    }
    $checksum = (Get-FileHash -LiteralPath $installer.FullName -Algorithm SHA256).Hash
    $checksumPath = "$($installer.FullName).sha256"
    [System.IO.File]::WriteAllText($checksumPath, "$checksum  $($installer.Name)`r`n", [System.Text.Encoding]::ASCII)
    Write-Host "安装包：$($installer.FullName) ($([math]::Round($installer.Length / 1MB, 2)) MiB)"
    Write-Host "文件版本：$actualSetupVersion"
    Write-Host "SHA256：$checksum"
} finally {
    Pop-Location
}
