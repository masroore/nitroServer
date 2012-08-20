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
// $Version:0.6.2$ $Revision:1.5.1.0$ $Author:masroore$ $RevDate:9/30/2007 21:38:12$
//
////////////////////////////////////////////////////////////////////////////////

unit IOCPWorker;

interface

{$I NITROHTTPD.INC}

uses
  Windows, WinSock, Winsock2, Common,
   {$IFDEF GZIP_COMPRESS} GZipDataCache, {$ENDIF} FileDataCache;

function IOCPWorkerThread(Param: Pointer): Integer;

procedure SockRecv(Ctx: PClientContext; BytesToRead: Cardinal);
procedure SockSend(Ctx: PClientContext);
procedure SockSendCachedFile(Ctx: PClientContext; CachedData: PAnsiChar;
                             CacheSize: Cardinal; CacheEntry: PFileDataCache);
{$IFDEF GZIP_COMPRESS}
procedure SockSendCachedGzFile(Ctx: PClientContext; CachedData: PAnsiChar;
                               CacheSize: Cardinal; CacheEntry: PFileGZCache);
{$ENDIF}
procedure SockTransmitFile(Ctx: PClientContext; Disconnect: Boolean);

{$IFDEF REUSE_SOCKET}
procedure SockDisconnect(Ctx: PClientContext);
{$ENDIF}

procedure HandleIOCompletion(Ctx: PClientContext);

implementation

uses
{$IFDEF XBUG}
  {$IFDEF TRACK_SOCKET_SESSION}
  SiAuto,
  SmartInspect,
  {$ENDIF}
  uDebug,
{$ENDIF}
  SysUtils,
  Buffer,
  CachedLogger,
{$IFDEF BUSINESS_LOGIC_THREADPOOL}
  BusinessThreadPool,
{$ENDIF}
  HTTPConn,
  VirtualFileIO;

var
  g_hIOCP:      THandle;
  g_ListenSock: TSocket;

procedure SockRecv(Ctx: PClientContext; BytesToRead: Cardinal);
var
  Flags: Cardinal;
  Res:   Integer;
begin
  with Ctx^ do
  begin
    if RecvBuf^.Available < BytesToRead then
      BufReserve(RecvBuf, BytesToRead);

    State      := stReading;
    Bytes      := BytesToRead;
    wbRecv.buf := BufGetWritePos(RecvBuf);
    wbRecv.len := BytesToRead;

    ZeroMemory(@Ovl, SizeOf(TOverlapped));

    Flags := 0;
    Res   := WSARecv(Sock, @wbRecv, 1, Bytes, Flags, POverlapped(Ctx), nil);
    if (Res = SOCKET_ERROR) and (WSAGetLastError <> WSA_IO_PENDING) then
    begin
{$IFDEF ENABLE_LOGGING}
      LogSockError(Ctx, 'WSARecv');
{$ENDIF}
      CloseConn(Ctx, True);
    end
    else
    begin
{$IFDEF XBUG}
{$IFDEF TRACK_SOCKET_SESSION}
        XINFO(Ctx^.xSession, Ctx^.Sock, 'Receiving...');
{$ELSE}
        INFO(Ctx^.Sock, 'Receiving...');
{$ENDIF}
{$ENDIF}
    end;
  end;
end;

procedure SockSend(Ctx: PClientContext);
var
  B: BOOL;
  Res, Err:   Integer;
begin
  with Ctx^ do
  begin
    State             := stWriting;
    SendFile          := False;
    SendCacheType     := scNone;
    DataCache         := nil;
    ZeroMemory(@Ovl, SizeOf(TOverlapped));

