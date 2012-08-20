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
// $Version:0.6.2$ $Revision:1.0.1.0$ $Author:masroore$ $RevDate:9/30/2007 21:38:10$
//
////////////////////////////////////////////////////////////////////////////////

unit GZipDataCache;

interface

{$I NITROHTTPD.INC}

{$IFDEF GZIP_COMPRESS}

uses
  Windows, WinSock, SysUtils, Common, HashTable;

type
  PFileGZCache = ^TFileGZCache;
  TFileGZCache = record
    FName:        AnsiString;
    Data:         PAnsiChar;
    DataSize:     Cardinal;
    Timer:        Integer;
    BucketIndex:  Integer;
    RefCnt:       Integer;
    LastIP:       in_addr;
    Prev, Next:   PFileGZCache;
  end;

procedure GZCacheInit;
procedure GZCacheShutdown;
function  GZCacheRemoveFile(P: PFileGZCache; Bucket: Integer): PFileGZCache;
function  GZCacheAddFile(Ctx: PClientContext; FName: AnsiString; Bucket: Integer): PFileGZCache;
function  GZCacheFindFile(Ctx: PClientContext; FName: AnsiString; Bucket: Integer): PFileGZCache;
procedure GZCacheDoneWith(P: PFileGZCache; Remove: Boolean);
procedure GZCachePurge(TimeOutSecs: Cardinal);
procedure GZCacheClear(ForcedRemove: Boolean);

function GzGetFileBufFromCache(Ctx: PClientContext;
                               FName: AnsiString;
                               out Count: Integer;
                               out Data: Pointer
                               ): PFileGZCache;

{$ENDIF}

implementation

{$IFDEF GZIP_COMPRESS}

uses
  GZipEncoder,
  LockPool,
  Config;

const
  TIME_IN_CACHE         =  60;
  MAX_CACHE_TIMER       = 300;
  MAX_CACHE_DELAY_TIMER = WATCHDOG_INTERVAL;
  MAX_CACHE_ITEMS       = DEFAULT_HASHTABLE_SIZE;

var
  g_Cache: array [0..Pred(MAX_CACHE_ITEMS)] of PFileGZCache;
  g_LockPool: TLockPool;
  g_CacheSize: Cardinal;

procedure GZCacheInit;
var
  I: Integer;
begin
  g_LockPool := TLockPool.Create(Pred(MAX_CACHE_ITEMS), MAX_CACHE_ITEMS div 20, 0, False);

  for I := 0 to Pred(MAX_CACHE_ITEMS) do
    g_Cache[I] := nil;
end;

function GZCacheRemoveFile(P: PFileGZCache; Bucket: Integer): PFileGZCache;
begin
  if (P^.Prev <> nil) then
    P^.Prev^.Next := P^.Next;

  Result := P^.Next;

  if (P^.Next <> nil) then
    P^.Next^.Prev := P^.Prev;

  Dec(g_CacheSize, P^.DataSize);
  if g_Cache[Bucket] = P then
    g_Cache[Bucket] := P^.Next;

  SetLength(P^.FName, 0);
  FreeMem(P^.Data, P^.DataSize);
  Dispose(P);
end;

function GZCacheAddFile(Ctx: PClientContext; FName: AnsiString; Bucket: Integer): PFileGZCache;
var
  P: PFileGZCache;
  FileInfo: TByHandleFileInformation;
  hFile: THandle;
  Sz: Integer;
  pData: Pointer; 
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
      Sz := FileInfo.nFileSizeLow; //GetDataSize(hFile, nil);
      if (Sz > 0) and ((g_CacheSize + Sz) <= CfgGetDataCacheMaxCapacity) then
      begin
        New(P);
        P^.FName := FName;
        with P^ do
        begin
          GZCompressFileData2(hFile, 0, Sz, pData, Sz);

          DataSize    := Sz;
          Data        := pData;
          Timer       := TIME_IN_CACHE;
          LastIP      := Ctx^.saPeer.sin_addr;
          RefCnt      := 1;
        end;

        P^.Prev := nil;
        P^.Next := g_Cache[Bucket];
        if g_Cache[Bucket] <> nil then
          g_Cache[Bucket]^.Prev := P;
        g_Cache[Bucket] := P;
        Inc(g_CacheSize, P^.DataSize);
        P^.BucketIndex  := Bucket;

        Result := P;
      end;
    end;
  end;

  CloseHandle(hFile);
end;

function GZCacheFindFile(Ctx: PClientContext; FName: AnsiString; Bucket: Integer): PFileGZCache;
var
  Obj: PFileGZCache;
begin
  Result := nil;
  Obj := g_Cache[Bucket];

  while (Obj <> nil) do
  begin
    begin
      if CompareStr(Obj^.FName, FName) = 0 then
      begin
        if (Obj^.Timer > 0) then
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
            GzCacheRemoveFile(Obj, Bucket);
        end;

        Break;
      end;
    end;

    Obj := Obj^.Next;
  end;
end;

procedure GZCacheDoneWith(P: PFileGZCache; Remove: Boolean);
begin
  g_LockPool.Enter(P^.BucketIndex);
  if Remove then
    P^.Timer := 0;
  Dec(P^.RefCnt);
  g_LockPool.Leave(P^.BucketIndex);
end;             

procedure GZCachePurge(TimeOutSecs: Cardinal);
var
  P: PFileGZCache;
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
          P := GzCacheRemoveFile(P, Index);
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

procedure GZCacheClear(ForcedRemove: Boolean);
var
  P, List: PFileGZCache;
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
        Dec(g_CacheSize, P^.DataSize);

        SetLength(P^.FName, 0);
        FreeMem(P^.Data, P^.DataSize);
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

procedure GZCacheShutdown;
begin
  GZCacheClear(True);
  FreeAndNil(g_LockPool);
end;

function GzGetFileBufFromCache(Ctx: PClientContext;
                               FName: AnsiString;
                               out Count: Integer;
                               out Data: Pointer
                               ): PFileGZCache;
var
  Bucket: Integer;
begin
  Data    := nil;
  FName   := LowerCase(FName);
  Bucket  := SuperFastHash(PAnsiChar(FName), Length(FName)) mod MAX_CACHE_ITEMS;
  g_LockPool.Enter(Bucket);
  Result  := GZCacheFindFile(Ctx, FName, Bucket);
  if (Result = nil) then
    Result := GZCacheAddFile(Ctx, FName, Bucket);
  g_LockPool.Leave(Bucket);

  if (Result <> nil) then
  begin
    Count := Result^.DataSize;
    Data  := Result^.Data;
  end;
end;

{$ENDIF}

end.
