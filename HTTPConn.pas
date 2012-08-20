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
// $Version:0.6.2$ $Revision:1.5.1.0$ $Author:masroore$ $RevDate:9/30/2007 21:38:10$
//
////////////////////////////////////////////////////////////////////////////////

unit HTTPConn;

interface

{$I NITROHTTPD.INC}

uses
  Windows, WinSock, Winsock2, Common;

procedure InitConnections(hIOCP: THandle; ListenSock: TSocket);
procedure DeinitConnections;
procedure AcceptNewConn;
procedure CloseConn(var Ctx: PClientContext; Force: Boolean = False; AcceptAgain: Boolean = True);
procedure ReinitContext(var Ctx: PClientContext);
procedure DeleteContext(var Ctx: PClientContext);
procedure FreeContext(var Ctx: PClientContext);

procedure HandleNewConnection(Ctx: PClientContext);
procedure HandleDataReceived(Ctx: PClientContext);
procedure HandleDataSent(Ctx: PClientContext);
procedure HandleFileSent(Ctx: PClientContext);
{$IFDEF REUSE_SOCKET}
procedure HandleDisconnect(Ctx: PClientContext);
{$ENDIF}

procedure ScavengeStaleConnections(TimeOutSecs: Cardinal);

{$IFDEF XBUG}
procedure DumpActiveConns;
{$ENDIF}

implementation

uses
{$IFDEF XBUG}
  uDebug,
  {$IFDEF TRACK_SOCKET_SESSION}
  SiAuto,
  SmartInspect,
  {$ENDIF}
{$ENDIF}
  SysUtils,
  CachedLogger,
  HTTPRequests,
  HTTPProcessor,
  FastLock,
  IOCPWorker,
  Classes,
{$IFDEF ENABLE_STATS}
  ServerStats,
{$ENDIF}
  Buffer,
  VirtualFileIO,
{$IFDEF GZIP_COMPRESS}
  GZipDataCache,
{$ENDIF}
  FileDataCache;

var
  g_hIOCP:      THandle;
  g_ListenSock: TSocket;
  g_Lock:       TFastLock;
  g_ClientList: TList; 

procedure InitConnections(hIOCP: THandle; ListenSock: TSocket);
begin
  g_Lock      := TFastLock.Create(128, False);
  g_ClientList := TList.Create;
  g_ClientList.Capacity := 512;
  g_hIOCP     := hIOCP;
  g_ListenSock := ListenSock;
end;

procedure FreeAllSockets;
var
  I: Integer;
  P: PClientContext;
begin
  g_Lock.Enter;
  try
    for I := 0 to g_ClientList.Count - 1 do
    begin
      P := PClientContext(g_ClientList[I]);
      if (P <> nil) then
        FreeContext(P);
    end;

    g_ClientList.Clear;
  finally
    g_Lock.Leave;
  end;
end;

procedure ContextAddToList(P: PClientContext);
begin
  g_Lock.Enter;
  try
    g_ClientList.Add(P);
  finally
    g_Lock.Leave;
  end;
end;

procedure ContextDeleteFromList(P: PClientContext);
var
  I: Integer;
begin
  g_Lock.Enter;
  try
    for I := 0 to g_ClientList.Count - 1 do
      if PClientContext(g_ClientList[I]) = P then
      begin
        g_ClientList.Delete(I);
        Break;
      end;
  finally
    g_Lock.Leave;
  end;
end;

procedure DeinitConnections;
begin
  FreeAllSockets;

  FreeAndNil(g_Lock);
  FreeAndNil(g_ClientList);
end;

function InitNewContext: PClientContext;
{$IFDEF TRACK_SOCKET_SESSION}
var
  Sess: TSiSession;
{$ENDIF}
begin
  Result := AllocMem(SizeOf(TClientContext));
  with Result^ do
  begin
    hIOCP    := g_hIOCP;
    SendFile := False;
    State    := stClosed;
    Sock     := SOCKET_ERROR;
    DisconnectAfterSend := False;
    ReuseCount  := 0;

    BufCreate(RecvBuf, MAX_RECV_BUF_SIZE);
    BufCreate(SendBuf, MAX_SEND_BUF_SIZE);
    HTTPRequestCreate(HTTPReq, Result);
    TxBuf := AllocMem(SizeOf(TTransmitFileBuffers));
    DataCache        := nil;
    SendCacheType := Common.scNone;
{$IFDEF TRANSMIT_PACKETS}
    //tpSend := AllocMem(SizeOf(TTransmitPacketsElement) * 2);
{$ENDIF}

