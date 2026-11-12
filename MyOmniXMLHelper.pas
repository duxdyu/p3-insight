unit MyOmniXMLHelper;

interface

uses SysUtils, OmniXML;

type
  EMyXML = class(Exception);
  TMyXMLUtils = class
  public
    class function LoadXMLDocFromFile(const FileName: string): IXMLDocument; static;
    class function FindFirstChildElmtNamed(const Parent: IXMLNode; const Name: string): IXMLElement; static;
    class function GetFirstChildElmtNamed(const Parent: IXMLNode; const Name: string): IXMLElement; static;
    class function FindNextSiblingElmtSameName(const Element: IXMLElement): IXMLElement; static;
    class function GetAttrValue(const Element: IXMLElement; const Name: string; AllowEmpty: Boolean = True): string; static;
    class function GetAttrValueNotEmpty(const Element: IXMLElement; const Name: string): string; static;
    class function GetAttrValueDef(const Element: IXMLElement; const Name, Default: string): string; static;
    class function GetAttrValueDefEmpty(const Element: IXMLElement; const Name: string): string; static;
    class function GetAttrValueAsBoolean(const Element: IXMLElement; const Name: string): Boolean; static;
    class function GetAttrValueAsBooleanDef(const Element: IXMLElement; const Name: string; Default: Boolean): Boolean; static;
    class function GetAttrValueAsLongInt(const Element: IXMLElement; const Name: string): LongInt; static;
    class function GetAttrValueAsLongIntDef(const Element: IXMLElement; const Name: string; Default: LongInt): LongInt; static;
    class function GetAttrValueAsByte(const Element: IXMLElement; const Name: string): Byte; static;
    class function CreateUTF8EncodedXMLDocDefault(const RootName: string): IXMLDocument; static;
    class function CreateChildElmt(const Parent: IXMLNode; const Name: string): IXMLElement; static;
  end;

implementation

class function TMyXMLUtils.LoadXMLDocFromFile(const FileName: string): IXMLDocument;
begin
  Result := CreateXMLDoc;
  if not Result.Load(FileName) then
    raise EMyXML.CreateFmt('Cannot load XML: %s', [FileName]);
  if Result.DocumentElement = nil then
    raise EMyXML.CreateFmt('XML root missing: %s', [FileName]);
end;

class function TMyXMLUtils.FindFirstChildElmtNamed(const Parent: IXMLNode; const Name: string): IXMLElement;
var Node: IXMLNode;
begin
  Result := nil;
  if Parent = nil then Exit;
  Node := Parent.FirstChild;
  while Node <> nil do
  begin
    if (Node.NodeType = ELEMENT_NODE) and (Node.NodeName = Name) then
      Exit(Node as IXMLElement);
    Node := Node.NextSibling;
  end;
end;

class function TMyXMLUtils.GetFirstChildElmtNamed(const Parent: IXMLNode; const Name: string): IXMLElement;
begin
  Result := FindFirstChildElmtNamed(Parent, Name);
  if Result = nil then raise EMyXML.CreateFmt('Required XML element missing: %s', [Name]);
end;

class function TMyXMLUtils.FindNextSiblingElmtSameName(const Element: IXMLElement): IXMLElement;
var Node: IXMLNode;
begin
  Result := nil;
  if Element = nil then Exit;
  Node := Element.NextSibling;
  while Node <> nil do
  begin
    if (Node.NodeType = ELEMENT_NODE) and (Node.NodeName = Element.NodeName) then
      Exit(Node as IXMLElement);
    Node := Node.NextSibling;
  end;
end;

class function TMyXMLUtils.GetAttrValue(const Element: IXMLElement; const Name: string; AllowEmpty: Boolean): string;
begin
  if (Element = nil) or (Element.GetAttributeNode(Name) = nil) then
    raise EMyXML.CreateFmt('Required XML attribute missing: %s', [Name]);
  Result := Element.GetAttribute(Name);
  if not AllowEmpty and (Result = '') then
    raise EMyXML.CreateFmt('Required XML attribute empty: %s', [Name]);
end;

class function TMyXMLUtils.GetAttrValueNotEmpty(const Element: IXMLElement; const Name: string): string;
begin
  Result := GetAttrValue(Element, Name, False);
end;

class function TMyXMLUtils.GetAttrValueDef(const Element: IXMLElement; const Name, Default: string): string;
begin
  if (Element = nil) or (Element.GetAttributeNode(Name) = nil) then Exit(Default);
  Result := Element.GetAttribute(Name);
end;

class function TMyXMLUtils.GetAttrValueDefEmpty(const Element: IXMLElement; const Name: string): string;
begin
  Result := GetAttrValueDef(Element, Name, '');
end;

function ParseBoolean(const Value: string): Boolean;
begin
  if SameText(Trim(Value), 'true') or (Trim(Value) = '1') then Exit(True);
  if SameText(Trim(Value), 'false') or (Trim(Value) = '0') then Exit(False);
  raise EMyXML.CreateFmt('Invalid XML boolean: %s', [Value]);
end;

class function TMyXMLUtils.GetAttrValueAsBoolean(const Element: IXMLElement; const Name: string): Boolean;
begin
  Result := ParseBoolean(GetAttrValueNotEmpty(Element, Name));
end;

class function TMyXMLUtils.GetAttrValueAsBooleanDef(const Element: IXMLElement; const Name: string; Default: Boolean): Boolean;
begin
  if (Element = nil) or (Element.GetAttributeNode(Name) = nil) then Exit(Default);
  Result := GetAttrValueAsBoolean(Element, Name);
end;

class function TMyXMLUtils.GetAttrValueAsLongInt(const Element: IXMLElement; const Name: string): LongInt;
begin
  Result := StrToInt(Trim(GetAttrValueNotEmpty(Element, Name)));
end;

class function TMyXMLUtils.GetAttrValueAsLongIntDef(const Element: IXMLElement; const Name: string; Default: LongInt): LongInt;
begin
  if (Element = nil) or (Element.GetAttributeNode(Name) = nil) then Exit(Default);
  Result := GetAttrValueAsLongInt(Element, Name);
end;

class function TMyXMLUtils.GetAttrValueAsByte(const Element: IXMLElement; const Name: string): Byte;
var Value: LongInt;
begin
  Value := GetAttrValueAsLongInt(Element, Name);
  if (Value < 0) or (Value > 255) then raise EMyXML.CreateFmt('XML byte out of range: %s', [Name]);
  Result := Value;
end;

class function TMyXMLUtils.CreateUTF8EncodedXMLDocDefault(const RootName: string): IXMLDocument;
begin
  Result := CreateXMLDoc;
  Result.AppendChild(Result.CreateProcessingInstruction('xml', 'version="1.0" encoding="UTF-8"'));
  Result.AppendChild(Result.CreateElement(RootName));
end;

class function TMyXMLUtils.CreateChildElmt(const Parent: IXMLNode; const Name: string): IXMLElement;
begin
  if Parent = nil then raise EMyXML.Create('Cannot append to nil XML parent');
  Result := Parent.OwnerDocument.CreateElement(Name);
  Parent.AppendChild(Result);
end;

end.
