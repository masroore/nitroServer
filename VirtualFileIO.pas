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
// DOCUMENTATION IS MANDATORY. IF YOUR PROGRAM HAS AN "ABOUT BOX" THE
// FOLLOWING CREDIT MUST BE DISPLAYED IN IT:
//   "nitroServer (C) Dr. Masroor Ehsan Choudhury <nitroserver@gmail.com>"
//
// ALTERED SOURCE VERSIONS MUST BE PLAINLY MARKED AS SUCH, AND MUST NOT BE
// MISREPRESENTED AS BEING THE ORIGINAL SOFTWARE.
//
// $Version:0.6.1$ $Revision:1.4$ $Author:masroore$ $RevDate:9/18/2007 14:36:54$
//
////////////////////////////////////////////////////////////////////////////////

unit VirtualFileIO;

{$I NITROHTTPD.INC}

interface

uses
  Windows, WinSock, Classes;

procedure VFileStart(MaxFiles, FileGranularity, LockGranularity: Integer);
procedure VFileStop;
procedure VFilePurge(PurgeTimeout: Cardinal);
procedure VFileGetStats(var TotalFiles, TotalHandles, TotalUsages: Integer);
function VFileOpen(FName: string): Integer;
function VFileSeek(VFile: Integer;
                   Offset: Integer;
                   MoveMethod: Cardinal): Cardinal;
function VFileRead(VFile: Integer; var Buffer; Count: LongWord): Integer;
function VFileTransmit(VFile: Integer; Sock: TSocket; 
                       nNumberOfBytesToWrite: DWORD;
                       nNumberOfBytesPerSend: DWORD;
                       lpOverlapped: POverlapped;
                       lpTransmitBuffers: PTransmitFileBuffers;
                       dwReserved: DWORD): BOOL;
procedure VFileClose(VFile: Integer);

implementation

uses
{$IFDEF XBUG}
  uDebug,
{$ENDIF}
{$IFDEF SHARE_FILEHANDLES}
  LockPool,
{$ENDIF}
  SysUtils,
  HashTable;

{$IFDEF SHARE_FILEHANDLES}
const
  VFILE_HASHTABLE_SIZE    = 319;
  VFILE_SHARE_GRANULARITY =   4;

type
  PVHandleInfo = ^TVHandleInfo;
  TVHandleInfo = record
    FHandle: THandle;
    BucketIndex,
    LastAccess: DWORD;
    RefCnt: Integer;
    Next: PVHandleInfo;
  end;

  PVFileRec = ^TVFileRec;
  TVFileRec = record
    FName: string;
    CkSum: Cardinal;
    Handles: PVHandleInfo;
  end;

var
  g_FilesTable: THashTable;
  g_LockPool: TLockPool;
  g_FileShareGranularity: Integer = VFILE_SHARE_GRANULARITY;

function VFileHashFindCB(Item: Pointer): Boolean;
begin
  Result := (PVHandleInfo(Item)^.RefCnt = 0);
end;

function InternalFindFile(const FName: string; const Hash: Cardinal; var VFile: PVFileRec): Boolean;
var
  H: PHashNode;
begin
  Result := False;
  VFile  := nil;

  H := HashFind(g_FilesTable, FName, Hash);
  if Assigned(H) then
  begin
    VFile := PVFileRec(H^.Data);
    Result := True;
  end;
end;
{$ENDIF}

procedure VFileStart(MaxFiles, FileGranularity, LockGranularity: Integer);
begin
{$IFDEF SHARE_FILEHANDLES}
  SetLength(g_FilesTable, VFILE_HASHTABLE_SIZE);
  g_LockPool        := TLockPool.Create(VFILE_HASHTABLE_SIZE div LockGranularity, LockGranularity, 128, False);
  g_FileShareGranularity := FileGranularity;
{$ENDIF}
end;

{$IFDEF SHARE_FILEHANDLES}
function VFilePurgeCallback(Item: Pointer; Param: LongInt): Boolean;
var
  P: PVFileRec;
  hCurr, hNext: PVHandleInfo;
  TimeOut: Cardinal;
begin
  TimeOut := Cardinal(Param);
  P := PVFileRec(Item);
  hCurr := P^.Handles;

  while (hCurr <> nil) do
  begin
    hNext := hCurr^.Next;

    if (hCurr^.RefCnt <= 0) AND (hCurr^.LastAccess < TimeOut) then
    begin
      if (hCurr^.FHandle <> INVALID_HANDLE_VALUE) then
        CloseHandle(hCurr^.FHandle);

      hCurr^.FHandle := INVALID_HANDLE_VALUE;
      if (P^.Handles = hCurr) then
        P^.Handles  := hNext;

      FreeMem(hCurr, SizeOf(TVHandleInfo));
      hCurr := nil;
    end;

    hCurr := hNext;
  end;

  Result := (P^.Handles = nil);
  
  if Result then
  begin
    SetLength(P^.FName, 0);
    FreeMem(P, SizeOf(TVFileRec));
    P := nil;
  end;  
