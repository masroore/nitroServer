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
// $Version:0.6.1$ $Revision:1.2$ $Author:masroore$ $RevDate:9/19/2007 20:09:36$
//
////////////////////////////////////////////////////////////////////////////////

unit ISAPIEngine;

interface

uses
  Windows, WinSock, Winsock2, HTTPExt, SysUtils, Buffer, Common,
  Classes, HashTable;

function IsISAPIScript(const FN: string): Boolean;
function ISAPIExecuteScript(const FileName: String; Ctx: PClientContext; Buf: PSmartBuffer): Boolean;

implementation

{$I NITROHTTPD.INC}

uses
{$IFDEF XBUG}
  uDebug,
{$ENDIF}
  HTTPResponse,
  Config,
  IOCPServer,
  CachedLogger,
  FastDateCache;

const
  ISAPI_HASH_TABLE_SIZE = 127;

type
  PISAPIContext = ^TISAPIContext;
  TISAPIContext = record
    Ctx:     PClientContext;
    OutBuf: PSmartBuffer;
    DLLName: string;
    PathInfo: string;
  end;

type
  PISAPIModule = ^TISAPIModule;
  TISAPIModule = record
    DLLName:      string;
    ModuleHandle: THandle;
    LastAccessed: DWORD;
{
    VerProc:      TGetExtensionVersion;
    ExtProc:      THttpExtensionProc;
    TermProc:     TTerminateExtension;
}
  end;

  TISAPICacheManager = class
  PRIVATE
    FHashTable: THashTable;
    FLock:      TRTLCriticalSection;
  PUBLIC
    constructor Create;
    destructor Destroy; OVERRIDE;
    function LoadModule(DLLName: String; var ModuleInfo: PISAPIModule): THandle;
    procedure UnloadAll;
  end;
  
var
  g_ISAPIManager: TISAPICacheManager;

constructor TISAPICacheManager.Create;
begin
  inherited;

  SetLength(FHashTable, ISAPI_HASH_TABLE_SIZE);
  InitializeCriticalSection(FLock);
end;

destructor TISAPICacheManager.Destroy;
begin
  UnloadAll;
  HashClear(FHashTable, ISAPI_HASH_TABLE_SIZE, nil);
  DeleteCriticalSection(FLock);
end;

function TISAPICacheManager.LoadModule(DLLName: String; var ModuleInfo: PISAPIModule): THandle;
var
  hDLL: THandle;
  Len: Integer;
  CkSum: Cardinal;
  H: PHashNode;
  P: PISAPIModule;
  bFound: Boolean;
begin
  Result := 0;
  DLLName := LowerCase(DLLName);
  Len    := Length(DLLName);
  CkSum  := SuperFastHash(PAnsiChar(DLLName), Len) mod ISAPI_HASH_TABLE_SIZE;

  EnterCriticalSection(FLock);
  try
    H       := HashFind(FHashTable, DLLName, CkSum);
    bFound  := Assigned(H);

    if bFound then
    begin
      hDLL := PISAPIModule(H^.Data)^.ModuleHandle;

      {
      if (hDLL = 0) then
      begin
        hDLL := GetModuleHandle(PAnsiChar(DLLName));
        if (hDLL <> 0) then
        begin
          // Ok, module in memory, return handle.
          PISAPIModule(H^.Data)^.ModuleHandle := hDLL;
        end;
      end;
      }
      Result := hDLL;
    end;

    // No valid libaries in memory found, load library.
    if (Result = 0) then
    begin
      hDLL := LoadLibraryExA(PAnsiChar(DLLName), 0, LOAD_WITH_ALTERED_SEARCH_PATH);
      Assert(hDLL <> 0, 'Unable to load DLL: ' + DLLName);

      if bFound then
        P := PISAPIModule(H^.Data)
      else
      begin
        P := AllocMem(SizeOf(TISAPIModule));
        P^.DLLName  := DLLName;
        HashInsert(FHashTable, DLLName, CkSum, P);
      end;

      P^.ModuleHandle := hDLL;
      P^.LastAccessed := GetTickCount;
      {
      P^.VerProc      := GetProcAddress(hDLL, 'GetExtensionVersion');
      P^.ExtProc      := GetProcAddress(hDLL, 'HttpExtensionProc');
      P^.TermProc     := GetProcAddress(hDLL, 'TerminateExtension');
      }
      Result      := hDLL;
      ModuleInfo  := P;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure UnloadModule(hDLL: THandle; P: PISAPIModule);
