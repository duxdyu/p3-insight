unit PIHistoricalCoreTests;

interface

procedure RunHistoricalCoreTests;

implementation

uses System.SysUtils, p3DataStruct, p3insight_utils, VirtualTrees, Vcl.Forms,
  PIProductionEdit, P3ProductionRules;

procedure Check(Condition: Boolean; const Message: string);
begin
  if not Condition then raise Exception.Create('Historical core: ' + Message);
end;

procedure CheckNear(Actual, Expected: Double; const Message: string);
begin
  Check(Abs(Actual - Expected) < 0.000001, Message);
end;

procedure RunHistoricalCoreTests;
const
  // Historical DLL $4E329C switch, all 20 goods plus default 1.
  ProductionCosts: array[1..20] of Integer =
    (110,957,440,34,28,110,279,220,206,676,82,55,255,224,880,55,880,440,170,79);
  ProductionOffsets: array[1..20] of Integer =
    ($8D8,$8E8,$898,$8A8,$918,$8C8,-1,$948,$908,$888,$2CC,$8F8,$8B8,$8E8,$938,$978,$928,$988,$958,$968);
  BoundaryRates: array[0..10] of Word = (0,1,200,201,768,899,900,901,1000,1024,4096);
var
  Route: TTradeRoute;
  City: TCityStruct;
  Goods, Grade, ExpectedLevel, RateIndex: Integer;
  Rate: Word;
  Tables: TProductionTables;
  BytesBefore: array[0..$9F7] of Byte;
  I, Kind: Integer;
  Offset: NativeUInt;
  Consume: TResidentConsumePrecalc;
  Host: TForm;
  Tree: TVirtualStringTree;
  First, Second, LowAddress, HighAddress: PVirtualNode;
