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
// $Version:0.6.2$ $Revision:1.3$ $Author:masroore$ $RevDate:9/30/2007 21:38:04$
//
////////////////////////////////////////////////////////////////////////////////

unit CGIEngine;

interface

uses
  Classes, SysUtils, Windows, Common, Buffer, XMLConfig;

const
  MAX_CUSTOM_HEADERS = 8;
  CGI_ENV_SIZE    = 4096;
  CGI_TIMEOUT     = 30000;

type
  PCGIHeaders = ^TCGIHeaders;
  TCGIHeaders = record
    Status,
    Location,
    ContType,
    Pragma:    array [0..199] of AnsiChar;
    HdrLen:    Integer;
    NumCustom: Cardinal;
    CustomHeaders: array [1..MAX_CUSTOM_HEADERS, 0..199] of AnsiChar;
  end;

  PCGIInfo = ^TCGIInfo;
  TCGIInfo = record
    DocExt:      String;
    Interpreter: String;
    IsInterpreted,
    IsNonParsed: Boolean;
  end;

function IsCGIScript(const FN: String): Boolean;
procedure CGIRegisterScript(const AExt, AInterpreter: string; const AInterpreted, ANonParsed: Boolean);
function CGIGetInfo(const Doc: String; var Interpreter: String;
  var IsInterpreted, IsNonParsed: Boolean): Boolean;
procedure CGISaveConfig(XMLCfg: TXMLConfig);
function CGIExecuteScript(const Ctx: PClientContext;
  const CGIProgram, PathToCGI: String;
  var OutBuf: PSmartBuffer;
  var ErrorMsg: String): Boolean;
procedure CGIParseOutput(var Hdr: PCGIHeaders; Buf: PAnsiChar; BufLen: Cardinal);

implementation

{$I NITROHTTPD.INC}

uses
{$IFDEF XBUG}
  uDebug,
{$ENDIF}
  FastLock,
  IOCPServer,
  CachedLogger,
  Config;

var
  g_Lock: TFastLock;
  g_CGIInfos: TList;

procedure CGIRegisterScript(const AExt, AInterpreter: string; const AInterpreted, ANonParsed: Boolean);
var
  P: PCGIInfo;
begin
  P := AllocMem(sizeof(TCGIInfo));

  if AExt[1] = '.' then
    P^.DocExt       := LowerCase(AExt)
  else
    P^.DocExt       := LowerCase('.' + AExt);

  P^.Interpreter    := AInterpreter;
  P^.IsInterpreted  := AInterpreted;
  P^.IsNonParsed    := ANonParsed;

  g_Lock.Enter;
  g_CGIInfos.Add(P);
  g_Lock.Leave;
end;

function CGIIndex(const FN: String): Integer;
var
  I: Integer;
  Ext: string;
begin
  Result := -1;
  Ext := LowerCase(ExtractFileExt(FN));
  if (Ext <> '') then
  begin
    for I := Pred(g_CGIInfos.Count) downto 0 do
    begin
      if CompareStr(Ext, PCGIInfo(g_CGIInfos[I]).DocExt) = 0 then
      begin
        Result := I;
        Break;
      end;
    end;
  end;
end;

function IsCGIScript(const FN: String): Boolean;
begin
  g_Lock.Enter;
  Result := CGIIndex(FN) <> -1 ;
  g_Lock.Leave;
end;

function CGIGetInfo(const Doc: String; var Interpreter: String;
  var IsInterpreted, IsNonParsed: Boolean): Boolean;
var
  I: Integer;
  P: PCGIInfo;
begin
  g_Lock.Enter;

  I := CGIIndex(Doc);

  Result := (I <> -1);
  if Result then
  begin
    P := PCGIInfo(g_CGIInfos[I]);
    IsNonParsed   := P^.IsNonParsed;
    IsInterpreted := P^.IsInterpreted;
    if IsInterpreted then
      Interpreter := P^.Interpreter
    else
      Interpreter := Doc;
  end;
  g_Lock.Leave;
end;

procedure CGISaveConfig(XMLCfg: TXMLConfig);
var
  I, J: Integer;
  Key: string;
  P: PCGIInfo;
begin
  g_Lock.Enter;

  try
    J := g_CGIInfos.Count;
    XMLCfg.SetValue('CGIRunner/Count', J);
    for I := 0 to J - 1 do
    begin
      Key := 'CGIRunner/Entry_' + IntToStr(I) + '/';
      P := PCGIInfo(g_CGIInfos[I]);

      with P^ do
      begin
        XMLCfg.SetValue(Key + 'Extension', DocExt);
        XMLCfg.SetValue(Key + 'IsNonParsed', IsNonParsed);
        XMLCfg.SetValue(Key + 'IsInterpreted', IsInterpreted);
        XMLCfg.SetValue(Key + 'Interpreter', Interpreter);
      end;
    end;
  finally
    g_Lock.Leave;
  end;
