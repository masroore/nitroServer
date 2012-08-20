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
// $Version:0.6.2$ $Revision:1.6$ $Author:masroore$ $RevDate:9/30/2007 21:38:12$
//
////////////////////////////////////////////////////////////////////////////////

unit IOCPServer;

interface

uses
  Windows, WinSock, Winsock2, SysUtils;

procedure ServerInit;
procedure ServerStart;
procedure ServerStop;

function SvrGetServerAddr: string;
function SvrGetServerPort: string;
function SvrGetIOCPThreadPoolSize: Integer;

implementation

{$I NITROHTTPD.INC}

uses
{$IFDEF XBUG}
  uDebug,
{$ENDIF}
  Common,
  IOCPWorker,
{$IFDEF BUSINESS_LOGIC_THREADPOOL}
  BusinessThreadPool,
{$ENDIF}
  HTTPConn,
  CachedLogger,
  Config, GarbageCollector, ThreadAffinity;

const
  WORKER_THREADS_PER_PROCESSOR = 2;

var
  g_TotalThreads: Cardinal;
  g_WorkerThreads: array of THandle;
  g_IOCP:     THandle;
  g_Stopping: Boolean;
  g_ListenSock: TSocket;
  g_ServerAddr,
  g_ServerPort: string;
  g_Impersonated: Boolean = False;

procedure ServerInit;
var
  wd:  TWSAData;
  Res: Integer;
  si:  TSystemInfo;
begin
  Res := WSAStartup($0202, wd);
  if Res <> 0 then
  begin
{$IFDEF ENABLE_LOGGING}
    LogCrit(nil, 'Error occured while initialising winsock stack!');
{$ENDIF}
    Exit;
  end;

  g_IOCP := CreateIoCompletionPort(INVALID_HANDLE_VALUE, 0, 0, 0);
  if g_IOCP = 0 then
  begin
{$IFDEF ENABLE_LOGGING}
    LogCrit(nil, 'Error occurred while creating I/O Completion Port: ' + SysErrorMessage(GetLastError));
{$ENDIF}
    Exit;
  end;

  g_Stopping := False;

  g_TotalThreads := GetProcessorCount * WORKER_THREADS_PER_PROCESSOR;
  SetLength(g_WorkerThreads, g_TotalThreads);
end;

procedure ServerStart;
var
  sai:    TSockAddrIn;
  IP, I:  Integer;
  ID:     Cardinal;
  Params: array [0..1] of THandle;
  pszUser, pszPass: LPSTR;
  hImpersonation: THandle;
  bLoggedOn: BOOL;