begin
  // Historical $4E1CA0 stride; $4E3184/$4E321C array accesses.
  Check(SizeOf(Route) = $DC, 'trade route stride 220');
  Check(NativeUInt(@Route.Orders) - NativeUInt(@Route) = 4, 'route orders offset');
  Check(NativeUInt(@Route.Prices) - NativeUInt(@Route) = $1C, 'route prices offset');
  Check(NativeUInt(@Route.MaxQty) - NativeUInt(@Route) = $7C, 'route quantity offset');
  // Historical $4E10B0 city stride, $4E21DC population reads.
  Check(SizeOf(City) = $9F8, 'city stride 2552');
  Check(NativeUInt(@City.Pop_rich) - NativeUInt(@City) = $2D8, 'rich population offset');
  Check(NativeUInt(@City.Pop_common) - NativeUInt(@City) = $2DC, 'common population offset');
  Check(NativeUInt(@City.Pop_poor) - NativeUInt(@City) = $2E0, 'poor population offset');
  Check(SizeOf(TCityBuilding) = 8, 'city building stride');
  Check(SizeOf(TBusinessOffice) = 1100, 'business office stride');
  Move(ExpectedProductionFactors,Tables.Coefficient,SizeOf(Tables.Coefficient));
  Move(ExpectedProductionCaps,Tables.Capacity,SizeOf(Tables.Capacity));
  for Goods:=0 to 19 do
  begin
    FillChar(City,SizeOf(City),0);
    City.CityCode:=15;
    for I:=0 to 20 do
    begin
      PByte(NativeUInt(@City)+$846+I*16)^:=I;
      PByte(NativeUInt(@City)+$847+I*16)^:=15;
    end;
    Kind:=GoodsToProductionType(Goods);
    if Kind=ProductionWhaleType then Kind:=5;
    Move(City,BytesBefore,SizeOf(City));
    EditLocalProduction(@City,Goods,Tables);
    for I:=0 to High(BytesBefore) do
    begin
      if Kind>=0 then
      begin
        Offset:=$840+Kind*16;
        if ((I>=Integer(Offset)) and (I<Integer(Offset)+6)) or
           ((I>=Integer(Offset)+8) and (I<Integer(Offset)+10)) or
           ((Kind=5) and (I>=$2CC) and (I<$2D0)) then Continue;
      end;
      Check(PByte(NativeUInt(@City)+I)^=BytesBefore[I],'local editor did not change unrelated city bytes');
    end;
    if Kind>=0 then
    begin
      Check(PCardinal(NativeUInt(@City)+$840+Kind*16)^=ComputeLocalCoefficient(City.OriginalProd[Kind].Rate,Tables.Coefficient[Kind]),'local coefficient updated');
      Check(PWord(NativeUInt(@City)+$844+Kind*16)^>0,'local supply enabled');
    end;
  end;
  FillChar(City,SizeOf(City),0);
  PByte(NativeUInt(@City)+$896)^:=5;
  for I:=1 to 6 do
  begin
    EditLocalProduction(@City,2,Tables);
    case I mod 3 of
      1: Check((City.OriginalProd[5].Rate=768) and (City.WhaleOilProdRate=1024),'fish low whale high');
      2: Check((City.OriginalProd[5].Rate=1024) and (City.WhaleOilProdRate=0),'fish high whale none');
      0: Check((City.OriginalProd[5].Rate=0) and (City.WhaleOilProdRate=0) and
               (PWord(NativeUInt(@City)+$894)^=0) and (PCardinal(NativeUInt(@City)+$890)^=0),'fish off clears local supply');
    end;
  end;
  EditLocalProduction(@City,10,Tables);
  Check((City.OriginalProd[5].Rate=768) and (City.WhaleOilProdRate=1024),'whale enable');
  EditLocalProduction(@City,10,Tables);
  Check((City.OriginalProd[5].Rate=1024) and (City.WhaleOilProdRate=0),'whale disable restores fish high');
  Writeln('PASS: PI local-only edits for 20 goods, unrelated bytes, activation and closed fish/whale cycles');
  Check(High(City.OriginalProd) = 20, 'hemp production record within declared array');
  Check(NativeUInt(@City.OriginalProd[20].Rate)-NativeUInt(@City)=$988, 'hemp native offset');
  Check(NativeUInt(@City.Soldiers)-NativeUInt(@City)=$998, 'soldiers unchanged after production record');
  for Goods := 1 to 20 do
  begin
    if (Goods <> GOODSID__SPICE) and (Goods <> GOODSID__WHALE_OIL) then
    begin
      RateIndex := GoodsIDToProdRateIndex(Goods);
      Check((RateIndex >= Low(City.OriginalProd)) and (RateIndex <= High(City.OriginalProd)), 'all goods within production array');
      Check(NativeUInt(@City.OriginalProd[RateIndex].Rate)-NativeUInt(@City)=NativeUInt(ProductionOffsets[Goods]), 'all native goods offsets');
    end;
    for Rate in BoundaryRates do
    begin
      FillChar(City, SizeOf(City), 0);
      if Goods <> GOODSID__SPICE then
        PWord(NativeUInt(@City)+NativeUInt(ProductionOffsets[Goods]))^ := Rate;
      ExpectedLevel := PROD_LVL__NO_PROD;
      if Goods = GOODSID__WHALE_OIL then
      begin
        if Rate > 1000 then ExpectedLevel := PROD_LVL__HIGH_PROD
        else if Rate > 0 then ExpectedLevel := PROD_LVL__LOW_PROD;
      end
      else if Goods <> GOODSID__SPICE then
      begin
        if Rate > 900 then ExpectedLevel := PROD_LVL__HIGH_PROD
        else if (Rate > 200) and (Rate < 900) then ExpectedLevel := PROD_LVL__LOW_PROD;
      end;
      Check(getCityOriginalProdLvl(@City,Goods)=ExpectedLevel, 'native statue boundary classification');
    end;
  end;

  FillChar(Route, SizeOf(Route), 0);
  Writeln('PASS: 20 production mappings, hemp slot bounds, city layout and 220 native statue boundary cases');
  Route.setFirstFlag; Route.setFixFlag; Route.setNoStopFlag;
  Check(Route.Flags = $0D, 'route flag bits');
  Route.clearFixFlag;
  Check(Route.isFirstFlagSet and Route.isNoStopFlagSet and not Route.isFixFlagSet, 'independent route flags');
  Route.setBuy(1, 110, 450);
  Check((LongInt(Route.Prices[1]) = -110) and (Route.getOpType(1) = RT__BUY), 'buy signed price');
  Route.setSell(2, -110, 450);
  Check((Route.Prices[2] = 110) and (Route.getOpType(2) = RT__SELL), 'sell signed price');
  Route.setPutInto(3, 450);
  Check((LongInt(Route.MaxQty[3]) = -450) and (Route.getOpType(3) = RT__PUT_INTO), 'put into signed quantity');
  Route.setGetOut(4, -450);
  Check((Route.MaxQty[4] = 450) and (Route.getOpType(4) = RT__GET_OUT), 'get out signed quantity');
  Check((Route.getPrice(1) = 110) and (Route.getMaxQty(3) = 450), 'route absolute getters');
  Route.setBuy(5, 1, 1000000000);
  Check(Route.IsUnlimitedQty(5), 'historical unlimited quantity sentinel');
  Route.setNoOp(5);
  Check(Route.getOpType(5) = RT__UNSPECIFIED, 'zero quantity disables order');

  for Goods := 1 to 20 do Check(getGeneralGoodsProdCost(Goods) = ProductionCosts[Goods], 'production price table');
  Check((getGeneralGoodsProdCost(0) = 1) and (getGeneralGoodsProdCost(21) = 1), 'production default');
  Check(isWinter(1) and isWinter(2) and isWinter(12) and not isWinter(3), 'winter months');
  CheckNear(calcWinterReqIncrease(100, GOODSID__WOOD), 120, 'winter wood requirement');
  CheckNear(calcWinterReqIncrease(100, GOODSID__ANIMAL_SKIN), 120, 'winter skin requirement');
  CheckNear(calcWinterReqIncrease(100, GOODSID__RICE), 100, 'other requirements unchanged');
  Consume := TResidentConsumePrecalc.Create;
  try
    // Prepared synthetic cache: these calls never read game process memory.
    Consume.Ready := True;
    for Goods := 1 to 20 do
      for Grade := 0 to 2 do
      begin
        Consume.items[Goods].ThousandResidentsReqsInWeek[Grade] := 70;
        CheckNear(Consume.internalCalcWeek(Grade, Goods, 1500), 105, 'weekly residents /1000');
        CheckNear(Consume.calcWeek(Grade, Goods, 1500), 105, 'week cache wrapper');
        CheckNear(Consume.calcDay(Grade, Goods, 1500), 15, 'day /7');
      end;
  finally
    Consume.Free;
  end;

  Host := TForm.CreateNew(nil);
  Tree := TVirtualStringTree.Create(Host);
  try
    Tree.Parent := Host;
    Tree.TreeOptions.SelectionOptions := Tree.TreeOptions.SelectionOptions + [toMultiSelect];
    Tree.RootNodeCount := 3;
    First := Tree.GetFirst;
    Second := Tree.GetNextSibling(First);
    Tree.FocusedNode := First;
    Tree.SelectNode(First);
    Tree.SelectNode(Second);
    Check((Tree.SelectedCount = 2) and Tree.Selected[First] and Tree.Selected[Second], 'SelectNode retains multi-selection');
    Check(Tree.FocusedNode = First, 'SelectNode does not change focus');
    if NativeUInt(First) < NativeUInt(Second) then
    begin LowAddress := First; HighAddress := Second; end
    else
    begin LowAddress := Second; HighAddress := First; end;
    Tree.MoveTo(HighAddress, LowAddress, amInsertBefore, False);
    Check(Tree.GetFirstSelected = HighAddress, 'fixture display order differs from address order');
    Check(Tree.SelectedNode = LowAddress, 'historical SelectedNode uses address order');
    Tree.SelectNode(nil);
    Check(Tree.SelectedCount = 0, 'SelectNode(nil) clears selection');
    Check(Tree.SelectedNode = nil, 'empty SelectedNode');
    Check(Tree.FocusedNode = First, 'clear selection preserves focus');
    Tree.TreeOptions.SelectionOptions := Tree.TreeOptions.SelectionOptions - [toMultiSelect];
    Tree.SelectNode(First); Tree.SelectNode(Second);
    Check((Tree.SelectedCount = 1) and Tree.Selected[Second], 'single-select uses native SetSelected policy');
  finally
    Host.Free;
  end;
  Writeln('PASS: historical route/city/BO layouts, route flags/orders, 20 production costs, resident/week/day and winter math, selection policy');
end;

end.