var
  Termfn: TTerminateExtension;
  szBuf: array [0..64] of Char;
begin
{
  Termfn := P^.TermProc;
  if not Assigned(Termfn) then
}
    Termfn := GetProcAddress(hDLL, 'TerminateExtension');
  //INFO(0, '','Terminating ISAPI handle:', inttostr(h),'','');
  if Assigned(Termfn) then
  begin
    //INFO(0, '','Asking ISAPI for shutdown on handle:', inttostr(h),'','');
    Termfn(HSE_TERM_MUST_UNLOAD);
  end;

  // To be on the safe side, check if library died by itself. If not kill it.
  if GetModuleFileName(hDLL, szBuf, 63) <> 0 then
    FreeLibrary(hDLL);
end;

procedure ISAPIUnloadCB(Item: Pointer);
var
  P: PISAPIModule;
  hDLL: THandle;
begin
  P := PISAPIModule(Item);
  hDLL := GetModuleHandleA(PAnsiChar(P^.DLLName));
  if (hDLL <> 0) then
    UnloadModule(hDLL, P);

  SetLength(P^.DLLName, 0);
  Dispose(P);
end;

procedure TISAPICacheManager.UnloadAll;
begin
  EnterCriticalSection(FLock);
  try
    HashClear(FHashTable, ISAPI_HASH_TABLE_SIZE, ISAPIUnloadCB);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function GetServerVariable( hConn: HCONN;
                            VariableName: PAnsiChar;
                            Buffer: Pointer;
                            var Size: DWORD): BOOL STDCALL;
var
  P:    PISAPIContext;
  S, V: String;
