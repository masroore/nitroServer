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
// $Version:0.6.2$ $Revision:1.4.1.0$ $Author:masroore$ $RevDate:9/30/2007 21:38:10$
//
////////////////////////////////////////////////////////////////////////////////

unit GarbageCollector;

interface

uses
  Windows;

procedure GarbageCollect(const ScanIntervalSecs: Integer = 30);
procedure GarbageShutDown;

implementation

{$I NITROHTTPD.INC}

uses
{$IFDEF XBUG}
  uDebug,
{$ENDIF}
  CachedLogger,
  FileInfoCache,
  FileDataCache,
{$IFDEF CACHE_DIR_LIST}
  FastDirLister,
{$ENDIF}
  HTTPConn,
  VirtualFileIO, GZipDataCache;

var
  g_GarbageThread: THandle;
  g_ScanInterval: Integer;
  g_Event: THandle;
  g_ShutDown: Boolean;

function GarbageThread(Param: Pointer): Integer;
begin
  while True do
  begin
    if g_ShutDown then
      Break;

    case WaitForSingleObject(g_Event, g_ScanInterval * 1000) of
      WAIT_OBJECT_0:
        begin
          Break;
        end;
      WAIT_TIMEOUT:
        begin
{$IFDEF XBUG}
          INFO(0, 'Rise & Shine! Garbage man!');
{$ENDIF}
          if g_ShutDown then
            Break;

          ScavengeStaleConnections(300);
          FileInfoCachePurge(g_ScanInterval);
          DataCachePurge(g_ScanInterval);
{$IFDEF GZIP_COMPRESS}
          GZCachePurge(g_ScanInterval);
{$ENDIF}
          VFilePurge(g_ScanInterval);
{$IFDEF ENABLE_LOGGING}
          LogFlushCache;
{$ENDIF}
{$IFDEF CACHE_DIR_LIST}
          FListCachePurge(DIR_LIST_PURGE_TIMEOUT);
{$ENDIF}
        end;  
      WAIT_FAILED:
        begin
          Break;
        end;  
    end;
  end;

  Result := 0;
end;    

procedure GarbageCollect(const ScanIntervalSecs: Integer = 30);
var
  ID: Cardinal;
begin
  g_Event         := CreateEventW(nil, False, False, nil);
  g_ShutDown      := False;
  g_ScanInterval  := ScanIntervalSecs;

  g_GarbageThread := BeginThread(nil,
                                  0,
                                  @GarbageThread,
                                  Pointer(g_Event),
                                  0,
                                  ID);
  SetThreadPriority(g_GarbageThread, THREAD_PRIORITY_BELOW_NORMAL);
end;

procedure GarbageShutDown;
begin
  g_ShutDown := True;
  SetEvent(g_Event);

  WaitForSingleObject(g_GarbageThread, INFINITE);

  g_GarbageThread := INVALID_HANDLE_VALUE;
  CloseHandle(g_Event);
end;

end.
