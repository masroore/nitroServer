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

unit CachedLogger;

interface

{$I NITROHTTPD.INC}

{$IFDEF ENABLE_LOGGING}

uses
  Windows, WinSock, Common, Classes;

type
  TLogHookDebugProc = procedure(const AThreadID: DWORD; ASock: TSocket; const
    Msg: string);
  TLogHookErrorProc = procedure(const AThreadID: DWORD; ASock: TSocket; const
    Msg: string);
  TLogHookAccessProc = procedure(const ClientAddr: TInAddr; const StatusCode:
    Byte; const Doc: string);

type
  TLogLevel = (llNone, llCritical, llWarn, llAccess, llDebug);

procedure LogInit;
procedure LogShutdown;

procedure LogSetDir(const ADirName: string);
procedure LogSetCacheMaxSize(const ASize: Integer);
procedure LogSetCacheFlushInterval(const ASeconds: Cardinal);
procedure LogSetLevel(ALevel: TLogLevel);

function LogGetDir: string;
function LogGetCacheMaxSize: Integer;
function LogGetCacheFlushInterval: Integer;
function LogGetLevel: TLogLevel;

procedure LogSetErrorHook(Proc: TLogHookErrorProc);
procedure LogSetDebugHook(Proc: TLogHookDebugProc);
procedure LogSetAccessHook(Proc: TLogHookAccessProc);

procedure LogFlushCache;
procedure LogFlushCacheNow;

procedure LogRequest(Ctx: PClientContext);
procedure LogCrit(Ctx: PClientContext; Msg: string);
procedure LogSockError(Ctx: PClientContext; Op: string);
procedure LogWarn(Ctx: PClientContext; Op: string);
procedure LogDebug(Ctx: PClientContext; Msg: string);

{$ENDIF}

implementation

{$IFDEF ENABLE_LOGGING}

uses
{$IFDEF XBUG}
  uDebug,
{$ENDIF}
  SysUtils,
  FastLock;

type
  PLogEntry = ^TLogEntry;
  TLogEntry = record
    Level: TLogLevel;
    ThreadID: DWORD;
    Sock: TSocket;
    ClientAddr: TInAddr;
    DateTime: TDateTime;
    BytesTransferred: Integer;
    StatusCode: Integer;
    IsFree: Boolean;
    Cookie,
    AuthUser: string;
    Msg: string;
  end;

const
  LOG_ENTRY_SIZE = SizeOf(TLogEntry);
  LOG_ACCESS_NAME = 'access.log';
  LOG_DEBUG_NAME = 'debug.log';
  LOG_ERROR_NAME = 'error.log';

var
  g_Lock,
  g_AccessLock: TFastLock;
  g_AccessCache,
  g_CacheList: TList;
  g_LogLevel: TLogLevel;
  g_CacheFlushInterval,
  g_LastFlushed: DWORD;
  g_CacheMax,
  g_AccessCacheSize,
  g_CacheSize: Integer;
  g_LogDir: string;
  g_FormatSettings: TFormatSettings;
  g_HookError: TLogHookErrorProc;
  g_HookDebug: TLogHookDebugProc;
  g_HookAccess: TLogHookAccessProc;

procedure ResetEntry(var LE: PLogEntry);
begin
  with LE^ do
  begin
    IsFree := True;
    ThreadID := INVALID_HANDLE_VALUE;
    Sock := INVALID_SOCKET;
    StatusCode := 0;
    ClientAddr.S_addr := INADDR_NONE;
    BytesTransferred := 0;
    DateTime := -1;
    Level := llNone;

    SetLength(Cookie, 0);
    SetLength(AuthUser, 0);
    SetLength(Msg, 0);
  end;
end;

