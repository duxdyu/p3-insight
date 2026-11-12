unit XPTick;

interface

// Valid for waits shorter than one complete DWORD tick cycle (49.7 days).
// These helpers also work with overflow/range checks enabled.
function ElapsedTickMs(StartTick, NowTick: Cardinal): Cardinal;
function RemainingTickMs(StartTick, NowTick, TimeoutMs: Cardinal): Cardinal;

implementation

{$OVERFLOWCHECKS ON}
{$RANGECHECKS ON}
function ElapsedTickMs(StartTick, NowTick: Cardinal): Cardinal;
begin
  if NowTick >= StartTick then
    Result := NowTick - StartTick
  else
    Result := (High(Cardinal) - StartTick) + NowTick + 1;
end;

function RemainingTickMs(StartTick, NowTick, TimeoutMs: Cardinal): Cardinal;
var Elapsed: Cardinal;
begin
  Elapsed := ElapsedTickMs(StartTick, NowTick);
  if Elapsed >= TimeoutMs then
    Result := 0
  else
    Result := TimeoutMs - Elapsed;
end;

end.