{$IFDEF TRANSMIT_PACKETS}
    if SendBuf^.Used > 0 then
    begin
      tpSend[0].cLength   := SendBuf^.Used;
      tpSend[0].pBuffer   := SendBuf^.Data;
      tpSend[0].dwElFlags := TP_ELEMENT_MEMORY;

      tpSend[1].cLength   := 0;
      tpSend[1].pBuffer   := nil;
      tpSend[1].dwElFlags := TP_ELEMENT_EOP;
    end;

    B := TransmitPackets(Sock, @tpSend, 1, 0,
                         POverlapped(Ctx), TP_USE_KERNEL_APC) ;

    if (not B) and (WSAGetLastError <> WSA_IO_PENDING) then
{$ELSE}
    wbSend[0].len := SendBuf^.Used;
    wbSend[0].buf := SendBuf^.Data;

    Res   := WSASend(Sock, @wbSend, 1, Bytes, 0, POverlapped(Ctx), nil);
    if (Res = SOCKET_ERROR) and (WSAGetLastError <> WSA_IO_PENDING) then
{$ENDIF}
    begin
{$IFDEF ENABLE_LOGGING}
      LogSockError(Ctx, 'WSASend/TransmitPacket');
{$ENDIF}
      CloseConn(Ctx, True);
    end
    else
    begin
{$IFDEF XBUG}
{$IFDEF TRACK_SOCKET_SESSION}
        XINFO(Ctx^.xSession, Ctx^.Sock, 'Sending ' + IntToStr(wbSend[0].len) + '...');
{$ELSE}
        INFO(Ctx^.Sock, 'Sending ' + IntToStr(SendBuf^.Used) + ' bytes...');
{$ENDIF}
{$ENDIF}
    end;
  end;
end;

procedure SockSendCachedFile(Ctx: PClientContext; CachedData: PAnsiChar;
                             CacheSize: Cardinal; CacheEntry: PFileDataCache);
var
  B:         BOOL;
  Res, Err:  Integer;
begin
  with Ctx^ do
  begin
    State     := stWriting;
    SendFile  := False;
    SendCacheType := scDataCache;
    DataCache := CacheEntry;
    ZeroMemory(@Ovl, SizeOf(TOverlapped));

{$IFDEF TRANSMIT_PACKETS}
    if SendBuf^.Used > 0 then
    begin
      tpSend[0].cLength   := SendBuf^.Used;
      tpSend[0].pBuffer   := Pointer(SendBuf^.Data);
      tpSend[0].dwElFlags := TP_ELEMENT_MEMORY;

      tpSend[1].cLength   := CacheSize;
      tpSend[1].pBuffer   := Pointer(CachedData);
      tpSend[1].dwElFlags := TP_ELEMENT_MEMORY;
    end;
    Err := Integer(@Ctx);
    B := TransmitPackets(Sock, @tpSend, 2, 0,
                         POverlapped(Ctx), TP_USE_KERNEL_APC) ;

    if (not B) and (WSAGetLastError <> WSA_IO_PENDING) then
{$ELSE}
    wbSend[0].len := SendBuf^.Used;
    wbSend[0].buf := SendBuf^.Data;

    wbSend[1].len := CacheSize;
    wbSend[1].buf := CachedData;

    //Flags := 0;
    Res   := WSASend(Sock, @wbSend, 2, Bytes, 0, POverlapped(Ctx), nil);
    if (Res = SOCKET_ERROR) and (WSAGetLastError <> WSA_IO_PENDING) then
{$ENDIF}
    begin
{$IFDEF ENABLE_LOGGING}
      LogSockError(Ctx, 'WSASend/TransmitPacket');
{$ENDIF}
      CloseConn(Ctx, True);
    end
    else
    begin

{$IFDEF XBUG}
{$IFDEF TRACK_SOCKET_SESSION}
        XINFO(Ctx^.xSession, Ctx^.Sock, 'Sending ' + IntToStr(wbSend[0].len) + '...');
{$ELSE}
        //INFO(Ctx^.Sock, 'Sending ' + IntToStr(tpSend[0].cLength + tpSend[1].cLength) + '...');
        //INFO(Ctx^.Sock, IntToStr(WSAGetLastError) + ' = ' + SysErrorMessage(WSAGetLastError) +  ' on TxPacket');
        INFO(Ctx^.Sock, 'Sending ' + IntToStr(wbSend[0].len + wbSend[1].len ) + '...');
{$ENDIF}
{$ENDIF}
    end;
  end;