{$IFDEF TRACK_SOCKET_SESSION}
    Sess := Si.AddSession(IntToStr(Integer(Result)));
    Sess.Color := GetNextSessionColor;
    xSession := Integer(Sess);
{$ENDIF}
  end;

  ContextAddToList(Result);
end;

procedure ReinitContext(var Ctx: PClientContext);
var
  Zero: Cardinal;
begin
  with Ctx^ do
  begin
    Sock := WSASocket(AF_INET, SOCK_STREAM, 0, nil, 0, WSA_FLAG_OVERLAPPED);
    if Sock <> INVALID_SOCKET then
    begin
      //BufRemove(RecvBuf, -1);
      //BufRemove(SendBuf, -1);
      BufShrink(RecvBuf, MAX_RECV_BUF_SIZE);
      BufShrink(SendBuf, MAX_SEND_BUF_SIZE);
      HTTPRequestReset(HTTPReq);
      ReuseCount := 0;

      if SendCacheType = scDataCache then
      begin
        DataCacheDoneWith(DataCache, False);
        SendCacheType := Common.scNone;
      end
      else
      if SendCacheType = scGZipCache then
      begin
{$IFDEF GZIP_COMPRESS}
        GZCacheDoneWith(DataCache, False);
{$ENDIF}
        SendCacheType := Common.scNone;
      end;

      HTTPReq^.KACount := 0;
      HTTPReq^.KeepAlive := False;


      State    := stAccepting;
      SendFile := False;
      DisconnectAfterSend := False;
{$IFDEF DISABLE_SENDBUFFER}
      Zero := 0;
      setsockopt(Sock, SOL_SOCKET, SO_SNDBUF, @Zero, SizeOf(Zero));
{$ENDIF}

      {
      if CreateIoCompletionPort(Sock, hIOCP, Integer(Ctx), 0) = 0 then
      begin
        LogSockError('CreateIoCompletionPort');
        CloseConn(Ctx, True, False);
        Exit;
      end;
      }

      if not AcceptEx(g_ListenSock, Sock, @RecvBuf^.Data^,
        ACCEPT_BUF_SIZE, SOCKADDRIN_SIZE + 16, SOCKADDRIN_SIZE +
        16, Bytes, Pointer(Ctx)) then
      begin
        if WSAGetLastError <> ERROR_IO_PENDING then
        begin
{$IFDEF ENABLE_LOGGING}
          LogSockError(Ctx, 'AcceptEx');
{$ENDIF}
          DeleteContext(Ctx);
          AcceptNewConn;
        end;
      end;
{$IFDEF XBUG}
{$IFDEF TRACK_SOCKET_SESSION}
      XINFO(Ctx^.xSession, Ctx^.Sock, 'Accepting new connection...');
{$ELSE}
      INFO(Ctx^.Sock, 'Accepting new connection...');
{$ENDIF}
{$ENDIF}
    end;
  end;
end;

procedure CloseConn(var Ctx: PClientContext; Force: Boolean = False;
  AcceptAgain: Boolean = True);
var
  li: TLinger;
begin
{$IFDEF XBUG}
{$IFDEF TRACK_SOCKET_SESSION}
  XINFO(Ctx^.xSession, Ctx^.Sock, 'Closing connection...');
{$ELSE}
  INFO(Ctx^.Sock, 'Closing connection...');
{$ENDIF}
{$ENDIF}

{$IFDEF ENABLE_STATS}
  if (Ctx^.State <> stAccepting) and (Ctx^.State <> stDisconnect) then
    StatsDecCurrConn;
{$ENDIF}

  if Ctx^.SendFile then
  begin
{$IFDEF XBUG}
{$IFDEF TRACK_SOCKET_SESSION}
    XINFO(Ctx^.xSession, Ctx^.Sock, 'Closing file handle...');
{$ELSE}
    INFO(Ctx^.Sock, 'Closing file handle...');
{$ENDIF}
{$ENDIF}
    Ctx^.SendFile := False;
    if (Ctx^.FileHandle <> -1) then
      VFileClose(Ctx^.FileHandle);
    Ctx^.FileHandle := -1;
  end;

