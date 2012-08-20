////////////////////////////////////////////////////////////////////////////////
//
// nitroServer
// The FASTest and most SCALABLE webserver written in Delphi
//
// Author: Dr. Masroor Ehsan Choudhury
// <nitroserver@gmail.com>
// http://nitrohttpd.blogspot.com/
//
// Copyright (C) 2007 Dr. Masroor Ehsan Choudhury
// All rights reserved.
//
// PERMISSION TO USE, COPY, MODIFY, AND DISTRIBUTE THIS SOFTWARE AND ITS
// DOCUMENTATION FOR NON-COMMERCIAL PURPOSE IS HEREBY GRANTED, PROVIDED
// THAT THE ABOVE COPYRIGHT NOTICE AND THIS PARAGRAPH AND THE FOLLOWING
// PARAGRAPHS APPEAR IN ALL COPIES.
//
// IN NO EVENT SHALL THE AUTHOR BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
// SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS,
// ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF
// THE AUTHOR HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// THE AUTHOR SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON AN "AS IS" BASIS,
// AND THE AUTHOR HAS NO OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT, UPDATES,
// ENHANCEMENTS, OR MODIFICATIONS.
//
// THE ORIGIN OF THIS SOFTWARE MUST NOT BE MISREPRESENTED, YOU MUST NOT CLAIM
// THAT YOU WROTE THE ORIGINAL SOFTWARE.
//
// IF YOU USE THIS SOFTWARE IN A PRODUCT, AN ACKNOWLEDGMENT IN THE PRODUCT
// DOCUMENTATION IS REQUIRED. IF YOUR PROGRAM HAS AN "ABOUT BOX" THE
// FOLLOWING CREDIT SHOULD BE DISPLAYED IN IT:
//   "nitroServer (C) Dr. Masroor Ehsan Choudhury <nitroserver@gmail.com>"
//
// ALTERED SOURCE VERSIONS MUST BE PLAINLY MARKED AS SUCH, AND MUST NOT BE
// MISREPRESENTED AS BEING THE ORIGINAL SOFTWARE.
//
// $Version:0.6.2$ $Revision:1.5$ $Author:masroore$ $RevDate:9/30/2007 21:38:14$
//
////////////////////////////////////////////////////////////////////////////////

unit VirtualDir;

interface

uses
  SysUtils, Classes, XMLConfig, FastLock;

type
  TVirtualDirs = class
  private
    FDocRoot: string;
    FVirtualDirs: TList;
  protected
    procedure SetDocRoot(const APath: string);
    function GetVirtualDirCount: Integer;
    function VirtualDirIndex(const ADir: string; CkSum: Cardinal; Len: Integer): Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure RegisterVirtualDir(const AVDir, ARealDir: string;
                                 const ACache, ADirList, AExecScript, AAuth: Boolean);
    function  ResolveRealPath(const AURL : String;
                              var Cache, DirList, ExecScript, Auth: Boolean) : String;
    procedure ClearVirtualDirs;
    procedure SaveConfig(XML: TXMLConfig; const RootKey: string);
    procedure LoadConfig(XML: TXMLConfig; const RootKey: string);

    property DocRoot: string read FDocRoot write SetDocRoot;
    property Count: Integer read GetVirtualDirCount;
  end;


implementation

{$I NITROHTTPD.INC}

uses
{$IFDEF XBUG}
  uDebug,
{$ENDIF}
  Common, 
  HashTable;

type
  PVirtualDir = ^TVirtualDir;
  TVirtualDir = record
    VPath,
    RealDir: string;
    ChkSum: Cardinal;
    VPathLen: Integer;
    AllowDirListing: Boolean;
    AllowCaching: Boolean;
    ExecScript: Boolean;
    AuthEnabled: Boolean;
  end;

{ TVirtualDirs }

procedure TVirtualDirs.ClearVirtualDirs;
var
  I: Integer;
  P: PVirtualDir;
begin
  I := Pred(FVirtualDirs.Count);
  while (I >= 0) do
  begin
    P := PVirtualDir(FVirtualDirs[I]);
    with P^ do
    begin
      SetLength(VPath, 0);
      SetLength(RealDir, 0);
    end;
    FreeMem(P);
    Dec(I);
  end;
  FVirtualDirs.Clear;
end;

constructor TVirtualDirs.Create;
begin
  inherited;
  
  FVirtualDirs :=  TList.Create;
end;

destructor TVirtualDirs.Destroy;
begin
  ClearVirtualDirs;

  FreeAndNil(FVirtualDirs);

  inherited;
end;

function TVirtualDirs.GetVirtualDirCount: Integer;
begin
  Result := FVirtualDirs.Count;
end;

procedure TVirtualDirs.RegisterVirtualDir(const AVDir, ARealDir: string;
  const ACache, ADirList, AExecScript, AAuth: Boolean);
var
  P: PVirtualDir;
