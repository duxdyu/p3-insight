unit PIWindowCompatTests;
interface
procedure RunPIWindowCompatTests;
implementation
uses Winapi.Windows, System.SysUtils, PIWindowCompat;

procedure RunPIWindowCompatTests;
var Game, Insight: HWND; Client, Actual: TRect; Origin: TPoint;
  procedure CheckAligned;
  begin
    GetClientRect(Game,Client);Origin.X:=0;Origin.Y:=0;ClientToScreen(Game,Origin);
    GetWindowRect(Insight,Actual);
    if (Actual.Left<>Origin.X) or (Actual.Top<>Origin.Y) or
       (Actual.Right-Actual.Left<>Client.Right) or (Actual.Bottom-Actual.Top<>Client.Bottom) then
      raise Exception.Create('PI does not match the actual game client');
  end;
begin
  Game:=CreateWindowExA(0,'STATIC','PI compatibility test',WS_OVERLAPPEDWINDOW,
    120,80,800,600,0,0,HInstance,nil);
  if Game=0 then RaiseLastOSError;
  Insight:=CreateWindowExW(WS_EX_TOPMOST,'STATIC','PI test overlay',WS_POPUP,
    0,0,200,100,0,0,HInstance,nil);
  if Insight=0 then begin DestroyWindow(Game);RaiseLastOSError;end;
  try
    if not PIUsesGameWindow(Game) then raise Exception.Create('Captioned window should use compatibility');
    EnableWindow(Game,False);
    PIShowInGameWindow(Game,Insight);
    CheckAligned;
    if not IsWindowEnabled(Game) then raise Exception.Create('Game title bar remains disabled');
    if GetWindow(Insight,GW_OWNER)<>Game then raise Exception.Create('PI owner is not the game');
    if (GetWindowLong(Insight,GWL_EXSTYLE) and WS_EX_TOPMOST)<>0 then
      raise Exception.Create('PI remains permanently topmost');
    SetWindowPos(Game,0,230,160,1024,768,SWP_NOZORDER or SWP_NOACTIVATE);
    PIShowInGameWindow(Game,Insight);
    CheckAligned;
    Writeln('PASS: PI client alignment, move/resize geometry, game enabled, owned popup, no permanent topmost');
  finally
    PIDetachWindow(Insight);DestroyWindow(Insight);DestroyWindow(Game);
  end;
end;
end.