end;
{$ENDIF}

procedure VFilePurge(PurgeTimeout: Cardinal);
{$IFDEF SHARE_FILEHANDLES}
var
  CacheMinTime: DWORD;
{$ENDIF}
begin
{$IFDEF SHARE_FILEHANDLES}
  CacheMinTime := GetTickCount - (PurgeTimeout * 1000);
  g_LockPool.EnterAll;
  try
    HashPurge(g_FilesTable, VFILE_HASHTABLE_SIZE, CacheMinTime, VFilePurgeCallback);
  finally
    g_LockPool.LeaveAll;
  end;
{$ENDIF}
end;

{$IFDEF SHARE_FILEHANDLES}
var
  iTotalFiles, iTotalHandles, iTotalRefCnt: Integer;

function VFCountCallback(Item: Pointer): Boolean;
var
  F: PVFileRec;
  H: PVHandleInfo; 
begin
  Inc(iTotalFiles);
  F := PVFileRec(Item);
  H := F^.Handles;
  while (H <> nil) do
  begin
    Inc(iTotalHandles);
    Inc(iTotalRefCnt, H^.RefCnt);
    H := H^.Next;
  end;
end;
{$ENDIF}

procedure VFileGetStats(var TotalFiles, TotalHandles, TotalUsages: Integer);
begin
{$IFDEF SHARE_FILEHANDLES}
  iTotalFiles   := 0;
  iTotalHandles := 0;
  iTotalRefCnt  := 0;

  g_LockPool.EnterAll;
  try
    HashIterate(g_FilesTable, VFILE_HASHTABLE_SIZE, VFCountCallback);
  finally
    g_LockPool.LeaveAll;
  end;

  TotalFiles   := iTotalFiles;
  TotalHandles := iTotalHandles;
  TotalUsages  := iTotalRefCnt;
{$ENDIF}
end;

{$IFDEF SHARE_FILEHANDLES}
procedure VFileClearCallBack(Item: Pointer);
var
  P: PVFileRec;
  hCurr, hNext: PVHandleInfo;
begin
  P := PVFileRec(Item);
  hCurr := P^.Handles;

  while (hCurr <> nil) do
  begin
    hNext := hCurr^.Next;

    if (hCurr^.FHandle <> INVALID_HANDLE_VALUE) then
      CloseHandle(hCurr^.FHandle);
    hCurr^.FHandle := INVALID_HANDLE_VALUE;
    FreeMem(hCurr, SizeOf(TVHandleInfo));

    hCurr := hNext;
  end;

  SetLength(P^.FName, 0);
  FreeMem(P, SizeOf(TVFileRec));
  P := nil;
end;
{$ENDIF}

procedure VFileStop;
begin
{$IFDEF SHARE_FILEHANDLES}
  HashClear(g_FilesTable, VFILE_HASHTABLE_SIZE, VFileClearCallBack);
  SetLength(g_FilesTable, 0);
  FreeAndNil(g_LockPool);
{$ENDIF}
end;

{$IFDEF SHARE_FILEHANDLES}
function InternalGetHandle(P: PVFileRec): PVHandleInfo;
var
  H, Prev: PVHandleInfo;
begin
  Result := nil;

  H := P^.Handles;
  while (H <> nil) do
  begin
    if (H^.RefCnt < g_FileShareGranularity) then
    begin
      Result := H;
      Break;
    end;

    H := H^.Next;
  end;

  if (Result = nil) then
  begin
    Result := AllocMem(SizeOf(TVHandleInfo));
    Result^.FHandle :=  CreateFile(PChar(P^.FName), GENERIC_READ,
                                   FILE_SHARE_READ, nil,
                                   OPEN_EXISTING,
                                   FILE_FLAG_SEQUENTIAL_SCAN, 0);
    Result^.BucketIndex:= P^.CkSum;
    Result^.Next       := nil;
    Result^.RefCnt     := 0;
    Result^.LastAccess := GetTickCount;

    if (P^.Handles = nil) then
      P^.Handles := Result
    else
    begin
      H := P^.Handles;
      Prev := H;
      while (H <> nil) do
      begin
        Prev := H;

        H    := H^.Next;
      end;

      Prev^.Next := Result;
    end;
  end;
end;

function InternalAddFile(FName: string; CkSum: Cardinal): PVFileRec;
begin
  Result := AllocMem(SizeOf(TVFileRec));
  Result^.FName :=  FName;
  Result^.CkSum := CkSum;
  Result^.Handles := nil;

  InternalGetHandle(Result);

  HashInsert(g_FilesTable, FName, CkSum, Result);
end;
{$ENDIF}

