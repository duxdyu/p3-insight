unit PISettingsTests;
interface
procedure RunPISettingsTests(const TestRoot: string);
implementation
uses Winapi.Windows, System.SysUtils, System.Classes, PISettings;
procedure Check(Value: Boolean; const Text: string);
begin
  if not Value then raise Exception.Create(Text);
end;
procedure RunPISettingsTests(const TestRoot: string);
var Root: string; Lines: TStringList; Settings: TPISettings; Wnd: HWND;
  procedure Put(const Name, Text: string);
  begin
    Lines.Text := Text;
    Lines.SaveToFile(Root + Name, TEncoding.UTF8);
  end;
  procedure Invalid(const Text: string);
  var Failed: Boolean;
  begin
    Put('PI.ini', Text);
    Failed := False;
    try Settings := ReadPISettings(Root); except on E: Exception do Failed := True; end;
    Check(Failed, 'invalid configuration accepted: ' + Text);
  end;
begin
  Root := IncludeTrailingPathDelimiter(ExpandFileName(TestRoot)) + 'settings-' + IntToStr(GetCurrentProcessId) + '\';
  ForceDirectories(Root);
  Lines := TStringList.Create;
  try
    Settings := ReadPISettings(Root);
    Check(Settings.Target = ExpandFileName(Root + '../Patrician3.exe'), 'default target');
    Check(Settings.WindowTitle = '大 航 海 家 3', 'default title');
    Put('injluncher.ini', 'target=../p3.exe' + sLineBreak + 'dlls=p3insight.dll');
    Check(ReadPISettings(Root).Target = ExpandFileName(Root + '../p3.exe'), 'legacy target');
    Put('PI.ini', '[Game]' + sLineBreak + 'Target=../中文 路径/p3.exe' + sLineBreak + 'WindowTitle=测试标题');
    Settings := ReadPISettings(Root);
    Check(Settings.Target = ExpandFileName(Root + '../中文 路径/p3.exe'), 'relative Unicode path');
    Check(Settings.WindowTitle = '测试标题', 'UTF8 title and PI.ini precedence');
    Put('PI.ini', '[Game]' + sLineBreak + 'Target=' + Root + 'p3.exe');
    Check(ReadPISettings(Root).Target = Root + 'p3.exe', 'absolute target');
    Invalid('[Game]' + sLineBreak + 'Target=');
    Invalid('[Game]' + sLineBreak + 'WindowTitle=');
    Invalid('[Game]' + sLineBreak + 'Target=C:p3.exe');
    Invalid('[Game]' + sLineBreak + 'Target=../p3.exe -arg');
    Invalid('[Game]' + sLineBreak + 'DLLs=other.dll');
    Invalid('Target=../p3.exe');
    Invalid('[Game]' + sLineBreak + 'WindowTitel=wrong');
    Check(PIDataDirectory(Root) = Root + 'data\', 'module data directory');
    Check(PIRelativeResource(Root + 'data\sound', 'alarm.wav') = Root + 'data\sound\alarm.wav', 'relative sound');
    try PIRelativeResource(Root + 'data\sound', '..\..\outside.wav');
      raise EAbort.Create('escaped resource accepted');
    except on E: EAbort do raise; on E: Exception do ; end;
    Wnd := CreateWindowEx(0, 'STATIC', '测试标题', WS_POPUP or WS_VISIBLE,
      -32000, -32000, 1, 1, 0, 0, HInstance, nil);
    Check(Wnd <> 0, 'create owned probe window');
    try
      Check(FindPIWindow(GetCurrentProcessId, '测试标题') = Wnd, 'own PID title match');
      Check(FindPIWindow(GetCurrentProcessId + 1, '测试标题') = 0, 'foreign PID rejected');
      Check(FindPIWindow(GetCurrentProcessId, 'wrong title') = 0, 'wrong title rejected');
    finally DestroyWindow(Wnd); end;
    Writeln('PASS: PI defaults, legacy target, PI.ini priority, Unicode/absolute/relative paths, invalid config, resource containment, PID/title window lookup');
  finally
    Lines.Free;
    DeleteFile(Root + 'PI.ini');
    DeleteFile(Root + 'injluncher.ini');
    RemoveDir(Root);
  end;
end;
end.