end;

{$IFDEF GZIP_COMPRESS}
procedure SockSendCachedGzFile(Ctx: PClientContext; CachedData: PAnsiChar;
                               CacheSize: Cardinal; CacheEntry: PFileGZCache);
var
  B:         BOOL;
  Res, Err:  Integer;
begin
  with Ctx^ do
  begin
    State     := stWriting;
    SendFile  := False;
    SendCacheType := scGZipCache;
    DataCache := CacheEntry;
    ZeroMemory(@Ovl, SizeOf(TOverlapped));

{$IFDEF TRANSMIT_PACKETS}
    if SendBuf^.Used > 0 then
    begin
      tpSend[0].cLength   := SendBuf^.Used;
      tpSend[0].pBuffer   := Pointer(SendBuf^.Data);
      tpSend[0].dwElFlags := TP_ELEMENT_MEMORY;

      tpSend[1].cLength   := CacheSize;
      tpSend[1].pBuffer   := Pointer(CachedData);
      tpSend[1].dwElFlags := TP_ELEMENT_MEMORY;
    end;
    Err := Integer(@Ctx);
    B := TransmitPackets(Sock, @tpSend, 2, 0,
                         POverlapped(Ctx), TP_USE_KERNEL_APC) ;

    if (not B) and (WSAGetLastError <> WSA_IO_PENDING) then
{$ELSE}
    wbSend[0].len := SendBuf^.Used;
    wbSend[0].buf := SendBuf^.Data;

    wbSend[1].len := CacheSize;
    wbSend[1].buf := CachedData;

    //Flags := 0;
    Res   := WSASend(Sock, @wbSend, 2, Bytes, 0, POverlapped(Ctx), nil);
    if (Res = SOCKET_ERROR) and (WSAGetLastError <> WSA_IO_PENDING) then
{$ENDIF}
    begin
{$IFDEF ENABLE_LOGGING}
      LogSockError(Ctx, 'WSASend/TransmitPacket');
{$ENDIF}
      CloseConn(Ctx, True);
    end
    else
    begin

{$IFDEF XBUG}
{$IFDEF TRACK_SOCKET_SESSION}
        XINFO(Ctx^.xSession, Ctx^.Sock, 'Sending ' + IntToStr(wbSend[0].len) + '...');
{$ELSE}
        //INFO(Ctx^.Sock, 'Sending ' + IntToStr(tpSend[0].cLength + tpSend[1].cLength) + '...');
        //INFO(Ctx^.Sock, IntToStr(WSAGetLastError) + ' = ' + SysErrorMessage(WSAGetLastError) +  ' on TxPacket');
        INFO(Ctx^.Sock, 'Sending ' + IntToStr(wbSend[0].len + wbSend[1].len ) + '...');
{$ENDIF}
{$ENDIF}
    end;
  end;
end;
{$ENDIF}

procedure SockTransmitFile(Ctx: PClientContext; Disconnect: Boolean);
const
  TF_MAP: array [Boolean] of DWORD = (TF_USE_KERNEL_APC,
                                      TF_USE_KERNEL_APC or TF_REUSE_SOCKET or TF_DISCONNECT);
var
  Res: BOOL;
begin
  with Ctx^ do
  begin
    State := stSendingFile;
    SendFile  := True;
    SendCacheType := scNone;
    DataCache := nil;
    ZeroMemory(@Ovl, SizeOf(TOverlapped));
    if SendBuf^.Used > 0 then
    begin
      TxBuf^.Head       := Pointer(SendBuf^.Data);
      TxBuf^.HeadLength := SendBuf^.Used;

      TxBuf^.Tail       := nil;
      TxBuf^.TailLength := 0;
    end;

    DisconnectAfterSend := Disconnect;
    Res := VFileTransmit(FileHandle, Sock, FileSize, 0, POverlapped(Ctx),
                         TxBuf, TF_MAP[Disconnect]);

    if (not Res) and (WSAGetLastError <> WSA_IO_PENDING) then
    begin
{$IFDEF ENABLE_LOGGING}
      LogWarn(Ctx, 'TransmitFile');
{$ENDIF}
      CloseConn(Ctx, True);
    end
    else
    begin
{$IFDEF XBUG}
{$IFDEF TRACK_SOCKET_SESSION}
        XINFO(Ctx^.xSession, Ctx^.Sock, 'Transmitting file... ' + IntToStr(Ctx^.FileHandle));
{$ELSE}
        INFO(Ctx^.Sock, 'Transmitting file... ' + IntToStr(Ctx^.FileHandle));
{$ENDIF}
{$ENDIF}
    end;
  end;
