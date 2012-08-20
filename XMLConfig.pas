{
    $Id: laz_xmlcfg.pas 7541 2005-08-22 12:30:03Z vincents $
 **********************************************************************}

{
  TXMLConfig enables applications to use XML files for storing their
  configuration data
}

{$H+}

unit XMLConfig;

interface

uses
  SysUtils, Classes, AVLTree, FastList;

type
  DOMString = AnsiString;
  DOMPChar  = PAnsiChar;

const
  // DOM Level 1 exception codes:
  INDEX_SIZE_ERR              = 1;  // index or size is negative, or greater than the allowed value
  DOMSTRING_SIZE_ERR          = 2;  // Specified range of text does not fit into a DOMString
  HIERARCHY_REQUEST_ERR       = 3;  // node is inserted somewhere it does not belong
  WRONG_DOCUMENT_ERR          = 4;  // node is used in a different document than the one that created it (that does not support it)
  INVALID_CHARACTER_ERR       = 5;  // invalid or illegal character is specified, such as in a name
  NO_DATA_ALLOWED_ERR         = 6;  // data is specified for a node which does not support data
  NO_MODIFICATION_ALLOWED_ERR = 7;  // an attempt is made to modify an object where modifications are not allowed
  NOT_FOUND_ERR               = 8;  // an attempt is made to reference a node in a context where it does not exist
  NOT_SUPPORTED_ERR           = 9;  // implementation does not support the type of object requested
  INUSE_ATTRIBUTE_ERR         = 10;  // an attempt is made to add an attribute that is already in use elsewhere

  // DOM Level 2 exception codes:
  INVALID_STATE_ERR        = 11;  // an attempt is made to use an object that is not, or is no longer, usable
  SYNTAX_ERR               = 12;  // invalid or illegal string specified
  INVALID_MODIFICATION_ERR = 13;  // an attempt is made to modify the type of the underlying object
  NAMESPACE_ERR            = 14;  // an attempt is made to create or change an object in a way which is incorrect with regard to namespaces
  INVALID_ACCESS_ERR       = 15;  // parameter or operation is not supported by the underlying object

type
  EDOMError = class (Exception)
  public
    Code: Integer;
    constructor Create(ACode: Integer; const ASituation: AnsiString);
  end;

  EDOMIndexSize = class (EDOMError)
  public
    constructor Create(const ASituation: AnsiString);
  end;

  EDOMHierarchyRequest = class (EDOMError)
  public
    constructor Create(const ASituation: AnsiString);
  end;

  EDOMWrongDocument = class (EDOMError)
  public
    constructor Create(const ASituation: AnsiString);
  end;

  EDOMNotFound = class (EDOMError)
  public
    constructor Create(const ASituation: AnsiString);
  end;

  EDOMNotSupported = class (EDOMError)
  public
    constructor Create(const ASituation: AnsiString);
  end;

  EDOMInUseAttribute = class (EDOMError)
  public
    constructor Create(const ASituation: AnsiString);
  end;

  EDOMInvalidState = class (EDOMError)
  public
    constructor Create(const ASituation: AnsiString);
  end;

  EDOMSyntax = class (EDOMError)
  public
    constructor Create(const ASituation: AnsiString);
  end;

  EDOMInvalidModification = class (EDOMError)
  public
    constructor Create(const ASituation: AnsiString);
  end;

  EDOMNamespace = class (EDOMError)
  public
    constructor Create(const ASituation: AnsiString);
  end;

  EDOMInvalidAccess = class (EDOMError)
  public
    constructor Create(const ASituation: AnsiString);
  end;


const
  ELEMENT_NODE                = 1;
  ATTRIBUTE_NODE              = 2;
  TEXT_NODE                   = 3;
  CDATA_SECTION_NODE          = 4;
  ENTITY_REFERENCE_NODE       = 5;
  ENTITY_NODE                 = 6;
  PROCESSING_INSTRUCTION_NODE = 7;
  COMMENT_NODE                = 8;
  DOCUMENT_NODE               = 9;
  DOCUMENT_TYPE_NODE          = 10;
  DOCUMENT_FRAGMENT_NODE      = 11;
  NOTATION_NODE               = 12;


type
  TDOMImplementation        = class ;
  TDOMDocumentFragment      = class ;
  TDOMDocument              = class ;
  TDOMNode                  = class ;
  TDOMNodeList              = class ;
  TDOMNamedNodeMap          = class ;
  TDOMCharacterData         = class ;
  TDOMAttr                  = class ;
  TDOMElement               = class ;
  TDOMText                  = class ;
  TDOMComment               = class ;
  TDOMCDATASection          = class ;
  TDOMDocumentType          = class ;
  TDOMNotation              = class ;
  TDOMEntity                = class ;
  TDOMEntityReference       = class ;
  TDOMProcessingInstruction = class ;

  TRefClass = class (TObject)
  protected
    RefCounter: LongInt;
  public
    constructor Create;
    function AddRef: LongInt; Virtual;
    function Release: LongInt; Virtual;
  end;

  TDOMNode = class (TObject)
  protected
    FNextSibling:     TDOMNode;
    FNodeName:        DOMString;
    FNodeType:        Integer;
    FNodeValue:       DOMString;
    FOwnerDocument:   TDOMDocument;
    FParentNode:      TDOMNode;
    FPreviousSibling: TDOMNode;
    function GetAttributes: TDOMNamedNodeMap; Virtual;
    function GetFirstChild: TDOMNode; Virtual;
    function GetLastChild: TDOMNode; Virtual;
    function GetNodeValue: DOMString; Virtual;
    procedure SetNodeValue(const AValue: DOMString); Virtual;
  public
    constructor Create(AOwner: TDOMDocument);
    function AppendChild(NewChild: TDOMNode): TDOMNode; Virtual;
    function CloneNode(deep: Boolean): TDOMNode; Overload;
    function CloneNode(deep: Boolean; ACloneOwner: TDOMDocument): TDOMNode;
      Overload; Virtual;
    function FindNode(const ANodeName: DOMString): TDOMNode; Virtual;
    function GetChildNodes: TDOMNodeList; Virtual;
    function HasChildNodes: Boolean; Virtual;
    function InsertBefore(NewChild, RefChild: TDOMNode): TDOMNode; Virtual;
    function RemoveChild(OldChild: TDOMNode): TDOMNode; Virtual;
    function ReplaceChild(NewChild, OldChild: TDOMNode): TDOMNode; Virtual;
    property Attributes: TDOMNamedNodeMap read GetAttributes;
    property ChildNodes: TDOMNodeList read GetChildNodes;
    property FirstChild: TDOMNode read GetFirstChild;
    property LastChild: TDOMNode read GetLastChild;
    property NextSibling: TDOMNode read FNextSibling;
    property NodeName: DOMString read FNodeName;
    property NodeType: Integer read FNodeType;
    property NodeValue: DOMString read GetNodeValue write SetNodeValue;
    property OwnerDocument: TDOMDocument read FOwnerDocument;
    property ParentNode: TDOMNode read FParentNode;
    property PreviousSibling: TDOMNode read FPreviousSibling;
  end;

  TDOMNode_WithChildren = class (TDOMNode)
  protected
    FChildNodeTree: TAVLTree;
    FFirstChild:    TDOMNode;
    FLastChild:     TDOMNode;
    procedure AddToChildNodeTree(NewNode: TDOMNode);
    procedure CloneChildren(ACopy: TDOMNode; ACloneOwner: TDOMDocument);
    function GetFirstChild: TDOMNode; Override;
    function GetLastChild: TDOMNode; Override;
    procedure RemoveFromChildNodeTree(OldNode: TDOMNode);
  public
    destructor Destroy; Override;
    function AppendChild(NewChild: TDOMNode): TDOMNode; Override;
    function FindNode(const ANodeName: DOMString): TDOMNode; Override;
    function HasChildNodes: Boolean; Override;
    function InsertBefore(NewChild, RefChild: TDOMNode): TDOMNode; Override;
    function RemoveChild(OldChild: TDOMNode): TDOMNode; Override;
    function ReplaceChild(NewChild, OldChild: TDOMNode): TDOMNode; Override;
  end;

  TDOMNodeList = class (TRefClass)
  protected
    filter:    DOMString;
    node:      TDOMNode;
    UseFilter: Boolean;
    function GetCount: LongInt;
    function GetItem(index: LongWord): TDOMNode;
  public
    constructor Create(ANode: TDOMNode; const AFilter: DOMString);
    property Count: LongInt read GetCount;
    property Item[index: LongWord]: TDOMNode read GetItem;
  end;

  TDOMNamedNodeMap = class (TFastList)
  protected
    OwnerDocument: TDOMDocument;
    function GetItem(index: LongWord): TDOMNode;
    function GetLength: LongInt;
    procedure SetItem(index: LongWord; AItem: TDOMNode);
  public
    constructor Create(AOwner: TDOMDocument);
    function GetNamedItem(const name: DOMString): TDOMNode;
    function RemoveNamedItem(const name: DOMString): TDOMNode;
    function SetNamedItem(arg: TDOMNode): TDOMNode;
    property Item[index: LongWord]: TDOMNode read GetItem write SetItem; Default;
    property Length: LongInt read GetLength;
  end;

  TDOMCharacterData = class (TDOMNode)
  protected
    function GetLength: LongInt;
  public
    procedure AppendData(const arg: DOMString);
    procedure DeleteData(offset, count: LongWord);
    procedure InsertData(offset: LongWord; const arg: DOMString);
    procedure ReplaceData(offset, count: LongWord; const arg: DOMString);
    function SubstringData(offset, count: LongWord): DOMString;
    property Data: DOMString read FNodeValue;
    property Length: LongInt read GetLength;
  end;

  TDOMImplementation = class (TObject)
  public
    function CreateDocument(const NamespaceURI, QualifiedName: DOMString; doctype: TDOMDocumentType): TDOMDocument;
    function CreateDocumentType(const QualifiedName, PublicID, SystemID: DOMString): TDOMDocumentType;
    function HasFeature(const feature, version: DOMString): Boolean;
  end;

  TDOMDocumentFragment = class (TDOMNode_WithChildren)
  public
    constructor Create(AOwner: TDOMDocument);
  end;

  TDOMDocument = class (TDOMNode_WithChildren)
  protected
    FDocType:        TDOMDocumentType;
    FImplementation: TDOMImplementation;
    function GetDocumentElement: TDOMElement;
  public
    constructor Create;
    function CreateAttribute(const name: DOMString): TDOMAttr; Virtual;
    function CreateCDATASection(const data: DOMString): TDOMCDATASection;
      Virtual;
    function CreateComment(const data: DOMString): TDOMComment;
    function CreateDocumentFragment: TDOMDocumentFragment;
    function CreateElement(const tagName: DOMString): TDOMElement; Virtual;
    function CreateEntity(const data: DOMString): TDOMEntity;
    function CreateEntityReference(const name: DOMString): TDOMEntityReference;
      Virtual;
    function CreateProcessingInstruction(const target, data: DOMString): TDOMProcessingInstruction; Virtual;
    function CreateTextNode(const data: DOMString): TDOMText;
    function GetElementsByTagName(const tagname: DOMString): TDOMNodeList;
    property DocType: TDOMDocumentType read FDocType;
    property DocumentElement: TDOMElement read GetDocumentElement;
    property Impl: TDOMImplementation read FImplementation;
  end;

  TXMLDocument = class (TDOMDocument)
  public
    Encoding:       DOMString;
    StylesheetHRef: DOMString;
    StylesheetType: DOMString;
    XMLVersion:     DOMString;
    function CreateCDATASection(const data: DOMString): TDOMCDATASection;
      Override;
    function CreateEntityReference(const name: DOMString): TDOMEntityReference;
      Override;
    function CreateProcessingInstruction(const target, data: DOMString): TDOMProcessingInstruction; Override;
  end;

  TDOMAttr = class (TDOMNode_WithChildren)
  protected
    AttrOwner:  TDOMNamedNodeMap;
    FSpecified: Boolean;
    function GetNodeValue: DOMString; Override;
    procedure SetNodeValue(const AValue: DOMString); Override;
  public
    constructor Create(AOwner: TDOMDocument);
    function CloneNode(deep: Boolean; ACloneOwner: TDOMDocument): TDOMNode;
      Overload; Override;
    property Name: DOMString read FNodeName;
    property Specified: Boolean read FSpecified;
    property Value: DOMString read GetNodeValue write SetNodeValue;
  end;

  TDOMElement = class (TDOMNode_WithChildren)
  private
    FAttributes: TDOMNamedNodeMap;
  protected
    function GetAttributes: TDOMNamedNodeMap; Override;
  public
    constructor Create(AOwner: TDOMDocument);
    destructor Destroy; Override;
    function CloneNode(deep: Boolean; ACloneOwner: TDOMDocument): TDOMNode;
      Overload; Override;
    function GetAttribute(const Name: DOMString): DOMString;
    function GetAttributeNode(const name: DOMString): TDOMAttr;
    function GetElementsByTagName(const name: DOMString): TDOMNodeList;
    procedure Normalize;
    procedure RemoveAttribute(const name: DOMString);
    function RemoveAttributeNode(OldAttr: TDOMAttr): TDOMAttr;
    procedure SetAttribute(const Name: DOMString; const Value: DOMString);
    procedure SetAttributeNode(NewAttr: TDOMAttr);
    property AttribStrings[const Name: DOMString]: DOMString read GetAttribute write SetAttribute; Default;
    property TagName: DOMString read FNodeName;
  end;

  TDOMText = class (TDOMCharacterData)
  public
    constructor Create(AOwner: TDOMDocument);
    function CloneNode(deep: Boolean; ACloneOwner: TDOMDocument): TDOMNode;
      Overload; Override;
    function SplitText(offset: LongWord): TDOMText;
  end;

  TDOMComment = class (TDOMCharacterData)
  public
    constructor Create(AOwner: TDOMDocument);
    function CloneNode(deep: Boolean; ACloneOwner: TDOMDocument): TDOMNode;
      Overload; Override;
  end;

  TDOMCDATASection = class (TDOMText)
  public
    constructor Create(AOwner: TDOMDocument);
    function CloneNode(deep: Boolean; ACloneOwner: TDOMDocument): TDOMNode;
      Overload; Override;
  end;

  TDOMDocumentType = class (TDOMNode)
  protected
    FEntities:  TDOMNamedNodeMap;
    FNotations: TDOMNamedNodeMap;
  public
    constructor Create(AOwner: TDOMDocument);
    function CloneNode(deep: Boolean; ACloneOwner: TDOMDocument): TDOMNode;
      Overload; Override;
    property Entities: TDOMNamedNodeMap read FEntities;
    property Name: DOMString read FNodeName;
    property Notations: TDOMNamedNodeMap read FEntities;
  end;

  TDOMNotation = class (TDOMNode)
  protected
    FPublicID: DOMString;
    FSystemID: DOMString;
  public
    constructor Create(AOwner: TDOMDocument);
    function CloneNode(deep: Boolean; ACloneOwner: TDOMDocument): TDOMNode;
      Overload; Override;
    property PublicID: DOMString read FPublicID;
    property SystemID: DOMString read FSystemID;
  end;

  TDOMEntity = class (TDOMNode_WithChildren)
  protected
    FNotationName: DOMString;
    FPublicID:     DOMString;
    FSystemID:     DOMString;
  public
    constructor Create(AOwner: TDOMDocument);
    property NotationName: DOMString read FNotationName;
    property PublicID: DOMString read FPublicID;
    property SystemID: DOMString read FSystemID;
  end;

  TDOMEntityReference = class (TDOMNode_WithChildren)
  public
    constructor Create(AOwner: TDOMDocument);
  end;

  TDOMProcessingInstruction = class (TDOMNode)
  public
    constructor Create(AOwner: TDOMDocument);
    property Data: DOMString read FNodeValue;
    property Target: DOMString read FNodeName;
  end;


