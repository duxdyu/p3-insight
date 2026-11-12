unit PIWindowCompat;

interface

uses Winapi.Windows;

function PIUsesGameWindow(Game: HWND): Boolean;
function PIExclusiveGameBounds(Game: HWND; out Bounds: TRect): Boolean;
procedure PIShowInGameWindow(Game, Insight: HWND);
procedure PIReleaseMouse;
procedure PIDetachWindow(Insight: HWND);

implementation

uses Winapi.Messages, Winapi.MultiMon, System.SysUtils, System.Types, System.IniFiles, PITrace;

type
  TGetRect = function(Wnd: HWND; var Rect: TRect): BOOL; stdcall;
  TToScreen = function(Wnd: HWND; var Point: TPoint): BOOL; stdcall;
  TPosition = function(Wnd, After: HWND; X,Y,CX,CY: Integer; Flags: UINT): BOOL; stdcall;
  TGetLong = function(Wnd: HWND; Index: Integer): NativeInt; stdcall;
  TSetLong = function(Wnd: HWND; Index: Integer; Value: NativeInt): NativeInt; stdcall;
  TEnable = function(Wnd: HWND; Enable: BOOL): BOOL; stdcall;
  TClip = function(Rect: PRect): BOOL; stdcall;
  THostAttach = function(Game, Insight: HWND): Integer; cdecl;
  THostDetach = procedure(Insight: HWND); cdecl;
  THostRunningMode = function: Integer; cdecl;
var
  RealClient, RealOuter: TGetRect;
  RealScreen: TToScreen;
  RealPosition: TPosition;
  RealGetLong: TGetLong;
  RealSetLong: TSetLong;
  RealEnable: TEnable;
  RealClip: TClip;
  GameWindow, InsightWindow: HWND;
  FollowHook: HHOOK;
  Busy: Boolean;
  HostAttached: Boolean;
  HostDetach: THostDetach;

procedure ResolveUser32;
var Module: HMODULE;
begin
  if Assigned(RealClient) then Exit;
  Module:=GetModuleHandle('user32.dll');
  @RealClient:=GetProcAddress(Module,'GetClientRect');
  @RealOuter:=GetProcAddress(Module,'GetWindowRect');
  @RealScreen:=GetProcAddress(Module,'ClientToScreen');
  @RealPosition:=GetProcAddress(Module,'SetWindowPos');
  @RealGetLong:=GetProcAddress(Module,'GetWindowLongW');
  @RealSetLong:=GetProcAddress(Module,'SetWindowLongW');
  @RealEnable:=GetProcAddress(Module,'EnableWindow');
  @RealClip:=GetProcAddress(Module,'ClipCursor');
end;

function LegacyHostMode(Host: HMODULE): Integer;
var Ini: TIniFile; ModulePath: array[0..32767] of Char;
    ModuleLength: DWORD; HostDir, GameDir, FileName: string; I: Integer;
    Paths: array[0..3] of string;
begin
  Result:=-1;
  // Only a loaded legacy core may use saved settings as a compatibility hint.
  ModuleLength:=GetModuleFileName(Host,ModulePath,Length(ModulePath));
  if (ModuleLength=0) or (ModuleLength>=DWORD(Length(ModulePath))) then Exit;
  SetString(HostDir,PChar(@ModulePath[0]),ModuleLength);
  HostDir:=ExtractFilePath(HostDir);
  GameDir:=ExtractFilePath(ParamStr(0))+'P3Modern\';
  Paths[0]:=HostDir+'P3Modern.ini';
  Paths[1]:=HostDir+'ddraw.ini';
  Paths[2]:=GameDir+'P3Modern.ini';
  Paths[3]:=GameDir+'ddraw.ini';
  for I:=Low(Paths) to High(Paths) do
  begin
    FileName:=Paths[I];
    if FileExists(FileName) then
    begin
      Ini:=TIniFile.Create(FileName);
      try Result:=Ini.ReadInteger('Display','Mode',-1); finally Ini.Free; end;
      if (Result<0) or (Result>2) then Result:=-1;
      // A present new config owns precedence, even when malformed.
      Exit;
    end;
  end;
