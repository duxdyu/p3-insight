program XMLHelperTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, OmniXML, MyOmniXMLHelper;
var Doc, Reloaded: IXMLDocument; El, Next: IXMLElement; Raised: Boolean;
procedure Check(Value: Boolean; const Message: string);
begin
  if not Value then raise Exception.Create(Message);
end;
begin
  try
    Doc := CreateXMLDoc;
    Check(Doc.LoadXML('<root><!--skip--><item name="" b="true" n="$FF"/><other/><item name="second" b="0" n="-5"/></root>'), 'parse');
    El := TMyXMLUtils.GetFirstChildElmtNamed(Doc.DocumentElement, 'item');
    Check(TMyXMLUtils.GetAttrValue(El, 'name', True) = '', 'present empty');
    Check(TMyXMLUtils.GetAttrValueDef(El, 'name', 'fallback') = '', 'empty is not missing');
    Check(TMyXMLUtils.GetAttrValueDef(El, 'missing', 'fallback') = 'fallback', 'missing default');
    Check(TMyXMLUtils.GetAttrValueAsBoolean(El, 'b'), 'true');
    Check(TMyXMLUtils.GetAttrValueAsByte(El, 'n') = 255, 'hex byte');
    Raised := False;
    try TMyXMLUtils.GetAttrValueNotEmpty(El, 'name'); except on E: EMyXML do Raised := True; end;
    Check(Raised, 'required empty rejected');
    Next := TMyXMLUtils.FindNextSiblingElmtSameName(El);
    Check(TMyXMLUtils.GetAttrValue(Next, 'name') = 'second', 'same-name sibling');
    Check(not TMyXMLUtils.GetAttrValueAsBoolean(Next, 'b'), 'false');
    Check(TMyXMLUtils.GetAttrValueAsLongInt(Next, 'n') = -5, 'negative integer');
    Check(TMyXMLUtils.FindNextSiblingElmtSameName(Next) = nil, 'end siblings');
    El.SetAttribute('b', 'bogus');
    Raised := False;
    try TMyXMLUtils.GetAttrValueAsBooleanDef(El, 'b', True); except on E: EMyXML do Raised := True; end;
    Check(Raised, 'invalid present boolean must not use default');
    El.SetAttribute('n', '256');
    Raised := False;
    try TMyXMLUtils.GetAttrValueAsByte(El, 'n'); except on E: EMyXML do Raised := True; end;
    Check(Raised, 'byte overflow');
    Doc := TMyXMLUtils.CreateUTF8EncodedXMLDocDefault('root');
    El := TMyXMLUtils.CreateChildElmt(Doc.DocumentElement, 'item');
    El.SetAttribute('name', WideChar($4E2D) + WideChar($6587));
    Doc.Save(ParamStr(1), ofIndent);
    Reloaded := TMyXMLUtils.LoadXMLDocFromFile(ParamStr(1));
    Check(TMyXMLUtils.GetAttrValue(TMyXMLUtils.GetFirstChildElmtNamed(Reloaded.DocumentElement, 'item'), 'name') = string(WideChar($4E2D) + WideChar($6587)), 'Unicode UTF-8 round trip');
    Writeln('PASS: XML required/default/empty, sibling, boolean, integer/byte, UTF-8 round trip');
  except
    on E: Exception do begin Writeln(E.ClassName, ': ', E.Message); Halt(1); end;
  end;
end.