begin
  P := PISAPIContext(hConn);
  V := UpperCase(VariableName);

  PAnsiChar(Buffer)[0] := #0;
  Size   := 0;
  Result := False;

  case V[1] of
    'A':
      begin
        if CompareText(V, 'AUTH_NAME') = 0 then
          S := P^.Ctx^.HTTPReq^.AuthUser
        else
        if CompareText(V, 'AUTH_PASS') = 0 then
          S := P^.Ctx^.HTTPReq^.AuthPass
        else
        if CompareText(V, 'AUTH_TYPE') = 0 then
          S := P^.Ctx^.HTTPReq^.AuthType
        else
        if CompareText(V, 'ALL_HTTP') = 0 then
          S := P^.Ctx^.HTTPReq^.OrigHdr;
      end;
    'C':
      begin
        if CompareText(V, 'CONTENT_LENGTH') = 0 then
          S := IntToStr(P^.Ctx^.HTTPReq^.ContentLen)
        else
        if CompareText(V, 'CONTENT_TYPE') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.ContentType)
        else
        if CompareText(V, 'CONNECTION') = 0 then
          S := CONN_TABLE[P^.Ctx^.HTTPReq^.KeepAlive]
        else
        if CompareText(V, 'COOKIE2') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.Cookie2)
        else
        if CompareText(V, 'COOKIE') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.Cookie);
      end;
    'D':
      begin
        if CompareText(V, 'DOCUMENT_ROOT') = 0 then
          S := ExtractFileDir(P^.DLLName);
      end;  
    'G':
      begin
        if CompareText(V, 'GATEWAY_INTERFACE') = 0 then
          S := 'CGI/1.1';
      end;
    'H':
      begin
        if CompareText(V, 'HTTP_ACCEPT') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.Accept)
        else
        if CompareText(V, 'HTTP_ACCEPT_CHARSET') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.AcceptCharset)
        else
        if CompareText(V, 'HTTP_ACCEPT_ENCODING') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.AcceptEncoding)
        else
        if CompareText(V, 'HTTP_ACCEPT_LANGUAGE') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.AcceptLanguage)
        else
        if CompareText(V, 'HTTP_AUTHORIZATION') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.Authorization)
        else
        if CompareText(V, 'HTTP_USER_AGENT') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.UserAgent)
        else
        if CompareText(V, 'HTTP_CONNECTION') = 0 then
          S := CONN_TABLE[P^.Ctx^.HTTPReq^.KeepAlive]
        else
        if CompareText(V, 'HTTP_HOST') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.Host)
        else
        if CompareText(V, 'HTTP_REFERER') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.Referrer)
        else
        if CompareText(V, 'HTTP_USER_AGENT') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.UserAgent)
        else
        if CompareText(V, 'HTTP_TE') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.TE)
        else
        if CompareText(V, 'HOST') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.Host);
      end;
    'I':
      begin
        if CompareText(V, 'IF_MODIFIED_SINCE') = 0 then
          if P^.Ctx^.HTTPReq^.IfModSince <> -1 then
            S := HTTPDate(P^.Ctx^.HTTPReq^.IfModSince);
      end;
    'P':
      begin
        if CompareText(V, 'PATH_INFO') = 0 then
          S := P^.PathInfo
        else
        if CompareText(V, 'PATH_TRANSLATED') = 0 then
          S := P^.PathInfo
        else
        if CompareText(V, 'PHP_SELF') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.URI);
      end;
    'Q':
      begin
        if CompareText(V, 'QUERY_STRING') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.Query);
      end;
    'R':
      begin
        if CompareText(V, 'REFERER') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.Referrer)
        else
        if CompareText(V, 'REFERRER') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.Referrer)
        else
        if CompareText(V, 'REQUEST_METHOD') = 0 then
          S := StrPas(METHOD_TABLE[P^.Ctx^.HTTPReq^.Method].Str)
        else
        if CompareText(V, 'REDIRECT_STATUS') = 0 then
          S := '200'
        else
        if CompareText(V, 'REMOTE_HOST') = 0 then
          S := P^.Ctx^.HTTPReq^.ClientAddr
        else
        if CompareText(V, 'REMOTE_ADDR') = 0 then
          S := P^.Ctx^.HTTPReq^.ClientAddr
        else
        if CompareText(V, 'REMOTE_USER') = 0 then
          S := P^.Ctx^.HTTPReq^.ClientAddr
        else
        if CompareText(V, 'REMOTE_PORT') = 0 then
          S := IntToStr(P^.Ctx^.HTTPReq^.ClientPort)
        else
        if CompareText(V, 'REQUEST_URI') = 0 then
          S := P^.Ctx^.HTTPReq^.OrigURL;
      end;
    'S':
      begin
        if CompareText(V, 'SCRIPT_NAME') = 0 then
          S := '/' + ExtractFileName(P^.DLLName)
        else
        if CompareText(V, 'SCRIPT_FILENAME') = 0 then
          S := '/' + ExtractFileName(P^.DLLName)
        else
        if CompareText(V, 'SERVER_NAME') = 0 then
          S := CfgGetServerName
        else
        if CompareText(V, 'SERVER_ADDR') = 0 then
          S := SvrGetServerAddr
        else
        if CompareText(V, 'SERVER_PORT') = 0 then
          S := SvrGetServerPort
        else
        if CompareText(V, 'SERVER_PROTOCOL') = 0 then
          S := StrPas(VERSION_TABLE[P^.Ctx^.HTTPReq^.Version].Str)
        else
        if CompareText(V, 'SERVER_SOFTWARE') = 0 then
          S := SERVER_SOFTWARE;
      end;
    'T':
      begin
        if CompareText(V, 'TE') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.TE);
      end;
    'U':
      begin
        if CompareText(V, 'USER_AGENT') = 0 then
          S := StrPas(P^.Ctx^.HTTPReq^.UserAgent)
        else
        if CompareText(V, 'USER_NAME') = 0 then
          S := P^.Ctx^.HTTPReq^.AuthUser
        else
        if CompareText(V, 'USER_PASSWORD') = 0 then
          S := P^.Ctx^.HTTPReq^.AuthPass;
      end;
  end;

  if (S <> '') then
  begin
    StrPCopy(PAnsiChar(Buffer), s);
    Size   := Length(s) + 1;
    Result := True;
  end;
