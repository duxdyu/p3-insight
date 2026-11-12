unit PIGameProfile;

interface

uses System.SysUtils, System.Classes;

const ChinesePIABI = 'chinese-fixed-abi-pi-20261112';
function CheckGameProfile(const Target: string): string;

implementation

type
  TSection = record
    RVA, Span, Raw, RawSize, Flags: Cardinal;
  end;

function CheckGameProfile(const Target: string): string;
const
  Readable = $40000000;
  Executable = $20000000;
  Writable = $80000000;
var
  Stream: TFileStream;
  Sections: array of TSection;
  PE, Opt, Table, ImageSize, HeaderSize, Count, I, J: Cardinal;

  procedure Reject(const Detail: string);
  begin
    raise Exception.Create('PI 不支持此游戏 EXE 的地址/指令布局（中文固定 ABI）。' +
      sLineBreak + Detail + sLineBreak + Target);
  end;

  procedure ReadAt(Offset: UInt64; var Buffer; Size: Cardinal);
  begin
    if (Offset > UInt64(Stream.Size)) or
      (UInt64(Size) > UInt64(Stream.Size) - Offset) then Reject('PE/file range truncated');
    Stream.Position := Int64(Offset);
    Stream.ReadBuffer(Buffer, Size);
  end;

  function U16(Offset: UInt64): Word;
  begin
    ReadAt(Offset, Result, 2);
  end;

  function U32(Offset: UInt64): Cardinal;
  begin
    ReadAt(Offset, Result, 4);
  end;

  function MapVA(VA, Size, Flags: Cardinal; FileBacked: Boolean): UInt64;
  var K, RVA: Cardinal; S: TSection;
  begin
    Result := 0;
    if (VA < $400000) or (Size = 0) then Reject('Invalid ABI range');
    RVA := VA - $400000;
    for K := 0 to High(Sections) do
    begin
      S := Sections[K];
      if (RVA >= S.RVA) and (UInt64(RVA) + Size <= UInt64(S.RVA) + S.Span) then
      begin
        if (S.Flags and Flags) <> Flags then Reject('Section access at ' + IntToHex(VA, 8));
        if FileBacked and (UInt64(RVA-S.RVA)+Size > S.RawSize) then
          Reject('Unbacked ABI bytes at ' + IntToHex(VA, 8));
        Exit(UInt64(S.Raw) + RVA - S.RVA);
      end;
    end;
    Reject('Missing ABI range at ' + IntToHex(VA, 8));
  end;

  procedure Bytes(VA: Cardinal; const Hex: string; Flags: Cardinal;
    RawAddressed: Boolean = False);
  var Offset: UInt64; K, N: Integer; Actual, Expected: Byte;
  begin
    N := Length(Hex) div 2;
    Offset := MapVA(VA, N, Flags, True);
    // PI's XML mod offsets and several data APIs use file offsets, not RVAs.
    if RawAddressed and (Offset <> VA-$400000) then
      Reject('PI raw-offset mapping changed at ' + IntToHex(VA, 8));
    for K := 0 to N-1 do
    begin
      Expected := StrToInt('$' + Copy(Hex, 2*K+1, 2));
      ReadAt(Offset+Cardinal(K), Actual, 1);
      if Actual <> Expected then Reject('ABI bytes differ at ' + IntToHex(VA+Cardinal(K), 8));
    end;
  end;

  procedure RawRange(VA, Size, Flags: Cardinal);
  begin
    if MapVA(VA, Size, Flags, True) <> VA-$400000 then
      Reject('PI raw data mapping changed at ' + IntToHex(VA, 8));
  end;

