program ProfileProbe;
{$APPTYPE CONSOLE}
{$SETPEOSVERSION 5.1}
{$SETPESUBSYSVERSION 5.1}
uses System.SysUtils, PIGameProfile, PISettings;
var Settings: TPISettings;
begin
  try
    if ParamCount = 1 then Writeln(CheckGameProfile(ParamStr(1)))
    else if (ParamCount = 2) and (ParamStr(1) = '--settings') then
    begin
      Settings := ReadPISettings(ParamStr(2));
      Writeln(CheckGameProfile(Settings.Target));
      Writeln(Settings.Target);
      Writeln(Settings.WindowTitle);
      Writeln(PIDataDirectory(ParamStr(2)));
    end
    else raise Exception.Create('Expected target or --settings absolute-module-directory');
  except
    on E: Exception do begin Writeln(E.Message); Halt(1); end;
  end;
end.
