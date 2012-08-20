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
// $Version:0.6.2$ $Revision:1.1$ $Author:masroore$ $RevDate:9/30/2007 21:38:08$
//
////////////////////////////////////////////////////////////////////////////////

unit FileInfoCache;

{$I NITROHTTPD.INC}

interface

uses
  Windows, Classes, SysUtils, Buffer, HashTable, VHosts;

type
  PFileStat = ^TFileStat;
  TFileStat = record
    DateTime:  TDateTime;
    FileSize:  Cardinal;
    Attribute: Integer;
    MIMEType:  Integer;
    Chksum:    Cardinal;
    NameLen:   Cardinal;
    AddedOn: Cardinal;
  end;

  TFileStatCache = class
  private
    FHashTable: THashTable;

    function AddNewItem(const FName: AnsiString; const CkSum, Len: Cardinal): PFileStat;
    function GetCount: Integer;
  public
    constructor Create;
    destructor Destroy; OVERRIDE;
    procedure Purge(Expires: DWORD);

    function GetFileStat(FName: String): PFileStat;

    property Count: Integer read GetCount;
  end;

  PURLInfo = ^TURLInfo;
  TURLInfo = record
    FileName:     AnsiString;
    VHost:        AnsiString;
    Chksum:       Cardinal;
    URLLen:       Cardinal;
    IsDir:        Boolean;
    FileStat:     PFileStat;
    AllowDirListing: Boolean;
    ExecScript:   Boolean;
    AuthEnabled:  Boolean;
    AllowCaching:     Boolean;
    AddedOn:      Cardinal;
    Prev, Next:   PURLInfo;
  end;

  TURLToFileMapper = class
  private
    FHashTable: array [0..DEFAULT_HASHTABLE_SIZE] of PURLInfo;

    function AddNewItem(const AURL: AnsiString; AVHost: TVirtualHost;
                        const CkSum: Cardinal;
                        const Len, Bucket: Integer
                        ): PURLInfo;
    function FindItem(const AURL: AnsiString; AVHost: TVirtualHost;
                      const CkSum: Cardinal;
                      const Bucket: Integer): PURLInfo;
    function RemoveItem(P: PURLInfo; Bucket: Integer): PURLInfo;
    procedure RemoveAllItems;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Purge(Expires: DWORD);

    function GetCount: Integer;

    function ResolveURL(AURL: AnsiString;
                        AVHost: TVirtualHost;
                        var FileName: AnsiString;
                        var AllowCaching, IsDir, ExecScript, AllowDirList, Auth: Boolean;
                        var Stat: PFileStat): Boolean;
    function ResolveURLEx(AURL: AnsiString;
                          AVHost: TVirtualHost;
                          const AHash: Cardinal;
                          const Len, Bucket: Integer;
                          var FileName: AnsiString;
                          var AllowCaching, IsDir, ExecScript, AllowDirList, Auth: Boolean;
                          var Stat: PFileStat): Boolean;
  end;

{
function GetFileInfo(var FName: AnsiString;
                     var FTime: TDateTime;
                     var FSize: Cardinal;
                     var FIsDir: Boolean;
                     var MIMEType: Integer): Boolean;
}
function GetFileStat(var FName: AnsiString;
                     var FIsDir: Boolean;
                     var Stat: PFileStat): Boolean;
function MapURLToFile(AURL: AnsiString;
                      AVHost: TVirtualHost;
                      var FileName: AnsiString;
                      var AllowCaching, IsDir, ExecScript, AllowDirList, Auth: Boolean;
                      var DateTime:  TDateTime;
                      var FileSize:  Cardinal;
                      var Attribute, MIMEType:  Integer): Boolean;
procedure FileInfoCachePurge(TimeOutSecs: Cardinal);

{$IFDEF ENABLE_STATS}
procedure InfoCacheStats(var Stats, URLs: Integer);
{$ENDIF}


implementation

uses
  Common, MimeType, VirtualDir, LockPool;

var
  g_StatLock,
  g_DataLock,
  g_MapLock:    TLockPool;
  g_StatCache:  TFileStatCache;
  g_URLResolver: TURLToFileMapper;