end;

{$IFDEF REUSE_SOCKET}
procedure SockDisconnect(Ctx: PClientContext);
begin
  with Ctx^ do
  begin
    State := stDisconnect;
    ZeroMemory(@Ovl, SizeOf(TOverlapped));
  {$IFDEF XP_OR_HIGHER}
    DisconnectEx(Sock,
                 POverlapped(Ctx),
                 DE_REUSE_SOCKET,
                 0);
  {$ELSE}
    TransmitFile(Sock,
                 0,
                 0,
                 0,
                 POverlapped(Ctx),
                 nil,
                 TF_DISCONNECT or TF_REUSE_SOCKET);
  {$ENDIF}
  end;
end;
{$ENDIF}

procedure HandleIOCompletion(Ctx: PClientContext);
var
  LocLen, RemLen: Integer;
  pLoc, pRem:     PSockAddr;
begin
  with Ctx^ do
    case Ctx^.State of
      stAccepting:
      begin
        //AcceptNewConn(g_hIOCP);
{$IFDEF ENABLE_LOGGING}
        LogDebug(Ctx, 'Client connected from ' + inet_ntoa(Ctx^.saPeer.sin_addr));
{$ENDIF}
        GetAcceptExSockaddrs(@RecvBuf^.Data, ACCEPT_BUF_SIZE,
          SOCKADDRIN_SIZE + 16, SOCKADDRIN_SIZE + 16,
          pLoc, LocLen,
          pRem, RemLen);

        Move(pLoc, saLocal, SizeOf(saLocal));
        Move(pRem, saPeer, SizeOf(saPeer));

{$IFDEF REUSE_SOCKET}
        if (ReuseCount > 0) then
        begin
          if setsockopt(Sock, SOL_SOCKET, SO_UPDATE_ACCEPT_CONTEXT,
            @g_ListenSock, sizeof(TSocket)) = SOCKET_ERROR then
          begin
{$IFDEF ENABLE_LOGGING}
            LogSockError(Ctx, 'setsockopt(SO_UPDATE_ACCEPT_CONTEXT');
{$ENDIF}
            CloseConn(Ctx, True, True);
            Exit;
          end;
        end;
{$ENDIF}

        if (ReuseCount = 0) then
        begin
          if CreateIoCompletionPort(Sock, hIOCP, Integer(Ctx), 0) = 0 then
          begin
{$IFDEF ENABLE_LOGGING}
            LogSockError(Ctx, 'CreateIOCompletion(client socket)');
{$ENDIF}
            CloseConn(Ctx, True, False);
            DeleteContext(Ctx);
            Exit;
          end;
        end;

        HandleNewConnection(Ctx);
      end;
      stReading:
      begin
        if (Bytes = Cardinal(SOCKET_ERROR)) then
          CloseConn(Ctx, True)
        else if (Bytes = 0) then
          CloseConn(Ctx)
        else
          HandleDataReceived(Ctx);
      end;
      stWriting:
      begin
        if SendCacheType = scDataCache then
        begin
          DataCacheDoneWith(DataCache, False);
          SendCacheType := scNone;
        end
        else
        if SendCacheType = scGZipCache then
        begin
{$IFDEF GZIP_COMPRESS}
          GZCacheDoneWith(DataCache, False);
{$ENDIF}
          SendCacheType := scNone;
        end;

        if (Bytes = Cardinal(SOCKET_ERROR)) then
          CloseConn(Ctx, True)
        else if (Bytes = 0) then
          CloseConn(Ctx)
        else
          HandleDataSent(Ctx);
      end;
      stSendingFile:
      begin
{$IFDEF XBUG}
        INFO(Ctx^.Sock, 'File was sent. Closing file handle.');
{$ENDIF}
        SendFile := False;
        if (FileHandle <> -1) then
          VFileClose(FileHandle);
        FileHandle  := -1;

        if (Bytes = Cardinal(SOCKET_ERROR)) then
          CloseConn(Ctx, True)
        else if (Bytes = 0) then
          CloseConn(Ctx, True)
        else
          HandleFileSent(Ctx);
      end;
{$IFDEF REUSE_SOCKET}
      stDisconnect:
      begin
        if SendFile then
        begin
{$IFDEF XBUG}
          INFO(Ctx^.Sock, 'Disconnect complete. Closing file handle.');
{$ENDIF}
          SendFile := False;
          if (FileHandle <> -1) then
            VFileClose(FileHandle);
          FileHandle  := -1;
        end;

        HandleDisconnect(Ctx);
      end;
{$ENDIF}
    end;