function VFileOpen(FName: string): Integer;
{$IFDEF SHARE_FILEHANDLES}
var
  Hash: Cardinal;
  P: PVFileRec;
  H: PVHandleInfo;
{$ENDIF}
begin
{$IFDEF SHARE_FILEHANDLES}
  Result  := -1;
  if FName = '' then
    Exit;
  FName   := LowerCase(FName);
  Hash    := SuperFastHash(PChar(FName), Length(FName)) mod VFILE_HASHTABLE_SIZE;

  g_LockPool.Enter(Hash);
  try
    if InternalFindFile(FName, Hash, P) then
      H := InternalGetHandle(P)
    else
    begin
      P := InternalAddFile(FName, Hash);
      H := P^.Handles;
    end;

    if Assigned(H) then
    begin
      Inc(H^.RefCnt);
{$IFDEF XBUG}
      INFO(0, 'File ' + IntToStr(Integer(H)) + ' ' + P^.FName + ' has reference count of ' + IntToStr(H^.RefCnt));
{$ENDIF}
      H^.LastAccess := GetTickCount;
      Result  := Integer(H);
    end;
  finally
    g_LockPool.Leave(Hash);
  end;
{$ELSE}
    Result :=  CreateFile(PChar(FName),
                          GENERIC_READ,
                          FILE_SHARE_READ or FILE_SHARE_WRITE,
                          nil,
                          OPEN_EXISTING,
                          FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN,
                          0);
{$ENDIF}
end;

function VFileSeek(VFile: Integer; Offset: Integer; MoveMethod: Cardinal): Cardinal;
begin
{$IFDEF SHARE_FILEHANDLES}
  //g_LockPool.Enter(PVHandleInfo(VFile)^.BucketIndex);
  Result := SetFilePointer(PVHandleInfo(VFile)^.FHandle, Offset, nil, MoveMethod);
  //g_LockPool.Leave(PVHandleInfo(VFile)^.BucketIndex);
{$ELSE}
  Result := SetFilePointer(Cardinal(VFile), Offset, nil, MoveMethod);
{$ENDIF}
end;

function VFileRead(VFile: Integer; var Buffer; Count: LongWord): Integer;
begin
{$IFDEF SHARE_FILEHANDLES}
{$IFDEF XBUG}
  INFO(0, 'Reading file... V:' + IntToStr(VFile) + ' R:' + IntToStr(pvhandleinfo(VFile)^.FHandle) + ' Bytes:' + IntToStr(Count));
{$ENDIF}
  //g_LockPool.Enter(PVHandleInfo(VFile)^.BucketIndex);
  if not ReadFile(PVHandleInfo(VFile)^.FHandle, Buffer, Count, LongWord(Result), nil) then
    Result := -1;
  //g_LockPool.Leave(PVHandleInfo(VFile)^.BucketIndex);
{$ELSE}
  if not ReadFile(Cardinal(VFile), Buffer, Count, LongWord(Result), nil) then
    Result := -1;
{$ENDIF}
end;

function VFileTransmit(VFile: Integer; Sock: TSocket; 
                        nNumberOfBytesToWrite: DWORD;
                        nNumberOfBytesPerSend: DWORD;
                        lpOverlapped: POverlapped;
                        lpTransmitBuffers: PTransmitFileBuffers;
                        dwReserved: DWORD): BOOL;
begin
{$IFDEF SHARE_FILEHANDLES}
{$IFDEF XBUG}
  INFO(0, 'Transmitting file... V:' + IntToStr(VFile) + ' R:' + IntToStr(PVHandleInfo(VFile)^.FHandle) + ' Bytes:' + IntToStr(nNumberOfBytesToWrite));
{$ENDIF}
  //g_LockPool.Enter(PVHandleInfo(VFile)^.BucketIndex);
  Result  := TransmitFile(Sock, PVHandleInfo(VFile)^.FHandle,
                          nNumberOfBytesToWrite, nNumberOfBytesPerSend,
                          lpOverlapped, lpTransmitBuffers, dwReserved);
  //g_LockPool.Leave(PVHandleInfo(VFile)^.BucketIndex);
{$ELSE}
  Result  := TransmitFile(Sock, Cardinal(VFile),
                          nNumberOfBytesToWrite, nNumberOfBytesPerSend,
                          lpOverlapped, lpTransmitBuffers, dwReserved);
{$ENDIF}
end;

procedure VFileClose(VFile: Integer);
{$IFDEF SHARE_FILEHANDLES}
var
  P: PVHandleInfo;
{$ENDIF}
begin
{$IFDEF SHARE_FILEHANDLES}
  P := PVHandleInfo(VFile);
  if Assigned(P) then
  begin
    g_LockPool.Enter(P^.BucketIndex);

    Dec(P^.RefCnt);
  {$IFDEF XBUG}
    INFO(0, 'File ' + IntToStr(VFile) + ' has reference count of ' + IntToStr(P^.RefCnt));
  {$ENDIF}
    P^.LastAccess := GetTickCount;
    
    g_LockPool.Leave(P^.BucketIndex);
  end;
{$ELSE}
  CloseHandle(Cardinal(VFile));
{$ENDIF}
end;

end.
