unit PITrace;
interface
procedure TracePI(const Text: string);
implementation
uses Winapi.Windows, System.SysUtils, System.Classes;
procedure TracePI(const Text: string);
var Name: array[0..32767] of Char; Dir: string; FileStream: TFileStream; Data: TBytes;
begin
  try
    if GetModuleFileName(HInstance,Name,Length(Name))=0 then Exit;
    Dir:=ExtractFilePath(string(Name));
    if not FileExists(Dir+'PI-recovery-diagnostics.enable') then Exit;
    if FileExists(Dir+'PI-recovery-diagnostics.log') then
      FileStream:=TFileStream.Create(Dir+'PI-recovery-diagnostics.log',fmOpenWrite or fmShareDenyWrite)
    else FileStream:=TFileStream.Create(Dir+'PI-recovery-diagnostics.log',fmCreate or fmShareDenyWrite);
    try
      FileStream.Seek(0,soEnd);
      Data:=TEncoding.UTF8.GetBytes(FormatDateTime('hh:nn:ss.zzz',Now)+' '+Text+sLineBreak);
      if Length(Data)>0 then FileStream.WriteBuffer(Data[0],Length(Data));
    finally FileStream.Free; end;
  except end;
end;
end.