end;

function IOCPWorkerThread(Param: Pointer): Integer;
{$IFDEF XBUG}
const
  STATES: array [TIOState] of string =
  ('stClosed', 'stAccepting', 'stReading', 'stWriting', 'stSendingFile', 'stDisconnect');
{$ENDIF}
var
  BytesTransferred: Cardinal;
  Key:     Cardinal;
  Retval:  Longbool;
  pov:     PClientContext;
  hIOCP:   THandle;
  sListen: TSocket;
begin
  hIOCP   := THandle(Param^);
  sListen := TSocket(Pointer(Integer(Param) + SizeOf(Cardinal))^);

  if (hIOCP = 0) or (hIOCP = INVALID_HANDLE_VALUE) or (sListen = INVALID_SOCKET) then
  begin
{$IFDEF ENABLE_LOGGING}
    LogCrit(nil, 'No I/O completion port or listenner socket found!');
{$ENDIF}
    Exit;
  end;

  InterlockedExchange(Integer(g_hIOCP), hIOCP);
  InterlockedExchange(LongInt(g_ListenSock), LongInt(sListen));

  while True do
  begin
    Retval := GetQueuedCompletionStatus(hIOCP, BytesTransferred, Key,
      POverlapped(pov), INFINITE);

{$IFDEF XBUG}
    INFO(0, 'GQCS: ' + IntToStr(Integer(Retval)) + ' Bytes: ' +
    IntToStr(BytesTransferred) + ' Key: ' + IntToStr(Key));
{$ENDIF}

    if Key = SHUTDOWN_FLAG then
    begin
{$IFDEF ENABLE_LOGGING}
      LogDebug(nil, 'Shutting down IOCP worker thread...');
{$ENDIF}
      Sleep(100);
      Break;
    end;

    if (pov <> nil) then
      pov^.Bytes := BytesTransferred;

    if (not Retval) or ((BytesTransferred <= 0) and (pov^.State <> stDisconnect)) then
    begin
{$IFDEF XBUG}
      if not Retval then
{$IFDEF TRACK_SOCKET_SESSION}
        XINFO(pov^.xSession, pov^.Sock, STATES[pov^.State] + ' ReturnValue = False ' + SysErrorMessage(WSAGetLastError))
{$ELSE}
        INFO(pov^.Sock, 'ReturnValue = False ' + SysErrorMessage(WSAGetLastError))
{$ENDIF}
      else
{$IFDEF TRACK_SOCKET_SESSION}
        XINFO(pov^.xSession, pov^.Sock, 'Bytes <= 0');
{$ELSE}
        INFO(pov^.Sock, 'Bytes <= 0');
{$ENDIF}
{$ENDIF}

      CloseConn(pov, True);

        Continue;
    end;
{$IFDEF BUSINESS_LOGIC_THREADPOOL}
    BusinessPoolQueueJob(pov);
{$ELSE}
    HandleIOCompletion(pov);
{$ENDIF}
  end;

  Result := 0;
end;

end.