end;

type
  ThreadParams = record
    ReadPipe: THandle;
    Buf: PSmartBuffer;
  end;
  PThreadParams = ^ThreadParams;     

function CGIThreadRead(Params : Pointer):DWORD; stdcall;
var
  Info:     PThreadParams;
  Buffer:   array [0..4095] of AnsiChar;
  Bytes:    DWORD;
begin
  Result := 0;
  Info := PThreadParams(Params);
  while ReadFile(Info^.ReadPipe,  Buffer,  SizeOf(Buffer),  Bytes,  nil) do
  begin
    if Bytes = 0 then
     Break;

    if (Bytes > 0) then
      BufAppendData(Info^.Buf, @Buffer, Bytes);
  end;
end;

function CGIExecuteScript(const Ctx: PClientContext;
  const CGIProgram, PathToCGI: String;
  var OutBuf: PSmartBuffer;
  var ErrorMsg: String): Boolean;
var
  Security: TSecurityAttributes;
  StdIn_Read, StdIn_Write: THandle;
  StdOut_Read, StdOut_Write: THandle;
  StdErr_Read, StdErr_Write: THandle;
  StartupInfo: TStartupInfoA;
  Status: Boolean;
  ProcessInformation: TProcessInformation;
  ReaderHandle: THandle;
  ReaderID: DWORD;
  Params: PThreadParams;
  Bytes: Cardinal;

  procedure FreeStdIOHandles;
  begin
    CloseHandle(StdIn_Read);
    CloseHandle(StdIn_Write);

    CloseHandle(StdErr_Read);
    CloseHandle(StdErr_Write);

    CloseHandle(StdOut_Write);
    CloseHandle(StdOut_Read);
  end;

  function GetEnvStr: String;
  var
    S: String;
    p:    PByteArray;
    j:    Integer;

    procedure Add(const Name, Value: String);
    begin
      if Value <> '' then
        Result := Result + Name + '=' + Value + #0;
    end;

  begin
    p := Pointer(GetEnvironmentStrings);
    j := 0;
    while (p^[j] <> 0) or (p^[j + 1] <> 0) do
      Inc(j);
    Inc(j);
    SetLength(Result, j);
    Move(p^, Result[1], j);
    FreeEnvironmentStrings(Pointer(p));
    if Assigned(Ctx) then
    begin
      S := PathDosToUnix(PathAddSlash(PathToCGI));
      Add('PATH_INFO', S);
      if S <> '' then
        S := PathAddSlash(PathToCGI);
      Add('PATH_TRANSLATED', S);
      Add('DOCUMENT_ROOT', S);
      Add('REMOTE_HOST', Ctx^.HTTPReq^.Host);
      Add('REMOTE_ADDR', Ctx^.HTTPReq^.ClientAddr);
      Add('REMOTE_PORT', IntToStr(Ctx^.HTTPReq^.ClientPort));
      Add('GATEWAY_INTERFACE', 'CGI/1.1');
      Add('SCRIPT_NAME', Ctx^.HTTPReq^.URI);
      Add('SCRIPT_FILENAME', Ctx^.HTTPReq^.Filename);
      Add('REQUEST_METHOD', METHOD_TABLE[Ctx^.HTTPReq^.Method].Str);
      Add('REQUEST_URI', Ctx^.HTTPReq^.OrigURL);
      Add('HTTP_ACCEPT', Ctx^.HTTPReq^.Accept);
      Add('HTTP_HOST', Ctx^.HTTPReq^.Host);
      Add('HTTP_REFERER', Ctx^.HTTPReq^.Referrer);
      Add('HTTP_USER_AGENT', Ctx^.HTTPReq^.UserAgent);
      Add('HTTP_COOKIE', Ctx^.HTTPReq^.Cookie);
      Add('HTTP_COOKIE2', Ctx^.HTTPReq^.Cookie2);
      Add('QUERY_STRING', Ctx^.HTTPReq^.Query);
      Add('PHP_SELF', Ctx^.HTTPReq^.URI);
      Add('SERVER_SOFTWARE', SERVER_SOFTWARE);
      Add('SERVER_NAME', CfgGetServerName);
      Add('SERVER_ADDR', SvrGetServerAddr);
      Add('SERVER_PORT', SvrGetServerPort);
      Add('SERVER_PROTOCOL', VERSION_TABLE[Ctx^.HTTPReq^.Version].Str);
      Add('CONTENT_TYPE', Ctx^.HTTPReq^.ContentType);
      Add('CONTENT_LENGTH', IntToStr(Ctx^.HTTPReq^.ContentLen));
      Add('HTTP_ACCEPT_CHARSET', Ctx^.HTTPReq^.AcceptCharset);
      Add('HTTP_ACCEPT_ENCODING', Ctx^.HTTPReq^.AcceptEncoding);
      Add('HTTP_ACCEPT_LANGUAGE', Ctx^.HTTPReq^.AcceptLanguage);
      Add('HTTP_CONNECTION', Ctx^.HTTPReq^.Connection);
      Add('HTTP_TE', Ctx^.HTTPReq^.TE);
      Add('REDIRECT_STATUS', '200');

      //Add('HTTP_FROM', Ctx^.HTTPReq^.From);
      Add('USER_NAME', Ctx^.HTTPReq^.AuthUser);
      Add('USER_PASSWORD', Ctx^.HTTPReq^.AuthPass);
      Add('AUTH_TYPE', Ctx^.HTTPReq^.AuthType);
    end;
  end;

