unit GameWindowHook;

interface

uses Winapi.Windows;

// The game uses an ANSI window procedure. Do not let Unicode Delphi select
// the W APIs here: those change subclass/message conversion semantics.
function InstallGameWindowProc(Wnd: HWND; NewProc: Pointer): Pointer;
function CallGameWindowProc(PreviousProc: Pointer; Wnd: HWND;
  Msg: UINT; WParam: WPARAM; LParam: LPARAM): LRESULT;

implementation

uses System.SysUtils, PITrace;

type
  TRealSetWindowLong = function(Wnd: HWND; Index: Integer; Value: NativeInt): NativeInt; stdcall;
  TRealCallWindowProc = function(Previous: Pointer; Wnd: HWND; Msg: UINT;
    WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall;
var RealSetWindowLong: TRealSetWindowLong;
    RealCallWindowProc: TRealCallWindowProc;

procedure ResolveUser32;
var Module: HMODULE;
begin
  if Assigned(RealSetWindowLong) then Exit;
  Module := GetModuleHandle('user32.dll');
  @RealSetWindowLong := GetProcAddress(Module, 'SetWindowLongA');
  @RealCallWindowProc := GetProcAddress(Module, 'CallWindowProcA');
  if not Assigned(RealSetWindowLong) or not Assigned(RealCallWindowProc) then RaiseLastOSError;
end;

function InstallGameWindowProc(Wnd: HWND; NewProc: Pointer): Pointer;
begin
  ResolveUser32;
  SetLastError(0);
  Result := Pointer(RealSetWindowLong(Wnd, GWLP_WNDPROC, NativeInt(NewProc)));
  if (Result=nil) and (GetLastError<>0) then RaiseLastOSError;
  TracePI('Window subclass hwnd='+IntToStr(Wnd)+' old='+IntToHex(NativeUInt(Result),8)+' new='+IntToHex(NativeUInt(NewProc),8));
end;

function CallGameWindowProc(PreviousProc: Pointer; Wnd: HWND;
  Msg: UINT; WParam: WPARAM; LParam: LPARAM): LRESULT;
begin
  ResolveUser32;
  Result := RealCallWindowProc(PreviousProc, Wnd, Msg, WParam, LParam);
end;

end.
