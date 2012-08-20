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
// $Version:0.6.2$ $Revision:1.1.1.0$ $Author:masroore$ $RevDate:9/30/2007 21:38:12$
//
////////////////////////////////////////////////////////////////////////////////

unit ScriptThreadPool;

interface

uses
  Windows, Common;

procedure ScriptPoolCreate(const MaxThreads: Cardinal = 4);
procedure ScriptPoolShutDown;
procedure ScriptPoolQueueJob(Ctx: PClientContext);

implementation

{$I NITROHTTPD.INC}

uses
{$ifdef xbug}
  uDebug,
{$endif}
{$IFDEF FPC}
  WinSock2,
{$ENDIF}
{$IFDEF ENABLE_STATS}
  ServerStats,
{$ENDIF}
  IOCPWorker,
  SysUtils,
  Buffer,
  HTTPResponse,
  FastDateCache,
  FileDataCache,
  MimeType,
{$IFDEF ENABLE_LOGGING}
  CachedLogger,
{$ENDIF}
{$IFDEF PHP_DIRECT_EXECUTE}
  PHPEngine,
{$ENDIF}
  CGIEngine,
  ISAPIEngine;

var
  g_ThreadsCount: Cardinal = 0;
  g_ScriptThreads: array of THandle;
  g_ScriptPort: THandle;
  g_ScriptClosed: Boolean;

procedure CGIHeadersToHTTPHeader(Headers: PCGIHeaders; ContentLen: Integer; OutBuf: PSmartBuffer);
var
  I: Integer;
