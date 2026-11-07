; UTF-8 with BOM. 海尔采暖控制台的按用户安装包。
; AppId 是永久升级标识，不要在后续发版时重新生成。
#define MyAppName "海尔采暖控制台"
#define MyAppPublisher "海尔采暖控制台"
#define MyAppExeName "haier_heat.exe"
#define MyAppId "{{1213590F-2D00-44D8-9012-806D603DA1ED}"
#define AutostartValue "HaierHeat"
#ifndef MyAppVersion
  #error 请通过 windows/packaging/build.ps1 传入 MyAppVersion
#endif
#ifndef MyAppBuild
  #error 请通过 windows/packaging/build.ps1 传入 MyAppBuild
#endif

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
VersionInfoVersion={#MyAppVersion}.{#MyAppBuild}
VersionInfoProductVersion={#MyAppVersion}.{#MyAppBuild}
DefaultDirName={code:DefaultInstallDir}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\..\dist
OutputBaseFilename=HaierHeat-Setup-{#MyAppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
CloseApplications=yes
RestartApplications=no
UsePreviousAppDir=yes
DisableDirPage=no
DisableWelcomePage=no

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\Unofficial\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
; 安装不启用开机自启动，卸载时仅清理本应用的自启动项。
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "{#AutostartValue}"; Flags: uninsdeletevalue dontcreatekey

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[Code]
const
  RunKey = 'Software\Microsoft\Windows\CurrentVersion\Run';
  DriveFixed = 3;

var
  HadAutostart: Boolean;

function UninstallKey: String;
begin
  Result := ExpandConstant('Software\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppId}_is1');
end;

function WinGetDriveType(Root: String): Cardinal;
  external 'GetDriveTypeW@kernel32.dll stdcall';

function DefaultInstallDir(Param: String): String;
begin
  if WinGetDriveType('D:\') = DriveFixed then
    Result := 'D:\HaierHeat'
  else
    Result := ExpandConstant('{localappdata}\Programs\HaierHeat');
end;

function SameDir(A, B: String): Boolean;
begin
  Result := CompareText(RemoveBackslashUnlessRoot(A), RemoveBackslashUnlessRoot(B)) = 0;
end;

function IsInsideDir(Child, Parent: String): Boolean;
begin
  Result := Pos(Lowercase(AddBackslash(Parent)), Lowercase(AddBackslash(Child))) = 1;
end;

function UninstallPreviousIfMoved: String;
var
  OldDir, NewDir, Uninstaller: String;
  Code, I: Integer;
begin
  Result := '';
  if not RegQueryStringValue(HKCU, UninstallKey, 'InstallLocation', OldDir) then
    exit;
  NewDir := ExpandConstant('{app}');
  if SameDir(NewDir, OldDir) then
    exit;
  // 相互包含的目录会让旧版卸载和新版写入相互干扰，要求使用原目录或独立目录。
  if (OldDir = '') or IsInsideDir(NewDir, OldDir) or IsInsideDir(OldDir, NewDir) then
  begin
    Result := '新旧安装目录不能相互包含。请使用原安装目录，或选择一个独立目录。';
    exit;
  end;
  // 只自动迁移本应用的默认目录名；自定义旧目录应先手动卸载。
  if CompareText(ExtractFileName(RemoveBackslashUnlessRoot(OldDir)), 'HaierHeat') <> 0 then
  begin
    Result := '旧版位于自定义目录。请使用原目录升级，或先卸载旧版再更换目录。用户配置和能耗记录会保留。';
    exit;
  end;
  if not RegQueryStringValue(HKCU, UninstallKey, 'UninstallString', Uninstaller) then
  begin
    Result := '找不到旧版卸载信息。请使用原目录升级，或先手动卸载旧版。';
    exit;
  end;
  Uninstaller := RemoveQuotes(Uninstaller);
  if not FileExists(Uninstaller) or not SameDir(ExtractFileDir(Uninstaller), OldDir) then
  begin
    Result := '旧版卸载程序不存在或位置不匹配。请使用原目录升级，或先手动卸载旧版。';
    exit;
  end;
  Log('更换安装目录，先卸载旧版: ' + OldDir);
  if not Exec(Uninstaller, '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART', '', SW_HIDE,
    ewWaitUntilTerminated, Code) then
  begin
    Result := '无法启动旧版卸载程序。请先手动卸载旧版。';
    exit;
  end;
  if Code <> 0 then
  begin
    Result := '旧版卸载失败，退出码: ' + IntToStr(Code) + '。请先手动卸载旧版。';
    exit;
  end;
  I := 0;
  while (FileExists(Uninstaller) or RegKeyExists(HKCU, UninstallKey)) and (I < 50) do
  begin
    Sleep(200);
    I := I + 1;
  end;
  if FileExists(Uninstaller) or RegKeyExists(HKCU, UninstallKey) then
    Result := '旧版卸载尚未完成，请稍后重试。';
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Code: Integer;
  Value: String;
begin
  Result := '';
  // 同时保留直接运行 Release 版本时已经开启的自启动设置。
  HadAutostart := HadAutostart or RegQueryStringValue(HKCU, RunKey, '{#AutostartValue}', Value);
  if not RegKeyExists(HKCU, UninstallKey) then
    exit;
  // 托盘会拦截关闭请求。升级前应正常退出；此兜底不执行应用的写盘钩子。
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM {#MyAppExeName}', '', SW_HIDE,
    ewWaitUntilTerminated, Code);
  Result := UninstallPreviousIfMoved;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssPostInstall) and HadAutostart then
    RegWriteStringValue(HKCU, RunKey, '{#AutostartValue}', '"' + ExpandConstant('{app}\{#MyAppExeName}') + '"');
end;