{$IFDEF REUSE_SOCKET}
  if (not Force) and AcceptAgain then
    SockDisconnect(Ctx)
  else
{$ENDIF}
  begin
    with Ctx^ do
    begin
      if Sock <> INVALID_SOCKET then
      begin
        if Force then
        begin
          li.l_onoff  := 1;
          li.l_linger := 0;
          setsockopt(Sock, SOL_SOCKET, SO_LINGER, @li, SizeOf(li));
        end;

        closesocket(Sock);
      end;
    end;

    if AcceptAgain then
      ReinitContext(Ctx);
  end;
end;

procedure FreeContext(var Ctx: PClientContext);
begin
  CloseConn(Ctx, True, False);

  with Ctx^ do
  begin
    BufFree(RecvBuf);
    BufFree(SendBuf);
    FreeMem(TxBuf, SizeOf(TTransmitFileBuffers));
{$IFDEF TRANSMIT_PACKETS}
    //FreeMem(tpSend, SizeOf(TTransmitPacketsElement) * 2);
{$ENDIF}
    HTTPRequestFree(HTTPReq);

{$IFDEF XBUG}
{$IFDEF TRACK_SOCKET_SESSION}
    Si.DeleteSession(TSiSession(Ctx^.xSession));
{$ENDIF}
{$ENDIF}
  end;

  FreeMem(Ctx, SizeOf(TClientContext));
  Ctx := nil;
end;

procedure DeleteContext(var Ctx: PClientContext);
begin
  ContextDeleteFromList(Ctx);
  FreeContext(Ctx);
end;

procedure AcceptNewConn;
var
  P: PClientContext;
begin
  //ReinitContext(InitNewContext);
  P := InitNewContext;
  ReinitContext(P);
end;

procedure HandleNewConnection(Ctx: PClientContext);
var
  s: String;
begin
  //TODO: Handle
  BufSetUsed(Ctx^.RecvBuf, Ctx^.Bytes);
  Ctx^.HTTPReq^.ClientAddr := StrPas(inet_ntoa(Ctx^.saPeer.sin_addr));
  Ctx^.HTTPReq^.ClientPort := Ctx^.saPeer.sin_port;