type
  EXMLReadError = class (Exception)
  end;


procedure ReadXMLFile(var ADoc: TXMLDocument; const AFilename: AnsiString); Overload;
procedure ReadXMLFile(var ADoc: TXMLDocument; var f: file); Overload;
procedure ReadXMLFile(var ADoc: TXMLDocument; var f: TStream); Overload;
procedure ReadXMLFile(var ADoc: TXMLDocument; var f: TStream; const AFilename: AnsiString); Overload;

procedure ReadXMLFragment(AParentNode: TDOMNode; const AFilename: AnsiString); Overload;
procedure ReadXMLFragment(AParentNode: TDOMNode; var f: file); Overload;
procedure ReadXMLFragment(AParentNode: TDOMNode; var f: TStream); Overload;
procedure ReadXMLFragment(AParentNode: TDOMNode; var f: TStream; const AFilename: AnsiString); Overload;

procedure ReadDTDFile(var ADoc: TXMLDocument; const AFilename: AnsiString); Overload;
procedure ReadDTDFile(var ADoc: TXMLDocument; var f: file); Overload;
procedure ReadDTDFile(var ADoc: TXMLDocument; var f: TStream); Overload;
procedure ReadDTDFile(var ADoc: TXMLDocument; var f: TStream; const AFilename: AnsiString); Overload;

procedure WriteXMLFile(doc: TXMLDocument; const AFileName: AnsiString); Overload;
procedure WriteXMLFile(doc: TXMLDocument; var AFile: Text); Overload;
procedure WriteXMLFile(doc: TXMLDocument; AStream: TStream); Overload;

procedure WriteXML(Element: TDOMNode; const AFileName: AnsiString); Overload;
procedure WriteXML(Element: TDOMNode; var AFile: Text); Overload;
procedure WriteXML(Element: TDOMNode; AStream: TStream); Overload;


type
  {"APath" is the path and name of a value: A XML configuration file is
   hierachical. "/" is the path delimiter, the part after the last "/"
   is the name of the value. The path components will be mapped to XML
   elements, the name will be an element attribute.}
  TXMLConfig = class (TObject)
  private
    FFilename: AnsiString;
    procedure SetFilename(const AFilename: AnsiString);
  protected
    doc:        TXMLDocument;
    fDoNotLoad: Boolean;
    FModified:  Boolean;
    function ExtendedToStr(const e: Extended): AnsiString;
    function FindNode(const APath: AnsiString; PathHasValue: Boolean): TDomNode;
    function StrToExtended(const s: AnsiString; const ADefault: Extended): Extended;
  public
    constructor Create(const AFilename: AnsiString); Overload;
    constructor CreateClean(const AFilename: AnsiString);
    destructor Destroy; Override;
    procedure Clear;
    procedure DeletePath(const APath: AnsiString);
    procedure DeleteValue(const APath: AnsiString);
    procedure Flush;
    function GetExtendedValue(const APath: AnsiString; const ADefault: Extended): Extended;
    function GetValue(const APath: AnsiString; ADefault: Boolean): Boolean;
      Overload;
    function GetValue(const APath: AnsiString; ADefault: Integer): Integer;
      Overload;
    function GetValue(const APath, ADefault: AnsiString): AnsiString; Overload;
    procedure SetDeleteExtendedValue(const APath: AnsiString; const AValue, DefValue: Extended);
    procedure SetDeleteValue(const APath: AnsiString; AValue, DefValue: Boolean);
      Overload;
    procedure SetDeleteValue(const APath: AnsiString; AValue, DefValue: Integer);
      Overload;
    procedure SetDeleteValue(const APath, AValue, DefValue: AnsiString); Overload;
    procedure SetExtendedValue(const APath: AnsiString; const AValue: Extended);
    procedure SetValue(const APath: AnsiString; AValue: Boolean); Overload;
    procedure SetValue(const APath: AnsiString; AValue: Integer); Overload;
    procedure SetValue(const APath, AValue: AnsiString); Overload;
    property Modified: Boolean read FModified;
  published
    property Filename: AnsiString read FFilename write SetFilename;
  end;

procedure LoadStringList(XMLConfig: TXMLConfig; List: TStrings; const Path: AnsiString);
procedure SaveStringList(XMLConfig: TXMLConfig; List: TStrings; const Path: AnsiString);

implementation

{
********************************** TRefClass ***********************************
}
constructor TRefClass.Create;
begin
  inherited Create;
  RefCounter := 1;
end;

function TRefClass.AddRef: LongInt;
begin
  Inc(RefCounter);
  Result := RefCounter;
end;

function TRefClass.Release: LongInt;
begin
  Dec(RefCounter);
  Result := RefCounter;
  if RefCounter <= 0 then
    Free;
end;

{
********************************** EDOMError ***********************************
}
constructor EDOMError.Create(ACode: Integer; const ASituation: AnsiString);
begin
  Code := ACode;
  inherited Create(Self.ClassName + ' in ' + ASituation);
end;

{
******************************** EDOMIndexSize *********************************
}
constructor EDOMIndexSize.Create(const ASituation: AnsiString);
begin
  inherited Create(INDEX_SIZE_ERR, ASituation);
end;

{
***************************** EDOMHierarchyRequest *****************************
}
constructor EDOMHierarchyRequest.Create(const ASituation: AnsiString);
begin
  inherited Create(HIERARCHY_REQUEST_ERR, ASituation);
end;

{
****************************** EDOMWrongDocument *******************************
}
constructor EDOMWrongDocument.Create(const ASituation: AnsiString);
begin
  inherited Create(WRONG_DOCUMENT_ERR, ASituation);
end;

{
********************************* EDOMNotFound *********************************
}
constructor EDOMNotFound.Create(const ASituation: AnsiString);
begin
  inherited Create(NOT_FOUND_ERR, ASituation);
end;

{
******************************* EDOMNotSupported *******************************
}
constructor EDOMNotSupported.Create(const ASituation: AnsiString);
begin
  inherited Create(NOT_SUPPORTED_ERR, ASituation);
end;

{
****************************** EDOMInUseAttribute ******************************
}
constructor EDOMInUseAttribute.Create(const ASituation: AnsiString);
begin
  inherited Create(INUSE_ATTRIBUTE_ERR, ASituation);
end;

{
******************************* EDOMInvalidState *******************************
}
constructor EDOMInvalidState.Create(const ASituation: AnsiString);

  // 11

begin
  inherited Create(INVALID_STATE_ERR, ASituation);
end;

{
********************************** EDOMSyntax **********************************
}
constructor EDOMSyntax.Create(const ASituation: AnsiString);
begin
  inherited Create(SYNTAX_ERR, ASituation);
end;

{
*************************** EDOMInvalidModification ****************************
}
constructor EDOMInvalidModification.Create(const ASituation: AnsiString);
begin
  inherited Create(INVALID_MODIFICATION_ERR, ASituation);
end;

{
******************************** EDOMNamespace *********************************
}
constructor EDOMNamespace.Create(const ASituation: AnsiString);
begin
  inherited Create(NAMESPACE_ERR, ASituation);
end;

{
****************************** EDOMInvalidAccess *******************************
}
constructor EDOMInvalidAccess.Create(const ASituation: AnsiString);
begin
  inherited Create(INVALID_ACCESS_ERR, ASituation);
end;


{
*********************************** TDOMNode ***********************************
}
constructor TDOMNode.Create(AOwner: TDOMDocument);
begin
  FOwnerDocument := AOwner;
  inherited Create;
end;

function TDOMNode.AppendChild(NewChild: TDOMNode): TDOMNode;
begin
  raise EDOMHierarchyRequest.Create('Node.AppendChild');
  if (NewChild = Nil) then
  ;
  Result := Nil;
end;

function TDOMNode.CloneNode(deep: Boolean): TDOMNode;
begin
  if deep then
  ;
  Result := CloneNode(deep, FOwnerDocument);
end;

function TDOMNode.CloneNode(deep: Boolean; ACloneOwner: TDOMDocument): TDOMNode;
begin
  raise EDOMNotSupported.Create('CloneNode not implemented for ' + ClassName);
  if (deep) And (ACloneOwner = Nil) then
  ;
  Result := Nil;
end;

function TDOMNode.FindNode(const ANodeName: DOMString): TDOMNode;
var
  child: TDOMNode;
begin
  child := FirstChild;
  while Assigned(child) do
  begin
    if child.NodeName = ANodeName then
    begin
      Result := child;
      exit;
    end;
    child := child.NextSibling;
  end;
  Result := Nil;
end;

function TDOMNode.GetAttributes: TDOMNamedNodeMap;
begin
  Result := Nil;
end;

function TDOMNode.GetChildNodes: TDOMNodeList;
begin
  Result := TDOMNodeList.Create(Self, '*');
end;

function TDOMNode.GetFirstChild: TDOMNode;
begin
  Result := Nil;
end;

function TDOMNode.GetLastChild: TDOMNode;
begin
  Result := Nil;
end;

function TDOMNode.GetNodeValue: DOMString;
begin
  Result := FNodeValue;
end;

function TDOMNode.HasChildNodes: Boolean;
begin
  Result := False;
end;

function TDOMNode.InsertBefore(NewChild, RefChild: TDOMNode): TDOMNode;
begin
  raise EDOMHierarchyRequest.Create('Node.InsertBefore');
  if (NewChild = Nil) And (RefChild = Nil) then
  ;
  Result := Nil;
end;

function TDOMNode.RemoveChild(OldChild: TDOMNode): TDOMNode;
begin
  raise EDOMHierarchyRequest.Create('Node.RemoveChild');
  if (OldChild = Nil) then
  ;
  Result := Nil;
end;

function TDOMNode.ReplaceChild(NewChild, OldChild: TDOMNode): TDOMNode;
begin
  raise EDOMHierarchyRequest.Create('Node.ReplaceChild');
  if (NewChild = Nil) And (OldChild = Nil) then
  ;
  Result := Nil;
end;

procedure TDOMNode.SetNodeValue(const AValue: DOMString);
begin
  FNodeValue := AValue;
end;


function CompareDOMStrings(const s1, s2: DOMPChar; l1, l2: Integer): Integer;
var
  i: Integer;
begin
  Result := l1 - l2;
  i      := 1;
  while (i <= l1) And (Result = 0) do
  begin
    Result := ord(s1[i]) - ord(s2[i]);
    inc(i);
  end;
end;

function CompareDOMNodeWithDOMNode(Node1, Node2: Pointer): Integer;
begin
  Result := CompareDOMStrings(DOMPChar(TDOMNode(Node1).NodeName),
    DOMPChar(TDOMNode(Node2).NodeName),
    length(TDOMNode(Node1).NodeName),
    length(TDOMNode(Node2).NodeName)
    );
end;

function CompareDOMStringWithDOMNode(AKey, ANode: Pointer): Integer;
begin
  Result := CompareDOMStrings(DOMPChar(AKey),
    DOMPChar(TDOMNode(ANode).NodeName),
    length(DOMString(AKey)),
    length(TDOMNode(ANode).NodeName)
    );
end;


{
**************************** TDOMNode_WithChildren *****************************
}
destructor TDOMNode_WithChildren.Destroy;
var
  child, next: TDOMNode;
begin
  if FChildNodeTree <> Nil then
  begin
    FChildNodeTree.Free;
    FChildNodeTree := Nil;
  end;
  child := FirstChild;
  while Assigned(child) do
  begin
    next := child.NextSibling;
    child.Free;
    child := next;
  end;
  inherited Destroy;
end;

procedure TDOMNode_WithChildren.AddToChildNodeTree(NewNode: TDOMNode);
var
  ChildCount: Integer;
  ANode:      TDOMNode;
begin
  if (FChildNodeTree = Nil) then
  begin
    // there is no childnodetree yet
    // Most xml trees contains nodes with only a few child nodes. It would be
    // overhead to create a tree for only a few childs.
    ChildCount := 0;
    ANode      := FirstChild;
    while Assigned(ANode) do
    begin
      inc(ChildCount);
      ANode := ANode.NextSibling;
    end;
    if ChildCount > 5 then
    begin
      FChildNodeTree := TAVLTree.Create( @CompareDOMNodeWithDOMNode);
      // add all existing childs
      ANode          := FirstChild;
      while Assigned(ANode) do
      begin
        if (FChildNodeTree.Find(ANode) = Nil) then
          FChildNodeTree.Add(ANode);
        ANode := ANode.NextSibling;
      end;
    end;
  end;
  if Assigned(FChildNodeTree) And (FChildNodeTree.Find(NewNode) = Nil) then
    FChildNodeTree.Add(NewNode);
  //if FChildNodeTree.ConsistencyCheck<>0 then
  //  raise exception.Create('TDOMNode_WithChildren.FindNode');
end;

function TDOMNode_WithChildren.AppendChild(NewChild: TDOMNode): TDOMNode;
var
  Parent: TDOMNode;