procedure InternalFlushCache(const DeleteEntries: Boolean);
var
  sError, sDebug: string;
  I, J: Integer;
  P: PLogEntry;

  procedure LogAppend(LE: PLogEntry);
  const
    LEVEL_STR: array[TLogLevel] of string[10] =
      (
      '', 'CRITICAL ', 'WARNING ', '', ''
      );
  begin
    with LE^ do
    begin
      case Level of
        llCritical,
          llWarn:
          begin
            if Assigned(g_HookError) then
              g_HookError(ThreadID, Sock, Msg);

            sError := sError + '[' + FormatDateTime('ddd mmm dd hh:nn:ss yyyy',
              DateTime) + ';';

            if (ThreadID <> INVALID_HANDLE_VALUE) then
              sError := sError + IntToHex(ThreadID, 4) + ';'
            else
              sError := sError + '-;';

            if (Sock <> INVALID_SOCKET) then
              sError := sError + IntToHex(Sock, 4) + ';'
            else
              sError := sError + '-;';

            if (ClientAddr.S_addr <> INADDR_NONE) then
              sError := sError + inet_ntoa(ClientAddr) + '] '
            else
              sError := sError + '-] ';

            sError := sError + LEVEL_STR[Level] + Msg + #13#10;
          end;
        llDebug:
          begin
            if Assigned(g_HookDebug) then
              g_HookDebug(ThreadID, Sock, Msg);

            sDebug := sDebug + '[' + FormatDateTime('dd/mmm/yyyy:hh:nn:ss',
              DateTime) + ';';

            if (ThreadID <> INVALID_HANDLE_VALUE) then
              sDebug := sDebug + IntToHex(ThreadID, 4) + ':'
            else
              sDebug := sDebug + '0000:';

            if (Sock <> INVALID_SOCKET) then
              sDebug := sDebug + IntToHex(Sock, 4) + ':'
            else
              sDebug := sDebug + '0000:';

            if (ClientAddr.S_addr <> INADDR_NONE) then
              sDebug := sDebug + inet_ntoa(ClientAddr) + '] '
            else
              sDebug := sDebug + '000.000.000.000] ';

            sDebug := sDebug + LEVEL_STR[Level] + Msg + #13#10;
          end;
      end;
    end;
  end;

  procedure LogWrite(Level: TLogLevel);
  var
    L: Integer;
    FName: string;
    fLog: Integer;
    Msg: string;
    bFileOpen: Boolean;
  begin
    case Level of
      llCritical,
        llWarn:
        begin
          FName := PathAddSlash(g_LogDir) + LOG_ERROR_NAME;
          Msg := sError;
        end;
      llDebug:
        begin
          FName := PathAddSlash(g_LogDir) + LOG_DEBUG_NAME;
          Msg := sDebug;
        end;
    end;

    if (Msg <> '') then
    begin
      if FileExists(FName) then
        fLog := FileOpen(FName, fmOpenReadWrite or fmShareDenyWrite)
      else
        fLog := FileCreate(FName, fmOpenWrite or fmShareDenyWrite);

      bFileOpen := (fLog <> INVALID_HANDLE_VALUE);

      if bFileOpen then
      begin
        FileSeek(fLog, 0, soFromEnd);
        FileWrite(fLog, Msg[1], Length(Msg));
      end;
      FileClose(fLog);
    end;
  end;

begin
  J := Pred(g_CacheList.Count);
  if (J >= 0) then
  begin
    for I := 0 to J do
    begin
      P := PLogEntry(g_CacheList[I]);
      if (P^.Level <= g_LogLevel) and (not P^.IsFree) then
        LogAppend(P);

      ResetEntry(P);

      if DeleteEntries then
        FreeMem(P);
    end;

    if (g_LogLevel >= llCritical) then
      LogWrite(llWarn);

    if (g_LogLevel = llDebug) then
      LogWrite(llDebug);
  end;

  if DeleteEntries then
    g_CacheList.Clear
  else
  begin
    if g_CacheList.Count > g_CacheMax then
    begin
      I := g_CacheList.Count - g_CacheMax;

      while (I > 0) do
      begin
        P := PLogEntry(g_CacheList[g_CacheList.Count - 1]);
        FreeMem(P);
        g_CacheList.Delete(g_CacheList.Count - 1);
        Dec(I);
      end;
    end;
  end;

  g_LastFlushed := GetTickCount;
