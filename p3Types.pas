unit p3Types;

interface
uses
  SysUtils, Classes, Windows;

type
  TCityIconType = (
    CI__RED,
    CI__RED_BLUE,
    CI__BLUE
  );
  
  TGoodsImageProvider = class
  public
    function  get(const aGoodsID: Integer): HDC; virtual; abstract;
//    function  height(): Integer;  virtual; abstract;
    function  rect(): TRect;  virtual; abstract;
  end;


//  TCityIconTypeProvider = class
//  public
//    function  get(const cityCode: Byte): TCityIconType; virtual; abstract;
//  end;


const
  Txt_All = '(全部)';
  Txt_None = '(无)';
  Txt_Tick = '√';
  Txt_CycleClear = '○';
  Txt_CycleSolid = '●';
  Txt_SquareClear = '□';
  Txt_SquareSolid = '■';
  Txt_Infinite = '∞';
  

implementation

end.
