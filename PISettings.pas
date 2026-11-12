unit PISettings;
interface
uses Winapi.Windows, System.SysUtils, System.Classes, System.IniFiles;
type
  TPISettings = record
    Target, WindowTitle: string;
  end;
function PIModuleDirectory(Module: HMODULE): string;
function PIDataDirectory(const Base: string): string;
function PIRelativeResource(const Base, Name: string): string;
function ReadPISettings(const Base: string): TPISettings;
function FindPIWindow(PID: DWORD; const Title: string): HWND;
implementation
function PIModuleDirectory(Module: HMODULE): string;
var Buffer: array[0..32767] of Char; Count: DWORD;
begin
  Count := GetModuleFileName(Module, Buffer, Length(Buffer));
  if (Count = 0) or (Count >= Length(Buffer)) then
    raise Exception.Create('Cannot resolve PI module directory');
  Result := ExtractFilePath(string(Buffer));
end;
function PIDataDirectory(const Base: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ExpandFileName(Base)) + 'data\';
end;
function PIRelativeResource(const Base, Name: string): string;
var Root: string;
begin
  if (Name = '') or (ExtractFileDrive(Name) <> '') or
    (Name[1] = '\') or (Name[1] = '/') or (Pos(':', Name) > 0) then
    raise Exception.Create('PI resource must be a relative path: ' + Name);
  Root := IncludeTrailingPathDelimiter(ExpandFileName(Base));
  Result := ExpandFileName(Root + Name);
  if not SameText(Copy(Result, 1, Length(Root)), Root) then
    raise Exception.Create('PI resource escapes its directory: ' + Name);
end;
function ReadPISettings(const Base: string): TPISettings;
var Ini: TMemIniFile; Legacy, Keys: TStringList; Root, Raw, FileName: string;
  I: Integer;
begin
  Root := IncludeTrailingPathDelimiter(ExpandFileName(Base));
  Raw := '../Patrician3.exe';
  Result.WindowTitle := '大 航 海 家 3';
  FileName := Root + 'PI.ini';
  if FileExists(FileName) then
  begin
    Ini := TMemIniFile.Create(FileName, TEncoding.UTF8);
    try
      if not Ini.SectionExists('Game') then
        raise Exception.Create('PI.ini requires a [Game] section');
      Keys := TStringList.Create;
      try
        Ini.ReadSections(Keys);
        for I := 0 to Keys.Count - 1 do
          if not SameText(Keys[I], 'Game') then
            raise Exception.Create('PI.ini unknown section: ' + Keys[I]);
        Ini.ReadSection('Game', Keys);
        for I := 0 to Keys.Count - 1 do
          if not SameText(Keys[I], 'Target') and not SameText(Keys[I], 'WindowTitle') then
            raise Exception.Create('PI.ini does not support key: ' + Keys[I]);
      finally
        Keys.Free;
      end;
      Raw := Trim(Ini.ReadString('Game', 'Target', Raw));
      Result.WindowTitle := Trim(Ini.ReadString('Game', 'WindowTitle', Result.WindowTitle));
    finally
      Ini.Free;
    end;
  end
  else if FileExists(Root + 'injluncher.ini') then
  begin
    Legacy := TStringList.Create;
    try
      Legacy.LoadFromFile(Root + 'injluncher.ini', TEncoding.UTF8);
      if Legacy.IndexOfName('target') >= 0 then Raw := Trim(Legacy.Values['target']);
      if (Legacy.IndexOfName('dlls') >= 0) and
        not SameText(Trim(Legacy.Values['dlls']), 'p3insight.dll') then
        raise Exception.Create('injluncher.ini: only fixed p3insight.dll is supported');
    finally
      Legacy.Free;
    end;
  end;
  if Raw = '' then raise Exception.Create('PI.ini [Game] Target is empty');
  if Result.WindowTitle = '' then raise Exception.Create('PI.ini [Game] WindowTitle is empty');
  if (Pos('"', Raw) > 0) or not SameText(ExtractFileExt(Raw), '.exe') then
    raise Exception.Create('Target must be an EXE path without arguments or quotes');
  Raw := StringReplace(Raw, '/', '\', [rfReplaceAll]);
  if (ExtractFileDrive(Raw) = '') and (Raw[1] <> '\') then
    Result.Target := ExpandFileName(Root + Raw)
  else if ((Length(Raw) >= 3) and (Raw[2] = ':') and (Raw[3] = '\')) or
    (Copy(Raw, 1, 2) = '\\') then Result.Target := ExpandFileName(Raw)
  else raise Exception.Create('Target must be relative or fully absolute (not drive-relative)');
end;
type
  PPIWindowSearch = ^TPIWindowSearch;
  TPIWindowSearch = record
    PID: DWORD;
    Title: string;
    Window: HWND;
  end;
function EnumPIWindow(Window: HWND; Param: LPARAM): BOOL; stdcall;
var PID: DWORD; Text: array[0..1023] of Char; Search: PPIWindowSearch;
begin
  Result := True;
  Search := PPIWindowSearch(Param);
  GetWindowThreadProcessId(Window, @PID);
  if (PID <> Search.PID) or not IsWindowVisible(Window) then Exit;
  GetWindowText(Window, Text, Length(Text));
  if string(Text) = Search.Title then
  begin
    Search.Window := Window;
    Result := False;
  end;
end;
function FindPIWindow(PID: DWORD; const Title: string): HWND;
var Search: TPIWindowSearch;
begin
  Search.PID := PID;
  Search.Title := Title;
  Search.Window := 0;
  EnumWindows(@EnumPIWindow, LPARAM(@Search));
  Result := Search.Window;
end;
end.