end;

procedure InternalFlushAccessCache(const DeleteEntries: Boolean);
var
  sAccess: string;
  I, J: Integer;
  P: PLogEntry;

  procedure LogAppend(LE: PLogEntry);
  var
    sAuth, sCookie: string;
  begin
    with LE^ do
    begin
      if Assigned(g_HookAccess) then
        g_HookAccess(ClientAddr, StatusCode, Msg);

      if (AuthUser <> '') then
        sAuth := AuthUser
      else
        sAuth := '-';

      if (Cookie <> '') then
        sCookie := '"cookie=' + Cookie + '"';

      sAccess := sAccess + inet_ntoa(ClientAddr) + ' - ' + AuthUser + ' [' +
        FormatDateTime('dd/mmm/yyyy:hh:nn:ss', DateTime) +
        ' GMT] "' + Msg + '" ' + IntToStr(StatusCode) +
        ' ' + IntToStr(BytesTransferred) +
        sCookie + #13#10;
    end;
  end;

  procedure LogWrite;
  var
    FName: string;
    fLog: Integer;
    Msg: string;
    bFileOpen: Boolean;
  begin
    FName := PathAddSlash(g_LogDir) + LOG_ACCESS_NAME;
    Msg := sAccess;

    if (Msg <> '') then
    begin
      if FileExists(FName) then
        fLog := FileOpen(FName, fmOpenReadWrite or fmShareDenyWrite)
      else
        fLog := FileCreate(FName, fmOpenWrite or fmShareDenyWrite);

      bFileOpen := (fLog <> INVALID_HANDLE_VALUE);

      if bFileOpen then
      begin
        FileSeek(fLog, 0, soFromEnd);
        FileWrite(fLog, Msg[1], Length(Msg));
      end;
      FileClose(fLog);
    end;
  end;

begin
  J := Pred(g_AccessCache.Count);
  if (J >= 0) then
  begin
    for I := 0 to J do
    begin
      P := PLogEntry(g_AccessCache[I]);
      if (not P^.IsFree) then
        LogAppend(P);

      ResetEntry(P);

      if DeleteEntries then
        FreeMem(P);
    end;

    LogWrite;
  end;

  if DeleteEntries then
    g_AccessCache.Clear
  else
  begin
    if g_AccessCache.Count > g_CacheMax then
    begin
      I := g_AccessCache.Count - g_CacheMax;

      while (I > 0) do
      begin
        P := PLogEntry(g_AccessCache[g_AccessCache.Count - 1]);
        FreeMem(P);
        g_AccessCache.Delete(g_AccessCache.Count - 1);
        Dec(I);
      end;
    end;
  end;

  g_LastFlushed := GetTickCount;
end;

procedure InternalAdd(ALevel: TLogLevel; Ctx: PClientContext; AMsg: string);
var
  I, J: Integer;
  P: PLogEntry;
begin
  P := nil;
  J := Pred(g_CacheList.Count);
  for I := 0 to J do
    if PLogEntry(g_CacheList[I])^.IsFree then
    begin
      P := PLogEntry(g_CacheList[I]);
      Break;
    end;

  if not Assigned(P) then
  begin
    P := AllocMem(SizeOf(TLogEntry));
    ResetEntry(P);
    g_CacheList.Add(P);
  end;
  Inc(g_CacheSize);

  with P^ do
  begin
    IsFree := False;
    DateTime := Now;
    ThreadID := GetCurrentThreadId;
    Level := ALevel;
    Msg := AMsg;

    if Assigned(Ctx) then
    begin
      ClientAddr := Ctx^.saPeer.sin_addr;
      StatusCode := Ctx^.HTTPReq^.StatusCode;
    end;
  end;
end;

