unit GameText;

interface

type
  TGameString = type AnsiString(936);

function ReadGameText(Text: PAnsiChar; MaxBytes: Integer = MaxInt): string;
function EncodeGameText(const Text: string): TGameString;

implementation

uses System.SysUtils;

function ReadGameText(Text: PAnsiChar; MaxBytes: Integer): string;
var Count: Integer; Bytes: TGameString;
begin
  if Text = nil then Exit('');
  Count := 0;
  while (Count < MaxBytes) and (Text[Count] <> #0) do Inc(Count);
  SetString(Bytes, Text, Count);
  Result := string(Bytes);
end;

function EncodeGameText(const Text: string): TGameString;
begin
  Result := TGameString(Text);
  if string(Result) <> Text then
    raise EConvertError.Create('Game text cannot be represented in CP936');
end;

end.
