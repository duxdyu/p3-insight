unit PIFormResourceTests;
interface
procedure RunFormResourceTest(const FileName: string);
implementation
uses System.SysUtils, System.Classes, System.StrUtils, Vcl.Forms, Vcl.Controls,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Buttons, Vcl.ImgList, Vcl.Menus,
  Vcl.ActnList, Vcl.Imaging.jpeg, Vcl.Imaging.pngimage, VirtualTrees, GR32_Image,
  JvSpin, JvTabBar, JvWavePlayer, JvXPContainer, BarMenus, BcXPMenuDrawModule;

procedure RunFormResourceTest(const FileName: string);
var Lines: TStringList; Input: TStringStream; Binary: TMemoryStream;
    Form: TForm; I, Expected: Integer; Line: string;
begin
  RegisterClasses([TAction,TActionList,TBcBarPopupMenu,TBcXPMenuDrawModule,TBevel,TBitBtn,
    TBitmap32List,TButton,TCheckBox,TComboBox,TEdit,TGroupBox,TImage,TImage32,TImageList,
    TJvSpinEdit,TJvTabBar,TJvWavePlayer,TJvXPContainer,TLabel,TMenuItem,TPageControl,
    TPaintBox,TPanel,TRadioButton,TRadioGroup,TSpeedButton,TStaticText,TStatusBar,
    TTabSheet,TTimer,TVirtualStringTree]);
  Lines:=TStringList.Create;
  try
    Lines.LoadFromFile(FileName,TEncoding.UTF8);
    Expected:=0;
    for I:=Lines.Count-1 downto 0 do
    begin
      Line:=Trim(Lines[I]);
      if StartsText('object ',Line) then Inc(Expected);
      // Disable game handlers in this in-memory fixture only. No source DFM edits.
      if StartsText('On',Line) and (Pos('=',Line)>0) then Lines.Delete(I);
    end;
    Lines[0]:='object PIFormFixture: TForm';
    Input:=TStringStream.Create(Lines.Text,TEncoding.UTF8);
    Binary:=TMemoryStream.Create;
    Form:=TForm.CreateNew(nil);
    try
      ObjectTextToBinary(Input,Binary);
      Binary.Position:=0;
      Binary.ReadComponent(Form);
      if Form.ComponentCount<>Expected-1 then
        raise Exception.CreateFmt('Resource component count: %d vs %d',[Form.ComponentCount,Expected-1]);
      Writeln('PASS: full PI DFM streamed into hidden fixture; ',Expected,' objects, no game handlers executed');
    finally Form.Free; Binary.Free; Input.Free; end;
  finally Lines.Free; end;
end;
end.