begin
  Result := False;
  with Security do
  begin
    nLength := SizeOf(TSecurityAttributes);
    lpSecurityDescriptor := nil;
    bInheritHandle := True;
  end;

  CreatePipe(StdIn_Read, StdIn_Write, @Security, 0);
  CreatePipe(StdOut_Read, StdOut_Write, @Security, 0);
  CreatePipe(StdErr_Read, StdErr_Write, @Security, 0);

  FillChar(StartupInfo, SizeOf(StartupInfo), 0);
  with StartupInfo do
  begin
    CB          := SizeOf(TStartupInfo);
    dwFlags     := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    hStdInput   := StdIn_Read;
    hStdOutput  := StdOut_Write;
    hStdError   := StdErr_Write;
    wShowWindow := SW_HIDE;
  end;

  New(Params);
  Params^.ReadPipe  := StdOut_Read;
  Params^.Buf       := OutBuf;

  ReaderHandle := CreateThread( nil,
                                0,
                                @CGIThreadRead,
                                Params,
                                0,
                                ReaderId);
  if (ReaderHandle = 0) then
  begin
    ErrorMsg := SysErrorMessage(GetLastError);
    Ctx^.HTTPReq^.StatusCode := 500;
    FreeStdIOHandles;
    Exit;
  end;

{$IFDEF XBUG}
  INFO(0, 'Running CGI script ' + CGIProgram + '...');
{$ENDIF}

  Status := CreateProcessA(nil, PAnsiChar(CGIProgram), @Security, @Security,
                          True, CREATE_NEW_CONSOLE,
                          PAnsiChar(GetEnvStr), PAnsiChar(PathToCGI),
                          StartupInfo, ProcessInformation);

  if not Status then
  begin
    ErrorMsg := SysErrorMessage(GetLastError);

    FreeStdIOHandles;
    Exit;
  end;

  if Assigned(Ctx) then
  begin
    if (Ctx^.HTTPReq^.Query = nil) and (Ctx^.HTTPReq^.PostData = nil) then
    begin
{$IFDEF XBUG}
      INFO(0, 'Nothing to write to CGI.');
{$ENDIF}
    end
    else
    if (Ctx^.HTTPReq^.Query <> nil) and (Ctx^.HTTPReq^.ContentLen = 0) then
    begin
{$IFDEF XBUG}
      INFO(0, 'Writing CGI Query: ' + StrPas(Ctx^.HTTPReq^.Query));
{$ENDIF}
      WriteFile(Stdin_Write,
                Ctx^.HTTPReq^.Query^,
                StrLen(Ctx^.HTTPReq^.Query),
                Bytes, nil);
    end
    else
    if (Ctx^.HTTPReq^.PostData <> nil) and (Ctx^.HTTPReq^.ContentLen > 0) then
    begin
{$IFDEF XBUG}
      INFO(0, 'Writing CGI POST data: ');
{$ENDIF}
      WriteFile(Stdin_Write,
                Ctx^.HTTPReq^.PostData^,
                Ctx^.HTTPReq^.ContentLen,
                Bytes, nil);
    end
    else
    begin
{$IFDEF XBUG}
      WARNING(0, 'WEIRD! POST data NOT NIL AND nothing to write??');
{$ENDIF}
    end;
  end;

