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
// $Version:0.6.2$ $Revision:1.3$ $Author:masroore$ $RevDate:9/30/2007 21:38:08$
//
////////////////////////////////////////////////////////////////////////////////

unit FileDataCache;

interface

{$I NITROHTTPD.INC}

uses
  Windows, WinSock, SysUtils, Common;

type
  PFileDataCache = ^TFileDataCache;
  TFileDataCache = record
    FName:        String;
    Data:         PAnsiChar;
    FileSize:     Cardinal;
    LastChanged:  TFileTime;
    RefCnt:       Integer;
    Timer:        Integer;
    BucketIndex:  Integer;
    LastIP:       in_addr;
    Prev, Next:   PFileDataCache;
  end;

procedure DataCacheInit;
procedure DataCacheShutdown;
function DataCacheRemoveFile(P: PFileDataCache; Bucket: Integer): PFileDataCache;
function DataCacheAddFile(Ctx: PClientContext; FName: string; Bucket: Integer): PFileDataCache;
function DataCacheFindFile(Ctx: PClientContext; FName: string; Bucket: Integer): PFileDataCache;
procedure DataCacheDoneWith(P: PFileDataCache; Remove: Boolean);
procedure DataCachePurge(TimeOutSecs: Cardinal);
procedure DataCacheClear(ForcedRemove: Boolean);

function DataCacheDumpInfo: string;
{$IFDEF ENABLE_STATS}
procedure DataCacheStats(var Size, Counts: Integer);
{$ENDIF}

function GetFileBufFromCache(Ctx: PClientContext; FName: String;
                             const Offset: Integer; out Count: Integer;
                             out Data: Pointer): PFileDataCache;

implementation

uses
  LockPool, Config, HashTable{$IFDEF BORLAND}{, JCLAnsiStrings}{$ENDIF};

const
  TIME_IN_CACHE         =  60;
  MAX_CACHE_TIMER       = 300;
  MAX_CACHE_DELAY_TIMER = WATCHDOG_INTERVAL;
  MAX_CACHE_ITEMS       = DEFAULT_HASHTABLE_SIZE;

var
  g_Cache:      array [0..Pred(MAX_CACHE_ITEMS)] of PFileDataCache;
  g_LockPool:   TLockPool;
  g_CacheSize:  Cardinal;

procedure DataCacheInit;
var
  I: Integer;
begin
  g_LockPool := TLockPool.Create(Pred(MAX_CACHE_ITEMS), MAX_CACHE_ITEMS div 20, 0, False);

  for I := 0 to Pred(MAX_CACHE_ITEMS) do
    g_Cache[I] := nil;
end;

function DataCacheRemoveFile(P: PFileDataCache; Bucket: Integer): PFileDataCache;
begin
  Result := P^.Next;

  if (P^.Prev <> nil) then
    P^.Prev^.Next := P^.Next;

  if (P^.Next <> nil) then
    P^.Next^.Prev := P^.Prev;

  Dec(g_CacheSize, P^.FileSize);

  if g_Cache[Bucket] = P then
    g_Cache[Bucket] := P^.Next;

  SetLength(P^.FName, 0);
  FreeMem(P^.Data, P^.FileSize);
  Dispose(P);
end;

function DataCacheAddFile(Ctx: PClientContext; FName: string; Bucket: Integer): PFileDataCache;
var
  P: PFileDataCache;
  FileInfo: TByHandleFileInformation;
  hFile: THandle;
  Sz, Rd: DWORD;
begin
  Result := nil;
  hFile := CreateFileA(PAnsiChar(FName),
                      GENERIC_READ,
                      0,
                      nil,
                      OPEN_EXISTING,
                      FILE_ATTRIBUTE_NORMAL,
                      0);

  if (hFile <> INVALID_HANDLE_VALUE) then
  begin
    if GetFileInformationByHandle(hFile, FileInfo) then
    begin
      Sz := FileInfo.nFileSizeLow; //GetFileSize(hFile, nil);
      if (Sz > 0) and ((g_CacheSize + Sz) <= CfgGetDataCacheMaxCapacity) then
      begin
        New(P);
        //FName  := LowerCase(FName);
        P^.FName := FName;
        with P^ do
        begin
          GetMem(Data, Sz);
          FileSize := Sz;

          Rd := 0;
          Sz := 0;
          SetFilePointer(hFile, 0, nil, FILE_BEGIN);

          repeat
            if not ReadFile(hFile, PAnsiChar(Integer(Data) + Sz)^, READ_BUFFER_SIZE, Rd, nil) then
              Break;

            Inc(Sz, Rd);
          until (Rd < READ_BUFFER_SIZE);

          LastChanged := FileInfo.ftLastWriteTime;
          Timer       := TIME_IN_CACHE;
          LastIP      := Ctx^.saPeer.sin_addr;
        end;

        P^.RefCnt := 1;
        P^.BucketIndex  := Bucket;
        P^.Prev := nil;
        P^.Next := g_Cache[Bucket];
        if g_Cache[Bucket] <> nil then
          g_Cache[Bucket]^.Prev := P;
        g_Cache[Bucket] := P;
        Inc(g_CacheSize, P^.FileSize);

        Result := P;
      end;
    end;
  end;

  CloseHandle(hFile);