procedure InternalAccessAdd(Ctx: PClientContext; AMsg: string);
var
  I, J: Integer;
  P: PLogEntry;
begin
  P := nil;
  J := Pred(g_AccessCache.Count);
  for I := 0 to J do
    if PLogEntry(g_AccessCache[I])^.IsFree then
    begin
      P := PLogEntry(g_AccessCache[I]);
      Break;
    end;

  if not Assigned(P) then
  begin
    P := AllocMem(SizeOf(TLogEntry));
    ResetEntry(P);
    g_AccessCache.Add(P);
  end;
  Inc(g_AccessCacheSize);

  with P^ do
  begin
    IsFree := False;
    DateTime := Now;
    ThreadID := GetCurrentThreadId;
    Level := llAccess;
    Msg := AMsg;

    if Assigned(Ctx) then
    begin
      ClientAddr := Ctx^.saPeer.sin_addr;
      StatusCode := Ctx^.HTTPReq^.StatusCode;

      Cookie := StrPas(Ctx^.HTTPReq^.Cookie);
      AuthUser := StrPas(Ctx^.HTTPReq^.Authorization);
      BytesTransferred := Ctx^.Bytes;
    end;
  end;
end;

procedure LogInit;
begin
  g_Lock := TFastLock.Create(128, False);
  g_AccessLock := TFastLock.Create(128, True);

  g_CacheList := TList.Create;
  g_CacheList.Capacity := g_CacheMax;

  g_AccessCache := TList.Create;
  g_CacheList.Capacity := g_CacheMax;

  g_LastFlushed := GetTickCount;
  g_AccessCacheSize := 0;
  g_CacheSize := 0;
end;

procedure LogShutdown;
begin
  InternalFlushAccessCache(True);
  InternalFlushCache(True);

  FreeAndNil(g_Lock);
  FreeAndNil(g_AccessLock);

  FreeAndNil(g_CacheList);
  FreeAndNil(g_AccessCache);
end;

procedure LogSetDir(const ADirName: string);
begin
  g_LogDir := ADirName;
end;

procedure LogSetCacheMaxSize(const ASize: Integer);
begin
  g_CacheMax := ASize;
end;

procedure LogSetCacheFlushInterval(const ASeconds: Cardinal);
begin
  g_CacheFlushInterval := ASeconds;
end;

procedure LogSetLevel(ALevel: TLogLevel);
begin
  g_LogLevel := ALevel;
end;

procedure LogFlushCache;
begin
  if (g_CacheSize >= g_CacheMax) or (g_AccessCacheSize >= g_CacheMax) or
    ((g_LastFlushed <= (GetTickCount - (g_CacheFlushInterval * 1000))) and
      (g_CacheList.Count > 0)) then
  begin
    g_AccessLock.Enter;
    try
      InternalFlushAccessCache(False);
    finally
      g_AccessLock.Leave;
    end;

    g_Lock.Enter;
    try
      InternalFlushCache(False);
    finally
      g_Lock.Leave;
    end;
  end;

{$IFDEF XBUG}
  uDebug.ERROR(0, 'Flushed cached log entries to disk');
{$ENDIF}
end;

procedure LogFlushCacheNow;
begin
  g_AccessLock.Enter;
  try
    InternalFlushAccessCache(False);
  finally
    g_AccessLock.Leave;
  end;

  g_Lock.Enter;
  try
    InternalFlushCache(False);
  finally
    g_Lock.Leave;
  end;

{$IFDEF XBUG}
  uDebug.ERROR(0, 'Flushed cached log entries to disk');
{$ENDIF}
end;

procedure LogRequest(Ctx: PClientContext);
begin
  if (g_LogLevel >= llAccess) then
  begin
    g_AccessLock.Enter;
    try
      InternalAccessAdd(Ctx, METHOD_TABLE[Ctx^.HTTPReq^.Method].Str + ' ' +
        Ctx^.HTTPReq^.OrigURL);
    finally
      g_AccessLock.Leave;
    end;
  end;