end;

function WriteClient(ConnID: HCONN; Buffer: Pointer; var Bytes: DWORD;
  dwReserved: DWORD): BOOL STDCALL;
var
  P: PISAPIContext;
begin
  P := PISAPIContext(ConnID);

  if ((P = nil) or (dwReserved = HSE_IO_ASYNC)) then
  begin
    SetLastError(ERROR_INVALID_PARAMETER);
    Result := False;
  end
  else
  begin
    // Just dump the data into our output buffer. Fake a successful WSASend.
    BufAppendData(P^.OutBuf, Buffer, Bytes);
    Result := True;
  end;
end;

function ReadClient(ConnID: HCONN; Buffer: Pointer; var Size: DWORD): BOOL STDCALL;
var
  P: PISAPIContext;
  Flags: Cardinal;
  Res:   Integer;
begin
  //nothing to read, so set the value
  Size   := 0;

  //Validate our parameters
  P      := PISAPIContext(ConnID);

  // We do not support reading from the client, since we supply all of the data
  // in the EXTENSION_CONTROL_BLOCK
  SetLastError(ERROR_NO_DATA);
  Result := False;
  
  {
  with P^.Ctx^ do
  begin
    State      := stReading;
    wbRecv.buf := Buffer;
    wbRecv.len := Size;

    Flags := 0;
    Res   := WSARecv(Sock, @wbRecv, 1, Size, Flags, nil, nil);
    if (Res = SOCKET_ERROR) then
    begin
      //LogSocketError(Ctx, 'WSARecv');
    end
    else
    begin
      Size   := Res;
      Result := True;
    end;
  end;
  }
end;

function ServerSupport(ConnID: HCONN; HSERRequest: DWORD; Buffer: Pointer;
  Size: LPDWORD; DataType: LPDWORD): BOOL STDCALL;
var
  Len: Cardinal;
  S:   String;
  P: PISAPIContext;
begin
  P := PISAPIContext(ConnID);

  if (P = nil) then
  begin
    SetLastError(ERROR_INVALID_PARAMETER);
    Result := False;
    Exit;
  end;

  case HSERRequest of
    HSE_REQ_CLOSE_CONNECTION:
    begin
      //We support this function but do a NOOP since
      //the connection will be closed when HttpExtensionProc
      //returns normally
      Result := True;
    end;
    HSE_REQ_IS_KEEP_CONN:
    begin
      PBOOL(Buffer)^ := BOOL(P^.Ctx^.HTTPReq^.KeepAlive);
      Result := True;
    end;
    HSE_REQ_SEND_RESPONSE_HEADER:
    begin
      Result := True;
      P^.Ctx^.HTTPReq^.StatusCode := 200;
      S      := StrPas(VERSION_TABLE[P^.Ctx^.HTTPReq^.Version].Str) + ' ' +
                PAnsiChar(Buffer) + #13#10 + PAnsiChar(DataType);
      //Len    := Length(s);
      BufAppendStrZ(P^.OutBuf, PAnsiChar(S));
      //WriteClient(hConn, PAnsiChar(s), Len, 0);
    end;
    HSE_REQ_SEND_URL,
    HSE_REQ_SEND_URL_REDIRECT_RESP:
    begin
      Result := True;
      S      := StrPas(VERSION_TABLE[P^.Ctx^.HTTPReq^.Version].Str) +
                ' 302 Moved temporarily' + #13#10 +
                'Location:' + PAnsiChar(Buffer);
      //Len    := Length(s);
      BufAppendStrZ(P^.OutBuf, PAnsiChar(S));
      //WriteClient(hConn, PAnsiChar(s), Len, 0);
    end;
    else
    begin
      Result := False;
    end;
  end;
end;

function ISAPIExecuteScript(const FileName: String;
                            Ctx: PClientContext;
                            Buf: PSmartBuffer): Boolean;
