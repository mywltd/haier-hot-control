; UTF-8 with BOM. Inno Setup 6 Unicode script for 风铃·回响 (WindBellEcho).
; 版本号由 build.ps1 从 pubspec.yaml 读取后用 /DMyAppVersion=x.y.z 传入。
; AppId 沿用 1.0.0，安装为覆盖升级；1.0.0 的英文名是 EntranceEffect，升级时迁移到 WindBellEcho。
; 默认装到 D:\WindBellEcho（没有 D 盘时装到 %LOCALAPPDATA%\Programs\WindBellEcho），目录页里可改，升级时也能换目录。
#define MyAppName "风铃·回响"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.1"
#endif
#define MyAppPublisher "风铃回响"
#define MyAppExeName "WindBellEcho.exe"
#define MyAppId "{{8F3C2A91-6B47-4E1D-9C5A-2D8E7F4B1A06}"
#define LegacyExeName "bilibili_auto_player.exe"
#define LegacyAutostart "BilibiliAutoPlayer"
#define AutostartValue "WindBellEcho"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppCopyright=Copyright (C) 2026 {#MyAppPublisher}
VersionInfoVersion={#MyAppVersion}
DefaultDirName={code:DefaultInstallDir}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\..\dist
OutputBaseFilename=WindBellEcho-Setup-{#MyAppVersion}
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
; 升级时也显示目录页（默认 auto 会跳过），方便换安装位置。
DisableDirPage=no
DisableWelcomePage=no

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\Unofficial\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[InstallDelete]
; 1.0.0 叫「进场特效」：删掉旧名字的快捷方式，避免开始菜单 / 桌面出现两个。
Type: files; Name: "{autoprograms}\进场特效.lnk"
Type: files; Name: "{autodesktop}\进场特效.lnk"
; 装在原目录（用户自选过目录）时删掉旧文件名的主程序。
Type: files; Name: "{app}\{#LegacyExeName}"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
; 卸载时清掉开机自启动项（只删不写，安装时不会自动开启自启动）。
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "{#AutostartValue}"; Flags: uninsdeletevalue dontcreatekey

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[Code]
const
  RunKey = 'Software\Microsoft\Windows\CurrentVersion\Run';
  DriveFixed = 3;

var
  HadAutostart: Boolean;

// AppId 里的 {{ 要经 ExpandConstant 才变成注册表里的 {。
function UninstallKey: String;
begin
  Result := ExpandConstant('Software\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppId}_is1');
end;

function WinGetDriveType(Root: String): Cardinal;
  external 'GetDriveTypeW@kernel32.dll stdcall';

// D 盘是本地硬盘就默认装 D:\WindBellEcho；没有 D 盘（或是光驱、U 盘）退回用户目录，免管理员权限。
function DefaultInstallDir(Param: String): String;
begin
  if WinGetDriveType('D:\') = DriveFixed then
    Result := 'D:\WindBellEcho'
  else
    Result := ExpandConstant('{localappdata}\Programs\WindBellEcho');
end;

function SameDir(A, B: String): Boolean;
begin
  Result := CompareText(RemoveBackslashUnlessRoot(A), RemoveBackslashUnlessRoot(B)) = 0;
end;

// Child 是否等于 Parent 或在它里面。
function IsInsideDir(Child, Parent: String): Boolean;
begin
  Result := Pos(Lowercase(AddBackslash(Parent)), Lowercase(AddBackslash(Child))) = 1;
end;

// 旧版的默认目录（1.0.0 的 Programs\EntranceEffect、1.0.1 的 Programs\WindBellEcho）不是用户挑的，
// 升级时换成新默认目录；用户自选的目录保持不变。
procedure InitializeWizard;
var
  Dir: String;
begin
  Dir := WizardForm.DirEdit.Text;
  if SameDir(Dir, ExpandConstant('{localappdata}\Programs\EntranceEffect')) or
     SameDir(Dir, ExpandConstant('{localappdata}\Programs\WindBellEcho')) then
    WizardForm.DirEdit.Text := DefaultInstallDir('');
end;

// 换了安装目录：先静默卸载旧目录里的旧版。留着的话旧目录里有一份能跑的旧程序，日后运行它的
// 卸载程序还会删掉新版共用的卸载信息和自启动项。1.0.x 的卸载程序会整个删掉它的安装目录，
// 所以只在旧目录名是本程序自己的目录名时才调用，免得误删用户的其他文件。
procedure UninstallPreviousIfMoved;
var
  OldDir, NewDir, Uninstaller, OldName: String;
  Code, I: Integer;
begin
  if not RegQueryStringValue(HKCU, UninstallKey, 'InstallLocation', OldDir) or
     not RegQueryStringValue(HKCU, UninstallKey, 'UninstallString', Uninstaller) then
    exit;
  Uninstaller := RemoveQuotes(Uninstaller);
  NewDir := ExpandConstant('{app}');
  if IsInsideDir(NewDir, OldDir) or IsInsideDir(OldDir, NewDir) or not FileExists(Uninstaller) then
    exit;
  OldName := ExtractFileName(RemoveBackslashUnlessRoot(OldDir));
  if (CompareText(OldName, 'WindBellEcho') <> 0) and (CompareText(OldName, 'EntranceEffect') <> 0) then
  begin
    Log('旧版目录不是本程序的默认目录名，不自动卸载: ' + OldDir);
    exit;
  end;
  Log('安装目录从 ' + OldDir + ' 换到 ' + NewDir + '，先卸载旧版');
  Exec(Uninstaller, '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART', '', SW_HIDE, ewWaitUntilTerminated, Code);
  // 卸载程序会复制到临时目录再运行，等原文件删掉再继续，免得它和新安装抢注册表项。
  I := 0;
  while FileExists(Uninstaller) and (I < 50) do
  begin
    Sleep(200);
    I := I + 1;
  end;
end;

// 托盘程序拦了关闭（最小化到托盘），1.0.0 还换过文件名，Restart Manager 关不掉它，这里直接结束，
// 否则文件被占用、新版启动时展示页端口被旧版占着。程序数据都已实时写盘，强制结束不会丢数据。
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Code: Integer;
  Value: String;
begin
  Result := '';
  if not RegKeyExists(HKCU, UninstallKey) then
    exit;
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM {#MyAppExeName} /IM {#LegacyExeName}', '', SW_HIDE,
    ewWaitUntilTerminated, Code);
  // 旧版卸载程序会删掉自启动项，先记下，装完写回。
  HadAutostart := RegQueryStringValue(HKCU, RunKey, '{#AutostartValue}', Value) or
    RegQueryStringValue(HKCU, RunKey, '{#LegacyAutostart}', Value);
  UninstallPreviousIfMoved;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep <> ssPostInstall) or not HadAutostart then
    exit;
  // 自启动项指向新位置的程序（与程序自己写的格式一致，带引号）；1.0.0 的旧名字一并清掉。
  RegWriteStringValue(HKCU, RunKey, '{#AutostartValue}', '"' + ExpandConstant('{app}\{#MyAppExeName}') + '"');
  RegDeleteValue(HKCU, RunKey, '{#LegacyAutostart}');
end;