{$IFDEF XBUG}
  SetLength(s, Ctx^.RecvBuf^.Used);
  Move(Ctx^.RecvBuf^.Data^, S[1], Ctx^.RecvBuf^.Used);
{$IFDEF TRACK_SOCKET_SESSION}
  XINFO(Ctx^.xSession, Ctx^.Sock, 'Accept got data-' + #13#10 + IntToStr(Ctx^.RecvBuf^.Used) + ':' + S);
{$ELSE}
  INFO(Ctx^.Sock, 'Accept got data-' + #13#10 + IntToStr(Ctx^.RecvBuf^.Used) + ':' + S);
{$ENDIF}
{$ENDIF}

{$IFDEF ENABLE_STATS}
  StatsIncTotalConn;
  StatsIncCurrConn;
  {
  if (Ctx^.RecvBuf.Used > 0) then
    StatsRcvd(Ctx^.RecvBuf.Used);
  }
{$ENDIF}

  if ProcessRequests(Ctx) = False then
    SockRecv(Ctx, 1024);
end;

procedure HandleDataReceived(Ctx: PClientContext);
var
  s: String;
begin
  //TODO: Handle
  BufSetUsed(Ctx^.RecvBuf, Ctx^.Bytes);
{$IFDEF XBUG}
  SetLength(s, Ctx^.RecvBuf^.Used);
  Move(Ctx^.RecvBuf^.Data^, S[1], Ctx^.RecvBuf^.Used);
{$IFDEF TRACK_SOCKET_SESSION}
  XINFO(Ctx^.xSession, Ctx^.Sock, 'Recv got data-' + #13#10 + IntToStr(Ctx^.RecvBuf^.Used) + ':' + S);
{$ELSE}
  INFO(Ctx^.Sock, 'Recv got data-' + #13#10 + IntToStr(Ctx^.RecvBuf^.Used) + ':' + S);
{$ENDIF}

{$ENDIF}

{$IFDEF ENABLE_STATS}
{
  if (Ctx^.RecvBuf.Used > 0) then
    StatsRcvd(Ctx^.RecvBuf.Used);
}
{$ENDIF}

  if ProcessRequests(Ctx) = False then
    SockRecv(Ctx, 1024);
end;

procedure HandleDataSent(Ctx: PClientContext);
begin
{$IFDEF XBUG}
  //SetLength(s, Ctx^.Bytes + 1);
  //Move(Ctx^.SendBuf^.Data^, S[1], Ctx^.Bytes);
{$IFDEF TRACK_SOCKET_SESSION}
  XINFO(Ctx^.xSession, Ctx^.Sock, 'Sent ' + IntToStr(Ctx^.Bytes) + ' bytes' );
{$ELSE}
  INFO(Ctx^.Sock, 'Sent ' + IntToStr(Ctx^.Bytes) + ' bytes' );
{$ENDIF}

{$ENDIF}

  Inc(Ctx^.HTTPReq^.BytesSent, Ctx^.Bytes);

{$IFDEF ENABLE_STATS}
{
  if (Ctx^.Bytes > 0) then
    StatsSent(Ctx^.Bytes);
}
{$ENDIF}

  if (Ctx^.Bytes < Ctx^.SendBuf.Used) then
  begin
{$IFDEF XBUG}
{$IFDEF TRACK_SOCKET_SESSION}
  XINFO(Ctx^.xSession, Ctx^.Sock, IntToStr(Ctx^.Bytes) + ' bytes out of ' +IntToStr(Ctx^.sendbuf^.Used) + ' were sent. Sending the rest...');
{$ELSE}
  INFO(Ctx^.Sock, IntToStr(Ctx^.Bytes) + ' bytes out of ' +IntToStr(Ctx^.sendbuf^.Used) + ' were sent. Sending the rest...');
{$ENDIF}
{$ENDIF}
    BufRemove(Ctx^.SendBuf, Ctx^.Bytes);
    SockSend(Ctx);
  end
  else
  begin
{$IFDEF ENABLE_LOGGING}
    LogRequest(Ctx);
{$ENDIF}
{$IFDEF ENABLE_STATS}
    if (Ctx^.HTTPReq^.StatusCode < 400) then
      StatsSuccess;
{$ENDIF}

    BufRemove(Ctx^.SendBuf, -1);
    if Ctx^.HTTPReq^.KeepAlive then
    begin
{$IFDEF XBUG}
{$IFDEF TRACK_SOCKET_SESSION}
      XINFO(Ctx^.xSession, Ctx^.Sock, 'Keep-Alive=' +IntToStr(Ctx^.HTTPReq^.KACount) + ' receiving...');
{$ELSE}
      INFO(Ctx^.Sock, 'Keep-Alive=' +IntToStr(Ctx^.HTTPReq^.KACount) + ' receiving...');
{$ENDIF}
{$ENDIF}

      HTTPRequestReset(Ctx^.HTTPReq);
      BufRemove(Ctx^.RecvBuf, -1);
      SockRecv(Ctx, MAX_RECV_BUF_SIZE);
    end
    else
    begin
{$IFDEF XBUG}
{$IFDEF TRACK_SOCKET_SESSION}
      XINFO(Ctx^.xSession, Ctx^.Sock, 'Keep-Alive=' +IntToStr(Ctx^.HTTPReq^.KACount) + ' Closing socket...');
{$ELSE}
      INFO(Ctx^.Sock, 'Keep-Alive=' +IntToStr(Ctx^.HTTPReq^.KACount) + ' Closing socket...');
{$ENDIF}
{$ENDIF}
      CloseConn(Ctx);
    end;
  end;
end;

procedure RecycleContext(var Ctx: PClientContext);
begin
  with Ctx^ do
  begin
    if Sock <> INVALID_SOCKET then
    begin
{$IFDEF ENABLE_STATS}
      StatsDecCurrConn;
{$ENDIF}

      if RecvBuf^.TotalSize > (2 * ACCEPT_BUF_SIZE) then
        BufShrink(RecvBuf, ACCEPT_BUF_SIZE);

      if SendBuf^.TotalSize > (2 * MAX_SEND_BUF_SIZE) then
        BufShrink(SendBuf, MAX_SEND_BUF_SIZE);

      HTTPRequestReset(HTTPReq);

      HTTPReq^.KACount := 0;
      HTTPReq^.KeepAlive := False;

      State    := stAccepting;
      SendFile := False;
      DisconnectAfterSend := False;

      Inc(ReuseCount);

      if not AcceptEx(g_ListenSock, Sock, @RecvBuf^.Data^,
        ACCEPT_BUF_SIZE, SOCKADDRIN_SIZE + 16, SOCKADDRIN_SIZE +
        16, Bytes, Pointer(Ctx)) then
      begin
        if WSAGetLastError <> ERROR_IO_PENDING then
        begin
{$IFDEF ENABLE_LOGGING}
          LogSockError(Ctx, 'AcceptEx');
{$ENDIF}
          DeleteContext(Ctx);
          AcceptNewConn;
        end;
      end;
{$IFDEF XBUG}
{$IFDEF TRACK_SOCKET_SESSION}
      XINFO(Ctx^.xSession, Ctx^.Sock, 'Accepting new connection...');
{$ELSE}
      INFO(Ctx^.Sock, 'Accepting new connection...');
{$ENDIF}
{$ENDIF}
    end;
  end;
end;

procedure HandleFileSent(Ctx: PClientContext);
begin
{$IFDEF XBUG}
{$IFDEF TRACK_SOCKET_SESSION}
  if Ctx^.DisconnectAfterSend then
    XINFO(Ctx^.xSession, Ctx^.Sock, 'File was sent. Now disconnecting')
  else
    XINFO(Ctx^.xSession, Ctx^.Sock, 'File was sent. Now re-reading');
{$ELSE}
  if Ctx^.DisconnectAfterSend then
    INFO(Ctx^.Sock, 'File was sent. Now disconnecting')
  else
    INFO(Ctx^.Sock, 'File was sent. Now re-reading');
{$ENDIF}
{$ENDIF}

{$IFDEF ENABLE_STATS}
{
  if (Ctx^.Bytes > 0) then
    StatsSent(Ctx^.Bytes);
}
  StatsSuccess;
{$ENDIF}

  Inc(Ctx^.HTTPReq^.BytesSent, Ctx^.Bytes);
{$IFDEF ENABLE_LOGGING}
  LogRequest(Ctx);
{$ENDIF}

  if Ctx^.DisconnectAfterSend then
    RecycleContext(Ctx)
  else
  begin
    HTTPRequestReset(Ctx^.HTTPReq);
    BufRemove(Ctx^.RecvBuf, -1);
    SockRecv(Ctx, MAX_RECV_BUF_SIZE);
  end;
end;

{$IFDEF REUSE_SOCKET}
procedure HandleDisconnect(Ctx: PClientContext);
begin
  RecycleContext(Ctx);
end;
{$ENDIF}

procedure ScavengeStaleConnections(TimeOutSecs: Cardinal);
var
  P: PClientContext;
  I, J, Seconds, Len: Integer;
  //MinTime: Cardinal;
begin
  //MinTime := (TimeOutSecs * 1000);
  g_Lock.Enter;
  try
    J := Pred(g_ClientList.Count);
    for I := 0 to J do
    begin
      P := PClientContext(g_ClientList[I]);
      Len := SizeOf(Integer);
      if getsockopt(P^.Sock, SOL_SOCKET, SO_CONNECT_TIME, @Seconds, Len) = 0 then
      begin
        if (Seconds <> -1) and (Seconds > TimeOutSecs) then
        begin
{$IFDEF ENABLE_LOGGING}
          LogDebug(P, 'Socket idle for ' + IntToStr(Seconds) + ' seconds');
{$ENDIF}
          CloseConn(P, True);
        end;  
      end;  
    end;
  finally
    g_Lock.Leave;
  end;
end;  

{$IFDEF XBUG}
procedure DumpActiveConns;
const
  STATES: array [TIOState] of string =
  ('stClosed', 'stAccepting', 'stReading', 'stWriting', 'stSendingFile', 'stDisconnect');
var
  I: Integer;
  P: PClientContext;
  S: string;
begin
  g_Lock.Enter;
  try
    s := 'Active connections: ' + IntToStr(g_ClientList.Count) + #13#10;
    for I := 0 to g_ClientList.Count - 1 do
    begin
      P := PClientContext(g_ClientList[I]);
      if (P <> nil) then
      begin
        s := s + 'List index: ' + IntToStr(I) + #13#10;
        s := s + 'Socket: ' + IntToStr(p^.Sock)+ #13#10;
        s := s + 'State: ' + STATES[p^.State]+ #13#10;
        s := s + '----------------------------'+ #13#10;
        //s := s + 'Remote addr: ' + inet_ntoa(p^.saPeer) + #13#10;
        //s := s + 'Local addr: '+inet_ntoa(P^.saLocal) + #13#10;
      end;
    end;
  finally
    g_Lock.Leave;
  end;
  INFO(0, s);
end;
{$ENDIF}

end.
