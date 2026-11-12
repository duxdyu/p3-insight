program PIProductionLauncher;
{$SETPEOSVERSION 5.1}
{$SETPESUBSYSVERSION 5.1}

{$APPTYPE GUI}
{$R 'PIAppIcon.res'}

uses
  Winapi.UIAutomation in '..\sdk-overlay\Winapi.UIAutomation.pas',
  Winapi.Windows, Winapi.TlHelp32, System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Controls,
  PISettings in '..\PISettings.pas', PIGameProfile, XPTick, PIGameReadiness;

type
  TInjectLibW = function(Process: THandle; LibraryFile: PWideChar;
    Action: Integer): BOOL; cdecl;
  TLauncher = class(TForm)
  private
    Status: TLabel;
    Cancel: TButton;
    Poll: TTimer;
    Game: TProcessInformation;
    Injector: HMODULE;
    Inject: TInjectLibW;
    Worker: TThread;
    InjectDone: THandle;
    InjectOK: Boolean;
    InjectError: string;
    Base, Target, WindowTitle, LibraryFile, InjectorFile: string;
    Started, TestWait: Boolean;
    ReadySamples: Integer;
    Readiness: TPIReadinessState;
    WaitStarted: Cardinal;
    procedure Tick(Sender: TObject);
    procedure StopWaiting(Sender: TObject);
    procedure Closing(Sender: TObject; var CanClose: Boolean);
    procedure Fail(const Text: string);
    procedure StartGame;
    function LoadedGame: Boolean;
    procedure Log(const Text: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  Launcher: TLauncher;
  InstanceMutex: THandle;

procedure Info(const Text: string; Flags: UINT = MB_ICONINFORMATION);
begin
  MessageBox(0, PChar(Text), 'P3Insight 启动器', MB_OK or Flags);
end;

function ExistingGame(const Target: string): Boolean;
var Snapshot: THandle; Entry: TProcessEntry32;
begin
  Result := False;
  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snapshot = INVALID_HANDLE_VALUE then RaiseLastOSError;
  try
    Entry.dwSize := SizeOf(Entry);
    if not Process32First(Snapshot, Entry) then RaiseLastOSError;
    repeat
      if SameText(string(Entry.szExeFile), ExtractFileName(Target)) or
         SameText(string(Entry.szExeFile), 'Patrician3.exe') or
         SameText(string(Entry.szExeFile), 'P3.exe') then Exit(True);
    until not Process32Next(Snapshot, Entry);
    if GetLastError <> ERROR_NO_MORE_FILES then RaiseLastOSError;
  finally
    CloseHandle(Snapshot);
  end;
end;

constructor TLauncher.Create(AOwner: TComponent);
var Settings: TPISettings;
begin
  inherited CreateNew(AOwner);
  Caption := 'P3Insight - 等待读档';
  Position := poScreenCenter;
  BorderStyle := bsSingle;
  BorderIcons := [biSystemMenu, biMinimize];
  ClientWidth := 540;
  ClientHeight := 180;
  Font.Name := 'Microsoft YaHei UI';
  Font.Size := 10;
  OnCloseQuery := Closing;
  Status := TLabel.Create(Self);
  Status.Parent := Self;
  Status.SetBounds(20, 20, 500, 105);
  Status.AutoSize := False;
  Status.WordWrap := True;
  Status.Caption := '正在检查 PI.ini 配置与游戏版本……';
  Cancel := TButton.Create(Self);
  Cancel.Parent := Self;
  Cancel.SetBounds(310, 135, 210, 30);
  Cancel.Caption := '取消 PI 等待（保留游戏）';
  Cancel.OnClick := StopWaiting;
  Cancel.Cancel := True;
  Base := ExtractFilePath(ParamStr(0));
  Settings := ReadPISettings(Base);
  Target := Settings.Target;
  WindowTitle := Settings.WindowTitle;
  LibraryFile := Base + 'p3insight.dll';
  InjectorFile := Base + 'InjLib.dll';
  TestWait := (ParamCount = 1) and SameText(ParamStr(1), '/test-wait');
  InjectDone := CreateEvent(nil, True, False, nil);
  if InjectDone = 0 then RaiseLastOSError;
  Poll := TTimer.Create(Self);
  Poll.Enabled := False;
  Poll.Interval := 100;
  Poll.OnTimer := Tick;
  Poll.Enabled := True;
end;

destructor TLauncher.Destroy;
begin
  if Assigned(Worker) then
  begin
    Worker.WaitFor;
    Worker.Free;
  end;
  if Game.hThread <> 0 then CloseHandle(Game.hThread);
  if Game.hProcess <> 0 then CloseHandle(Game.hProcess);
  if Injector <> 0 then FreeLibrary(Injector);
  if InjectDone <> 0 then CloseHandle(InjectDone);
  inherited;
end;

procedure TLauncher.Log(const Text: string);
var Stream: TFileStream; Bytes: TBytes; FileName: string;
begin
  // A read-only installation must not prevent launching. No game/save writes.
  try
    FileName := Base + 'PI启动日志.txt';
    if FileExists(FileName) then
      Stream := TFileStream.Create(FileName, fmOpenWrite or fmShareDenyWrite)
    else
      Stream := TFileStream.Create(FileName, fmCreate);
    try
      Stream.Seek(0, soEnd);
      Bytes := TEncoding.UTF8.GetBytes(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) +
        ' ' + Text + sLineBreak);
      Stream.WriteBuffer(Bytes[0], Length(Bytes));
    finally
      Stream.Free;
    end;
  except
    // Logging is best effort.
  end;