const
  INVALID_FILE_ATTRIBUTES = -1;
{$IFDEF PHP_DEFAULT_DOC}
  MAX_DEFAULT_DOCUMENTS   = 6;
{$ELSE}
  MAX_DEFAULT_DOCUMENTS   = 5;
{$ENDIF}

const
  DEFAULT_DOCUMENTS: array [1..MAX_DEFAULT_DOCUMENTS] of string =
    (
      'index.html',
      'index.htm',
      'default.html',
      'default.htm',
{$IFDEF PHP_DEFAULT_DOC}
      'index.php',
{$ENDIF}
      'index.shtml'
    );

function GetFileStat(var FName: AnsiString;
                     var FIsDir: Boolean;
                     var Stat: PFileStat): Boolean;
var
  I, Code:  Integer;
  FPath, DirPath: AnsiString;
  bFileFound, bDirFound: Boolean;
begin
  Result := False;
  FPath  := FName;
  Code   := GetFileAttributesA(PAnsiChar(FPath));

  bDirFound   := (Code <> INVALID_FILE_ATTRIBUTES) and ((Code and FILE_ATTRIBUTE_DIRECTORY) <> 0);
  bFileFound  := (Code <> INVALID_FILE_ATTRIBUTES) and ((Code and FILE_ATTRIBUTE_DIRECTORY) = 0);

  if bDirFound then
  begin
    DirPath := FPath;
    for I := 1 to MAX_DEFAULT_DOCUMENTS do
    begin
      FPath := PathAddSlash(DirPath) + DEFAULT_DOCUMENTS[I];
      Code   := GetFileAttributesA(PAnsiChar(FPath));
      if (Code <> INVALID_FILE_ATTRIBUTES) then
      begin
        bFileFound  := True;
        Break;
      end;
    end;
  end;

  if bFileFound or bDirFound then
  begin
    Result := True;
    if bFileFound then
    begin
      FIsDir  := False;
      FName := FPath;
    end
    else
    begin
      FIsDir  := True;
      FName   := DirPath;
    end;

    if not FIsDir then
      Stat   := g_StatCache.GetFileStat(FPath);
  end;
end;

(*
function GetFileInfo(var FName: AnsiString; var FTime: TDateTime;
  var FSize: Cardinal; var FIsDir: Boolean; var MIMEType: Integer): Boolean;
var
  P:     PFileStat;
  I, Code:  Integer;
  FPath: AnsiString;
begin
  FPath  := FName;
  Code   := GetFileAttributes(PAnsiChar(FPath));
  if (Code = INVALID_FILE_ATTRIBUTES) then
  begin
    for I := Low(DEFAULT_DOCUMENTS) to High(DEFAULT_DOCUMENTS) do
    begin
      FPath := PathAddSlash(FPath) + DEFAULT_DOCUMENTS[I];
      Code   := GetFileAttributes(PAnsiChar(FPath));
      if (Code <> INVALID_FILE_ATTRIBUTES) then
        Break;
    end;
    {
    FPath  := PathAddSlash(FPath) + 'index.html';
    Code   := GetFileAttributes(PAnsiChar(FPath));
    if (Code = INVALID_FILE_ATTRIBUTES) then
    begin
      FPath  := PathAddSlash(FPath) + 'index.htm';
      Code   := GetFileAttributes(PAnsiChar(FPath));
      if (Code = INVALID_FILE_ATTRIBUTES) then
      begin
        FPath  := PathAddSlash(FPath) + 'default.htm';
        Code   := GetFileAttributes(PAnsiChar(FPath));
      end;
    end;
    }
  end;

  Result  := (Code <> INVALID_FILE_ATTRIBUTES);

  if Result then
  begin
    FIsDir  := (Code and FILE_ATTRIBUTE_DIRECTORY) <> 0;
    FName := FPath;

    if not FIsDir then
    begin
      g_StatLock.Enter;
      try
        P      := g_StatCache.GetFileStat(FPath);
        Result := (P <> nil);
        if Result then
        begin
          FTime := P^.DateTime;
          FSize := P^.FileSize;
          MIMEType := P^.MIMEType;
        end;
      finally
        g_StatLock.Leave;
      end;
    end;
  end;
end;

function GetFileStat(var FName: AnsiString;
                     var FIsDir: Boolean;
                     var Stat: PFileStat): Boolean;
var
  I, Code:  Integer;
  FPath: AnsiString;
begin
  FPath  := FName;
  Code   := GetFileAttributes(PAnsiChar(FPath));
  if (Code = INVALID_FILE_ATTRIBUTES) then
  begin
    for I := Low(DEFAULT_DOCUMENTS) to High(DEFAULT_DOCUMENTS) do
    begin
      FPath := PathAddSlash(FPath) + DEFAULT_DOCUMENTS[I];
      Code   := GetFileAttributes(PAnsiChar(FPath));
      if (Code <> INVALID_FILE_ATTRIBUTES) then
        Break;
    end;
  end;

  Result  := (Code <> INVALID_FILE_ATTRIBUTES);

  if Result then
  begin
    FIsDir  := (Code and FILE_ATTRIBUTE_DIRECTORY) <> 0;
    FName := FPath;

    if not FIsDir then
    begin
      //g_Lock.Enter;
      try
        Stat   := g_StatCache.GetFileStat(FPath);
        //Result := Assigned(Stat);
      finally
        //g_Lock.Leave;
      end;
    end;
  end;
end;
*)