end;

function PIUsesGameWindow(Game: HWND): Boolean;
var Host: HMODULE; RunningMode: THostRunningMode; Mode: Integer;
begin
  ResolveUser32;
  Result:=False;
  if not IsWindow(Game) then Exit;
  Mode:=-1;
  // Resolve the existing core only: no hard import, LoadLibrary or cached mode.
  Host:=GetModuleHandle('P3Modern.dll');
  if Host<>0 then
  begin
    @RunningMode:=GetProcAddress(Host,'P3ModeRunning');
    if Assigned(RunningMode) then Mode:=RunningMode()
    else Mode:=LegacyHostMode(Host);
  end;
  if (Mode>=0) and (Mode<=2) then Result:=(Mode=0) or (Mode=1)
  else Result:=(RealGetLong(Game,GWL_STYLE) and WS_CAPTION)=WS_CAPTION;
end;

procedure PIReleaseMouse;
begin
  ResolveUser32;
  RealClip(nil);
end;

function PIExclusiveGameBounds(Game: HWND; out Bounds: TRect): Boolean;
var Origin: TPoint; Client, ScreenClient: TRect; Info: TMonitorInfoW;
    Monitor: HMONITOR; PID: DWORD;
begin
  Result:=False; Bounds:=Rect(0,0,0,0); PID:=0;
  if (Game=0) or IsIconic(Game) then Exit;
  GetWindowThreadProcessId(Game,@PID);
  if PID<>GetCurrentProcessId then Exit;
  ResolveUser32; Origin:=Point(0,0);
  if not RealClient(Game,Client) or not RealScreen(Game,Origin) then Exit;
  if (Client.Right<=0) or (Client.Bottom<=0) or
     (Origin.X<=-32000) or (Origin.Y<=-32000) then Exit;
  // Use the physical monitor at the native surface origin. A stale oversized
  // game HWND must not select an adjacent monitor by largest overlap.
  Monitor:=MonitorFromPoint(Origin,MONITOR_DEFAULTTONULL);
  if Monitor=0 then Exit;
  FillChar(Info,SizeOf(Info),0);Info.cbSize:=SizeOf(Info);
  if not GetMonitorInfoW(Monitor,@Info) then Exit;
  ScreenClient:=Rect(Origin.X,Origin.Y,Origin.X+Client.Right,Origin.Y+Client.Bottom);
  Result:=IntersectRect(Bounds,ScreenClient,Info.rcMonitor);
end;

procedure SynchronizeBounds;
var GameRect, ToolRect, Client: TRect; GamePoint, ToolPoint: TPoint;
    Left, Top, Width, Height: Integer;
begin
  if not IsWindow(GameWindow) or not IsWindow(InsightWindow) or IsIconic(GameWindow) then Exit;
  GamePoint:=Point(0,0);ToolPoint:=Point(0,0);
  if not RealClient(GameWindow,GameRect) or not RealScreen(GameWindow,GamePoint) or
     not RealOuter(InsightWindow,ToolRect) or not RealClient(InsightWindow,Client) or
     not RealScreen(InsightWindow,ToolPoint) then Exit;
  if (GameRect.Right<=0) or (GameRect.Bottom<=0) then Exit;
  Left:=GamePoint.X-(ToolPoint.X-ToolRect.Left);
  Top:=GamePoint.Y-(ToolPoint.Y-ToolRect.Top);
  Width:=GameRect.Right+(ToolRect.Right-ToolRect.Left-Client.Right);
  Height:=GameRect.Bottom+(ToolRect.Bottom-ToolRect.Top-Client.Bottom);
  if (ToolRect.Left<>Left) or (ToolRect.Top<>Top) or
     (ToolRect.Right-ToolRect.Left<>Width) or (ToolRect.Bottom-ToolRect.Top<>Height) then
    RealPosition(InsightWindow,0,Left,Top,Width,Height,SWP_NOACTIVATE or SWP_NOZORDER);