begin
  if NewChild.FOwnerDocument <> FOwnerDocument then
    raise EDOMWrongDocument.Create('NodeWC.AppendChild');

  Parent := Self;
  while Assigned(Parent) do
  begin
    if Parent = NewChild then
      raise EDOMHierarchyRequest.Create('NodeWC.AppendChild (cycle in tree)');
    Parent := Parent.ParentNode;
  end;

  if NewChild.FParentNode = Self then
    RemoveChild(NewChild);

  if NewChild.NodeType = DOCUMENT_FRAGMENT_NODE then
    raise EDOMNotSupported.Create('NodeWC.AppendChild for DocumentFragments')
  else
  begin
    if Assigned(FFirstChild) then
    begin
      FLastChild.FNextSibling   := NewChild;
      NewChild.FPreviousSibling := FLastChild;
    end
    else
      FFirstChild := NewChild;
    FLastChild := NewChild;
    NewChild.FParentNode := Self;
  end;
  AddToChildNodeTree(NewChild);
  Result := NewChild;
end;

procedure TDOMNode_WithChildren.CloneChildren(ACopy: TDOMNode; ACloneOwner: TDOMDocument);
var
  node: TDOMNode;
begin
  node := FirstChild;
  while Assigned(node) do
  begin
    ACopy.AppendChild(node.CloneNode(True, ACloneOwner));
    node := node.NextSibling;
  end;
end;

function TDOMNode_WithChildren.FindNode(const ANodeName: DOMString): TDOMNode;
var
  AVLNode: TAVLTreeNode;
begin
  Result := Nil;
  if FChildNodeTree <> Nil then
  begin
    // use tree for fast search
    //if FChildNodeTree.ConsistencyCheck<>0 then
    //  raise exception.Create('TDOMNode_WithChildren.FindNode');
    AVLNode := FChildNodeTree.FindKey(DOMPChar(ANodeName), @CompareDOMStringWithDOMNode);
    if AVLNode <> Nil then
      Result := TDOMNode(AVLNode.Data);
  end
  else
  begin
    // search in list
    Result := FirstChild;
    while Assigned(Result) do
    begin
      if CompareDOMStringWithDOMNode(DOMPChar(ANodeName), Result) = 0 then
        exit;
      Result := Result.NextSibling;
    end;
  end;
end;

function TDOMNode_WithChildren.GetFirstChild: TDOMNode;
begin
  Result := FFirstChild;
end;

function TDOMNode_WithChildren.GetLastChild: TDOMNode;
begin
  Result := FLastChild;
end;

function TDOMNode_WithChildren.HasChildNodes: Boolean;
begin
  Result := Assigned(FFirstChild);
end;

function TDOMNode_WithChildren.InsertBefore(NewChild, RefChild: TDOMNode): TDOMNode;
begin
  Result := NewChild;

  if Not Assigned(RefChild) then
  begin
    AppendChild(NewChild);
    exit;
  end;

  if NewChild.FOwnerDocument <> FOwnerDocument then
    raise EDOMWrongDocument.Create('NodeWC.InsertBefore');

  if RefChild.ParentNode <> Self then
    raise EDOMHierarchyRequest.Create('NodeWC.InsertBefore');

  if NewChild.NodeType = DOCUMENT_FRAGMENT_NODE then
    raise EDOMNotSupported.Create('NodeWC.InsertBefore for DocumentFragment');

  NewChild.FNextSibling := RefChild;
  if RefChild = FFirstChild then
    FFirstChild := NewChild
  else
  begin
    RefChild.FPreviousSibling.FNextSibling := NewChild;
    NewChild.FPreviousSibling              := RefChild.FPreviousSibling;
  end;

  RefChild.FPreviousSibling := NewChild;
  NewChild.FParentNode      := Self;
  AddToChildNodeTree(NewChild);
end;

function TDOMNode_WithChildren.RemoveChild(OldChild: TDOMNode): TDOMNode;
begin
  if OldChild.ParentNode <> Self then
    raise EDOMHierarchyRequest.Create('NodeWC.RemoveChild');

  if OldChild = FFirstChild then
    FFirstChild := FFirstChild.NextSibling
  else
    OldChild.FPreviousSibling.FNextSibling := OldChild.FNextSibling;

  if OldChild = FLastChild then
    FLastChild := FLastChild.FPreviousSibling
  else
    OldChild.FNextSibling.FPreviousSibling := OldChild.FPreviousSibling;

  RemoveFromChildNodeTree(OldChild);
  OldChild.Free;
  Result := Nil;
end;

procedure TDOMNode_WithChildren.RemoveFromChildNodeTree(OldNode: TDOMNode);
begin
  if FChildNodeTree <> Nil then
    FChildNodeTree.Remove(OldNode);
  //if (FChildNodeTree<>nil) and (FChildNodeTree.ConsistencyCheck<>0) then
  //  raise exception.Create('TDOMNode_WithChildren.FindNode');
end;

function TDOMNode_WithChildren.ReplaceChild(NewChild, OldChild: TDOMNode): TDOMNode;
begin
  RemoveFromChildNodeTree(OldChild);
  InsertBefore(NewChild, OldChild);
  if Assigned(OldChild) then
    RemoveChild(OldChild);
  Result := NewChild;
end;


{
********************************* TDOMNodeList *********************************
}
constructor TDOMNodeList.Create(ANode: TDOMNode; const AFilter: DOMString);
begin
  inherited Create;
  node      := ANode;
  filter    := AFilter;
  UseFilter := filter <> '*';
end;

function TDOMNodeList.GetCount: LongInt;
var
  child: TDOMNode;
begin
  Result := 0;
  child  := node.FirstChild;
  while Assigned(child) do
  begin
    if ( Not UseFilter) Or (child.NodeName = filter) then
      Inc(Result);
    child := child.NextSibling;
  end;
end;

function TDOMNodeList.GetItem(index: LongWord): TDOMNode;
var
  child: TDOMNode;
begin
  Result := Nil;
  if index < 0 then
    exit;
  child := node.FirstChild;
  while Assigned(child) do
  begin
    if index = 0 then
    begin
      Result := child;
      break;
    end;
    if ( Not UseFilter) Or (child.NodeName = filter) then
      Dec(index);
    child := child.NextSibling;
  end;
end;


{
******************************* TDOMNamedNodeMap *******************************
}
constructor TDOMNamedNodeMap.Create(AOwner: TDOMDocument);
begin
  inherited Create;
  OwnerDocument := AOwner;
end;

function TDOMNamedNodeMap.GetItem(index: LongWord): TDOMNode;
begin
  Result := TDOMNode(Items[index]);
end;

function TDOMNamedNodeMap.GetLength: LongInt;
begin
  Result := Count;
end;

function TDOMNamedNodeMap.GetNamedItem(const name: DOMString): TDOMNode;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
  begin
    Result := Item[i];
    if Result.NodeName = name then
      exit;
  end;
  Result := Nil;
end;

function TDOMNamedNodeMap.RemoveNamedItem(const name: DOMString): TDOMNode;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    if Item[i].NodeName = name then
    begin
      Result             := Item[i];
      Result.FParentNode := Nil;
      exit;
    end;
  raise EDOMNotFound.Create('NamedNodeMap.RemoveNamedItem');
end;

procedure TDOMNamedNodeMap.SetItem(index: LongWord; AItem: TDOMNode);
begin
  Items[index] := AItem;
end;

function TDOMNamedNodeMap.SetNamedItem(arg: TDOMNode): TDOMNode;
var
  i: Integer;
begin
  if arg.FOwnerDocument <> OwnerDocument then
    raise EDOMWrongDocument.Create('NamedNodeMap.SetNamedItem');

  if arg.NodeType = ATTRIBUTE_NODE then
  begin
    if Assigned(TDOMAttr(arg).AttrOwner) then
      raise EDOMInUseAttribute.Create('NamedNodeMap.SetNamedItem');
    TDOMAttr(arg).AttrOwner := Self;
  end;

  for i := 0 to Count - 1 do
    if Item[i].NodeName = arg.NodeName then
    begin
      Result  := Item[i];
      Item[i] := arg;
      exit;
    end;
  Add(arg);
  Result := Nil;
end;


{
****************************** TDOMCharacterData *******************************
}
procedure TDOMCharacterData.AppendData(const arg: DOMString);
begin
  FNodeValue := FNodeValue + arg;
end;

procedure TDOMCharacterData.DeleteData(offset, count: LongWord);
begin
  if (offset < 0) Or (Longint(offset) > Length) Or (count < 0) then
    raise EDOMIndexSize.Create('CharacterData.DeleteData');

  FNodeValue := Copy(FNodeValue, 1, offset) +
    Copy(FNodeValue, offset + count + 1, Length);
end;

function TDOMCharacterData.GetLength: LongInt;
begin
  Result := system.Length(FNodeValue);
end;

procedure TDOMCharacterData.InsertData(offset: LongWord; const arg: DOMString);
begin
  if (offset < 0) Or (Longint(offset) > Length) then
    raise EDOMIndexSize.Create('CharacterData.InsertData');

  FNodeValue := Copy(FNodeValue, 1, offset) + arg +
    Copy(FNodeValue, offset + 1, Length);
end;

procedure TDOMCharacterData.ReplaceData(offset, count: LongWord; const arg: DOMString);
begin
  DeleteData(offset, count);
  InsertData(offset, arg);
end;

function TDOMCharacterData.SubstringData(offset, count: LongWord): DOMString;
begin
  if (offset < 0) Or (Longint(offset) > Length) Or (count < 0) then
    raise EDOMIndexSize.Create('CharacterData.SubstringData');
  Result := Copy(FNodeValue, offset + 1, count);
end;


{
***************************** TDOMDocumentFragment *****************************
}
constructor TDOMDocumentFragment.Create(AOwner: TDOMDocument);
begin
  FNodeType := DOCUMENT_FRAGMENT_NODE;
  FNodeName := '#document-fragment';
  inherited Create(AOwner);
end;


{
****************************** TDOMImplementation ******************************
}
function TDOMImplementation.CreateDocument(const NamespaceURI, QualifiedName: DOMString; doctype: TDOMDocumentType): TDOMDocument;
begin
  // !!!: Implement this method (easy to do)
  raise EDOMNotSupported.Create('DOMImplementation.CreateDocument');
  if (NamespaceURI = '') And (QualifiedName = '') And (doctype = Nil) then
  ;
  Result := Nil;
end;

function TDOMImplementation.CreateDocumentType(const QualifiedName, PublicID, SystemID: DOMString): TDOMDocumentType;
begin
  // !!!: Implement this method (easy to do)
  raise EDOMNotSupported.Create('DOMImplementation.CreateDocumentType');
  if (QualifiedName = '') And (PublicID = '') And (SystemID = '') then
  ;
  Result := Nil;
end;

function TDOMImplementation.HasFeature(const feature, version: DOMString): Boolean;
begin
  Result := False;
  if (feature = '') And (version = '') then
  ;
end;


{
********************************* TDOMDocument *********************************
}
constructor TDOMDocument.Create;
begin
  FNodeType := DOCUMENT_NODE;
  FNodeName := '#document';
  inherited Create(Nil);
  FOwnerDocument := Self;
end;

function TDOMDocument.CreateAttribute(const name: DOMString): TDOMAttr;
begin
  Result           := TDOMAttr.Create(Self);
  Result.FNodeName := name;
end;

function TDOMDocument.CreateCDATASection(const data: DOMString): TDOMCDATASection;
begin
  raise EDOMNotSupported.Create('DOMDocument.CreateCDATASection');
  if data = '' then
  ;
  Result := Nil;
end;

function TDOMDocument.CreateComment(const data: DOMString): TDOMComment;
begin
  Result            := TDOMComment.Create(Self);
  Result.FNodeValue := data;
end;

function TDOMDocument.CreateDocumentFragment: TDOMDocumentFragment;
begin
  Result := TDOMDocumentFragment.Create(Self);
end;

function TDOMDocument.CreateElement(const tagName: DOMString): TDOMElement;
begin
  Result           := TDOMElement.Create(Self);
  Result.FNodeName := tagName;
end;

function TDOMDocument.CreateEntity(const data: DOMString): TDOMEntity;
begin
  Result           := TDOMEntity.Create(Self);
  Result.FNodeName := data;
end;

function TDOMDocument.CreateEntityReference(const name: DOMString): TDOMEntityReference;
begin
  raise EDOMNotSupported.Create('DOMDocument.CreateEntityReference');
  if name = '' then
  ;
  Result := Nil;
end;

function TDOMDocument.CreateProcessingInstruction(const target, data: DOMString): TDOMProcessingInstruction;
begin
  raise EDOMNotSupported.Create('DOMDocument.CreateProcessingInstruction');
  if (target = '') And (data = '') then
  ;
  Result := Nil;
end;

function TDOMDocument.CreateTextNode(const data: DOMString): TDOMText;
begin
  Result            := TDOMText.Create(Self);
  Result.FNodeValue := data;
end;

function TDOMDocument.GetDocumentElement: TDOMElement;
var
  node: TDOMNode;
begin
  node := FFirstChild;
  while Assigned(node) do
  begin
    if node.FNodeType = ELEMENT_NODE then
    begin
      Result := TDOMElement(node);
      exit;
    end;
    node := node.NextSibling;
  end;
  Result := Nil;
end;

function TDOMDocument.GetElementsByTagName(const tagname: DOMString): TDOMNodeList;
begin
  Result := TDOMNodeList.Create(Self, tagname);
end;


{
********************************* TXMLDocument *********************************
}
function TXMLDocument.CreateCDATASection(const data: DOMString): TDOMCDATASection;
begin
  Result            := TDOMCDATASection.Create(Self);
  Result.FNodeValue := data;
end;

function TXMLDocument.CreateEntityReference(const name: DOMString): TDOMEntityReference;
begin
  Result           := TDOMEntityReference.Create(Self);
  Result.FNodeName := name;
end;

function TXMLDocument.CreateProcessingInstruction(const target, data: DOMString): TDOMProcessingInstruction;
begin
  Result            := TDOMProcessingInstruction.Create(Self);
  Result.FNodeName  := target;
  Result.FNodeValue := data;
end;


{
*********************************** TDOMAttr ***********************************
}
constructor TDOMAttr.Create(AOwner: TDOMDocument);
begin
  FNodeType := ATTRIBUTE_NODE;
  inherited Create(AOwner);
end;

function TDOMAttr.CloneNode(deep: Boolean; ACloneOwner: TDOMDocument): TDOMNode;
begin
  Result           := TDOMAttr.Create(ACloneOwner);
  Result.FNodeName := FNodeName;
  TDOMAttr(Result).FSpecified := FSpecified;
  if deep then
    CloneChildren(Result, ACloneOwner);
end;

function TDOMAttr.GetNodeValue: DOMString;
var
  child: TDOMNode;
