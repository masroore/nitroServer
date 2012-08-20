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
// $Version:0.6.2$ $Revision:1.0$ $Author:masroore$ $RevDate:9/30/2007 21:37:42$
//
////////////////////////////////////////////////////////////////////////////////

unit HTTPHeaderCache;

interface

{$I NITROHTTPD.INC}

{$IFDEF CACHE_HTTP_HEADERS}

uses
  WinSock, SysUtils, Common, Buffer, HashTable;

procedure HeaderCacheInit;
procedure HeaderCacheShutdown;
function GetHeaderFromCache(Ctx: PClientContext;
                            FName: AnsiString;
                            const FileTime: TDateTime;
                            const ContentLen: Cardinal;
                            Req: PHTTPRequest;
                            Buf: PSmartBuffer): Boolean;

{$IFDEF ENABLE_STATS}
procedure HdrCacheStats(var Counts: Integer);
{$ENDIF}

{$ENDIF}

implementation

{$IFDEF CACHE_HTTP_HEADERS}

uses
  LockPool, HTTPResponse, MimeType;

const
  TIME_IN_CACHE         =  60;
  MAX_CACHE_TIMER       = 300;
  MAX_CACHE_DELAY_TIMER = WATCHDOG_INTERVAL;
  MAX_CACHE_SIZE        = 257;

type
  PHeaderCache = ^THeaderCache;
  THeaderCache = record
    FName:        AnsiString;
    CheckSum:     Cardinal;
    Header:       PAnsiChar;
    HeaderLen:    Integer;
    Timer:        Integer;
    LastIP:       in_addr;
    Prev, Next:   PHeaderCache;
  end;

var
  g_Cache: array [0..MAX_CACHE_SIZE] of PHeaderCache;
  g_LockPool: TLockPool;

procedure HeaderCacheInit;
var
  I: Integer;
begin
  g_LockPool := TLockPool.Create(MAX_CACHE_SIZE, MAX_CACHE_SIZE div 50, 0, False);

  for I := 0 to MAX_CACHE_SIZE do
    g_Cache[I] := nil;
end;

function HeaderCacheRemoveEntry(P: PHeaderCache; Bucket: Integer): PHeaderCache;
begin
  if (P^.Prev <> nil) then
    P^.Prev^.Next := P^.Next;

  Result := P^.Next;

  if (P^.Next <> nil) then
    P^.Next^.Prev := P^.Prev;

  if g_Cache[Bucket] = P then
    g_Cache[Bucket] := P^.Next;

  SetLength(P^.FName, 0);
  FreeMem(P^.Header, P^.HeaderLen);
  Dispose(P);
end;

function HeaderCacheAddEntry( Ctx: PClientContext;
                              FName: AnsiString;
                              ACheckSum: Cardinal;
                              const ContentType: AnsiString;
                              const FileTime: TDateTime;
                              const ContentLen: Cardinal;
                              Req: PHTTPRequest;
                              Bucket: Integer): PHeaderCache;
begin
  New(Result);
  Result^.FName := FName;
  with Result^ do
  begin
    Timer       := TIME_IN_CACHE;
    LastIP      := Ctx^.saPeer.sin_addr;
    HTTPBuildHeaderString(Header, HeaderLen,
                          ContentType, FileTime,
                          ContentLen, Req);
    CheckSum := ACheckSum;
    Prev := nil;
    Next := g_Cache[Bucket];
  end;

  if g_Cache[Bucket] <> nil then
    g_Cache[Bucket]^.Prev := Result;
  g_Cache[Bucket] := Result;
end;

function HeaderCacheFindEntry(Ctx: PClientContext;
                              FName: AnsiString;
                              ACheckSum: Cardinal;
                              Bucket: Integer): PHeaderCache;
var
  Obj: PHeaderCache;
begin
  Result := nil;
  Obj := g_Cache[Bucket];

  while (Obj <> nil) do
  begin
    //if CompareStr(Obj^.FName, FName) = 0 then
    if (Obj^.CheckSum = ACheckSum) then
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

        Result := Obj;
      end
      else
        HeaderCacheRemoveEntry(Obj, Bucket);

      Break;
    end;

    Obj := Obj^.Next;
  end;
end;

procedure HeaderCachePurge;
var
  P: PHeaderCache;
  Index: Integer;
begin
  g_LockPool.EnterAll;

  for Index := 0 to MAX_CACHE_SIZE do
  begin
    P := g_Cache[Index];
    while (P <> nil) do
    begin
      Dec(P^.Timer, MAX_CACHE_DELAY_TIMER);
      if (P^.Timer <= 0) then
      begin
        P := HeaderCacheRemoveEntry(P, Index);
        Continue;
      end;
      P := P^.Next;
    end;
  end;

  g_LockPool.LeaveAll;
end;

procedure HeaderCacheClear;
var
  P, List: PHeaderCache;
  I: Integer;
begin
  g_LockPool.EnterAll;

  for I := 0 to MAX_CACHE_SIZE do
  begin
    List := g_Cache[I];
    g_Cache[I] := nil;

    while (List <> nil) do
    begin
      P := List;
      List := List^.Next;

      SetLength(P^.FName, 0);
      FreeMem(P^.Header, P^.HeaderLen);
      Dispose(P);
    end;
  end;

  g_LockPool.LeaveAll;
end;

procedure HeaderCacheShutdown;
begin
  HeaderCacheClear;
  FreeAndNil(g_LockPool);
end;

function GetHeaderFromCache(Ctx: PClientContext;
                            FName: AnsiString;
                            const FileTime: TDateTime;
                            const ContentLen: Cardinal;
                            Req: PHTTPRequest;
                            Buf: PSmartBuffer): Boolean;
var
  Bucket: Integer;
  P: PHeaderCache;
  ChkSum: Cardinal;
begin
  FName   := LowerCase(FName);
  ChkSum  := SuperFastHash(PAnsiChar(FName), Length(FName));
  Bucket  := ChkSum mod MAX_CACHE_SIZE;
  g_LockPool.Enter(Bucket);
  P := HeaderCacheFindEntry(Ctx, FName, ChkSum, Bucket);
  if (P = nil) then
    P := HeaderCacheAddEntry(Ctx, FName, ChkSum,
                            GetMIMEType(FName), FileTime,
                            ContentLen,  Req, Bucket);
  g_LockPool.Leave(Bucket);

  Result := (P <> nil);
  if Result then
    BufAppendData(Buf, P^.Header, P^.HeaderLen);
end;

{$IFDEF ENABLE_STATS}
procedure HdrCacheStats(var Counts: Integer);
var
  P: PHeaderCache;
  I, Count: Integer;
begin
  g_LockPool.EnterAll;

  Count := 0;
  for I := 0 to Pred(MAX_CACHE_SIZE) do
  begin
    P := g_Cache[I];

    while (P <> nil) do
    begin
      Inc(Count);

      P := P^.Next;
    end;
  end;
  g_LockPool.LeaveAll;

  Counts  := Count;
end;
{$ENDIF}


{$ENDIF}

end.