var
  hISAPILib:    THandle;
  pModule: PISAPIModule;
  Verfn: TGetExtensionVersion;
  ExtensionProc:    THttpExtensionProc;
  ECB:   TEXTENSION_CONTROL_BLOCK;
  Ver:   THSE_VERSION_INFO;
  tmp:   String;
  P:     PISAPIContext;
  I:     Integer;
begin
  P           := AllocMem(SizeOf(TISAPIContext));
  P^.DLLName  := FileName;
  P^.Ctx      := Ctx;
  P^.OutBuf   := Buf;
  I := Pos('.dll', LowerCase(Ctx^.HTTPReq^.OrigURL));
  if I > 0 then
  begin
      {
      S := PathDosToUnix(PathAddSlash(PathToCGI));
      Add('PATH_INFO', S);
      if S <> '' then
        S := PathAddSlash(PathToCGI);
      Add('PATH_TRANSLATED', S);
      Add('DOCUMENT_ROOT', S);
      }

    P^.PathInfo := Copy(Ctx^.HTTPReq^.OrigURL, I + 4, Length(Ctx^.HTTPReq^.OrigURL));
    I := Pos('?', P^.PathInfo);
    if I = 1 then
      P^.PathInfo := ''
    else
    if (I > 1) then
      P^.PathInfo := Copy(P^.PathInfo, 1, I - 1);
  end;

  hISAPILib := g_ISAPIManager.LoadModule(FileName, pModule);
  if (hISAPILib <= 0) then
  begin
    Result := False;
    Exit;
  end;
  {
  Verfn         := pModule^.VerProc;
  ExtensionProc := pModule^.ExtProc;
  }
  //if not Assigned(Verfn) then
    Verfn := GetProcAddress(hISAPILib, 'GetExtensionVersion');
  //if not Assigned(ExtensionProc) then
    ExtensionProc := GetProcAddress(hISAPILib, 'HttpExtensionProc');
  Assert(Assigned(ExtensionProc), 'Unable to find HttpExtensionProc in ISAPI DLL ' + FileName);

  if Assigned(Verfn) then
  begin
    Verfn(Ver);
{$IFDEF ENABLE_LOGGING}
    LogDebug(Ctx, 'Requested ISAPI version: ' +
          inttostr(Ver.dwExtensionVersion shr 16)+', '+
          inttostr(Ver.dwExtensionVersion and $FFFF) + ', ' +
          StrPas(Ver.lpszExtensionDesc));
{$ENDIF}
  end;

  FillChar(ECB, sizeof(TEXTENSION_CONTROL_BLOCK), 0);
  ECB.cbSize      := sizeof(TEXTENSION_CONTROL_BLOCK);
  ECB.dwVersion   := HSE_VERSION_MAJOR shl 16 + HSE_VERSION_MINOR;
  ECB.ConnID      := HCONN(P);
  ECB.dwHttpStatusCode := 200;
  ECB.lpszMethod  := METHOD_TABLE[Ctx^.HTTPReq^.Method].Str;
  ECB.lpszQueryString := Ctx^.HTTPReq^.Query;
  ECB.lpszPathInfo := PAnsiChar(P^.PathInfo);
  ECB.lpszPathTranslated := PAnsiChar(P^.PathInfo);
  ECB.cbAvailable   := Ctx^.HTTPReq^.ContentLen;
  ECB.lpbData       := Ctx^.HTTPReq^.PostData;
  ECB.cbTotalBytes := Ctx^.HTTPReq^.ContentLen;
  ECB.GetServerVariable := GetServerVariable;
  ECB.WriteClient := WriteClient;
  ECB.ReadClient  := ReadClient;
  ECB.ServerSupportFunction := ServerSupport;

  ExtensionProc(ECB);

  SetLength(P^.DLLName, 0);
  SetLength(P^.PathInfo, 0);
  FreeMem(P);
  
  Result := True;
end;

function IsISAPIScript(const FN: string): Boolean;
var
  sExt: string;
begin
  sExt := LowerCase(ExtractFileExt(FN));
  Result := AnsiCompareStr('.dll', sExt) = 0;
end;  

initialization
  g_ISAPIManager := TISAPICacheManager.Create;

finalization
  g_ISAPIManager.UnloadAll;
  FreeAndNil(g_ISAPIManager);
end.