function MapURLToFile(AURL: AnsiString;
                      AVHost: TVirtualHost;
                      var FileName: AnsiString;
                      var AllowCaching, IsDir, ExecScript, AllowDirList, Auth: Boolean;
                      var DateTime:  TDateTime;
                      var FileSize:  Cardinal;
                      var Attribute, MIMEType:  Integer): Boolean;
var
  P: PFileStat;
  Hash: Cardinal;
  Len, Bucket: Integer;
begin
  AURL  := LowerCase(AURL);
  Len   := Length(AURL);
  Hash  := SuperFastHash(PAnsiChar(AURL), Len);
  Bucket:= Hash mod DEFAULT_HASHTABLE_SIZE;

  g_MapLock.Enter(Bucket);
  try
    Result := g_URLResolver.ResolveURLEx(AURL, AVHost, Hash, Len, Bucket,
                                         FileName, AllowCaching, IsDir, ExecScript,
                                         AllowDirList, Auth, P);
  finally
    g_MapLock.Leave(Bucket);
  end;

  if Result and
     (not IsDir) and
     Assigned(P) then
  begin
    DateTime  := P^.DateTime;
    FileSize  := P^.FileSize;
    Attribute := P^.Attribute;
    MIMEType  := P^.MIMEType;
  end;
end;

procedure FileInfoCachePurge(TimeOutSecs: Cardinal);
var
  CacheMinTime: DWORD;
begin
  CacheMinTime := GetTickCount - (TimeOutSecs * 1000);

  g_StatLock.EnterAll;
  try
    g_StatCache.Purge(CacheMinTime);
  finally
    g_StatLock.LeaveAll;
  end;

  g_MapLock.EnterAll;
  try
    g_URLResolver.Purge(CacheMinTime);
  finally
    g_MapLock.LeaveAll;
  end;
end;

{ TFileStatCache }

function TFileStatCache.AddNewItem(const FName: AnsiString;
  const CkSum, Len: Cardinal): PFileStat;
var
  P:  PFileStat;
  SR: TSearchRec;
begin
  Result := nil;

  if (FindFirst(FName, faAnyFile, SR) = 0) and ((SR.Attr and faDirectory) = 0) then
  begin
    New(P);
    with P^ do
    begin
      DateTime  := FileDateToDateTime(SR.Time);
      FileSize  := SR.FindData.nFileSizeLow;
      Attribute := SR.Attr;
      Chksum    := CkSum;
      NameLen   := Len;
      MIMEType  := GetMIMEIndex(FName);
      AddedOn  := GetTickCount;
    end;

    HashInsert(FHashTable, FName, CkSum, P);
    Result := P;
  end;
  FindClose(SR);
end;

constructor TFileStatCache.Create;
begin
  inherited;

  SetLength(FHashTable, DEFAULT_HASHTABLE_SIZE);
end;

destructor TFileStatCache.Destroy;
begin
  HashClear(FHashTable, DEFAULT_HASHTABLE_SIZE, nil);
  SetLength(FHashTable, 0);

  inherited;
end;