begin
  if (Headers^.Location[0] <> #0) then
  begin
    { TODO : Handle 302 re-direction }
    BufAppendStrZ(OutBuf, 'HTTP/1.1 302 Moved Temporarily' + EOL_MARKER);
    BufAppendStrZ(OutBuf, 'Location: ');
    BufAppendStrZ(OutBuf, Headers^.Location);
    BufAppendStrZ(OutBuf, EOL_MARKER);
  end
  else
  begin
    if Headers^.Status[0] <> #0 then
    begin
      BufAppendStrZ(OutBuf, 'HTTP/1.1 ');
      BufAppendStrZ(OutBuf, Headers^.Status);
      BufAppendStrZ(OutBuf, EOL_MARKER);
    end
    else
      BufAppendStrZ(OutBuf, 'HTTP/1.1 200 OK+' + #13#10);
  end;

  if (Headers^.ContType[0] <> #0) then
  begin
    BufAppendStrZ(OutBuf, 'Content-Type: ');
    BufAppendStrZ(OutBuf, Headers^.ContType);
    BufAppendStrZ(OutBuf, EOL_MARKER);
  end
  else
    BufAppendStrZ(OutBuf, 'Content-Type: text/html' + #13#10);

  if (Headers^.Pragma[0] <> #0) then
  begin
    BufAppendStrZ(OutBuf, 'Pragma: ');
    BufAppendStrZ(OutBuf, Headers^.Pragma);
    BufAppendStrZ(OutBuf, EOL_MARKER);
  end;

  if Headers^.NumCustom > 0 then
  begin
    for I := 1 to Headers^.NumCustom do
    begin
      BufAppendStrZ(OutBuf, Headers^.CustomHeaders[I]);
      BufAppendStrZ(OutBuf, EOL_MARKER);
    end;
  end;

  BufAppendStrZ(OutBuf, PAnsiChar('Content-Length: ' + IntToStr(ContentLen) + EOL_MARKER));
{$IFDEF CACHE_HTTP_DATE}
  BufAppendStrZ(OutBuf, PAnsiChar('Date: ' + HTTPDateCached(Now) + EOL_MARKER));
{$ELSE}
  BufAppendStrZ(OutBuf, PAnsiChar('Date: ' + HTTPDate(Now) + EOL_MARKER));
{$ENDIF}
  BufAppendStrZ(OutBuf, PAnsiChar('Connection: Close' + EOL_MARKER));
  BufAppendStrZ(OutBuf, 'Server: ' + SERVER_SIGNATURE + EOH_MARKER);
end;

{$IFDEF PHP_DIRECT_EXECUTE}
const
  PHP_DLL_PATH ='C:\WAMP5\PHP\PHP5TS.DLL';
var
  PHPLoaded: Boolean = False;

procedure LoadPHPLibrary(const DLLPath, INIPath: string);
begin
  if not PHPLoaded then
  begin
    InitEngine(DLLPath, INIPath);
    PHPLoaded := True;
  end;
end;

procedure UnloadPHPLibrary;
begin
  if PHPLoaded then
  begin
    StopEngine;
    PHPLoaded := False;
  end;
end;

function ScriptRunPHPBuffered(var Ctx: PClientContext): Boolean;
var
  sScript: PAnsiChar;
  I:      Integer;
  FLen: Cardinal;
  Interpreted: Boolean;
  CGIBuf: PSmartBuffer;
begin
(*
  Result := False;

  LoadPHPLibrary(PHP_DLL_PATH, ExtractFileDir(PHP_DLL_PATH));

  with Ctx^ do
  begin
    if GetFileBufFromCache(HTTPReq^.Filename, sScript) then
    begin
      LogDebug(Ctx, 'Running PHP...' + HTTPReq^.Filename);
      BufCreate(CGIBuf, MAX_BUF_SIZE);
      BufRemove(Ctx^.SendBuf, -1);


      Result := PHPExecuteCode(Ctx,
                            HTTPReq^.Filename,
                            ExtractFilePath(HTTPReq^.Filename),
                            sScript,
                            CGIBuf);
      StrDispose(sScript);
      LogDebug(Ctx, 'finished PHP!');
    end;

    if (not Result) then
    begin
      HTTPReq^.StatusCode := 500;
      HTTPReq^.KeepAlive  := False;

      BufFree(CGIBuf);
{$IFDEF ENABLE_STATS}
      StatsFailedReq;
{$ENDIF}

      HTTPEmitBadRequest(Ctx);
      Result := True;
      Exit;
    end;

    HTTPReq^.KeepAlive := False;

{$IFDEF CACHE_HTTP_HEADERS}
    GetHeaderFromCache(Ctx, HTTPReq^.Filename,
      Now, CGIBuf^.Used, HTTPReq, SendBuf);
{$ELSE}
    HTTPBuildHeader(SendBuf, GetMIMEType(HTTPReq^.Filename),
      Now, CGIBuf^.Used, HTTPReq);
{$ENDIF}
    BufAppendData(SendBuf, CGIBuf^.Data, CGIBuf^.Used);
    BufFree(CGIBuf);

    Result := True;
    SockSend(Ctx);
  end;
*)
end;

function ScriptRunPHP(var Ctx: PClientContext): Boolean;
var
  Interpreted: Boolean;
  CGIBuf: PSmartBuffer;
  pCGI:   PCGIHeaders;
  I:      Integer;
begin
  Result := False;
  LoadPHPLibrary(PHP_DLL_PATH, ExtractFileDir(PHP_DLL_PATH));

  with Ctx^ do
  begin
{$IFDEF ENABLE_LOGGING}
    LogDebug(Ctx, 'Running PHP...' + HTTPReq^.Filename);
{$ENDIF}
{$IFDEF XBUG}
    INFO(Ctx^.Sock, 'Running PHP...' + HTTPReq^.Filename);
{$ENDIF}

    BufCreate(CGIBuf, MAX_SEND_BUF_SIZE);
    BufRemove(Ctx^.SendBuf, -1);
    pCGI := AllocMem(SizeOf(TCGIHeaders));
    Result := PHPExecuteScript(Ctx,
                              HTTPReq^.Filename,
                              ExtractFilePath(HTTPReq^.Filename),
                              pCGI,
                              CGIBuf);
{$IFDEF ENABLE_LOGGING}
    LogDebug(Ctx, 'Finished PHP!');
{$ENDIF}
{$IFDEF XBUG}
    INFO(Ctx^.Sock, 'Finished PHP!' + HTTPReq^.Filename);
    //DUMP('PHP output', PAnsiChar(CGIBuf^.Data), CGIBuf^.Used); 
{$ENDIF}

    if (not Result) then
    begin
      HTTPReq^.StatusCode := 500;
      HTTPReq^.KeepAlive  := False;
      BufFree(CGIBuf);
      FreeMem(pCGI);

{$IFDEF ENABLE_STATS}
      StatsFailedReq;
{$ENDIF}
      HTTPEmitBadRequest(Ctx);
      Result := True;
      Exit;
    end;

    //if not NonParsed then
    begin
      CGIHeadersToHTTPHeader(pCGI, CGIBuf^.Used, SendBuf);
      FreeMem(pCGI);
    end;

    HTTPReq^.KeepAlive := False;
    BufAppendData(SendBuf, CGIBuf^.Data, CGIBuf^.Used);
    BufFree(CGIBuf);

    Result := True;

    SockSend(Ctx);

  end;
end;

{$ENDIF PHP_DIRECT_EXECUTE}

function ScriptRunCGI(var Ctx: PClientContext): Boolean;
var
  sScript, sCGIErr: String;
  pCGI:   PCGIHeaders;
  I:      Integer;
  Interpreted, NonParsed: Boolean;
  CGIBuf: PSmartBuffer;
begin
  Result := False;

  with Ctx^ do
  begin
    CGIGetInfo(HTTPReq^.Filename, sScript, Interpreted, NonParsed);

    BufCreate(CGIBuf, MAX_SEND_BUF_SIZE);

    Result := CGIExecuteScript(Ctx, sScript,
                               ExtractFilePath(HTTPReq^.Filename),
                               CGIBuf, sCGIErr);

    if (sCGIErr <> '') then
    begin
      BufFree(CGIBuf);

      HTTPReq^.StatusCode := 502;
      HTTPReq^.KeepAlive  := False;

      HTTPBuildHTMLResponse(SendBuf, 'Bad gateway', 'CGI error', sCGIErr, HTTPReq);

{$IFDEF ENABLE_STATS}
      StatsFailedReq;
{$ENDIF}

      Result := True;
      SockSend(Ctx);

      Exit;
    end;

    if (not Result) or (CGIBuf^.Used = 0) then
    begin
      HTTPReq^.StatusCode := 500;
      HTTPReq^.KeepAlive  := False;

      BufFree(CGIBuf);
{$IFDEF ENABLE_STATS}
      StatsFailedReq;
{$ENDIF}

      HTTPEmitBadRequest(Ctx);
      Result := True;
      Exit;
    end;

    if not NonParsed then
    begin
      pCGI := AllocMem(SizeOf(TCGIHeaders));
      CGIParseOutput(pCGI, CGIBuf^.Data, CGIBuf^.Used);

      if (pCGI^.HdrLen > 0) then
        BufRemove(CGIBuf, pCGI^.HdrLen);

      CGIHeadersToHTTPHeader(pCGI, CGIBuf^.Used, SendBuf);

      FreeMem(pCGI);
    end;

    HTTPReq^.KeepAlive := False;
    BufAppendData(SendBuf, CGIBuf^.Data, CGIBuf^.Used);
    BufFree(CGIBuf);

    Result := True;

    SockSend(Ctx);
  end;
end;

function ScriptRunISAPI(var Ctx: PClientContext): Boolean;
var
  ISAPIHdr:   PCGIHeaders;
  I:      Integer;
  Interpreted: Boolean;
  ISAPIBuf: PSmartBuffer;
begin
  Result := False;

  with Ctx^ do
  begin
    BufCreate(ISAPIBuf, MAX_SEND_BUF_SIZE);

    Result := ISAPIExecuteScript(HTTPReq^.Filename, Ctx, ISAPIBuf);

    if (not Result) or (ISAPIBuf^.Used = 0) then
    begin
      HTTPReq^.StatusCode := 500;
      HTTPReq^.KeepAlive  := False;

      BufFree(ISAPIBuf);
{$IFDEF ENABLE_STATS}
      StatsFailedReq;
{$ENDIF}

      HTTPEmitBadRequest(Ctx);
      Result := True;
      Exit;
    end;

    ISAPIHdr := AllocMem(SizeOf(TCGIHeaders));

    CGIParseOutput(ISAPIHdr, ISAPIBuf^.Data, ISAPIBuf^.Used);

    if (ISAPIHdr^.HdrLen > 0) then
      BufRemove(ISAPIBuf, ISAPIHdr^.HdrLen);

    CGIHeadersToHTTPHeader(ISAPIHdr, ISAPIBuf^.Used, SendBuf);

    FreeMem(ISAPIHdr);

    HTTPReq^.KeepAlive := False;

    BufAppendData(SendBuf, ISAPIBuf^.Data, ISAPIBuf^.Used);
    BufFree(ISAPIBuf);

    Result := True;
    HTTPReq^.KeepAlive := False;

    SockSend(Ctx);
  end;
end;
  
function ScriptWorkerThread(Param: Pointer): Integer;
var
  BytesTransferred: Cardinal;
  Key:     Cardinal;
  pov:     PClientContext;
  hPort:   THandle;
begin
  hPort   := g_ScriptPort;// PHandle(Param)^;
{$IFDEF XBUG}
  INFO(0, 'Script thread');
{$ENDIF}
  if (hPort = 0) or (hPort = INVALID_HANDLE_VALUE) then
  begin
{$IFDEF ENABLE_LOGGING}
    LogCrit(nil, 'Invalid script engine I/O completion port!');
{$ENDIF}
    Exit;
  end;

  while True do
  begin
    if g_ScriptClosed then
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

    case pov^.HTTPReq^.ScriptType of
{$IFDEF PHP_DIRECT_EXECUTE}
      stPHP:
        begin
          ScriptRunPHP(pov);
          //ScriptRunPHPBuffered(Ctx);
        end;
{$ENDIF}
      stCGI:
        begin
          ScriptRunCGI(pov);
        end;
      stISAPI:
        begin
          ScriptRunISAPI(pov);
        end;
    end;
  end;
  Result := 0;
end;

procedure ScriptPoolCreate(const MaxThreads: Cardinal = 4);
var
  I, ID: Cardinal;
begin
  g_ScriptPort := CreateIoCompletionPort(INVALID_HANDLE_VALUE, 0, 0, 0);
  if g_ScriptPort = 0 then
  begin
{$IFDEF ENABLE_LOGGING}
    LogCrit(nil, 'Error occurred while creating business logic I/O Completion Port: ' + SysErrorMessage(GetLastError));
{$ENDIF}
    Exit;
  end;

  g_ThreadsCount    := MaxThreads;
  g_ScriptClosed  := False;

  SetLength(g_ScriptThreads, g_ThreadsCount);
  for I := 0 to Pred(g_ThreadsCount) do
    g_ScriptThreads[I] := BeginThread(nil,
                                      0,
                                      @ScriptWorkerThread,
                                      Pointer(g_ScriptPort),
                                      0,
                                      ID);
end;

procedure ScriptPoolShutDown;
var
  I: Integer;
begin
  g_ScriptClosed := True;

  for I := 0 to g_ThreadsCount - 1 do
    PostQueuedCompletionStatus(g_ScriptPort, 0, 0, POverLapped(SHUTDOWN_FLAG));

  WaitForMultipleObjects(g_ThreadsCount, @g_ScriptThreads, True, INFINITE);

  CloseHandle(g_ScriptPort);
  g_ScriptPort  := INVALID_HANDLE_VALUE;
  g_ThreadsCount := 0;
end;

procedure ScriptPoolQueueJob(Ctx: PClientContext);
begin
  PostQueuedCompletionStatus(g_ScriptPort,
                             1,
                             1,
                             POverlapped(Ctx));
end;

initialization
finalization
{$IFDEF PHP_DIRECT_EXECUTE}
  UnloadPHPLibrary;
{$ENDIF}
end.