begin
  SetLength(Result, 0);
  if Assigned(FFirstChild) then
  begin
    child := FFirstChild;
    while Assigned(child) do
    begin
      if child.NodeType = ENTITY_REFERENCE_NODE then
        Result := Result + '&' + child.NodeName + ';'
      else
        Result := Result + child.NodeValue;
      child := child.NextSibling;
    end;
  end;
end;

procedure TDOMAttr.SetNodeValue(const AValue: DOMString);
var
  tn: TDOMText;
begin
  FSpecified    := True;
  tn            := TDOMText.Create(FOwnerDocument);
  tn.FNodeValue := AValue;
  if Assigned(FFirstChild) then
    ReplaceChild(tn, FFirstChild)
  else
    AppendChild(tn);
end;


{
********************************* TDOMElement **********************************
}
constructor TDOMElement.Create(AOwner: TDOMDocument);
begin
  FNodeType := ELEMENT_NODE;
  inherited Create(AOwner);
end;

destructor TDOMElement.Destroy;
var
  i: Integer;
begin
  {As the attributes are _not_ childs of the element node, we have to free
   them manually here:}
  if FAttributes <> Nil then
  begin
    for i := 0 to FAttributes.Count - 1 do
      FAttributes[i].Free;
    FAttributes.Free;
    FAttributes := Nil;
  end;
  inherited Destroy;
end;

function TDOMElement.CloneNode(deep: Boolean; ACloneOwner: TDOMDocument): TDOMNode;
var
  i: Integer;
begin
  Result           := TDOMElement.Create(ACloneOwner);
  Result.FNodeName := FNodeName;
  if FAttributes <> Nil then
  begin
    TDOMElement(Result).GetAttributes;
    for i := 0 to FAttributes.Count - 1 do
      TDOMElement(Result).FAttributes.Add(FAttributes[i].CloneNode(True, ACloneOwner));
  end;
  if deep then
    CloneChildren(Result, ACloneOwner);
end;

function TDOMElement.GetAttribute(const Name: DOMString): DOMString;
var
  i: Integer;
begin
  if FAttributes <> Nil then
  begin
    for i := 0 to FAttributes.Count - 1 do
      if FAttributes[i].NodeName = name then
      begin
        Result := FAttributes[i].NodeValue;
        exit;
      end;
  end;
  SetLength(Result, 0);
end;

function TDOMElement.GetAttributeNode(const name: DOMString): TDOMAttr;
var
  i: Integer;
begin
  if FAttributes <> Nil then
  begin
    for i := 0 to FAttributes.Count - 1 do
      if FAttributes[i].NodeName = name then
      begin
        Result := TDOMAttr(FAttributes[i]);
        exit;
      end;
  end;
  Result := Nil;
end;

function TDOMElement.GetAttributes: TDOMNamedNodeMap;
begin
  if FAttributes = Nil then
    FAttributes := TDOMNamedNodeMap.Create(FOwnerDocument);
  Result := FAttributes;
end;

function TDOMElement.GetElementsByTagName(const name: DOMString): TDOMNodeList;
begin
  Result := TDOMNodeList.Create(Self, name);
end;

procedure TDOMElement.Normalize;
begin
  // !!!: Not implemented
end;

procedure TDOMElement.RemoveAttribute(const name: DOMString);
var
  i: Integer;
begin
  if FAttributes = Nil then
    exit;
  for i := 0 to FAttributes.Count - 1 do
    if FAttributes[i].NodeName = name then
    begin
      FAttributes[i].Free;
      FAttributes.Delete(i);
      exit;
    end;
end;

function TDOMElement.RemoveAttributeNode(OldAttr: TDOMAttr): TDOMAttr;
var
  i:    Integer;
  node: TDOMNode;
begin
  Result := Nil;
  if FAttributes = Nil then
    exit;
  for i := 0 to FAttributes.Count - 1 do
  begin
    node := FAttributes[i];
    if node = OldAttr then
    begin
      FAttributes.Delete(i);
      Result := TDOMAttr(node);
      exit;
    end;
  end;
end;

procedure TDOMElement.SetAttribute(const Name: DOMString; const Value: DOMString);
var
  i:    Integer;
  attr: TDOMAttr;
begin
  GetAttributes;
  for i := 0 to FAttributes.Count - 1 do
    if FAttributes[i].NodeName = name then
    begin
      FAttributes[i].NodeValue := value;
      exit;
    end;
  attr           := TDOMAttr.Create(FOwnerDocument);
  attr.FNodeName := name;
  attr.NodeValue := value;
  FAttributes.Add(attr);
end;

procedure TDOMElement.SetAttributeNode(NewAttr: TDOMAttr);
var
  i: Integer;
begin
  if FAttributes = Nil then
    exit;
  for i := 0 to FAttributes.Count - 1 do
    if FAttributes[i].NodeName = NewAttr.NodeName then
    begin
      FAttributes[i].Free;
      FAttributes[i] := NewAttr;
      exit;
    end;
end;


{
*********************************** TDOMText ***********************************
}
constructor TDOMText.Create(AOwner: TDOMDocument);
begin
  FNodeType := TEXT_NODE;
  FNodeName := '#text';
  inherited Create(AOwner);
end;

function TDOMText.CloneNode(deep: Boolean; ACloneOwner: TDOMDocument): TDOMNode;
begin
  Result            := TDOMText.Create(ACloneOwner);
  Result.FNodeValue := FNodeValue;
  if deep And (ACloneOwner = Nil) then
  ;
end;

function TDOMText.SplitText(offset: LongWord): TDOMText;
begin
  if Longint(offset) > Length then
    raise EDOMIndexSize.Create('Text.SplitText');

  Result            := TDOMText.Create(FOwnerDocument);
  Result.FNodeValue := Copy(FNodeValue, offset + 1, Length);
  FNodeValue        := Copy(FNodeValue, 1, offset);
  FParentNode.InsertBefore(Result, FNextSibling);
end;


{
********************************* TDOMComment **********************************
}
constructor TDOMComment.Create(AOwner: TDOMDocument);
begin
  FNodeType := COMMENT_NODE;
  FNodeName := '#comment';
  inherited Create(AOwner);
end;

function TDOMComment.CloneNode(deep: Boolean; ACloneOwner: TDOMDocument): TDOMNode;
begin
  Result            := TDOMComment.Create(ACloneOwner);
  Result.FNodeValue := FNodeValue;
  if deep And (ACloneOwner = Nil) then
  ;
end;


{
******************************* TDOMCDATASection *******************************
}
constructor TDOMCDATASection.Create(AOwner: TDOMDocument);
begin
  inherited Create(AOwner);
  FNodeType := CDATA_SECTION_NODE;
  FNodeName := '#cdata-section';
end;

function TDOMCDATASection.CloneNode(deep: Boolean; ACloneOwner: TDOMDocument): TDOMNode;
begin
  Result            := TDOMCDATASection.Create(ACloneOwner);
  Result.FNodeValue := FNodeValue;
  if deep And (ACloneOwner = Nil) then
  ;
end;


{
******************************* TDOMDocumentType *******************************
}
constructor TDOMDocumentType.Create(AOwner: TDOMDocument);
begin
  FNodeType := DOCUMENT_TYPE_NODE;
  inherited Create(AOwner);
end;

function TDOMDocumentType.CloneNode(deep: Boolean; ACloneOwner: TDOMDocument): TDOMNode;
begin
  Result           := TDOMDocumentType.Create(ACloneOwner);
  Result.FNodeName := FNodeName;
  if deep And (ACloneOwner = Nil) then
  ;
end;


{
********************************* TDOMNotation *********************************
}
constructor TDOMNotation.Create(AOwner: TDOMDocument);
begin
  FNodeType := NOTATION_NODE;
  inherited Create(AOwner);
end;

function TDOMNotation.CloneNode(deep: Boolean; ACloneOwner: TDOMDocument): TDOMNode;
begin
  Result           := TDOMNotation.Create(ACloneOwner);
  Result.FNodeName := FNodeName;
  if deep And (ACloneOwner = Nil) then
  ;
end;


{
********************************** TDOMEntity **********************************
}
constructor TDOMEntity.Create(AOwner: TDOMDocument);
begin
  FNodeType := ENTITY_NODE;
  inherited Create(AOwner);
end;


{
***************************** TDOMEntityReference ******************************
}
constructor TDOMEntityReference.Create(AOwner: TDOMDocument);
begin
  FNodeType := ENTITY_REFERENCE_NODE;
  inherited Create(AOwner);
end;


{
************************** TDOMProcessingInstruction ***************************
}
constructor TDOMProcessingInstruction.Create(AOwner: TDOMDocument);
begin
  FNodeType := PROCESSING_INSTRUCTION_NODE;
  inherited Create(AOwner);
end;