begin
  P := AllocMem(sizeof(TVirtualDir));
  with P^ do
  begin
    VPath           := UpperCase(AVDir);
    RealDir         := PathAddSlash(ARealDir);
    AllowDirListing := ADirList;
    AllowCaching    := ACache;
    ExecScript      := AExecScript;
    AuthEnabled     := AAuth;
    VPathLen        := Length(AVDir);
    ChkSum          := SuperFastHash(PAnsiChar(VPath), VPathLen);
  end;

  FVirtualDirs.Add(P);
end;

function TVirtualDirs.ResolveRealPath(const AURL: String; var Cache, DirList,
  ExecScript, Auth: Boolean): String;
var
  VDir: string;
  I, Idx, Adjust, VDirLen: Integer;
  CkSum: Cardinal;
begin
  Result := '';
  if (AURL = '') then
  begin
    Result := FDocRoot;
    Exit;
  end;

  if (AURL[1] = '\') then
  begin
    VDir := Copy(AURL, 2, Length(AURL));
    Adjust := 2;
  end
  else
  begin
    VDir := AURL;
    Adjust := 1;
  end;

  I := FastCharPos(VDir, '\');
  if (I > 0) then
    Delete(VDir, I, Length(VDir) - I + 1);

  VDirLen := Length(VDir);
  CkSum   := SuperFastHash(PAnsiChar(UpperCase(VDir)), VDirLen);

  Idx := VirtualDirIndex(VDir, CkSum, VDirLen);
  if (Idx <> -1) then
  begin
    if (I > 0) then
      Result    := PVirtualDir(FVirtualDirs[Idx]).RealDir + Copy(AURL, I + Adjust, Length(AURL))
    else
      Result    := PVirtualDir(FVirtualDirs[Idx]).RealDir;

    DirList     := PVirtualDir(FVirtualDirs[Idx]).AllowDirListing;
    ExecScript  := PVirtualDir(FVirtualDirs[Idx]).ExecScript;
    Auth        := PVirtualDir(FVirtualDirs[Idx]).AuthEnabled;
    Cache       := PVirtualDir(FVirtualDirs[Idx]).AllowCaching;
  end
  else
  begin
    Result      := FDocRoot + Copy(AURL, Adjust, Length(AURL));
    DirList     := True;
    ExecScript  := True;
    Auth        := False;
    Cache       := True;
  end;
end;

procedure TVirtualDirs.SetDocRoot(const APath: string);
begin
  FDocRoot := PathAddSlash(APath);
end;

function TVirtualDirs.VirtualDirIndex(const ADir: string; CkSum: Cardinal;
  Len: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;

  for I := Pred(FVirtualDirs.Count) downto 0 do
  begin
    if (PVirtualDir(FVirtualDirs[I]).ChkSum = CkSum) and
       (PVirtualDir(FVirtualDirs[I]).VPathLen = Len) then
    begin
      Result := I;
      Break;
    end;
  end;
end;

procedure TVirtualDirs.LoadConfig(XML: TXMLConfig; const RootKey: string);
var
  I, J: Integer;
  Key, VDir, RDir: string;
  Cache, DirList, Script, NonParse, Auth: Boolean;
begin
  J := XML.GetValue(RootKey + 'VirtualDirs/Count', 0);
  if (J > 0) then
  begin
    for I := 0 to (J - 1) do
    begin
      Key   :=  RootKey + 'VirtualDirs/Entry_' + IntToStr(I) + '/';
      VDir  :=  XML.GetValue(Key + 'VirtualPath', '');
      RDir  :=  XML.GetValue(Key + 'RealPath', '');
      Script:=  XML.GetValue(Key + 'ExecuteScript', False);
      DirList:= XML.GetValue(Key + 'DirListing', False);
      Auth  := XML.GetValue(Key + 'Authenticate', False);
      Cache := XML.GetValue(Key + 'AllowCaching', False);
      if (VDir <> '') and (RDir <> '') then
        RegisterVirtualDir(VDir, RDir, Cache, DirList, Script, Auth);
    end;
  end;
end;

procedure TVirtualDirs.SaveConfig(XML: TXMLConfig; const RootKey: string);
var
  I, J: Integer;
  Key: string;
  P: PVirtualDir;
begin
  J := FVirtualDirs.Count;
  XML.SetValue('VirtualDirs/Count', J);
  for I := 0 to J - 1 do
  begin
    Key := RootKey + 'VirtualDirs/Entry_' + IntToStr(I) + '/';
    P   := PVirtualDir(FVirtualDirs[I]);

    with P^ do
    begin
      XML.SetValue(Key + 'VirtualPath', VPath);
      XML.SetValue(Key + 'RealPath', RealDir);
      XML.SetValue(Key + 'ExecuteScript', ExecScript);
      XML.SetValue(Key + 'DirListing', AllowDirListing);
      XML.SetValue(Key + 'Authenticate', AuthEnabled);
    end;
  end;
end;

end.