end;

procedure LogCrit(Ctx: PClientContext; Msg: string);
begin
  if (g_LogLevel >= llCritical) then
  begin
    g_Lock.Enter;
    try
      InternalAdd(llCritical, Ctx, Msg);
    finally
      g_Lock.Leave;
    end;
  end;
{$IFDEF XBUG}
  if (Ctx <> nil) then
    uDebug.ERROR(Ctx^.Sock, Msg, 2)
  else
    uDebug.ERROR(0, Msg, 2);
{$ENDIF}
end;

procedure LogSockError(Ctx: PClientContext; Op: string);
var
  ErrCode: Integer;
  S: string;
begin
  if (g_LogLevel >= llCritical) then
  begin
    ErrCode := WSAGetLastError;
    if (ErrCode <> WSAEWOULDBLOCK) or (ErrCode <> ERROR_IO_PENDING) then
    begin
      S := Format('Winsock error: %s (%d), on API ''%s''',
        [SysErrorMessage(ErrCode), ErrCode, Op]);

      g_Lock.Enter;
      try
        InternalAdd(llWarn, Ctx, S);
      finally
        g_Lock.Leave;
      end;
    end;
  end;

{$IFDEF XBUG}
  if (Ctx <> nil) then
{$IFDEF TRACK_SOCKET_SESSION}
    XERROR(Ctx^.xSession, Ctx^.Sock, S, 2)
{$ELSE}
    ERROR(Ctx^.Sock, S, 2)
{$ENDIF}
  else
    uDebug.ERROR(0, S, 2);
{$ENDIF}
end;

procedure LogWarn(Ctx: PClientContext; Op: string);
var
  ErrCode: Cardinal;
  S: string;
begin
  if (g_LogLevel >= llWarn) then
  begin
    ErrCode := GetLastError;
    S := Format('Windows error: %s (%d), on API ''%s''',
      [SysErrorMessage(ErrCode), ErrCode, Op]);

    g_Lock.Enter;
    try
      InternalAdd(llWarn, Ctx, S);
    finally
      g_Lock.Leave;
    end;
  end;

{$IFDEF XBUG}
  if (Ctx <> nil) then
{$IFDEF TRACK_SOCKET_SESSION}
    XWARNING(Ctx^.xSession, Ctx^.Sock, S, 2)
{$ELSE}
    WARNING(Ctx^.Sock, S, 2)
{$ENDIF}
  else
    uDebug.WARNING(0, S, 2);
{$ENDIF}
end;

procedure LogDebug(Ctx: PClientContext; Msg: string);
begin
  if (g_LogLevel = llDebug) then
  begin
    g_Lock.Enter;
    try
      InternalAdd(llDebug, Ctx, Msg);
    finally
      g_Lock.Leave;
    end;
  end;

{$IFDEF XBUG}
  if (Ctx <> nil) then
{$IFDEF TRACK_SOCKET_SESSION}
    XINFO(Ctx^.xSession, Ctx^.Sock, Msg, 2)
{$ELSE}
    INFO(Ctx^.Sock, Msg, 2)
{$ENDIF}
  else
    uDebug.INFO(0, Msg, 2);
{$ENDIF}
end;

procedure LogSetErrorHook(Proc: TLogHookErrorProc);
begin
  g_HookError := Proc;
end;

procedure LogSetDebugHook(Proc: TLogHookDebugProc);
begin
  g_HookDebug := Proc;
end;

procedure LogSetAccessHook(Proc: TLogHookAccessProc);
begin
  g_HookAccess := Proc;
end;

function LogGetDir: string;
begin
  Result := g_LogDir;
end;

function LogGetCacheMaxSize: Integer;
begin
  Result := g_CacheMax;
end;

function LogGetCacheFlushInterval: Integer;
begin
  Result := g_CacheFlushInterval;
end;

function LogGetLevel: TLogLevel;
begin
  Result := g_LogLevel;
end;

{$ENDIF}

end.