const
  Letter = ['A'..'Z', 'a'..'z'];
  Digit  = ['0'..'9'];
  PubidChars: set of AnsiChar = [' ', #13, #10, 'a'..'z', 'A'..'Z', '0'..'9',
    '-', '''', '(', ')', '+', ',', '.', '/', ':', '=', '?', ';', '!', '*',
    '#', '@', '$', '_', '%'];
  WhitespaceChars: set of AnsiChar = [#9, #10, #13, ' '];
  NmToken: set of AnsiChar = Letter + Digit + ['.', '-', '_', ':'];

function ComparePChar(p1, p2: PAnsiChar): Boolean;
begin
  if p1 <> p2 then
  begin
    if (p1 <> Nil) And (p2 <> Nil) then
    begin
      while True do
      begin
        if (p1^ = p2^) then
        begin
          if p1^ <> #0 then
          begin
            inc(p1);
            inc(p2);
          end
          else
          begin
            Result := True;
            exit;
          end;
        end
        else
        begin
          Result := False;
          exit;
        end;
      end;
      Result := True;
    end
    else
    begin
      Result := False;
    end;
  end
  else
  begin
    Result := True;
  end;
end;

function CompareLPChar(p1, p2: PAnsiChar; Max: Integer): Boolean;
begin
  if p1 <> p2 then
  begin
    if (p1 <> Nil) And (p2 <> Nil) then
    begin
      while Max > 0 do
      begin
        if (p1^ = p2^) then
        begin
          if (p1^ <> #0) then
          begin
            inc(p1);
            inc(p2);
            dec(Max);
          end
          else
          begin
            Result := True;
            exit;
          end;
        end
        else
        begin
          Result := False;
          exit;
        end;
      end;
      Result := True;
    end
    else
    begin
      Result := False;
    end;
  end
  else
  begin
    Result := True;
  end;
end;

function CompareIPChar(p1, p2: PAnsiChar): Boolean;
begin
  if p1 <> p2 then
  begin
    if (p1 <> Nil) And (p2 <> Nil) then
    begin
      while True do
      begin
        if (p1^ = p2^) Or (upcase(p1^) = upcase(p2^)) then
        begin
          if p1^ <> #0 then
          begin
            inc(p1);
            inc(p2);
          end
          else
          begin
            Result := True;
            exit;
          end;
        end
        else
        begin
          Result := False;
          exit;
        end;
      end;
      Result := True;
    end
    else
    begin
      Result := False;
    end;
  end
  else
  begin
    Result := True;
  end;
end;

function CompareLIPChar(p1, p2: PAnsiChar; Max: Integer): Boolean;
begin
  if p1 <> p2 then
  begin
    if (p1 <> Nil) And (p2 <> Nil) then
    begin
      while Max > 0 do
      begin
        if (p1^ = p2^) Or (upcase(p1^) = upcase(p2^)) then
        begin
          if (p1^ <> #0) then
          begin
            inc(p1);
            inc(p2);
            dec(Max);
          end
          else
          begin
            Result := True;
            exit;
          end;
        end
        else
        begin
          Result := False;
          exit;
        end;
      end;
      Result := True;
    end
    else
    begin
      Result := False;
    end;
  end
  else
  begin
    Result := True;
  end;
end;


type
  TXMLReaderDocument = class (TXMLDocument)
  public
    procedure SetDocType(ADocType: TDOMDocumentType);
  end;

  TXMLReaderDocumentType = class (TDOMDocumentType)
  public
    constructor Create(ADocument: TXMLReaderDocument);
    property Name: DOMString read FNodeName write FNodeName;
  end;


  TSetOfChar = set of AnsiChar;

  TXMLReader = class (TObject)
  protected
    buf:      PAnsiChar;
    BufStart: PAnsiChar;
    Filename: AnsiString;
    function CheckFor(s: PAnsiChar): Boolean;
    function CheckForChar(c: AnsiChar): Boolean;
    function CheckName: Boolean;
    procedure ExpectAttValue(attr: TDOMAttr);
    procedure ExpectElement(AOwner: TDOMNode);
    procedure ExpectEq;
    procedure ExpectExternalID;
    function ExpectName: AnsiString;
    procedure ExpectProlog;
    function ExpectPubidLiteral: AnsiString;
    procedure ExpectReference(AOwner: TDOMNode);
    procedure ExpectString(const s: AnsiString);
    procedure ExpectWhitespace;
    function GetName(var s: AnsiString): Boolean;
    function GetString(BufPos: PAnsiChar; Len: Integer): AnsiString; Overload;
    function GetString(const ValidChars: TSetOfChar): AnsiString; Overload;
    function ParseCDSect(AOwner: TDOMNode): Boolean;
    function ParseCharData(AOwner: TDOMNode): Boolean;
    function ParseComment(AOwner: TDOMNode): Boolean;
    function ParseElement(AOwner: TDOMNode): Boolean;
    function ParseEncodingDecl: AnsiString;
    function ParseEq: Boolean;
    function ParseExternalID: Boolean;
    function ParseMarkupDecl: Boolean;
    procedure ParseMisc(AOwner: TDOMNode);
    function ParsePEReference: Boolean;
    function ParsePI: Boolean;
    function ParseReference(AOwner: TDOMNode): Boolean;
    procedure RaiseExc(const descr: AnsiString);
    procedure ResolveEntities(RootNode: TDOMNode);
    procedure SkipEncodingDecl;
    procedure SkipName;
    procedure SkipPubidLiteral;
    procedure SkipString(const ValidChars: TSetOfChar);
    function SkipWhitespace: Boolean;
  public
    doc: TDOMDocument;
    procedure ProcessDTD(ABuf: PAnsiChar; const AFilename: AnsiString);
    procedure ProcessFragment(AOwner: TDOMNode; ABuf: PAnsiChar; const AFilename: AnsiString);
    procedure ProcessXML(ABuf: PAnsiChar; const AFilename: AnsiString);
  end;


{
****************************** TXMLReaderDocument ******************************
}
procedure TXMLReaderDocument.SetDocType(ADocType: TDOMDocumentType);
begin
  FDocType := ADocType;
end;


{
**************************** TXMLReaderDocumentType ****************************
}
constructor TXMLReaderDocumentType.Create(ADocument: TXMLReaderDocument);
begin
  inherited Create(ADocument);
end;


{
********************************** TXMLReader **********************************
}
function TXMLReader.CheckFor(s: PAnsiChar): Boolean;
begin
  if buf[0] <> #0 then
  begin
    if (buf[0] = s[0]) And (CompareLPChar(buf, s, StrLen(s))) then
    begin
      Inc(buf, StrLen(s));
      Result := True;
    end
    else
      Result := False;
  end
  else
  begin
    Result := False;
  end;
end;

function TXMLReader.CheckForChar(c: AnsiChar): Boolean;
begin
  if (buf[0] = c) And (c <> #0) then
  begin
    inc(buf);
    Result := True;
  end
  else
  begin
    Result := False;
  end;
end;

function TXMLReader.CheckName: Boolean;
var
  OldBuf: PAnsiChar;
begin
  if Not (buf[0] In (Letter + ['_', ':'])) then
  begin
    Result := False;
    exit;
  end;

  OldBuf := buf;
  Inc(buf);
  SkipString(Letter + ['0'..'9', '.', '-', '_', ':']);
  buf    := OldBuf;
  Result := True;
end;

procedure TXMLReader.ExpectAttValue(attr: TDOMAttr);
var
  OldBuf: PAnsiChar;

  // [10]

  procedure FlushStringBuffer;
  var
    s: AnsiString;
  begin
    if OldBuf <> buf then
    begin
      s      := GetString(OldBuf, buf - OldBuf);
      OldBuf := buf;
      attr.AppendChild(doc.CreateTextNode(s));
      SetLength(s, 0);
    end;
  end;

var
  StrDel: AnsiChar;

begin
  if (buf[0] <> '''') And (buf[0] <> '"') then
    RaiseExc('Expected quotation marks');
  StrDel := buf[0];
  Inc(buf);
  OldBuf := buf;
  while (buf[0] <> StrDel) And (buf[0] <> #0) do
  begin
    if buf[0] <> '&' then
    begin
      Inc(buf);
    end
    else
    begin
      if OldBuf <> buf then
        FlushStringBuffer;
      ParseReference(attr);
      OldBuf := buf;
    end;
  end;
  if OldBuf <> buf then
    FlushStringBuffer;
  inc(buf);
  ResolveEntities(Attr);
end;

procedure TXMLReader.ExpectElement(AOwner: TDOMNode);
begin
  if Not ParseElement(AOwner) then
    RaiseExc('Expected element');
end;

procedure TXMLReader.ExpectEq;
begin
  if Not ParseEq then
    RaiseExc('Expected "="');
end;

procedure TXMLReader.ExpectExternalID;
begin
  if Not ParseExternalID then
    RaiseExc('Expected external ID');
end;

function TXMLReader.ExpectName: AnsiString;

  // [5]

  procedure RaiseNameNotFound;
  begin
    RaiseExc('Expected letter, "_" or ":" for name, found "' + buf[0] + '"');
  end;

var
  OldBuf: PAnsiChar;

begin
  if Not (buf[0] In (Letter + ['_', ':'])) then
    RaiseNameNotFound;

  OldBuf := buf;
  Inc(buf);
  SkipString(Letter + ['0'..'9', '.', '-', '_', ':']);
  Result := GetString(OldBuf, buf - OldBuf);
end;

procedure TXMLReader.ExpectProlog;

// [22]

  procedure ParseVersionNum;
  begin
    if doc.InheritsFrom(TXMLDocument) then
      TXMLDocument(doc).XMLVersion :=
        GetString(['a'..'z', 'A'..'Z', '0'..'9', '_', '.', ':', '-']);
  end;

  procedure ParseDoctypeDecls;
  begin
    repeat
      SkipWhitespace;
    until Not (ParseMarkupDecl Or ParsePEReference);
    ExpectString(']');
  end;

var
  DocType: TXMLReaderDocumentType;

begin
  if CheckFor('<?xml') then
  begin
    // '<?xml' VersionInfo EncodingDecl? SDDecl? S? '?>'

    // VersionInfo: S 'version' Eq (' VersionNum ' | " VersionNum ")
    SkipWhitespace;
    ExpectString('version');
    ParseEq;
    if buf[0] = '''' then
    begin
      Inc(buf);
      ParseVersionNum;
      ExpectString('''');
    end
    else
    if buf[0] = '"' then
    begin
      Inc(buf);
      ParseVersionNum;
      ExpectString('"');
    end
    else
      RaiseExc('Expected single or double quotation mark');

    // EncodingDecl?
    SkipEncodingDecl;

    // SDDecl?
    SkipWhitespace;
    if CheckFor('standalone') then
    begin
      ExpectEq;
      if buf[0] = '''' then
      begin
        Inc(buf);
        if Not (CheckFor('yes''') Or CheckFor('no''')) then
          RaiseExc('Expected ''yes'' or ''no''');
      end
      else
      if buf[0] = '''' then
      begin
        Inc(buf);
        if Not (CheckFor('yes"') Or CheckFor('no"')) then
          RaiseExc('Expected "yes" or "no"');
      end;
      SkipWhitespace;
    end;

    ExpectString('?>');
  end;

  // Check for "Misc*"
  ParseMisc(doc);

  // Check for "(doctypedecl Misc*)?"    [28]
  if CheckFor('<!DOCTYPE') then
  begin
    DocType := TXMLReaderDocumentType.Create(doc As TXMLReaderDocument);
    if doc.InheritsFrom(TXMLReaderDocument) then
      TXMLReaderDocument(doc).SetDocType(DocType);
    SkipWhitespace;
    DocType.Name := ExpectName;
    SkipWhitespace;
    if CheckForChar('[') then
    begin
      ParseDoctypeDecls;
      SkipWhitespace;
      ExpectString('>');
    end
    else
    if Not CheckForChar('>') then
    begin
      ParseExternalID;
      SkipWhitespace;
      if CheckForChar('[') then
      begin
        ParseDoctypeDecls;
        SkipWhitespace;
      end;
      ExpectString('>');
    end;
    ParseMisc(doc);
  end;
end;

function TXMLReader.ExpectPubidLiteral: AnsiString;
begin
  SetLength(Result, 0);
  if CheckForChar('''') then
  begin
    SkipString(PubidChars - ['''']);
    ExpectString('''');
  end
  else
  if CheckForChar('"') then
  begin
    SkipString(PubidChars - ['"']);
    ExpectString('"');
  end
  else
    RaiseExc('Expected quotation marks');
end;

procedure TXMLReader.ExpectReference(AOwner: TDOMNode);
begin
  if Not ParseReference(AOwner) then
    RaiseExc('Expected reference ("&Name;" or "%Name;")');
end;

procedure TXMLReader.ExpectString(const s: AnsiString);

  procedure RaiseStringNotFound;
  var
    s2: PAnsiChar;
    s3: AnsiString;
  begin
    GetMem(s2, Length(s) + 1);
    StrLCopy(s2, buf, Length(s));
    s3 := StrPas(s2);
    FreeMem(s2);
    RaiseExc('Expected "' + s + '", found "' + s3 + '"');
  end;

var
  i: Integer;

begin
  for i := 1 to Length(s) do
    if buf[i - 1] <> s[i] then
    begin
      RaiseStringNotFound;
    end;
  Inc(buf, Length(s));
end;

procedure TXMLReader.ExpectWhitespace;
begin
  if Not SkipWhitespace then
    RaiseExc('Expected whitespace');
end;

function TXMLReader.GetName(var s: AnsiString): Boolean;
var
  OldBuf: PAnsiChar;

  // [5]

begin
  if Not (buf[0] In (Letter + ['_', ':'])) then
  begin
    SetLength(s, 0);
    Result := False;
    exit;
  end;

  OldBuf := buf;
  Inc(buf);
  SkipString(Letter + ['0'..'9', '.', '-', '_', ':']);
  s      := GetString(OldBuf, buf - OldBuf);
  Result := True;
end;

function TXMLReader.GetString(BufPos: PAnsiChar; Len: Integer): AnsiString;
var
  i: Integer;
begin
  SetLength(Result, Len);
  for i := 1 to Len do
  begin
    Result[i] := BufPos[0];
    inc(BufPos);
  end;
end;

function TXMLReader.GetString(const ValidChars: TSetOfChar): AnsiString;
var
  OldBuf: PAnsiChar;
  i, len: Integer;
begin
  OldBuf := Buf;
  while buf[0] In ValidChars do
  begin
    Inc(buf);
  end;
  len := buf - OldBuf;
  SetLength(Result, Len);
  for i := 1 to len do
  begin
    Result[i] := OldBuf[0];
    inc(OldBuf);
  end;
end;

function TXMLReader.ParseCDSect(AOwner: TDOMNode): Boolean;
var
  OldBuf: PAnsiChar;

  // [18]

begin
  if CheckFor('<![CDATA[') then
  begin
    OldBuf := buf;
    while Not CheckFor(']]>') do
    begin
      Inc(buf);
    end;
    AOwner.AppendChild(doc.CreateCDATASection(GetString(OldBuf, buf - OldBuf - 3))); { Copy CDATA, discarding terminator }
    Result := True;
  end
  else
    Result := False;
end;

function TXMLReader.ParseCharData(AOwner: TDOMNode): Boolean;
var
  p:       PAnsiChar;
  DataLen: Integer;
  OldBuf:  PAnsiChar;

  // [14]

begin
  OldBuf := buf;
  while Not (buf[0] In [#0, '<', '&']) do
  begin
    Inc(buf);
  end;
  DataLen := buf - OldBuf;
  if DataLen > 0 then
  begin
    // Check if chardata has non-whitespace content
    p := OldBuf;
    while (p < buf) And (p[0] In WhitespaceChars) do
      inc(p);
    if p < buf then
      AOwner.AppendChild(doc.CreateTextNode(GetString(OldBuf, DataLen)));
    Result := True;
  end
  else
    Result := False;
end;

function TXMLReader.ParseComment(AOwner: TDOMNode): Boolean;
var
  comment: AnsiString;
  OldBuf:  PAnsiChar;

  // [15]

begin
  if CheckFor('<!--') then
  begin
    OldBuf := buf;
    while (buf[0] <> #0) And (buf[1] <> #0) And
      ((buf[0] <> '-') Or (buf[1] <> '-')) do
    begin
      Inc(buf);
    end;
    comment := GetString(OldBuf, buf - OldBuf);
    AOwner.AppendChild(doc.CreateComment(comment));
    ExpectString('-->');
    Result := True;
  end
  else
    Result := False;
end;

function TXMLReader.ParseElement(AOwner: TDOMNode): Boolean;
var
  NewElem: TDOMElement;

  // [39] [40] [44]

  procedure CreateNameElement;
  var
    IsEmpty: Boolean;
    attr:    TDOMAttr;
    name:    AnsiString;
  begin
    GetName(name);
    NewElem := doc.CreateElement(name);
    AOwner.AppendChild(NewElem);

    SkipWhitespace;
    IsEmpty := False;
    while True do
    begin
      if CheckFor('/>') then
      begin
        IsEmpty := True;
        break;
      end;
      if CheckForChar('>') then
        break;

      // Get Attribute [41]
      attr := doc.CreateAttribute(ExpectName);
      NewElem.Attributes.SetNamedItem(attr);
      ExpectEq;
      ExpectAttValue(attr);

      SkipWhitespace;
    end;

    if Not IsEmpty then
    begin
      // Get content
      SkipWhitespace;
      while ParseCharData(NewElem) Or ParseCDSect(NewElem) Or ParsePI Or
        ParseComment(NewElem) Or ParseElement(NewElem) Or
        ParseReference(NewElem) do ;

      // Get ETag [42]
      ExpectString('</');
      if ExpectName <> name then
        RaiseExc('Unmatching element end tag (expected "</' + name + '>")');
      SkipWhitespace;
      ExpectString('>');
    end;

    ResolveEntities(NewElem);
  end;

var
  OldBuf: PAnsiChar;

begin
  OldBuf := Buf;
  if CheckForChar('<') then
  begin
    if Not CheckName then
    begin
      Buf    := OldBuf;
      Result := False;
    end
    else
    begin
      CreateNameElement;
      Result := True;
    end;
  end
  else
    Result := False;
end;

function TXMLReader.ParseEncodingDecl: AnsiString;

  // [80]

  function ParseEncName: AnsiString;
  var
    OldBuf: PAnsiChar;
  begin
    if Not (buf[0] In ['A'..'Z', 'a'..'z']) then
      RaiseExc('Expected character (A-Z, a-z)');
    OldBuf := buf;
    Inc(buf);
    SkipString(['A'..'Z', 'a'..'z', '0'..'9', '.', '_', '-']);
    Result := GetString(OldBuf, buf - OldBuf);
  end;

begin
  SetLength(Result, 0);
  SkipWhitespace;
  if CheckFor('encoding') then
  begin
    ExpectEq;
    if buf[0] = '''' then
    begin
      Inc(buf);
      Result := ParseEncName;
      ExpectString('''');
    end
    else
    if buf[0] = '"' then
    begin
      Inc(buf);
      Result := ParseEncName;
      ExpectString('"');
    end;
  end;
end;

function TXMLReader.ParseEq: Boolean;
var
  savedbuf: PAnsiChar;

  // [25]

begin
  savedbuf := buf;
  SkipWhitespace;
  if buf[0] = '=' then
  begin
    Inc(buf);
    SkipWhitespace;
    Result := True;
  end
  else
  begin
    buf    := savedbuf;
    Result := False;
  end;
end;

function TXMLReader.ParseExternalID: Boolean;

  // [75]

  function GetSystemLiteral: AnsiString;
  var
    OldBuf: PAnsiChar;
  begin
    if buf[0] = '''' then
    begin
      Inc(buf);
      OldBuf := buf;
      while (buf[0] <> '''') And (buf[0] <> #0) do
      begin
        Inc(buf);
      end;
      Result := GetString(OldBuf, buf - OldBuf);
      ExpectString('''');
    end
    else
    if buf[0] = '"' then
    begin
      Inc(buf);
      OldBuf := buf;
      while (buf[0] <> '"') And (buf[0] <> #0) do
      begin
        Inc(buf);
      end;
      Result := GetString(OldBuf, buf - OldBuf);
      ExpectString('"');
    end
    else
      Result := '';
  end;

  procedure SkipSystemLiteral;
  begin
    if buf[0] = '''' then
    begin
      Inc(buf);
      while (buf[0] <> '''') And (buf[0] <> #0) do
      begin
        Inc(buf);
      end;
      ExpectString('''');
    end
    else
    if buf[0] = '"' then
    begin
      Inc(buf);
      while (buf[0] <> '"') And (buf[0] <> #0) do
      begin
        Inc(buf);
      end;
      ExpectString('"');
    end;
  end;

begin
  if CheckFor('SYSTEM') then
  begin
    ExpectWhitespace;
    SkipSystemLiteral;
    Result := True;
  end
  else
  if CheckFor('PUBLIC') then
  begin
    ExpectWhitespace;
    SkipPubidLiteral;
    ExpectWhitespace;
    SkipSystemLiteral;
    Result := True;
  end
  else
    Result := False;
end;

function TXMLReader.ParseMarkupDecl: Boolean;

  // [29]

  function ParseElementDecl: Boolean;    // [45]

    procedure ExpectChoiceOrSeq;    // [49], [50]

      procedure ExpectCP;    // [48]
      begin
        if CheckForChar('(') then
          ExpectChoiceOrSeq
        else
          SkipName;
        if CheckForChar('?') then
        else
        if CheckForChar('*') then
        else
        if CheckForChar('+') then;
      end;

    var
      delimiter: AnsiChar;
    begin
      SkipWhitespace;
      ExpectCP;
      SkipWhitespace;
      delimiter := #0;
      while Not CheckForChar(')') do
      begin
        if delimiter = #0 then
        begin
          if (buf[0] = '|') Or (buf[0] = ',') then
            delimiter := buf[0]
          else
            RaiseExc('Expected "|" or ","');
          Inc(buf);
        end
        else
          ExpectString(delimiter);
        SkipWhitespace;
        ExpectCP;
      end;
    end;

  begin
    if CheckFor('<!ELEMENT') then
    begin
      ExpectWhitespace;
      SkipName;
      ExpectWhitespace;

      // Get contentspec [46]

      if CheckFor('EMPTY') then
      else
      if CheckFor('ANY') then
      else
      if CheckForChar('(') then
      begin
        SkipWhitespace;
        if CheckFor('#PCDATA') then
        begin
          // Parse Mixed section [51]
          SkipWhitespace;
          if Not CheckForChar(')') then
            repeat
              ExpectString('|');
              SkipWhitespace;
              SkipName;
            until CheckFor(')*');
        end
        else
        begin
          // Parse Children section [47]

          ExpectChoiceOrSeq;

          if CheckForChar('?') then
          else
          if CheckForChar('*') then
          else
          if CheckForChar('+') then;
        end;
      end
      else
        RaiseExc('Invalid content specification');

      SkipWhitespace;
      ExpectString('>');
      Result := True;
    end
    else
      Result := False;
  end;

  function ParseAttlistDecl: Boolean;    // [52]
  var
    attr: TDOMAttr;
  begin
    if CheckFor('<!ATTLIST') then
    begin
      ExpectWhitespace;
      SkipName;
      SkipWhitespace;
      while Not CheckForChar('>') do
      begin
        SkipName;
        ExpectWhitespace;

        // Get AttType [54], [55], [56]
        if CheckFor('CDATA') then
        else
        if CheckFor('ID') then
        else
        if CheckFor('IDREF') then
        else
        if CheckFor('IDREFS') then
        else
        if CheckFor('ENTITTY') then
        else
        if CheckFor('ENTITIES') then
        else
        if CheckFor('NMTOKEN') then
        else
        if CheckFor('NMTOKENS') then
        else
        if CheckFor('NOTATION') then
        begin   // [57], [58]
          ExpectWhitespace;
          ExpectString('(');
          SkipWhitespace;
          SkipName;
          SkipWhitespace;
          while Not CheckForChar(')') do
          begin
            ExpectString('|');
            SkipWhitespace;
            SkipName;
            SkipWhitespace;
          end;
        end
        else
        if CheckForChar('(') then
        begin    // [59]
          SkipWhitespace;
          SkipString(Nmtoken);
          SkipWhitespace;
          while Not CheckForChar(')') do
          begin
            ExpectString('|');
            SkipWhitespace;
            SkipString(Nmtoken);
            SkipWhitespace;
          end;
        end
        else
          RaiseExc('Invalid tokenized type');

        ExpectWhitespace;

        // Get DefaultDecl [60]
        if CheckFor('#REQUIRED') then
        else
        if CheckFor('#IMPLIED') then
        else
        begin
          if CheckFor('#FIXED') then
            SkipWhitespace;
          attr := doc.CreateAttribute('');
          ExpectAttValue(attr);
        end;

        SkipWhitespace;
      end;
      Result := True;
    end
    else
      Result := False;
  end;

  function ParseEntityDecl: Boolean;    // [70]
  var
    NewEntity: TDOMEntity;

    function ParseEntityValue: Boolean;    // [9]
    var
      strdel: AnsiChar;
    begin
      if (buf[0] <> '''') And (buf[0] <> '"') then
      begin
        Result := False;
        exit;
      end;
      strdel := buf[0];
      Inc(buf);
      while Not CheckForChar(strdel) do
        if ParsePEReference then
        else
        if ParseReference(NewEntity) then
        else
        begin
          Inc(buf);             // Normal haracter
        end;
      Result := True;
    end;

  begin
    if CheckFor('<!ENTITY') then
    begin
      ExpectWhitespace;
      if CheckForChar('%') then
      begin    // [72]
        ExpectWhitespace;
        NewEntity := doc.CreateEntity(ExpectName);
        ExpectWhitespace;
        // Get PEDef [74]
        if ParseEntityValue then
        else
        if ParseExternalID then
        else
          RaiseExc('Expected entity value or external ID');
      end
      else
      begin    // [71]
        NewEntity := doc.CreateEntity(ExpectName);
        ExpectWhitespace;
        // Get EntityDef [73]
        if ParseEntityValue then
        else
        begin
          ExpectExternalID;
          // Get NDataDecl [76]
          ExpectWhitespace;
          ExpectString('NDATA');
          ExpectWhitespace;
          SkipName;
        end;
      end;
      SkipWhitespace;
      ExpectString('>');
      Result := True;
    end
    else
      Result := False;
  end;

  function ParseNotationDecl: Boolean;    // [82]
  begin
    if CheckFor('<!NOTATION') then
    begin
      ExpectWhitespace;
      SkipName;
      ExpectWhitespace;
      if ParseExternalID then
      else
      if CheckFor('PUBLIC') then
      begin    // [83]
        ExpectWhitespace;
        SkipPubidLiteral;
      end
      else
        RaiseExc('Expected external or public ID');
      SkipWhitespace;
      ExpectString('>');
      Result := True;
    end
    else
      Result := False;
  end;

begin
  Result := False;
  while ParseElementDecl Or ParseAttlistDecl Or ParseEntityDecl Or
    ParseNotationDecl Or ParsePI Or ParseComment(doc) Or SkipWhitespace do
    Result := True;
end;

procedure TXMLReader.ParseMisc(AOwner: TDOMNode);

// [27]

begin
  repeat
    SkipWhitespace;
  until Not (ParseComment(AOwner) Or ParsePI);
end;

function TXMLReader.ParsePEReference: Boolean;

  // [69]

begin
  if CheckForChar('%') then
  begin
    SkipName;
    ExpectString(';');
    Result := True;
  end
  else
    Result := False;
end;

function TXMLReader.ParsePI: Boolean;

  // [16]

begin
  if CheckFor('<?') then
  begin
    if CompareLIPChar(buf, 'XML ', 4) then
      RaiseExc('"<?xml" processing instruction not allowed here');
    SkipName;
    if SkipWhitespace then
      while (buf[0] <> #0) And (buf[1] <> #0) And Not
        ((buf[0] = '?') And (buf[1] = '>')) do
        Inc(buf);
    ExpectString('?>');
    Result := True;
  end
  else
    Result := False;
end;

function TXMLReader.ParseReference(AOwner: TDOMNode): Boolean;

  // [67] [68]

begin
  if Not CheckForChar('&') then
  begin
    Result := False;
    exit;
  end;
  if CheckForChar('#') then
  begin    // Test for CharRef [66]
    if CheckForChar('x') then
    begin
      // !!!: there must be at least one digit
      while buf[0] In ['0'..'9', 'a'..'f', 'A'..'F'] do
        Inc(buf);
    end
    else
      // !!!: there must be at least one digit
      while buf[0] In ['0'..'9'] do
        Inc(buf);
  end
  else
    AOwner.AppendChild(doc.CreateEntityReference(ExpectName));
  ExpectString(';');
  Result := True;
end;

procedure TXMLReader.ProcessDTD(ABuf: PAnsiChar; const AFilename: AnsiString);
begin
  buf      := ABuf;
  BufStart := ABuf;
  Filename := AFilename;

  doc := TXMLReaderDocument.Create;
  ParseMarkupDecl;

  {
  if buf[0] <> #0 then begin
    DebugLn('=== Unparsed: ===');
    //DebugLn(buf);
    DebugLn(StrLen(buf), ' chars');
  end;
  }
end;

procedure TXMLReader.ProcessFragment(AOwner: TDOMNode; ABuf: PAnsiChar; const AFilename: AnsiString);
begin
  buf      := ABuf;
  BufStart := ABuf;
  Filename := AFilename;

  SkipWhitespace;
  while ParseCharData(AOwner) Or ParseCDSect(AOwner) Or ParsePI Or
    ParseComment(AOwner) Or ParseElement(AOwner) Or
    ParseReference(AOwner) do
    SkipWhitespace;
end;

procedure TXMLReader.ProcessXML(ABuf: PAnsiChar; const AFilename: AnsiString);
begin
  buf      := ABuf;
  BufStart := ABuf;
  Filename := AFilename;

  doc := TXMLReaderDocument.Create;
  ExpectProlog;
  ExpectElement(doc);
  ParseMisc(doc);

  if buf[0] <> #0 then
    RaiseExc('Text after end of document element found');
end;

procedure TXMLReader.RaiseExc(const descr: AnsiString);
var
  apos: PAnsiChar;
  x, y: Integer;
begin
  // find out the line in which the error occured
  apos := BufStart;
  x    := 1;
  y    := 1;
  while apos < buf do
  begin
    if apos[0] = #10 then
    begin
      Inc(y);
      x := 1;
    end
    else
      Inc(x);
    Inc(apos);
  end;

  raise EXMLReadError.Create('In ' + Filename + ' (line ' + IntToStr(y) + ' pos ' +
    IntToStr(x) + '): ' + descr);
end;

procedure TXMLReader.ResolveEntities(RootNode: TDOMNode);
var
  Node, NextNode: TDOMNode;

  procedure ReplaceEntityRef(EntityNode: TDOMNode; const Replacement: AnsiString);
  var
    PrevSibling, NextSibling: TDOMNode;
  begin
    PrevSibling := EntityNode.PreviousSibling;
    NextSibling := EntityNode.NextSibling;
    if Assigned(PrevSibling) And (PrevSibling.NodeType = TEXT_NODE) then
    begin
      TDOMCharacterData(PrevSibling).AppendData(Replacement);
      RootNode.RemoveChild(EntityNode);
      if Assigned(NextSibling) And (NextSibling.NodeType = TEXT_NODE) then
      begin
        NextNode := NextSibling.NextSibling;
        TDOMCharacterData(PrevSibling).AppendData(
          TDOMCharacterData(NextSibling).Data);
        RootNode.RemoveChild(NextSibling);
      end;
    end
    else
    if Assigned(NextSibling) And (NextSibling.NodeType = TEXT_NODE) then
    begin
      TDOMCharacterData(NextSibling).InsertData(0, Replacement);
      RootNode.RemoveChild(EntityNode);
    end
    else
      RootNode.ReplaceChild(Doc.CreateTextNode(Replacement), EntityNode);
  end;

begin
  Node := RootNode.FirstChild;
  while Assigned(Node) do
  begin
    NextNode := Node.NextSibling;
    if Node.NodeType = ENTITY_REFERENCE_NODE then
      if Node.NodeName = 'amp' then
        ReplaceEntityRef(Node, '&')
      else
      if Node.NodeName = 'apos' then
        ReplaceEntityRef(Node, '''')
      else
      if Node.NodeName = 'gt' then
        ReplaceEntityRef(Node, '>')
      else
      if Node.NodeName = 'lt' then
        ReplaceEntityRef(Node, '<')
      else
      if Node.NodeName = 'quot' then
        ReplaceEntityRef(Node, '"');
    Node := NextNode;
  end;
end;

procedure TXMLReader.SkipEncodingDecl;

  procedure ParseEncName;
  begin
    if Not (buf[0] In ['A'..'Z', 'a'..'z']) then
      RaiseExc('Expected character (A-Z, a-z)');
    Inc(buf);
    SkipString(['A'..'Z', 'a'..'z', '0'..'9', '.', '_', '-']);
  end;

begin
  SkipWhitespace;
  if CheckFor('encoding') then
  begin
    ExpectEq;
    if buf[0] = '''' then
    begin
      Inc(buf);
      ParseEncName;
      ExpectString('''');
    end
    else
    if buf[0] = '"' then
    begin
      Inc(buf);
      ParseEncName;
      ExpectString('"');
    end;
  end;
end;

procedure TXMLReader.SkipName;

  procedure RaiseSkipNameNotFound;
  begin
    RaiseExc('Expected letter, "_" or ":" for name, found "' + buf[0] + '"');
  end;

begin
  if Not (buf[0] In (Letter + ['_', ':'])) then
    RaiseSkipNameNotFound;

  Inc(buf);
  SkipString(Letter + ['0'..'9', '.', '-', '_', ':']);
end;

procedure TXMLReader.SkipPubidLiteral;
begin
  if CheckForChar('''') then
  begin
    SkipString(PubidChars - ['''']);
    ExpectString('''');
  end
  else
  if CheckForChar('"') then
  begin
    SkipString(PubidChars - ['"']);
    ExpectString('"');
  end
  else
    RaiseExc('Expected quotation marks');
end;

procedure TXMLReader.SkipString(const ValidChars: TSetOfChar);
begin
  while buf[0] In ValidChars do
  begin
    Inc(buf);
  end;
end;

function TXMLReader.SkipWhitespace: Boolean;
begin
  Result := False;
  while buf[0] In WhitespaceChars do
  begin
    Inc(buf);
    Result := True;
  end;
end;


procedure ReadXMLFile(var ADoc: TXMLDocument; var f: file);
var
  reader:  TXMLReader;
  buf:     PAnsiChar;
  BufSize: LongInt;
begin
  ADoc    := Nil;
  BufSize := FileSize(f) + 1;
  if BufSize <= 1 then
    exit;

  GetMem(buf, BufSize);
  try
    BlockRead(f, buf^, BufSize - 1);
    buf[BufSize - 1] := #0;
    Reader           := TXMLReader.Create;
    try
      Reader.ProcessXML(buf, TFileRec(f).name);
      ADoc := TXMLDocument(Reader.doc);
    finally
      Reader.Free;
    end;
  finally
    FreeMem(buf);
  end;
end;

procedure ReadXMLFile(var ADoc: TXMLDocument; var f: TStream; const AFilename: AnsiString);
var
  reader: TXMLReader;
  buf:    PAnsiChar;
begin
  ADoc := Nil;
  if f.Size = 0 then
    exit;

  GetMem(buf, f.Size + 1);
  try
    f.Read(buf^, f.Size);
    buf[f.Size] := #0;
    Reader      := TXMLReader.Create;
    try
      Reader.ProcessXML(buf, AFilename);
      ADoc := TXMLDocument(Reader.doc);
    finally
      Reader.Free;
    end;
  finally
    FreeMem(buf);
  end;
end;

procedure ReadXMLFile(var ADoc: TXMLDocument; var f: TStream);
begin
  ReadXMLFile(ADoc, f, '<Stream>');
end;

procedure ReadXMLFile(var ADoc: TXMLDocument; const AFilename: AnsiString);
var
  FileStream: TFileStream;
  MemStream:  TMemoryStream;
begin
  ADoc       := Nil;
  FileStream := TFileStream.Create(AFilename, fmOpenRead);
  if FileStream = Nil then
    exit;
  MemStream := TMemoryStream.Create;
  try
    MemStream.LoadFromStream(FileStream);
    ReadXMLFile(ADoc, TStream(MemStream), AFilename);
  finally
    FileStream.Free;
    MemStream.Free;
  end;
end;

procedure ReadXMLFragment(AParentNode: TDOMNode; var f: file);
var
  Reader:  TXMLReader;
  buf:     PAnsiChar;
  BufSize: LongInt;
begin
  BufSize := FileSize(f) + 1;
  if BufSize <= 1 then
    exit;

  GetMem(buf, BufSize);
  try
    BlockRead(f, buf^, BufSize - 1);
    buf[BufSize - 1] := #0;
    Reader           := TXMLReader.Create;
    try
      Reader.Doc := AParentNode.OwnerDocument;
      Reader.ProcessFragment(AParentNode, buf, TFileRec(f).name);
    finally
      Reader.Free;
    end;
  finally
    FreeMem(buf);
  end;
end;

procedure ReadXMLFragment(AParentNode: TDOMNode; var f: TStream; const AFilename: AnsiString);
var
  Reader: TXMLReader;
  buf:    PAnsiChar;
begin
  if f.Size = 0 then
    exit;

  GetMem(buf, f.Size + 1);
  try
    f.Read(buf^, f.Size);
    buf[f.Size] := #0;
    Reader      := TXMLReader.Create;
    Reader.Doc  := AParentNode.OwnerDocument;
    try
      Reader.ProcessFragment(AParentNode, buf, AFilename);
    finally
      Reader.Free;
    end;
  finally
    FreeMem(buf);
  end;
end;

procedure ReadXMLFragment(AParentNode: TDOMNode; var f: TStream);
begin
  ReadXMLFragment(AParentNode, f, '<Stream>');
end;

procedure ReadXMLFragment(AParentNode: TDOMNode; const AFilename: AnsiString);
var
  Stream: TStream;
begin
  Stream := TFileStream.Create(AFilename, fmOpenRead);
  try
    ReadXMLFragment(AParentNode, Stream, AFilename);
  finally
    Stream.Free;
  end;
end;

procedure ReadDTDFile(var ADoc: TXMLDocument; var f: file);
var
  Reader:  TXMLReader;
  buf:     PAnsiChar;
  BufSize: LongInt;
begin
  ADoc    := Nil;
  BufSize := FileSize(f) + 1;
  if BufSize <= 1 then
    exit;

  GetMem(buf, BufSize);
  try
    BlockRead(f, buf^, BufSize - 1);
    buf[BufSize - 1] := #0;
    Reader           := TXMLReader.Create;
    try
      Reader.ProcessDTD(buf, TFileRec(f).name);
      ADoc := TXMLDocument(Reader.doc);
    finally
      Reader.Free;
    end;
  finally
    FreeMem(buf);
  end;
end;

procedure ReadDTDFile(var ADoc: TXMLDocument; var f: TStream; const AFilename: AnsiString);
var
  Reader: TXMLReader;
  buf:    PAnsiChar;
begin
  ADoc := Nil;
  if f.Size = 0 then
    exit;

  GetMem(buf, f.Size + 1);
  try
    f.Read(buf^, f.Size);
    buf[f.Size] := #0;
    Reader      := TXMLReader.Create;
    try
      Reader.ProcessDTD(buf, AFilename);
      ADoc := TXMLDocument(Reader.doc);
    finally
      Reader.Free;
    end;
  finally
    FreeMem(buf);
  end;
end;

procedure ReadDTDFile(var ADoc: TXMLDocument; var f: TStream);
begin
  ReadDTDFile(ADoc, f, '<Stream>');
end;

procedure ReadDTDFile(var ADoc: TXMLDocument; const AFilename: AnsiString);
var
  Stream: TStream;
begin
  ADoc   := Nil;
  Stream := TFileStream.Create(AFilename, fmOpenRead);
  try
    ReadDTDFile(ADoc, Stream, AFilename);
  finally
    Stream.Free;
  end;
end;

procedure WriteElement(node: TDOMNode); Forward;
procedure WriteAttribute(node: TDOMNode); Forward;
procedure WriteText(node: TDOMNode); Forward;
procedure WriteCDATA(node: TDOMNode); Forward;
procedure WriteEntityRef(node: TDOMNode); Forward;
procedure WriteEntity(node: TDOMNode); Forward;
procedure WritePI(node: TDOMNode); Forward;
procedure WriteComment(node: TDOMNode); Forward;
procedure WriteDocument(node: TDOMNode); Forward;
procedure WriteDocumentType(node: TDOMNode); Forward;
procedure WriteDocumentFragment(node: TDOMNode); Forward;
procedure WriteNotation(node: TDOMNode); Forward;

type
  TWriteNodeProc = procedure(node: TDOMNode);

const
  WriteProcs: array[ELEMENT_NODE..NOTATION_NODE] of TWriteNodeProc =
    (WriteElement, WriteAttribute, WriteText, WriteCDATA, WriteEntityRef,
    WriteEntity, WritePI, WriteComment, WriteDocument, WriteDocumentType,
    WriteDocumentFragment, WriteNotation);

procedure WriteNode(node: TDOMNode);
begin
  WriteProcs[node.NodeType](node);
end;

type
  TOutputProc = procedure(const Buffer; Count: Longint);

threadvar
  f:              ^Text;
  stream:         TStream;
  wrt, wrtln:     TOutputProc;
  InsideTextNode: Boolean;

procedure Text_Write(const Buffer; Count: Longint);
var
  s: AnsiString;
begin
  if Count > 0 then
  begin
    SetLength(s, Count);
    System.Move(Buffer, s[1], Count);
    Write(f^, s);
  end;
end;

procedure Text_WriteLn(const Buffer; Count: Longint);
var
  s: AnsiString;
begin
  if Count > 0 then
  begin
    SetLength(s, Count);
    System.Move(Buffer, s[1], Count);
    writeln(f^, s);
  end;
end;

procedure Stream_Write(const Buffer; Count: Longint);
begin
  if Count > 0 then
  begin
    stream.Write(Buffer, Count);
  end;
end;

procedure Stream_WriteLn(const Buffer; Count: Longint);
var
  B: Byte;
begin
  if Count > 0 then
  begin
    stream.Write(Buffer, Count);
    b := 10;
    stream.WriteBuffer(b, 1);
  end;
end;

procedure wrtStr(const s: AnsiString);
begin
  if s <> '' then
    wrt(s[1], length(s));
end;

procedure wrtStrLn(const s: AnsiString);
begin
  if s <> '' then
    wrtln(s[1], length(s));
end;

procedure wrtChr(c: AnsiChar);
begin
  wrt(c, 1);
end;

const
  LF: AnsiChar = #10;

procedure wrtLineEnd;
begin
  wrt(LF, 1);
end;

threadvar
  Indent:      AnsiString;
  IndentCount: Integer;

procedure wrtIndent;
var
  i: Integer;
begin
  for i := 1 to IndentCount do
    wrtStr(Indent);
end;

procedure IncIndent;
begin
  inc(IndentCount);
end;

procedure DecIndent;
begin
  if IndentCount > 0 then
    dec(IndentCount);
end;

type
  TCharacters          = set of AnsiChar;
  TSpecialCharCallback = procedure(c: AnsiChar);

const
  AttrSpecialChars = ['<', '>', '"', '&'];
  TextSpecialChars = ['<', '>', '&'];


procedure ConvWrite(const s: AnsiString; const SpecialChars: TCharacters; const SpecialCharCallback: TSpecialCharCallback);
var
  StartPos, EndPos: Integer;
begin
  StartPos := 1;
  EndPos   := 1;
  while EndPos <= Length(s) do
  begin
    if s[EndPos] In SpecialChars then
    begin
      wrt(s[StartPos], EndPos - StartPos);
      SpecialCharCallback(s[EndPos]);
      StartPos := EndPos + 1;
    end;
    Inc(EndPos);
  end;
  if StartPos <= length(s) then
    wrt(s[StartPos], EndPos - StartPos);
end;

procedure AttrSpecialCharCallback(c: AnsiChar);
const
  QuotStr = '&quot;';
  AmpStr  = '&amp;';
begin
  if c = '"' then
    wrtStr(QuotStr)
  else
  if c = '&' then
    wrtStr(AmpStr)
  else
    wrt(c, 1);
end;

procedure TextnodeSpecialCharCallback(c: AnsiChar);
const
  ltStr  = '&lt;';
  gtStr  = '&gt;';
  AmpStr = '&amp;';
begin
  if c = '<' then
    wrtStr(ltStr)
  else
  if c = '>' then
    wrtStr(gtStr)
  else
  if c = '&' then
    wrtStr(AmpStr)
  else
    wrt(c, 1);
end;

procedure WriteElement(node: TDOMNode);
var
  i:                   Integer;
  attr, child:         TDOMNode;
  SavedInsideTextNode: Boolean;
  s:                   AnsiString;
begin
  if Not InsideTextNode then
    wrtIndent;
  wrtChr('<');
  wrtStr(node.NodeName);
  for i := 0 to node.Attributes.Length - 1 do
  begin
    attr := node.Attributes.Item[i];
    wrtChr(' ');
    wrtStr(attr.NodeName);
    wrtChr('=');
    s := attr.NodeValue;
    // !!!: Replace special characters in "s" such as '&', '<', '>'
    wrtChr('"');
    ConvWrite(s, AttrSpecialChars, @AttrSpecialCharCallback);
    wrtChr('"');
  end;
  Child := node.FirstChild;
  if Child = Nil then
  begin
    wrtChr('/');
    wrtChr('>');
    if Not InsideTextNode then
      wrtLineEnd;
  end
  else
  begin
    SavedInsideTextNode := InsideTextNode;
    wrtChr('>');
    if Not (InsideTextNode Or Child.InheritsFrom(TDOMText)) then
      wrtLineEnd;
    IncIndent;
    repeat
      if Child.InheritsFrom(TDOMText) then
        InsideTextNode := True;
      WriteNode(Child);
      Child := Child.NextSibling;
    until child = Nil;
    DecIndent;
    if Not InsideTextNode then
      wrtIndent;
    InsideTextNode := SavedInsideTextNode;
    wrtChr('<');
    wrtChr('/');
    wrtStr(node.NodeName);
    wrtChr('>');
    if Not InsideTextNode then
      wrtLineEnd;
  end;
end;

procedure WriteAttribute(node: TDOMNode);
begin
  if node = Nil then
  ;
end;

procedure WriteText(node: TDOMNode);
begin
  ConvWrite(node.NodeValue, TextSpecialChars, @TextnodeSpecialCharCallback);
  if node = Nil then
  ;
end;

procedure WriteCDATA(node: TDOMNode);
begin
  if Not InsideTextNode then
    wrtStr('<![CDATA[' + node.NodeValue + ']]>')
  else
  begin
    wrtIndent;
    wrtStrln('<![CDATA[' + node.NodeValue + ']]>');
  end;
end;

procedure WriteEntityRef(node: TDOMNode);
begin
  wrtChr('&');
  wrtStr(node.NodeName);
  wrtChr(';');
end;

procedure WriteEntity(node: TDOMNode);
begin
  if node = Nil then
  ;
end;

procedure WritePI(node: TDOMNode);
begin
  if Not InsideTextNode then
    wrtIndent;
  wrtChr('<');
  wrtChr('!');
  wrtStr(TDOMProcessingInstruction(node).Target);
  wrtChr(' ');
  wrtStr(TDOMProcessingInstruction(node).Data);
  wrtChr('>');
  if Not InsideTextNode then
    wrtLineEnd;
end;

procedure WriteComment(node: TDOMNode);
begin
  if Not InsideTextNode then
    wrtIndent;
  wrtStr('<!--');
  wrtStr(node.NodeValue);
  wrtStr('-->');
  if Not InsideTextNode then
    wrtLineEnd;
end;

procedure WriteDocument(node: TDOMNode);
begin
  if node = Nil then
  ;
end;

procedure WriteDocumentType(node: TDOMNode);
begin
  if node = Nil then
  ;
end;

procedure WriteDocumentFragment(node: TDOMNode);
begin
  if node = Nil then
  ;
end;

procedure WriteNotation(node: TDOMNode);
begin
  if node = Nil then
  ;
end;

procedure InitWriter;
begin
  InsideTextNode := False;
  SetLength(Indent, 0);
end;

procedure RootWriter(doc: TXMLDocument);
var
  Child: TDOMNode;
begin
  InitWriter;
  wrtStr('<?xml version="');
  if Length(doc.XMLVersion) > 0 then
    ConvWrite(doc.XMLVersion, AttrSpecialChars, @AttrSpecialCharCallback)
  else
    wrtStr('1.0');
  wrtChr('"');
  if Length(doc.Encoding) > 0 then
  begin
    wrtStr(' encoding="');
    ConvWrite(doc.Encoding, AttrSpecialChars, @AttrSpecialCharCallback);
    wrtStr('"');
  end;
  wrtStrln('?>');

  if Length(doc.StylesheetType) > 0 then
  begin
    wrtStr('<?xml-stylesheet type="');
    ConvWrite(doc.StylesheetType, AttrSpecialChars, @AttrSpecialCharCallback);
    wrtStr('" href="');
    ConvWrite(doc.StylesheetHRef, AttrSpecialChars, @AttrSpecialCharCallback);
    wrtStrln('"?>');
  end;

  Indent      := '  ';
  IndentCount := 0;

  child := doc.FirstChild;
  while Assigned(Child) do
  begin
    WriteNode(Child);
    Child := Child.NextSibling;
  end;
end;

procedure WriteXMLMemStream(doc: TXMLDocument);
// internally used by the WriteXMLFile procedures
begin
  Stream := TMemoryStream.Create;
  WriteXMLFile(doc, Stream);
  Stream.Position := 0;
end;

procedure WriteXMLFile(doc: TXMLDocument; const AFileName: AnsiString);
var
  fs: TFileStream;
begin
  // write first to memory buffer and then as one whole block to file
  WriteXMLMemStream(doc);
  try
    fs := TFileStream.Create(AFileName, fmCreate);
    fs.CopyFrom(Stream, Stream.Size);
    fs.Free;
  finally
    Stream.Free;
  end;
end;

procedure WriteXMLFile(doc: TXMLDocument; var AFile: Text);
begin
  f     := @AFile;
  wrt   := @Text_Write;
  wrtln := @Text_WriteLn;
  RootWriter(doc);
end;

procedure WriteXMLFile(doc: TXMLDocument; AStream: TStream);
begin
  Stream := AStream;
  wrt    := @Stream_Write;
  wrtln  := @Stream_WriteLn;
  RootWriter(doc);
end;

procedure WriteXML(Element: TDOMNode; const AFileName: AnsiString);
begin
  Stream := TFileStream.Create(AFileName, fmCreate);
  wrt    := @Stream_Write;
  wrtln  := @Stream_WriteLn;
  InitWriter;
  WriteNode(Element);
  Stream.Free;
end;

procedure WriteXML(Element: TDOMNode; var AFile: Text);
begin
  f     := @AFile;
  wrt   := @Text_Write;
  wrtln := @Text_WriteLn;
  InitWriter;
  WriteNode(Element);
end;

procedure WriteXML(Element: TDOMNode; AStream: TStream);
begin
  stream := AStream;
  wrt    := @Stream_Write;
  wrtln  := @Stream_WriteLn;
  InitWriter;
  WriteNode(Element);
end;

{
********************************** TXMLConfig **********************************
}
constructor TXMLConfig.Create(const AFilename: AnsiString);
begin
  inherited Create;
  SetFilename(AFilename);
end;

constructor TXMLConfig.CreateClean(const AFilename: AnsiString);
begin
  inherited Create;
  fDoNotLoad := True;
  SetFilename(AFilename);
end;

destructor TXMLConfig.Destroy;
begin
  if Assigned(doc) then
  begin
    Flush;
    doc.Free;
  end;
  inherited Destroy;
end;

procedure TXMLConfig.Clear;
var
  cfg: TDOMElement;
begin
  // free old document
  doc.Free;
  // create new document
  doc := TXMLDocument.Create;
  cfg := TDOMElement(doc.FindNode('CONFIG'));
  if Not Assigned(cfg) then
  begin
    cfg := doc.CreateElement('CONFIG');
    doc.AppendChild(cfg);
  end;
end;

procedure TXMLConfig.DeletePath(const APath: AnsiString);
var
  Node: TDomNode;
begin
  Node := FindNode(APath, False);
  if (Node = Nil) Or (Node.ParentNode = Nil) then
    exit;
  Node.ParentNode.RemoveChild(Node);
  FModified := True;
end;

procedure TXMLConfig.DeleteValue(const APath: AnsiString);
var
  Node:     TDomNode;
  StartPos: Integer;
  NodeName: AnsiString;
begin
  Node := FindNode(APath, True);
  if (Node = Nil) then
    exit;
  StartPos := length(APath);
  while (StartPos > 0) And (APath[StartPos] <> '/') do
    dec(StartPos);
  NodeName := copy(APath, StartPos + 1, length(APath) - StartPos);
  if ( Not Assigned(TDOMElement(Node).GetAttributeNode(NodeName))) then
    exit;
  TDOMElement(Node).RemoveAttribute(NodeName);
  FModified := True;
end;

function TXMLConfig.ExtendedToStr(const e: Extended): AnsiString;
var
  OldDecimalSeparator:  Char;
  OldThousandSeparator: Char;
begin
  OldDecimalSeparator  := DecimalSeparator;
  OldThousandSeparator := ThousandSeparator;
  DecimalSeparator     := '.';
  ThousandSeparator    := ',';
  Result               := FloatToStr(e);
  DecimalSeparator     := OldDecimalSeparator;
  ThousandSeparator    := OldThousandSeparator;
end;

function TXMLConfig.FindNode(const APath: AnsiString; PathHasValue: Boolean): TDomNode;
var
  NodePath:         AnsiString;
  StartPos, EndPos: Integer;
  PathLen:          Integer;
begin
  Result   := doc.DocumentElement;
  PathLen  := length(APath);
  StartPos := 1;
  while (Result <> Nil) do
  begin
    EndPos := StartPos;
    while (EndPos <= PathLen) And (APath[EndPos] <> '/') do
      inc(EndPos);
    if (EndPos > PathLen) And PathHasValue then
      exit;
    if EndPos = StartPos then
      break;
    SetLength(NodePath, EndPos - StartPos);
    Move(APath[StartPos], NodePath[1], length(NodePath));
    Result   := Result.FindNode(NodePath);
    StartPos := EndPos + 1;
    if StartPos > PathLen then
      exit;
  end;
  Result := Nil;
end;

procedure TXMLConfig.Flush;
begin
  if Modified then
  begin
    WriteXMLFile(doc, Filename);
    FModified := False;
  end;
end;

function TXMLConfig.GetExtendedValue(const APath: AnsiString; const ADefault: Extended): Extended;
begin
  Result := StrToExtended(GetValue(APath, ExtendedToStr(ADefault)), ADefault);
end;

function TXMLConfig.GetValue(const APath: AnsiString; ADefault: Boolean): Boolean;
var
  s: AnsiString;
begin
  if ADefault then
    s := 'True'
  else
    s := 'False';

  s := GetValue(APath, s);

  if AnsiCompareText(s, 'TRUE') = 0 then
    Result := True
  else
  if AnsiCompareText(s, 'FALSE') = 0 then
    Result := False
  else
    Result := ADefault;
end;

function TXMLConfig.GetValue(const APath: AnsiString; ADefault: Integer): Integer;
begin
  Result := StrToIntDef(GetValue(APath, IntToStr(ADefault)), ADefault);
end;

function TXMLConfig.GetValue(const APath, ADefault: AnsiString): AnsiString;
var
  Node, Child, Attr: TDOMNode;
  NodeName:          AnsiString;
  PathLen:           Integer;
  StartPos, EndPos:  Integer;
begin
  //CheckHeapWrtMemCnt('TXMLConfig.GetValue A '+APath);
  Result   := ADefault;
  PathLen  := length(APath);
  Node     := doc.DocumentElement;
  StartPos := 1;
  while True do
  begin
    EndPos := StartPos;
    while (EndPos <= PathLen) And (APath[EndPos] <> '/') do
      inc(EndPos);
    if EndPos > PathLen then
      break;
    if EndPos > StartPos then
    begin
      NodeName := '';
      SetLength(NodeName, EndPos - StartPos);
      //UniqueString(NodeName);
      Move(APath[StartPos], NodeName[1], EndPos - StartPos);
      Child := Node.FindNode(NodeName);
      //writeln('TXMLConfig.GetValue C NodeName="',NodeName,'" ',
      //  PCardinal(Cardinal(NodeName)-8)^,' ',PCardinal(Cardinal(NodeName)-4)^);
      //CheckHeapWrtMemCnt('TXMLConfig.GetValue B2');
      if Not Assigned(Child) then
        exit;
      Node := Child;
    end;
    StartPos := EndPos + 1;
    //CheckHeapWrtMemCnt('TXMLConfig.GetValue D');
  end;
  if StartPos > PathLen then
    exit;
  //CheckHeapWrtMemCnt('TXMLConfig.GetValue E');
  NodeName := '';
  SetLength(NodeName, PathLen - StartPos + 1);
  //CheckHeapWrtMemCnt('TXMLConfig.GetValue F '+IntToStr(length(NodeName))+' '+IntToStr(StartPos)+' '+IntToStr(length(APath))+' '+APath[StartPos]);
  //UniqueString(NodeName);
  Move(APath[StartPos], NodeName[1], length(NodeName));
  //CheckHeapWrtMemCnt('TXMLConfig.GetValue G');
  //writeln('TXMLConfig.GetValue G2 NodeName="',NodeName,'"');
  Attr := Node.Attributes.GetNamedItem(NodeName);
  if Assigned(Attr) then
    Result := Attr.NodeValue;
  //CheckHeapWrtMemCnt('TXMLConfig.GetValue H');
  //writeln('TXMLConfig.GetValue END Result="',Result,'"');
end;

procedure TXMLConfig.SetDeleteExtendedValue(const APath: AnsiString; const AValue, DefValue: Extended);
begin
  if AValue = DefValue then
    DeleteValue(APath)
  else
    SetExtendedValue(APath, AValue);
end;

procedure TXMLConfig.SetDeleteValue(const APath: AnsiString; AValue, DefValue: Boolean);
begin
  if AValue = DefValue then
    DeleteValue(APath)
  else
    SetValue(APath, AValue);
end;

procedure TXMLConfig.SetDeleteValue(const APath: AnsiString; AValue, DefValue: Integer);
begin
  if AValue = DefValue then
    DeleteValue(APath)
  else
    SetValue(APath, AValue);
end;

procedure TXMLConfig.SetDeleteValue(const APath, AValue, DefValue: AnsiString);
begin
  if AValue = DefValue then
    DeleteValue(APath)
  else
    SetValue(APath, AValue);
end;

procedure TXMLConfig.SetExtendedValue(const APath: AnsiString; const AValue: Extended);
begin
  SetValue(APath, ExtendedToStr(AValue));
end;

procedure TXMLConfig.SetFilename(const AFilename: AnsiString);
var
  cfg: TDOMElement;
begin
  if FFilename = AFilename then
    exit;
  FFilename := AFilename;

  //  if csLoading in ComponentState then
  //    exit;

  if Assigned(doc) then
  begin
    Flush;
    doc.Free;
  end;

  doc := Nil;
  if FileExists(AFilename) And (Not fDoNotLoad) then
    ReadXMLFile(doc, AFilename);

  if Not Assigned(doc) then
    doc := TXMLDocument.Create;

  cfg := TDOMElement(doc.FindNode('CONFIG'));
  if Not Assigned(cfg) then
  begin
    cfg := doc.CreateElement('CONFIG');
    doc.AppendChild(cfg);
  end;
end;

procedure TXMLConfig.SetValue(const APath: AnsiString; AValue: Boolean);
begin
  if AValue then
    SetValue(APath, 'True')
  else
    SetValue(APath, 'False');
end;

procedure TXMLConfig.SetValue(const APath: AnsiString; AValue: Integer);
begin
  SetValue(APath, IntToStr(AValue));
end;

procedure TXMLConfig.SetValue(const APath, AValue: AnsiString);
var
  Node, Child:      TDOMNode;
  NodeName:         AnsiString;
  PathLen:          Integer;
  StartPos, EndPos: Integer;
begin
  Node     := Doc.DocumentElement;
  PathLen  := length(APath);
  StartPos := 1;
  while True do
  begin
    EndPos := StartPos;
    while (EndPos <= PathLen) And (APath[EndPos] <> '/') do
      inc(EndPos);
    if EndPos > PathLen then
      break;
    SetLength(NodeName, EndPos - StartPos);
    Move(APath[StartPos], NodeName[1], EndPos - StartPos);
    StartPos := EndPos + 1;
    Child    := Node.FindNode(NodeName);
    if Not Assigned(Child) then
    begin
      Child := Doc.CreateElement(NodeName);
      Node.AppendChild(Child);
    end;
    Node := Child;
  end;

  if StartPos > PathLen then
    exit;
  SetLength(NodeName, PathLen - StartPos + 1);
  Move(APath[StartPos], NodeName[1], length(NodeName));
  if ( Not Assigned(TDOMElement(Node).GetAttributeNode(NodeName))) Or
    (TDOMElement(Node)[NodeName] <> AValue) then
  begin
    TDOMElement(Node)[NodeName] := AValue;
    FModified                   := True;
  end;
end;

function TXMLConfig.StrToExtended(const s: AnsiString; const ADefault: Extended): Extended;
var
  OldDecimalSeparator:  Char;
  OldThousandSeparator: Char;
begin
  OldDecimalSeparator  := DecimalSeparator;
  OldThousandSeparator := ThousandSeparator;
  DecimalSeparator     := '.';
  ThousandSeparator    := ',';
  Result               := StrToFloatDef(s, ADefault);
  DecimalSeparator     := OldDecimalSeparator;
  ThousandSeparator    := OldThousandSeparator;
end;

procedure LoadStringList(XMLConfig: TXMLConfig; List: TStrings; const Path: AnsiString);
var
  i, Count: Integer;
  s:        AnsiString;
begin
  Count := XMLConfig.GetValue(Path + 'Count', 0);
  List.Clear;
  for i := 1 to Count do
  begin
    s := XMLConfig.GetValue(Path + 'Item' + IntToStr(i) + '/Value', '');
    if s <> '' then
      List.Add(s);
  end;
end;

procedure SaveStringList(XMLConfig: TXMLConfig; List: TStrings; const Path: AnsiString);
var
  i: Integer;
begin
  XMLConfig.SetDeleteValue(Path + 'Count', List.Count, 0);
  for i := 0 to List.Count - 1 do
    XMLConfig.SetDeleteValue(Path + 'Item' + IntToStr(i + 1) + '/Value', List[i], '');
end;

end.