{$IFDEF XBUG}
  INFO(0, 'Waiting for CGI process to finish.');
{$ENDIF}

  if WaitForSingleObject(ProcessInformation.hProcess, CGI_TIMEOUT) = WAIT_TIMEOUT then
  begin
    TerminateThread(ReaderHandle,0);

    ErrorMsg := 'Gateway timeout';

    Ctx^.HTTPReq^.StatusCode := 500;

    FreeStdIOHandles;
    //ResponseInfo.ContentText := FTimeOutMsg;
{$IFDEF XBUG}
    WARNING(0, 'CGI timeout occured.');
{$ENDIF}

    Exit;
  end;

{$IFDEF XBUG}
  INFO(0, 'CGI execution successful.');
{$ENDIF}

  if (ReaderHandle > 0) then
     CloseHandle(ReaderHandle);

  CloseHandle(ProcessInformation.hThread);
  CloseHandle(ProcessInformation.hProcess);
  FreeStdIOHandles;

  Dispose(Params);

{$IFDEF XBUG}
  INFO(0, 'CGI Output bytes=' + IntToStr(OutBuf^.Used));
{$ENDIF}

  Result := True;
end;

procedure CGIParseOutput(var Hdr: PCGIHeaders; Buf: PAnsiChar; BufLen: Cardinal);
var
  P, Nxt: PAnsiChar;
begin
  if BufLen = 0 then
    Exit;

  P := StrPos(Buf, EOH_MARKER);
  //if (P = nil) then P := StrPos(Buf, #10#10);

  if P <> nil then
  begin
    Inc(P, EOH_MARKER_LEN);
    Hdr^.HdrLen := P - Buf;
    P := Buf;
    while P <> nil do
    begin
      Nxt  := StrPos(P, #10);
      Nxt^ := #0;
      {$IFNDEF FPC}
      if Nxt[-1] = #13 then
        Nxt[-1] := #0;
      {$ELSE}
      if (Nxt - 1)^ = #13 then
        (Nxt - 1)^ := #0;
      {$ENDIF} //TODO: FIX FOR FPC
      Inc(Nxt);

      if StrLen(P) = 0 then
        Break;

      if StrLIComp(P, 'HTTP/', 5) = 0 then
      begin
        Inc(P, 5);

        // Skip past "HTTP/v.v"
        while (P^ <> #0) and (P^ <> #9) and (P^ <> #32) do
          Inc(P);

        // Skip the white-spaces
        while (P^ <> #0) and ((P^ = #9) or (P^ = #32)) do
          Inc(P);

        Move(P^, Hdr^.Status, StrLen(P));
      end
      else
      if StrLIComp(P, 'STATUS: ', 8) = 0 then
      begin
        Inc(P, 8);
        Move(P^, Hdr^.Status, StrLen(P));
      end
      else
      if StrLIComp(P, 'LOCATION: ', 10) = 0 then
      begin
        Inc(P, 10);
        Move(P^, Hdr^.Location, StrLen(P));
      end
      else
      if StrLIComp(P, 'CONTENT-TYPE: ', 14) = 0 then
      begin
        Inc(P, 14);
        Move(P^, Hdr^.ContType, StrLen(P));
      end
      else
      if StrLIComp(P, 'PRAGMA: ', 8) = 0 then
      begin
        Inc(P, 8);
        Move(P^, Hdr^.Pragma, StrLen(P));
      end
      else
      if (StrLIComp(P, 'SERVER: ', 8) = 0) or
         (StrLIComp(P, 'CONTENT-LENGTH: ', 16) = 0) or
         (StrLIComp(P, 'DATE: ', 6) = 0) or
         (StrLIComp(P, 'CONNECTION: ', 12) = 0) then
      begin
        // Our server adds these headers.
        // Filter them out
      end
      else
      begin
        if (Hdr^.NumCustom < MAX_CUSTOM_HEADERS) then
        begin
          Inc(Hdr^.NumCustom);
          Move(P^, Hdr^.CustomHeaders[Hdr^.NumCustom], StrLen(P));
        end;
      end;

      P := Nxt;
    end;
  end;
end;

procedure ClearList;
var
  I: Integer;
  P: PCGIInfo;
begin
  I := Pred(g_CGIInfos.Count);
  while (I >= 0) do
  begin
    P := PCGIInfo(g_CGIInfos[I]);
    with P^ do
    begin
      SetLength(DocExt, 0);
      SetLength(Interpreter, 0);
    end;
    FreeMem(P);
    Dec(I);
  end;
  g_CGIInfos.Clear;
end;

initialization
  g_Lock     := TFastLock.Create(128, False);
  g_CGIInfos :=  TList.Create;

finalization
  ClearList;
  FreeAndNil(g_Lock);
  FreeAndNil(g_CGIInfos);
end.