begin
  g_Impersonated := False;

  {$IFDEF BORLAND}
  if CfgImpersonate then
  begin
    pszUser   := StrNew(PAnsiChar(CfgGetImpersonateUser));
    pszPass   := StrNew(PAnsiChar(CfgGetImpersonatePass));
    bLoggedOn := LogonUserA(pszUser, nil, pszPass, LOGON32_LOGON_NETWORK, LOGON32_PROVIDER_DEFAULT, hImpersonation);

    if bLoggedOn then
    begin
      g_Impersonated := ImpersonateLoggedOnUser(hImpersonation);
{$IFDEF ENABLE_LOGGING}
      LogDebug(nil, 'Impersonating user ' + CfgGetImpersonateUser);
{$ENDIF}
{$IFDEF XBUG}
      INFO(0, 'Impersonating user ' + CfgGetImpersonateUser);
{$ENDIF}
    end
    else
    begin
{$IFDEF ENABLE_LOGGING}
      LogCrit(nil, 'Failed to logon using user name ' + CfgGetImpersonateUser + ': ' + SysErrorMessage(WSAGetLastError));
{$ENDIF}
{$IFDEF XBUG}
      ERROR(0, 'Failed to logon using user name ' + CfgGetImpersonateUser + ': ' + SysErrorMessage(WSAGetLastError));
{$ENDIF}
    end;

    StrDispose(pszUser);
    StrDispose(pszPass);
  end;
  {$ENDIF}

  g_ListenSock := WSASocket(AF_INET, SOCK_STREAM, 0, nil, 0, WSA_FLAG_OVERLAPPED);
  if g_ListenSock = INVALID_SOCKET then
  begin
{$IFDEF ENABLE_LOGGING}
    LogCrit(nil, 'Error occured while creating listening socket: ' + SysErrorMessage(WSAGetLastError));
{$ENDIF}
    Exit;
  end;

  FillChar(sai, SOCKADDRIN_SIZE, #0);
  sai.sin_family := AF_INET;
  sai.sin_port   := htons(CfgGetListenPort);

  if (CfgGetListenIP = '') then
    IP := -1
  else
    IP := inet_addr(PAnsiChar(CfgGetListenIP));

  if (IP <= 0) then
    sai.sin_addr.S_addr := INADDR_ANY
  else
    sai.sin_addr.S_addr := IP;

  if bind(g_ListenSock, sai, SOCKADDRIN_SIZE) = SOCKET_ERROR then
  begin
{$IFDEF ENABLE_LOGGING}
    LogSockError(nil, 'bind(' + IntToStr(sai.sin_port) + ')');
{$ENDIF}
    closesocket(g_ListenSock);
    Exit;
  end;

  if listen(g_ListenSock, SOMAXCONN) = SOCKET_ERROR then
  begin
{$IFDEF ENABLE_LOGGING}
    LogSockError(nil, 'listen');
{$ENDIF}
    closesocket(g_ListenSock);
    Exit;
  end;

  I := SizeOf(TSockAddrIn);
  getsockname(g_ListenSock, sai, I);

  g_ServerAddr  := inet_ntoa(sai.sin_addr);
  g_ServerPort  := IntToStr(ntohs(sai.sin_port));

{$IFDEF ENABLE_LOGGING}
  LogDebug(nil, 'Webserver running at ' + g_ServerAddr + ':' + g_ServerPort);
{$ENDIF}

{$IFDEF XBUG}
  uDebug.INFO(0, 'Webserver running at ' + g_ServerAddr + ':' + g_ServerPort, 1);
{$ENDIF}

  if CreateIoCompletionPort(g_ListenSock, g_IOCP, $ABCDEF, 0) = 0 then
  begin
{$IFDEF ENABLE_LOGGING}
    LogCrit(nil, 'Error occurred while creating I/O Completion Port on the listenning socket: ' + SysErrorMessage(GetLastError));
{$ENDIF}
    closesocket(g_ListenSock);
    Exit;
  end;

  IsMultiThread := True;

  InitConnections(g_IOCP, g_ListenSock);

{$IFDEF BUSINESS_LOGIC_THREADPOOL}
  BusinessPoolCreate(CfgGetBusinessThreadPoolSize);
{$ENDIF}

  Params[0] := g_IOCP;
  Params[1] := g_ListenSock;

  for I := 0 to g_TotalThreads - 1 do
    g_WorkerThreads[I] := BeginThread(nil,               // Security attributes
                                      0,                    // Initial stack size
                                      @IOCPWorkerThread,       // Thread function
                                      @Params,     // Thread parameter
                                      0,     // Creation options
                                      ID);        // Thread identifier
                                      
{$IFDEF SET_THREAD_AFFINITY}
  // Equally distribute the threadpool among the SMP cores
  if GetProcessorCount > 1 then
    BindThreadsToProcessors(g_WorkerThreads, g_TotalThreads, WORKER_THREADS_PER_PROCESSOR);
{$ENDIF}

  for I := 1 to CfgGetMaxClients do
    AcceptNewConn;

  GarbageCollect(WATCHDOG_INTERVAL);
end;

procedure ServerStop;
var
  I: Integer;
begin
  g_Stopping := True;
  for I := 0 to g_TotalThreads - 1 do
    PostQueuedCompletionStatus(g_IOCP, 0, SHUTDOWN_FLAG, nil);

  WaitForMultipleObjects(g_TotalThreads, @g_WorkerThreads, True, INFINITE);

  CloseHandle(g_IOCP);
  g_IOCP  := INVALID_HANDLE_VALUE;
  SetLength(g_WorkerThreads, 0);

{$IFDEF BUSINESS_LOGIC_THREADPOOL}
  BusinessPoolShutDown;
{$ENDIF}
  GarbageShutDown;

  DeinitConnections;
  if g_Impersonated then
    RevertToSelf;

  WSACleanup;
end;

function SvrGetServerAddr: string;
begin
  Result  := g_ServerAddr;
end;

function SvrGetServerPort: string;
begin
  Result  := g_ServerPort;
end;

function SvrGetIOCPThreadPoolSize: Integer;
begin
  Result  := g_TotalThreads;
end;

end.