function TFileStatCache.GetCount: Integer;
begin
  Result := HashGetItemsCount(FHashTable, DEFAULT_HASHTABLE_SIZE);
end;

function TFileStatCache.GetFileStat(FName: String): PFileStat;
var
  CkSum, Len: Cardinal;
  H: PHashNode;
begin
  Result := nil;
  FName  := LowerCase(FName);
  Len    := Length(FName);
  CkSum  := SuperFastHash(PAnsiChar(FName), Len) mod DEFAULT_HASHTABLE_SIZE;

  H := HashFind(FHashTable, FName, CkSum);

  if (H = nil) then
    Result := AddNewItem(FName, CkSum, Len)
  else
    Result := PFileStat(H^.Data);
end;

function StatsPurgeCallback(Item: Pointer; Param: LongInt): Boolean;
var
  P: PFileStat;
begin
  P := PFileStat(Item);
  Result := P^.AddedOn < Cardinal(Param);
  if Result then
  begin
    Dispose(P);
    P := nil;
  end;  
end;  

procedure TFileStatCache.Purge(Expires: DWORD);
begin
  HashPurge(FHashTable, DEFAULT_HASHTABLE_SIZE, Expires, StatsPurgeCallback);
end;

{ TURLToFileMapper }

function TURLToFileMapper.AddNewItem(const AURL: AnsiString;
  AVHost: TVirtualHost;
  const CkSum: Cardinal;
  const Len, Bucket: Integer): PURLInfo;
var
  FPath: AnsiString;
  bIsDir,
  bCache,
  bDirList,
  bScript,
  bAuth: Boolean;
  P: PFileStat;
begin
  Result := nil;
  FPath := AVHost.ResolveRealPath(AURL, bCache, bDirList, bScript, bAuth);
  if (FPath <> '') then
  begin
    if GetFileStat(FPath, bIsDir, P) then
    begin
      New(Result);

      with Result^ do
      begin
        FileName        := FPath;
        VHost           := AVHost.HostName;
        IsDir           := bIsDir;
        AllowDirListing := bDirList;
        ExecScript      := bScript;
        AuthEnabled     := bAuth;
        FileStat        := P;
        AddedOn         := GetTickCount;
        Chksum          := CkSum;
        Prev            := nil;
        Next            := FHashTable[Bucket];
      end;

      if FHashTable[Bucket] <> nil then
        FHashTable[Bucket]^.Prev := Result;
      FHashTable[Bucket] := Result;
    end;
  end;
end;

function TURLToFileMapper.FindItem(const AURL: AnsiString; AVHost: TVirtualHost;
                                   const CkSum: Cardinal;
                                   const Bucket: Integer): PURLInfo;
var
  Obj: PURLInfo;
begin
  Result  := nil;
  Obj     := FHashTable[Bucket];

  while (Obj <> nil) do
  begin
    //if CompareStr(Obj^.FName, FName) = 0 then
    if (Obj^.Chksum = CkSum) and (AnsiCompareStr(Obj^.VHost, AVHost.HostName) = 0) then
    begin
      Result := Obj;
      Break;
    end;

    Obj := Obj^.Next;
  end;
end;

function TURLToFileMapper.GetCount: Integer;
var
  Obj: PURLInfo;
  Bucket: Integer;
begin
  Result  := 0;
  for Bucket := 0 to DEFAULT_HASHTABLE_SIZE - 1 do
  begin
    Obj     := FHashTable[Bucket];

    while (Obj <> nil) do
    begin
      Inc(Result);
      Obj := Obj^.Next;
    end;
  end;
end;

constructor TURLToFileMapper.Create;
var
  I: Integer;
begin
  inherited;

  for I := 0 to DEFAULT_HASHTABLE_SIZE do
    FHashTable[I] := nil;
end;

destructor TURLToFileMapper.Destroy;
begin
  RemoveAllItems;

  inherited;
end;

procedure TURLToFileMapper.Purge(Expires: DWORD);
var
  P: PURLInfo;
  Index: Integer;
begin
  for Index := 0 to DEFAULT_HASHTABLE_SIZE do
  begin
    P := FHashTable[Index];
    while (P <> nil) do
    begin
      if (P^.AddedOn < Expires) then
        P := RemoveItem(P, Index)
      else
        P := P^.Next;
    end;
  end;
