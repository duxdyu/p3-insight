unit PIGameReadiness;

interface

uses Winapi.Windows;

type
  TPIReadMemory = function(Context: Pointer; Address: Cardinal;
    var Buffer; Size: Cardinal): Boolean;
  TPIReadySnapshot = record
    GameRoot, World, CityTable, LoopClock, FrameSerial: Cardinal;
  end;
  TPIReadinessState = record
    Seeded: Boolean;
    Advances: Integer;
    Previous: TPIReadySnapshot;
  end;

function ReadPIReadySnapshot(ReadMemory: TPIReadMemory; Context: Pointer;
  out Sample: TPIReadySnapshot): Boolean;
function ObservePIReadySample(var State: TPIReadinessState;
  Valid: Boolean; const Sample: TPIReadySnapshot): Boolean;
function PollPIReadiness(Process: THandle; var State: TPIReadinessState): Boolean;
procedure ResetPIReadiness(var State: TPIReadinessState);

implementation

procedure ResetPIReadiness(var State: TPIReadinessState);
begin
  FillChar(State, SizeOf(State), 0);
end;

function ReadPIReadySnapshot(ReadMemory: TPIReadMemory; Context: Pointer;
  out Sample: TPIReadySnapshot): Boolean;
var Node, Count, Root, VT, World, Check, Tiles: Cardinal;
    Cities, Players, Flag, Probe: Byte;

  function R32(Address: Cardinal; out Value: Cardinal): Boolean;
  begin
    Result := ReadMemory(Context, Address, Value, 4);
  end;

  function Field(Base, Offset, Size: Cardinal; var Value): Boolean;
  begin
    Result := (Base >= $10000) and
      (UInt64(Base)+Offset+Size <= $100000000);
    if Result then Result := ReadMemory(Context, Base+Offset, Value, Size);
  end;

begin
  Result := False;
  FillChar(Sample, SizeOf(Sample), 0);
  if not Assigned(ReadMemory) then Exit;
  // The registry may already contain CGameScreen while a load callback runs.
  // Require the actual TOP screen used by 565E10, not a search anywhere in it.
  if not R32($6E2030, Count) or (Count = 0) or (Count > 64) then Exit;
  if not R32($6E202C, Node) or not Field(Node, 8, 4, Root) then Exit;
  if not R32($6DD5E0, Check) or (Root <> Check) then Exit;
  if not Field(Root, 0, 4, VT) or (VT <> $6886E8) then Exit;
  if not R32($6DEF7C, World) then Exit;
  if not Field(World, 0, 4, VT) or (VT <> $68B1A8) then Exit;
  // 4F16AF..4F16C1 enables the initialized world after loading/selection.
  // vtable+CC -> 4DBB10 -> 45C6D0 writes +48; +34 -> 45BD20 writes +41.
  if not Field(World, $48, 1, Flag) or (Flag <> 1) then Exit;
  if not Field(World, $41, 1, Flag) or (Flag <> 1) then Exit;
  if not Field(World, $C308, 4, Tiles) or not Field(Tiles, 0, 1, Probe) then Exit;
  if not ReadMemory(Context, $71CDB8, Cities, 1) or
     (Cities = 0) or (Cities > 40) then Exit;
  if not ReadMemory(Context, $71CDB2, Players, 1) or (Players = 0) then Exit;
  if not R32($71CE10, Sample.CityTable) or
     not Field(Sample.CityTable, 0, 1, Probe) then Exit;
  // 585B60 is called by 565E10 after the message pump. Loading progress can
  // draw without returning through this loop, so a frame counter alone fails.
  if not R32($6ECFA0, Sample.LoopClock) or
     not R32($6ECF9C, Sample.FrameSerial) then Exit;
  // Reject sampled transitions. No target writes, calls, injection or hooks.
  if not R32($6E202C, Check) or (Check <> Node) then Exit;
  if not Field(Node, 8, 4, Check) or (Check <> Root) then Exit;
  if not R32($6DEF7C, Check) or (Check <> World) then Exit;
  if not R32($71CE10, Check) or (Check <> Sample.CityTable) then Exit;
  Sample.GameRoot := Root;
  Sample.World := World;
  Result := True;
end;

function ObservePIReadySample(var State: TPIReadinessState;
  Valid: Boolean; const Sample: TPIReadySnapshot): Boolean;
var ClockDelta, FrameDelta: Cardinal;
begin
  Result := False;
  if not Valid then
  begin
    ResetPIReadiness(State);
    Exit;
  end;
  if State.Seeded and (State.Previous.GameRoot = Sample.GameRoot) and
    (State.Previous.World = Sample.World) and
    (State.Previous.CityTable = Sample.CityTable) then
  begin
    ClockDelta := Cardinal((UInt64(Sample.LoopClock)+$100000000-
      State.Previous.LoopClock) and $FFFFFFFF);
    FrameDelta := Cardinal((UInt64(Sample.FrameSerial)+$100000000-
      State.Previous.FrameSerial) and $FFFFFFFF);
    if (ClockDelta >= $80000000) or (FrameDelta >= $80000000) then
    begin
      State.Advances := 0;
      State.Previous := Sample;
    end
    else if (ClockDelta > 0) and (FrameDelta >= 2) then
    begin
      if State.Advances < 3 then Inc(State.Advances);
      State.Previous := Sample;
    end;
    // Unchanged polls are pending, not failed evidence. Slow XP frames must
    // not require the game to run faster than the launcher's 100 ms timer.
    Exit(State.Advances >= 3);
  end;
  State.Previous := Sample;
  State.Seeded := True;
  State.Advances := 0;
end;

function ProcessRead(Context: Pointer; Address: Cardinal;
  var Buffer; Size: Cardinal): Boolean;
var BytesRead: NativeUInt;
begin
  Result := ReadProcessMemory(THandle(Context), Pointer(Address), @Buffer,
    Size, BytesRead) and (BytesRead = Size);
end;

function PollPIReadiness(Process: THandle; var State: TPIReadinessState): Boolean;
var Sample: TPIReadySnapshot; Valid: Boolean;
begin
  Valid := ReadPIReadySnapshot(ProcessRead, Pointer(Process), Sample);
  Result := ObservePIReadySample(State, Valid, Sample);
end;

end.