end;

procedure TLauncher.Fail(const Text: string);
begin
  Poll.Enabled := False;
  ExitCode := 1;
  Log('FAILED: ' + Text);
  Info(Text + sLineBreak + sLineBreak + '启动器不会关闭游戏。', MB_ICONWARNING);
  Close;
end;

procedure TLauncher.Closing(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not Assigned(Worker) or
    (WaitForSingleObject(InjectDone, 0) = WAIT_OBJECT_0);
  if not CanClose then
    Status.Caption := 'PI 初始化已经开始，请等待结果。游戏进程不会被终止。'
  else if Poll.Enabled then
  begin
    Poll.Enabled := False;
    ExitCode := 3;
    Log('CANCELLED: waiting stopped; game retained');
  end;
end;

procedure TLauncher.StopWaiting(Sender: TObject);
begin
  Close;
end;

procedure TLauncher.StartGame;
var Startup: TStartupInfo; Command: string;
begin
  if not FileExists(Target) then
    raise Exception.Create('找不到游戏：' + Target + sLineBreak +
      '请将启动器放在游戏根目录下的 P3Insight 文件夹中。');
  if not FileExists(LibraryFile) then
    raise Exception.Create('缺少同目录组件：' + LibraryFile);
  if not FileExists(InjectorFile) then
    raise Exception.Create('缺少同目录组件：' + InjectorFile);
  Log('PROFILE: ' + CheckGameProfile(Target));
  if ExistingGame(Target) then
    raise Exception.Create('已有 Patrician3.exe / P3.exe 游戏进程。' + sLineBreak +
      '请先自行退出已有游戏，再双击本入口；不会挂接或关闭已有游戏。');
  Injector := LoadLibraryEx(PChar(InjectorFile), 0, LOAD_WITH_ALTERED_SEARCH_PATH);
  if Injector = 0 then RaiseLastOSError;
  @Inject := GetProcAddress(Injector, 'InjectLibW');
  if not Assigned(Inject) then raise Exception.Create('InjLib.dll 缺少 InjectLibW。');
  FillChar(Startup, SizeOf(Startup), 0);
  Startup.cb := SizeOf(Startup);
  Command := '"' + Target + '"';
  UniqueString(Command);
  if not CreateProcess(PChar(Target), PChar(Command), nil, nil, False, 0,
    nil, PChar(ExtractFilePath(Target)), Startup, Game) then RaiseLastOSError;
  CloseHandle(Game.hThread);
  Game.hThread := 0;
  Log('START PID=' + UIntToStr(Game.dwProcessId) + ' target=' + Target +
    ' cwd=' + ExtractFilePath(Target));
  // Ten minutes to navigate menus; readiness is state-driven, not elapsed time.
  WaitStarted := GetTickCount;
end;

function TLauncher.LoadedGame: Boolean;
begin
  Result := False;
  if (FindPIWindow(Game.dwProcessId, WindowTitle) = 0) or
     (WaitForInputIdle(Game.hProcess, 0) <> 0) then
  begin
    ResetPIReadiness(Readiness);
    Exit;
  end;
  Result := PollPIReadiness(Game.hProcess, Readiness);
end;

procedure TLauncher.Tick(Sender: TObject);
var Remaining: Cardinal;
begin
  try
    if not Started then
    begin
      Started := True;
      if TestWait then
      begin
        WaitStarted := GetTickCount;
        Log('TEST-WAIT: no game started; no DLL loaded');
      end
      else StartGame;
      Exit;
    end;
    if Assigned(Worker) then
    begin
      if WaitForSingleObject(InjectDone, 0) <> WAIT_OBJECT_0 then Exit;
      Poll.Enabled := False;
      if InjectOK then
      begin
        Log('INJECTED PID=' + UIntToStr(Game.dwProcessId));
        ExitCode := 0;
        Close;
      end
      else Fail('PI 初始化失败：' + InjectError + sLineBreak +
        '本次游戏可继续作为普通模式运行。需要 PI 时请自行退出游戏后重试。');
      Exit;
    end;
    if not TestWait then
    begin
      if WaitForSingleObject(Game.hProcess, 0) = WAIT_OBJECT_0 then
      begin
        Fail('游戏在 PI 初始化前已退出。');
        Exit;
      end;
      // Readiness owns the three distinct native-loop observations.
      if LoadedGame then ReadySamples := 3 else ReadySamples := 0;
    end;
    if ReadySamples >= 3 then
    begin
      Status.Caption := '已检测到读档 / 新游戏就绪，正在初始化 PI……';
      Cancel.Enabled := False;
      Log('READY: top game/world active; three consecutive native-loop advances' +
        ' clock=' + UIntToStr(Readiness.Previous.LoopClock) +
        ' frame=' + UIntToStr(Readiness.Previous.FrameSerial));
      Worker := TThread.CreateAnonymousThread(
        procedure
        begin
          try
            try
              InjectOK := Inject(Game.hProcess, PWideChar(LibraryFile), 1);
              if not InjectOK then InjectError := 'InjectLibW returned FALSE';
            except
              on E: Exception do InjectError := E.ClassName + ': ' + E.Message;
            end;
          finally
            SetEvent(InjectDone);
          end;
        end);
      Worker.FreeOnTerminate := False;
      Worker.Start;
      Exit;
    end;
    Remaining := RemainingTickMs(WaitStarted, GetTickCount, 600000);
    if Remaining = 0 then
    begin
      Fail('等待已超过 10 分钟，尚未检测到可用的游戏读档状态。' + sLineBreak +
        '请检查 PI.ini 的 WindowTitle：' + WindowTitle + sLineBreak +
        '本次未启用 PI。需要 PI 时请自行退出游戏，再通过本入口启动并读档。');
      Exit;
    end;
    Status.Caption := '请切换到游戏，载入存档或开始新游戏。' + sLineBreak +
      'PI 会在游戏窗口和读档状态连续就绪后自动启用。' + sLineBreak +
      '剩余等待：' + UIntToStr(Remaining div 1000) +
      ' 秒。可最小化本窗口；取消只停止等待。';
    if TestWait then Status.Caption := '[无游戏等待测试] ' + Status.Caption;
  except
    on E: Exception do Fail(E.ClassName + ': ' + E.Message);
  end;
end;

function CheckPaths: Integer;
var Base, Target, Text: string; Settings: TPISettings;
begin
  Base := ExtractFilePath(ParamStr(0));
  Settings := ReadPISettings(Base);
  Target := Settings.Target;
  CheckGameProfile(Target);
  Result := 0;
  Text := '只检查路径，不启动游戏或加载 DLL。' + sLineBreak +
    '游戏：' + Target + sLineBreak + '工作目录：' + ExtractFilePath(Target) +
    sLineBreak + '窗口标题（同时匹配创建的 PID）：' + Settings.WindowTitle +
    sLineBreak + 'PI：' + Base + 'p3insight.dll' + sLineBreak +
    '加载组件：' + Base + 'InjLib.dll';
  if not (FileExists(Target) and FileExists(Base + 'p3insight.dll') and
    FileExists(Base + 'InjLib.dll')) then
  begin
    Result := 2;
    Text := Text + sLineBreak + '检查失败：一个或多个必需文件不存在。';
  end
  else Text := Text + sLineBreak + '所需文件均存在。';
  Info(Text);
end;

begin
  try
    if (ParamCount = 1) and (SameText(ParamStr(1), '/help') or
      SameText(ParamStr(1), '/?')) then
    begin
      Info('双击读取同目录 PI.ini [Game] Target / WindowTitle；默认 ../Patrician3.exe。' + sLineBreak +
        '检查中文游戏固定 ABI、PI 指令和生产表；支持改名及有/无 P3Modern。' + sLineBreak +
        '同目录必须有 p3insight.dll 与 InjLib.dll。游戏工作目录为根目录。' +
        sLineBreak + '进入游戏后请读档或开始新游戏；就绪后自动启用 PI。' +
        sLineBreak + '等待最长 10 分钟；关闭等待窗口不会关闭游戏。' +
        sLineBreak + '已有游戏时不会多开或挂接。MED 请使用 P3Med3/P3MED.exe。' +
        sLineBreak + '/check 仅检查路径；/test-wait 仅测试取消界面，不运行游戏。');
      Halt(0);
    end;
    if (ParamCount = 1) and SameText(ParamStr(1), '/check') then Halt(CheckPaths);
    if (ParamCount <> 0) and not ((ParamCount = 1) and
      SameText(ParamStr(1), '/test-wait')) then
    begin
      Info('目标和窗口标题请编辑同目录 PI.ini；此入口不接受目标或 DLL 参数。');
      Halt(2);
    end;
    InstanceMutex := CreateMutex(nil, True, 'Local\P3Insight.Modern.ProductionLauncher');
    if InstanceMutex = 0 then RaiseLastOSError;
    if GetLastError = ERROR_ALREADY_EXISTS then
    begin
      CloseHandle(InstanceMutex);
      Info('PI 启动器已在等待，请使用已有窗口。');
      Halt(2);
    end;
    try
      Application.Initialize;
      Application.MainFormOnTaskbar := True;
      Application.CreateForm(TLauncher, Launcher);
      Application.Run;
    finally
      ReleaseMutex(InstanceMutex);
      CloseHandle(InstanceMutex);
    end;
  except
    on E: Exception do
    begin
      Info(E.ClassName + ': ' + E.Message, MB_ICONERROR);
      ExitCode := 1;
    end;
  end;
end.