end;

function FollowGame(Code: Integer; WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall;
var Event: PCWPRetStruct; Foreground: HWND;
begin
  if (Code>=0) and not Busy and IsWindow(InsightWindow) and IsWindowVisible(InsightWindow) then
  begin
    Busy:=True;
    try
      Event:=PCWPRetStruct(LParam);
      if (Event.hwnd=GameWindow) and (Event.message=WM_ENABLE) and (Event.wParam=0) then
        RealEnable(GameWindow,True);
      if (Event.hwnd=GameWindow) and (Event.message in [WM_WINDOWPOSCHANGED,WM_SIZE]) then
        SynchronizeBounds;
      if (Event.hwnd=GameWindow) or (Event.hwnd=InsightWindow) then
      begin
        if (Event.message=WM_ACTIVATE) or (Event.message=WM_NCACTIVATE) or
           (Event.message=WM_ENTERSIZEMOVE) or (Event.message=WM_EXITSIZEMOVE) then
          RealClip(nil);
        if (Event.message=WM_ACTIVATE) and (LOWORD(Event.wParam)<>WA_INACTIVE) then
        begin
          Foreground:=GetForegroundWindow;
          if (Foreground=GameWindow) or (Foreground=InsightWindow) then
          begin
            RealPosition(GameWindow,HWND_TOP,0,0,0,0,SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
            RealPosition(InsightWindow,HWND_TOP,0,0,0,0,SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
          end;
        end;
      end;
    except
      on E: Exception do TracePI('Window compatibility exception: '+E.Message);
    end;
    Busy:=False;
  end;
  Result:=CallNextHookEx(FollowHook,Code,WParam,LParam);
end;

procedure PIShowInGameWindow(Game, Insight: HWND);
var Host: HMODULE; Attach: THostAttach;
begin
  if not PIUsesGameWindow(Game) then Exit;
  Host:=GetModuleHandle('P3Modern.dll');
  @Attach:=nil;
  if Host<>0 then @Attach:=GetProcAddress(Host,'P3AttachPIWindow');
  if Assigned(Attach) then
  begin
    @HostDetach:=GetProcAddress(Host,'P3DetachPIWindow');
    if not Assigned(HostDetach) then raise Exception.Create('Incomplete P3Modern PI window interface');
    if Attach(Game,Insight)<>1 then raise Exception.Create('P3Modern refused PI window attachment');
    HostAttached:=True;
    TracePI('Window compatibility delegated to P3Modern');
    Exit;
  end;
  GameWindow:=Game;InsightWindow:=Insight;
  if FollowHook=0 then
  begin
    FollowHook:=SetWindowsHookEx(WH_CALLWNDPROCRET,@FollowGame,HInstance,GetWindowThreadProcessId(Game,nil));
    if FollowHook=0 then RaiseLastOSError;
  end;
  Busy:=True;
  try
    RealSetLong(InsightWindow,GWLP_HWNDPARENT,NativeInt(GameWindow));
    RealPosition(InsightWindow,HWND_NOTOPMOST,0,0,0,0,SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
    RealEnable(GameWindow,True);
    SynchronizeBounds;
    RealClip(nil);
  finally Busy:=False; end;
end;

procedure PIDetachWindow(Insight: HWND);
begin
  if HostAttached then
  begin
    if Assigned(HostDetach) then HostDetach(Insight);
    HostAttached:=False;
  end;
  if InsightWindow=Insight then InsightWindow:=0;
  if FollowHook<>0 then
  begin
    UnhookWindowsHookEx(FollowHook);
    FollowHook:=0;
  end;
end;

end.