end;

{$IFDEF DATACACHE_VERIFY_FILE_FRESHNESS}
function GetFileInfo(const FileName: string; out FileSize: Cardinal; out LastWrite: TFileTime): Boolean;
var
  hFind: THandle;
  FindData: TWin32FindData;
begin
  Result  := False;
  hFind   := FindFirstFile(PAnsiChar(FileName), FindData);
  if (hFind <> INVALID_HANDLE_VALUE) then
  begin
    while (FindData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 do
      if not FindNextFile(hFind, FindData) then
      begin
        Windows.FindClose(hFind);
        Exit;
      end;

    FileSize  := FindData.nFileSizeLow;
    LastWrite := FindData.ftLastWriteTime;
    Result    := True;
    Windows.FindClose(hFind);
  end;
end;
{$ENDIF}

function DataCacheFindFile(Ctx: PClientContext; FName: string; Bucket: Integer): PFileDataCache;
var
{$IFDEF DATACACHE_VERIFY_FILE_FRESHNESS}
  FTime: TFileTime;
  FSize: Cardinal;
{$ENDIF}
  Obj: PFileDataCache;
begin
  Result := nil;
{$IFDEF DATACACHE_VERIFY_FILE_FRESHNESS}
  if not GetFileInfo(FName, FSize, FTime) then
    Exit;
{$ENDIF}
  Obj := g_Cache[Bucket];

  while (Obj <> nil) do
  begin
    if CompareStr(Obj^.FName, FName) = 0 then
    begin
      if (Obj^.Timer > 0)
{$IFDEF DATACACHE_VERIFY_FILE_FRESHNESS}
      and (Obj^.FileSize = FSize)
      and ((Obj^.LastChanged.dwLowDateTime = FTime.dwLowDateTime) and (Obj^.LastChanged.dwHighDateTime = FTime.dwHighDateTime))
{$ENDIF}
      then
      begin
        if (Obj^.LastIP.S_addr <> Ctx^.saPeer.sin_addr.S_addr) then
        begin
          Inc(Obj^.Timer, TIME_IN_CACHE);
          if (Obj^.Timer > MAX_CACHE_TIMER) then
            Obj^.Timer := MAX_CACHE_TIMER;

          Obj^.LastIP.S_addr := Ctx^.saPeer.sin_addr.S_addr;
        end;

        Inc(Obj^.RefCnt);
        Result := Obj;
      end
      else
      begin
        if (Obj^.RefCnt > 0) then
          Obj^.Timer := 0
        else
          DataCacheRemoveFile(Obj, Bucket);
      end;

      Break;
    end;

    Obj := Obj^.Next;
  end;
end;

procedure DataCacheDoneWith(P: PFileDataCache; Remove: Boolean);
begin
  Assert(P <> nil);

  g_LockPool.Enter(P^.BucketIndex);
  if Remove then
    P^.Timer := 0;
  Dec(P^.RefCnt);
  g_LockPool.Leave(P^.BucketIndex);
end;

procedure DataCachePurge(TimeOutSecs: Cardinal);
var
  P: PFileDataCache;
  Index: Integer;
begin
  g_LockPool.EnterAll;

  for Index := 0 to Pred(MAX_CACHE_ITEMS) do
  begin
    P := g_Cache[Index];
    while (P <> nil) do
    begin
      Dec(P^.Timer, MAX_CACHE_DELAY_TIMER);
      if (P^.Timer <= 0) then
      begin
        if (P^.RefCnt <= 0) then
        begin
          P := DataCacheRemoveFile(P, Index);
          Continue;
        end
        else
          P^.Timer := 0;
      end;
      P := P^.Next;
    end;
  end;

  g_LockPool.LeaveAll;
end;

procedure DataCacheClear(ForcedRemove: Boolean);
var
  P, List: PFileDataCache;
  I: Integer;
begin
  g_LockPool.EnterAll;

  for I := 0 to Pred(MAX_CACHE_ITEMS) do
  begin
    List := g_Cache[I];
    g_Cache[I] := nil;

    while (List <> nil) do
    begin
      P := List;
      List := List^.Next;

      if ForcedRemove or (P^.RefCnt <= 0) then
      begin
        Dec(g_CacheSize, P^.FileSize);

        SetLength(P^.FName, 0);
        FreeMem(P^.Data, P^.FileSize);
        Dispose(P);
      end
      else
      begin
        P^.Next := g_Cache[I];
        g_Cache[I] := P;
      end;
    end;
  end;

  g_LockPool.LeaveAll;
end;

procedure DataCacheShutdown;
begin
  DataCacheClear(True);
  FreeAndNil(g_LockPool);
end;

function DataCacheDumpInfo: string;
var
  P: PFileDataCache;
  I, Level, Count: Integer;
  S: string;
begin
{$IFDEF BORLAND}
  {
  g_LockPool.EnterAll;

  Level := 0;
  Count := 0;
  for I := 0 to Pred(MAX_CACHE_ITEMS) do
  begin
    Level := 1;
    Result := Result + StrPadLeft('Bucket=' + IntToStr(I), Level * 3) + EOL_CRLF;
    Result := Result + StrPadLeft('-------------------------', Level * 3) + EOL_CRLF;
    P := g_Cache[I];
    Level := 2;

    while (P <> nil) do
    begin
      Inc(Count);
      Result := Result + StrPadLeft('-------------------------', Level * 3) + EOL_CRLF;
      Result := Result + StrPadLeft('File:' + P^.FName, Level * 3) + EOL_CRLF;
      Result := Result + StrPadLeft('Size:' + IntToStr(P^.FileSize), Level * 3) + EOL_CRLF;
      //Result := Result + StrPadLeft('LastChanged:' + DateTimeToStr(P^.LastChanged), Level * 3) + EOL_CRLF;
      Result := Result + StrPadLeft('RefCnt:' + IntToStr(P^.RefCnt), Level * 3) + EOL_CRLF;
      Result := Result + StrPadLeft('Timer:' + IntToStr(P^.Timer), Level * 3) + EOL_CRLF;
      Result := Result + StrPadLeft('BucketIndex:' + IntToStr(P^.BucketIndex), Level * 3) + EOL_CRLF;
      Result := Result + StrPadLeft('LastIP:' + inet_ntoa(P^.LastIP), Level * 3) + EOL_CRLF;
      Result := Result + StrPadLeft('-------------------------', Level * 3) + EOL_CRLF;

      P := P^.Next;
    end;
  end;

  Result := Result + 'Total items in data-cache: ' + IntToStr(Count) + EOL_CRLF;
  Result := Result + 'Data-cache max size: ' + IntToStr(g_CacheSize) + '(' + StorageSize(g_CacheSize) + ')' + EOL_CRLF;

  g_LockPool.LeaveAll;
  }
{$ENDIF}
end;

{$IFDEF ENABLE_STATS}
procedure DataCacheStats(var Size, Counts: Integer);
var
  P: PFileDataCache;
  I, Count, Sz: Integer;
begin
  g_LockPool.EnterAll;

  Count := 0;
  Sz    := 0;
  for I := 0 to Pred(MAX_CACHE_ITEMS) do
  begin
    P := g_Cache[I];

    while (P <> nil) do
    begin
      Inc(Count);
      Inc(Sz, P^.FileSize);

      P := P^.Next;
    end;
  end;
  g_LockPool.LeaveAll;

  Counts  := Count;
  Size    := Sz;

end;
{$ENDIF}


function GetFileBufFromCache(Ctx: PClientContext;
                             FName: String;
                             const Offset: Integer;
                             out Count: Integer;
                             out Data: Pointer
                             ): PFileDataCache;
var
  Bucket: Integer;
begin
  Data    := nil;
  FName   := LowerCase(FName);
  Bucket  := SuperFastHash(PAnsiChar(FName), Length(FName)) mod MAX_CACHE_ITEMS;
  g_LockPool.Enter(Bucket);
  Result  := DataCacheFindFile(Ctx, FName, Bucket);
  if (Result = nil) then
    Result := DataCacheAddFile(Ctx, FName, Bucket);


  g_LockPool.Leave(Bucket);

  if (Result <> nil) then
  begin
    if (Offset + Count) > Result^.FileSize then
      Count := Result^.FileSize - Offset;

    Data := PAnsiChar(Integer(Result^.Data) + Offset);
  end;
end;

end.
