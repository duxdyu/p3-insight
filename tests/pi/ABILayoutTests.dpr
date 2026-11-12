program ABILayoutTests;
{$SETPEOSVERSION 5.1}
{$SETPESUBSYSVERSION 5.1}
{$APPTYPE CONSOLE}
uses
  Winapi.UIAutomation in '..\..\sdk-overlay\Winapi.UIAutomation.pas', System.SysUtils, Winapi.Windows, Winapi.Messages, GameWindowHook,
  p3DataStruct, p3insight_utils, p3insight_common, VirtualTrees, PIHistoricalCoreTests, PIFormResourceTests, PIWindowCompatTests, PISettingsTests;
type
  TProbeTree = class(TVirtualStringTree)
    procedure ProbePaint;
  end;
  TPaintObserver = class
    Called: Boolean;
    procedure Paint(Sender: TBaseVirtualTree; Info: TVTPaintInfo; var DefaultDraw: Boolean);
  end;
var Ship: TP3R2Ship; Bytes: RawByteString; I: Integer;
    Tree: TProbeTree; Observer: TPaintObserver;
    PreviousWindowProc: Pointer;
    ForwardedTextMessages: Integer;
function ProbeWindowProc(Wnd: HWND; Msg: UINT; WParam: WPARAM;
  LParam: LPARAM): LRESULT; stdcall;
begin
  if (Msg = WM_SETTEXT) or (Msg = WM_GETTEXT) then Inc(ForwardedTextMessages);
  Result := CallGameWindowProc(PreviousWindowProc, Wnd, Msg, WParam, LParam);
end;
procedure TProbeTree.ProbePaint;
var Info: TVTPaintInfo;
begin
  FillChar(Info, SizeOf(Info), 0);
  DoPaintNode(Info);
end;
procedure TPaintObserver.Paint(Sender: TBaseVirtualTree; Info: TVTPaintInfo; var DefaultDraw: Boolean);
begin
  Called := True;
  DefaultDraw := False;
end;
procedure Check(Value: Boolean; const Message: string);
begin
  if not Value then raise Exception.Create(Message);
end;
procedure CheckANSIWindowHook;
var
  Wnd: HWND;
  Text: RawByteString;
  Buffer: array[0..31] of AnsiChar;
begin
  Wnd := CreateWindowExA(0, 'STATIC', nil, WS_POPUP, 0, 0, 1, 1,
    0, 0, HInstance, nil);
  Check(Wnd <> 0, 'create owned hidden ANSI window');
  try
    Check(not IsWindowUnicode(Wnd), 'probe starts ANSI');
    PreviousWindowProc := InstallGameWindowProc(Wnd, @ProbeWindowProc);
    Check(PreviousWindowProc <> nil, 'install ANSI subclass');
    try
      Check(not IsWindowUnicode(Wnd), 'subclass must preserve ANSI window');
      // CP936 bytes for Chinese ship-name text, independent of source encoding.
      Text := SimpleHexToBin('B4F3BABDBAA3BCD233');
      SendMessageA(Wnd, WM_SETTEXT, 0, LPARAM(PAnsiChar(Text)));
      FillChar(Buffer, SizeOf(Buffer), 0);
      Check(SendMessageA(Wnd, WM_GETTEXT, Length(Buffer), LPARAM(@Buffer[0])) =
        Length(Text), 'ANSI message byte count');
      Check(AnsiString(PAnsiChar(@Buffer[0])) = Text, 'ANSI text message round trip');
      Check(ForwardedTextMessages = 2, 'text messages pass through actual wrapper');
    finally
      InstallGameWindowProc(Wnd, PreviousWindowProc);
    end;
  finally
    DestroyWindow(Wnd);
  end;
  Writeln('PASS: owned hidden ANSI window subclass, text-message forwarding and restoration');
end;
begin
  try
    Check(SizeOf(Pointer) = 4, 'Win32 required');
    Check(SizeOf(Ship) = $180, 'Ship stride must be 384 bytes');
    Check(NativeUInt(@Ship.ShipName) - NativeUInt(@Ship) = $160, 'ship name offset');
    Check(SizeOf(Ship.ShipName) = 18, 'ship name storage');
    Check(SizeOf(TCaptainRec) = 16, 'captain stride');
    FillChar(Ship, SizeOf(Ship), 0);
    p3setShipName_R2(@Ship, '1234567890123456789012345');
    Check(getShipName_R2(@Ship) = '12345678901234567', 'bounded name write');
    Check(Ship.Stub8[1] = 0, 'no write beyond name');
    for I := 1 to 18 do Ship.ShipName[I] := 'X';
    Check(Length(getShipName_R2(@Ship)) = 17, 'bounded nonterminated name read');
    Bytes := SimpleHexToBin('0080FF4142');
    Check(Length(Bytes) = 5, 'raw patch byte count');
    Check(SimpleBinToHex(Bytes) = '0080FF4142', 'raw patch byte roundtrip');
    Observer := TPaintObserver.Create;
    Tree := TProbeTree.Create(nil);
    try
      Tree.OnPaintCell := Observer.Paint;
      Tree.ProbePaint;
      Check(Observer.Called, 'custom cell painting callback must execute');
    finally
      Tree.Free;
      Observer.Free;
    end;
    Writeln('PASS: ship stride=384 name offset=352 storage=18 captain=16; bounded name, raw patch bytes, custom tree painting callback');
    CheckANSIWindowHook;
    RunHistoricalCoreTests;
    RunPIWindowCompatTests;
    RunPISettingsTests(ExtractFilePath(ParamStr(0)));
    RunFormResourceTest(ExpandFileName(ExtractFilePath(ParamStr(0))+'../../P3InsightMain.dfm'));
    // Optional read-only check of the shipped configuration, without p3HackInit,
    // patchP3, modP3, attachP3, or any game process.
    if ParamCount > 0 then
    begin
      StuffPath := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
      ImgPath := StuffPath + 'images\';
      SoundPath := StuffPath + 'sounds\';
      Conf.load;
      Writeln('PASS: shipped configuration loaded; mod items=', Conf.ModItems.List.Count,
        ' warning sound=', string(Conf.WarningSoundFN));
      Writeln('CONFIG: basic goods=', Conf.BasicGoods.count,
        ' price lists=', Conf.PriceDefs.List.Count,
        ' area definitions=', Conf.AreaDefList.getCount,
        ' trade routes=', Conf.CustomTRList.getTRCount,
        ' route categories=', Conf.CustomTRList.Categories.Count,
        ' store house capacity=', StdStoreHouseCapacity,
        ' allow modify=', Conf.AllowModify,
        ' auto captain birthday=', Conf.AutoResetCaptainBirthday);
    end;
  except
    on E: Exception do begin Writeln(E.ClassName, ': ', E.Message); Halt(1); end;
  end;
end.
