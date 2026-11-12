unit PIProductionEdit;

interface

uses Winapi.Windows, P3ProductionRules;

procedure ReadNativeProductionTables(Module: HMODULE; out Tables: TProductionTables);
procedure EditLocalProduction(City: Pointer; Goods0: Integer;
  const Tables: TProductionTables);

implementation

uses System.SysUtils;

type
  TLocalRecord = packed record
    Coefficient: Cardinal;
    Scale: Word;
    Kind, CityID: Byte;
    Rate: Word;
    Reserve: Word;
    Adjustment: Single;
  end;
  PLocalRecord = ^TLocalRecord;

procedure ReadNativeProductionTables(Module: HMODULE; out Tables: TProductionTables);
var Dos: PImageDosHeader; Nt: PImageNtHeaders;
begin
  if Module=0 then raise Exception.Create('Production: game module unavailable');
  Dos:=Pointer(Module);
  if Dos.e_magic<>IMAGE_DOS_SIGNATURE then raise Exception.Create('Production: invalid module');
  Nt:=Pointer(NativeUInt(Module)+Cardinal(Dos._lfanew));
  if (Nt.Signature<>IMAGE_NT_SIGNATURE) or (Nt.FileHeader.Machine<>IMAGE_FILE_MACHINE_I386) or
     (Nt.OptionalHeader.SizeOfImage<$292032) then
    raise Exception.Create('Production: unsupported module layout');
  Move(Pointer(NativeUInt(Module)+$292008)^,Tables.Coefficient,SizeOf(Tables.Coefficient));
  Move(Pointer(NativeUInt(Module)+$28BAA0)^,Tables.Capacity,SizeOf(Tables.Capacity));
  if not CompareMem(@Tables.Coefficient,@ExpectedProductionFactors,SizeOf(Tables.Coefficient)) or
     not CompareMem(@Tables.Capacity,@ExpectedProductionCaps,SizeOf(Tables.Capacity)) then
    raise Exception.Create('Production: native tables do not match this game profile');
end;

procedure EditLocalProduction(City: Pointer; Goods0: Integer;
  const Tables: TProductionTables);
var Kind: Integer; R: PLocalRecord; WhalePtr: PCardinal;
    Rate: Word; Whale: Cardinal; Scale: Word; Coefficient: Cardinal;
begin
  if City=nil then raise Exception.Create('Production: no selected city');
  Kind:=GoodsToProductionType(Goods0);
  if Kind=ProductionUnsupportedType then Exit;
  if Kind=ProductionWhaleType then Kind:=ProductionFishType;
  R:=Pointer(NativeUInt(City)+$840+NativeUInt(Kind)*16);
  if (R.Kind<>Kind) or (R.CityID<>PByte(NativeUInt(City)+$2C0)^) then
    raise Exception.Create('Production: local record identity mismatch');
  Rate:=R.Rate;
  WhalePtr:=Pointer(NativeUInt(City)+$2CC);
  Whale:=WhalePtr^;
  if Kind=ProductionFishType then
    EditFishWhale(Goods0=10,Rate,Whale)
  else
  begin
    // Keep PI's existing extended multipliers for ordinary goods.
    if Rate<$384 then Rate:=$400
    else if Rate<$600 then Rate:=$600
    else if Rate<$800 then Rate:=$800
    else if Rate<$1000 then Rate:=$1000
    else Rate:=$300;
  end;
  Coefficient:=ComputeLocalCoefficient(Rate,Tables.Coefficient[Kind]);
  Scale:=NextLocalScale(R.Scale,Rate,Byte(LocalProductionCapacity(Tables,Kind,Whale)));
  // Only local base inputs: no population, private factories, inventory,
  // weather/siege flags, reserve/adjustment, statistics or extra production calls.
  R.Rate:=Rate;
  R.Coefficient:=Coefficient;
  R.Scale:=Scale;
  if Kind=ProductionFishType then WhalePtr^:=Whale;
end;

end.
