program ReadinessTests;
{$APPTYPE CONSOLE}
{$SETPEOSVERSION 5.1}
{$SETPESUBSYSVERSION 5.1}
uses Winapi.Windows, System.SysUtils, System.Generics.Collections,
  PIGameReadiness;
var Memory: TDictionary<Cardinal, Byte>; Tests: Integer;
    Denied: Cardinal; ChangeRoot: Boolean; Reads: Integer;

procedure Put(Address: Cardinal; Value: Cardinal; Size: Integer = 4);
var I: Integer;
begin
  for I := 0 to Size-1 do Memory.AddOrSetValue(Address+Cardinal(I), Byte(Value shr (8*I)));
end;

function ReadFixture(Context: Pointer; Address: Cardinal; var Buffer; Size: Cardinal): Boolean;
var I: Cardinal; V: Byte;
begin
  Inc(Reads);
  Result := False;
  if Address = Denied then Exit;
  if ChangeRoot and (Address = $6E202C) and (Reads > 10) then Exit;
  for I := 0 to Size-1 do
  begin
    if not Memory.TryGetValue(Address+I, V) then Exit;
    PByte(NativeUInt(@Buffer)+I)^ := V;
  end;
  Result := True;
end;

procedure Check(Value: Boolean; const Text: string);
begin
  Inc(Tests);
  if not Value then raise Exception.Create(Text);
end;

procedure Seed;
begin
  Memory.Clear; Denied := 0; ChangeRoot := False; Reads := 0;
  Put($6E2030, 1); Put($6E202C, $10000); Put($10008, $20000);
  Put($6DD5E0, $20000); Put($20000, $6886E8);
  Put($6DEF7C, $30000); Put($30000, $68B1A8);
  Put($30048, 1, 1); Put($30041, 1, 1);
  Put($3C308, $40000); Put($40000, 0, 1);
  Put($71CDB8, 24, 1); Put($71CDB2, 30, 1);
  Put($71CE10, $50000); Put($50000, 0, 1);
  Put($6ECFA0, 100); Put($6ECF9C, 10);
end;

function Sample(out S: TPIReadySnapshot): Boolean;
begin
  Reads := 0;
  Result := ReadPIReadySnapshot(ReadFixture, nil, S);
end;

var S: TPIReadySnapshot; State: TPIReadinessState; I: Integer;
    Addresses: TArray<Cardinal>;
begin
  Memory := TDictionary<Cardinal, Byte>.Create;
  try
    try
      Seed;
      Check(Sample(S), 'initialized world sample');
      ResetPIReadiness(State);
      Check(not ObservePIReadySample(State, True, S), 'first observation only seeds');
      for I := 1 to 100 do Check(not ObservePIReadySample(State, True, S), 'frozen loading state never ready');
      Inc(S.FrameSerial, 20);
      Check(not ObservePIReadySample(State, True, S), 'progress repaint alone is not main-loop progress');
      Inc(S.LoopClock, 20);
      Check(not ObservePIReadySample(State, True, S), 'first loop advance not enough');
      Check(State.Advances = 1, 'separate start/end observations combine');
      ResetPIReadiness(State); ObservePIReadySample(State, True, S);
      for I := 1 to 3 do
      begin
        Check(not ObservePIReadySample(State, True, S), 'slow frames stay pending');
        Inc(S.FrameSerial, 4); Inc(S.LoopClock, 40);
        Check(ObservePIReadySample(State, True, S) = (I = 3), 'three native loop advancements');
      end;
      Inc(S.World, $10000); Inc(S.FrameSerial, 4); Inc(S.LoopClock, 40);
      Check(not ObservePIReadySample(State, True, S), 'new world reseeds');
      Check(not ObservePIReadySample(State, False, S), 'invalid snapshot resets');
      Check(not State.Seeded, 'reset state');
      S.FrameSerial := $FFFFFFFE; S.LoopClock := $FFFFFFF0;
      ObservePIReadySample(State, True, S);
      S.FrameSerial := 2; S.LoopClock := 20;
      ObservePIReadySample(State, True, S);
      Check(State.Advances = 1, '32-bit wraparound');
      S.FrameSerial := 1; S.LoopClock := 19;
      Check(not ObservePIReadySample(State, True, S), 'counter rollback rejected');
      Seed; Put($20000, $6899B0); Check(not Sample(S), 'tables populated in menu rejected');
      Seed; Put($10008, $60000); Put($60000, $68B318); Check(not Sample(S), 'game below load screen rejected');
      Seed; Put($30048, 0, 1); Check(not Sample(S), 'world hidden rejected');
      Seed; Put($30041, 0, 1); Check(not Sample(S), 'world disabled rejected');
      Seed; Put($30000, $12345678); Check(not Sample(S), 'wrong world ABI rejected');
      Seed; Put($3C308, 0); Check(not Sample(S), 'world tiles unavailable rejected');
      Seed; Put($6E2030, 65); Check(not Sample(S), 'invalid list count rejected');
      Seed; Put($6DEF7C, $FFFFFFF0); Check(not Sample(S), 'pointer overflow rejected');
      Seed; ChangeRoot := True; Check(not Sample(S), 'concurrent root transition rejected');
      Seed; Addresses := Memory.Keys.ToArray;
      // Denying every read start proves errors do not turn into ready defaults.
      for I := 0 to High(Addresses) do
      begin
        Denied := Addresses[I];
        if (Denied = $6E2030) or (Denied = $6E202C) or (Denied = $10008) or
           (Denied = $6DD5E0) or (Denied = $20000) or (Denied = $6DEF7C) or
           (Denied = $30000) or (Denied = $30048) or (Denied = $30041) or
           (Denied = $3C308) or (Denied = $40000) or (Denied = $71CDB8) or
           (Denied = $71CDB2) or (Denied = $71CE10) or (Denied = $50000) or
           (Denied = $6ECFA0) or (Denied = $6ECF9C) then
          Check(not Sample(S), 'read failure rejected '+IntToHex(Denied, 8));
      end;
      Writeln('PASS ', Tests, ' production readiness checks; no game/no injection');
    except on E: Exception do begin Writeln('FAIL: '+E.Message); Halt(1); end; end;
  finally Memory.Free; end;
end.