begin
  if not FileExists(Target) then raise Exception.Create('找不到配置的游戏 EXE：' + Target);
  Stream := TFileStream.Create(Target, fmOpenRead or fmShareDenyWrite);
  try
    if U16(0) <> $5A4D then Reject('MZ signature');
    PE := U32($3C);
    if (PE < $40) or (U32(PE) <> $4550) then Reject('PE signature');
    if U16(UInt64(PE)+4) <> $14C then Reject('Requires x86');
    Count := U16(UInt64(PE)+6);
    if (Count = 0) or (Count > 96) then Reject('Section count');
    if (U16(UInt64(PE)+22) and $2002) <> $0002 then Reject('Requires executable, not DLL');
    if U16(UInt64(PE)+20) < $E0 then Reject('Optional header size');
    if UInt64(PE)+24+U16(UInt64(PE)+20)+UInt64(Count)*40 > UInt64(Stream.Size) then
      Reject('Section table truncated');
    Opt := PE+24;
    if U16(Opt) <> $10B then Reject('Requires PE32');
    if U32(Opt+28) <> $400000 then Reject('Requires image base 00400000');
    if U16(Opt+68) <> 2 then Reject('Requires GUI host');
    if (U16(Opt+70) and $40) <> 0 then Reject('Fixed-address ABI cannot use ASLR');
    ImageSize := U32(Opt+56);
    HeaderSize := U32(Opt+60);
    Table := Opt+U16(PE+20);
    if (HeaderSize < UInt64(Table)+UInt64(Count)*40) or
      (HeaderSize > UInt64(Stream.Size)) or (ImageSize < HeaderSize) then Reject('PE header extent');
    SetLength(Sections, Count);
    for I := 0 to Count-1 do
    begin
      Sections[I].Span := U32(Table+I*40+8);
      Sections[I].RVA := U32(Table+I*40+12);
      Sections[I].RawSize := U32(Table+I*40+16);
      Sections[I].Raw := U32(Table+I*40+20);
      Sections[I].Flags := U32(Table+I*40+36);
      if Sections[I].RawSize > Sections[I].Span then Sections[I].Span := Sections[I].RawSize;
      if (Sections[I].RVA < HeaderSize) or
        (UInt64(Sections[I].RVA)+Sections[I].Span > ImageSize) or
        ((Sections[I].RawSize <> 0) and ((Sections[I].Raw < HeaderSize) or
         (UInt64(Sections[I].Raw)+Sections[I].RawSize > UInt64(Stream.Size)))) then
        Reject('Section extent');
      for J := 0 to I do
        if J <> I then
        begin
          if (UInt64(Sections[I].RVA) < UInt64(Sections[J].RVA)+Sections[J].Span) and
             (UInt64(Sections[J].RVA) < UInt64(Sections[I].RVA)+Sections[I].Span) then
            Reject('Overlapping virtual sections');
          if (Sections[I].RawSize <> 0) and (Sections[J].RawSize <> 0) and
             (UInt64(Sections[I].Raw) < UInt64(Sections[J].Raw)+Sections[J].RawSize) and
             (UInt64(Sections[J].Raw) < UInt64(Sections[I].Raw)+Sections[I].RawSize) then
            Reject('Overlapping file sections');
        end;
    end;
    // Entry location/bytes are not PI ABI, but the actual entry must be executable.
    if U32(Opt+16) > $FFBFFFFF then Reject('Entry address overflow');
    MapVA($400000+U32(Opt+16), 1, Readable or Executable, True);
    // p3DataStruct globals: route/ship/captain/city, current player, GameData+$78.
    MapVA($6DD06C, $71CE28-$6DD06C, Readable or Writable, False);
    MapVA($6B05B4, 4*40, Readable, True);
    // File-offset based static reads/writes: resident/house/worker/ship tables.
    RawRange($688D30, $688F02-$688D30, Readable);
    RawRange($689084, $14, Readable);
    RawRange($68DF6C, $14, Readable);
    RawRange($6926A0, $30, Readable);
    {$I PIABIBytes.inc}
    Result := ChinesePIABI;
  finally
    Stream.Free;
  end;
end;

end.
