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
// $Version:0.6.2$ $Revision:1.5$ $Author:masroore$ $RevDate:9/30/2007 21:38:02$
//
////////////////////////////////////////////////////////////////////////////////

unit BusinessThreadPool;

interface

uses
  Windows, SysUtils, Common;

procedure BusinessPoolCreate(const MaxThreads: Cardinal = 4);
procedure BusinessPoolShutDown;
procedure BusinessPoolQueueJob(Ctx: PClientContext);

implementation

{$I NITROHTTPD.INC}

uses
{$IFDEF xbug}
  uDebug,
{$ENDIF}
{$IFDEF FPC}
  WinSock2,
{$ENDIF}
  HTTPConn,
  HTTPProcessor,
  IOCPWorker,
  CachedLogger;

var
  g_ThreadsCount: Cardinal = 0;
  g_BusinessThreads: array of THandle;
  g_BusinessPort: THandle;
  g_BusinessClosed: Boolean;

function BusinessWorkerThread(Param: Pointer): Integer;
var
  BytesTransferred: Cardinal;
  Key: Cardinal;
  pov: PClientContext;
  hPort: THandle;
begin
  hPort := g_BusinessPort; // PHandle(Param)^;
{$IFDEF XBUG}
  INFO(0, 'business thread');
{$ENDIF}
  if (hPort = 0) or (hPort = INVALID_HANDLE_VALUE) then
  begin
{$IFDEF ENABLE_LOGGING}
    LogCrit(nil, 'Invalid business logic I/O completion port!');
{$ENDIF}
    Exit;
  end;

  while True do
  begin
    if g_BusinessClosed then
    begin
{$IFDEF ENABLE_LOGGING}
      LogDebug(nil, 'Shutting down business worker thread...');
{$ENDIF}
      Break;
    end;

    GetQueuedCompletionStatus(hPort, BytesTransferred, Key,
      POverlapped(pov), INFINITE);

    if Cardinal(pov) = SHUTDOWN_FLAG then
    begin
{$IFDEF ENABLE_LOGGING}
      LogDebug(nil, 'Shutting down business worker thread...');
{$ENDIF}
      Sleep(100);
      Break;
    end;

    HandleIOCompletion(pov);
  end;
  Result := 0;
end;

procedure BusinessPoolCreate(const MaxThreads: Cardinal = 4);
var
  I, ID: Cardinal;
begin
  g_BusinessPort := CreateIoCompletionPort(INVALID_HANDLE_VALUE, 0, 0, 0);
  if g_BusinessPort = 0 then
  begin
{$IFDEF ENABLE_LOGGING}
    LogCrit(nil,
      'Error occurred while creating business logic I/O Completion Port: ' +
      SysErrorMessage(GetLastError));
{$ENDIF}
    Exit;
  end;

  g_ThreadsCount := MaxThreads;
  g_BusinessClosed := False;

  SetLength(g_BusinessThreads, g_ThreadsCount);
  for I := 0 to Pred(g_ThreadsCount) do
    g_BusinessThreads[I] := BeginThread(nil, 0,
      @BusinessWorkerThread,
      Pointer(g_BusinessPort),
      0, ID);
end;

procedure BusinessPoolShutDown;
var
  I: Integer;
begin
  g_BusinessClosed := True;

  for I := 0 to g_ThreadsCount - 1 do
    PostQueuedCompletionStatus(g_BusinessPort, 0, 0,
      POverLapped(SHUTDOWN_FLAG));

  WaitForMultipleObjects(g_ThreadsCount, @g_BusinessThreads, True, INFINITE);

  CloseHandle(g_BusinessPort);
  g_BusinessPort := INVALID_HANDLE_VALUE;
  g_ThreadsCount := 0;
end;

procedure BusinessPoolQueueJob(Ctx: PClientContext);
begin
  PostQueuedCompletionStatus(g_BusinessPort,
    Ctx^.Bytes,
    Ctx^.Sock,
    POverlapped(Ctx));
end;

end.