end;

procedure TURLToFileMapper.RemoveAllItems;
var
  P, List: PURLInfo;
  I: Integer;
begin
  for I := 0 to DEFAULT_HASHTABLE_SIZE do
  begin
    List := FHashTable[I];
    FHashTable[I] := nil;

    while (List <> nil) do
    begin
      P := List;
      List := List^.Next;

      SetLength(P^.FileName, 0);
      SetLength(P^.VHost, 0);
      Dispose(P);
    end;
  end;
end;

function TURLToFileMapper.ResolveURL(AURL: AnsiString;
                                     AVHost: TVirtualHost;
                                     var FileName: AnsiString;
                                     var AllowCaching, IsDir, ExecScript, AllowDirList, Auth: Boolean;
                                     var Stat: PFileStat): Boolean;
var
  CkSum, Len: Cardinal;
  P: PURLInfo;
  Bucket: Integer;
begin
  Result :=   False;
  AURL   :=   LowerCase(AURL);
  Len    :=   Length(AURL);
  CkSum  :=   SuperFastHash(PAnsiChar(AURL), Len);
  Bucket :=   CkSum mod DEFAULT_HASHTABLE_SIZE;
  P      :=   FindItem(AURL, AVHost, CkSum, Bucket);
  if (P = nil) then
    P := AddNewItem(AURL, AVHost, CkSum, Len, Bucket);

  if Assigned(P) then
  begin
    Result    := True;
    FileName  := P^.FileName;
    IsDir     := P^.IsDir;
    ExecScript := P^.ExecScript;
    AllowDirList := P^.AllowDirListing;
    AllowCaching      := P^.AllowCaching;
    Auth      := P^.AuthEnabled;
    Stat      := P^.FileStat;
  end;
end;

function TURLToFileMapper.ResolveURLEx(AURL: AnsiString;
                                       AVHost: TVirtualHost;
                                       const AHash: Cardinal;
                                       const Len, Bucket: Integer;
                                       var FileName: AnsiString;
                                       var AllowCaching, IsDir, ExecScript, AllowDirList, Auth: Boolean;
                                       var Stat: PFileStat): Boolean;
var
  P: PURLInfo;
begin
  Result :=   False;

  P      :=   FindItem(AURL, AVHost, AHash, Bucket);
  if (P = nil) then
    P := AddNewItem(AURL, AVHost, AHash, Len, Bucket);

  if Assigned(P) then
  begin
    Result    := True;
    FileName  := P^.FileName;
    IsDir     := P^.IsDir;
    ExecScript := P^.ExecScript;
    AllowDirList := P^.AllowDirListing;
    AllowCaching      := P^.AllowCaching;
    Auth      := P^.AuthEnabled;
    Stat      := P^.FileStat;
  end;
end;

function TURLToFileMapper.RemoveItem(P: PURLInfo;
  Bucket: Integer): PURLInfo;
begin
  if (P^.Prev <> nil) then
    P^.Prev^.Next := P^.Next;

  Result := P^.Next;

  if (P^.Next <> nil) then
    P^.Next^.Prev := P^.Prev;

  if FHashTable[Bucket] = P then
    FHashTable[Bucket] := P^.Next;

  SetLength(P^.FileName, 0);
  SetLength(P^.VHost, 0);
  Dispose(P);
end;

{$IFDEF ENABLE_STATS}
procedure InfoCacheStats(var Stats, URLs: Integer);
begin
  g_StatLock.EnterAll;
  Stats := g_StatCache.GetCount;
  g_StatLock.LeaveAll;

  g_MapLock.EnterAll;
  URLs  := g_URLResolver.GetCount;
  g_MapLock.LeaveAll;
end;
{$ENDIF}


initialization
  g_StatLock := TLockPool.Create(10, 51, 128, False);
  g_MapLock :=  TLockPool.Create(10, 51, 128, False);

  g_StatCache   := TFileStatCache.Create;
  g_URLResolver := TURLToFileMapper.Create;

finalization
  FreeAndNil(g_StatLock);
  FreeAndNil(g_MapLock);

  FreeAndNil(g_URLResolver);
  FreeAndNil(g_StatCache);
end.
