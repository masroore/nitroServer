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
// $Version:0.6.2$ $Revision:1.1$ $Author:masroore$ $RevDate:9/30/2007 21:38:12$
//
////////////////////////////////////////////////////////////////////////////////

// Based on "PHP 4 Delphi"
{*******************************************************}
{                   PHP4Applications                    }
{ Author:                                               }
{ Serhiy Perevoznyk                                     }
{ serge_perevoznyk@hotmail.com                          }
{ http://users.chello.be/ws36637                        }
{*******************************************************}

{$I PHP.INC}
{$I NITROHTTPD.INC}

{$IFNDEF PHP_DIRECT_EXECUTE}
  ERROR! PHP_DIRECT_EXECUTE must be defined for this unit to work!
{$ENDIF}

{ $Id: php4AppUnit.pas,v 6.2 02/2006 delphi32 Exp $ }

unit PHPEngine;

interface

uses
  Windows, SysUtils, Classes, Common, Buffer,
  ZendTypes, phpTypes, PHPAPI, ZENDAPI, CGIEngine;

const
  REQUEST_ID_NOT_FOUND = -1;
  VARIABLE_NOT_FOUND   = -2;
  ERROR_CREATE_PIPE    = -3;
  SCRIPT_IS_EMPTY      = -4;

  ALLOW_REGISTER_GLOBALS = True;

type
  PPHPContext = ^TPHPContext;
  TPHPContext = record
    Headers: PCGIHeaders;
    BufContent:  PSmartBuffer;
    VarList: TStringList;
    Req: PHTTPRequest;
    PostData: PAnsiChar;
    PostLen, PostOffset: Integer;
  end;

procedure InitEngine(const DLLName, INIFolder: string); STDCALL;
function InitRequest: Integer; STDCALL;
procedure DoneRequest(PHPContext: Integer); STDCALL;
procedure RegisterVariable(PHPContext: Integer; AName: PAnsiChar; AValue: PAnsiChar); STDCALL;
function ExecutePHP(PHPContext: Integer; FileName: PAnsiChar): Integer; STDCALL;
function ExecuteCode(PHPContext: Integer; ACode: PAnsiChar): Integer; STDCALL;
//function GetResultText(PHPContext: Integer; Buffer: PChar; BufLen: Integer): Integer; STDCALL;
//function GetVariable(PHPContext: Integer; AName: PChar; Buffer: PChar; BufLen: Integer): Integer; STDCALL;
//procedure SaveToFile(PHPContext: Integer; AFileName: PChar); STDCALL;
function GetVariableSize(PHPContext: Integer; AName: PAnsiChar): Integer; STDCALL;
//function GetResultBufferSize(PHPContext: Integer): Integer; STDCALL;
function IsPHPScript(const FN: String): Boolean;

function PHPExecuteScript(ovx: PClientContext; const ScriptName, ScriptPath: string; Headers: PCGIHeaders; OutBuf: PSmartBuffer): Boolean;
function PHPExecuteCode(ovx: PClientContext; const ScriptName, ScriptPath: string; const Code:PAnsiChar; OutBuf: PSmartBuffer): Boolean;

procedure PrepareStartup;

procedure StopEngine;

implementation

uses
{$IFDEF XBUG}
  uDebug,
{$ENDIF}
  IOCPServer,
  CachedLogger;

function IsPHPScript(const FN: String): Boolean;
begin
  Result := CompareText(ExtractFileExt(FN), '.PHP') = 0;
end;

procedure SetParams(var PHPContext: PPHPContext; ABuf:  PSmartBuffer; AReq: PHTTPRequest);
begin
  PHPContext^.BufContent := ABuf;
  PHPContext^.Req    := AReq;
end;

function PHPExecuteScript(ovx: PClientContext; const ScriptName, ScriptPath: string; Headers: PCGIHeaders; OutBuf: PSmartBuffer): Boolean;
var
  Ctx: Integer;
  AuxS: String;

  procedure Add(const Name, Value: String);
  begin
    if Value <> '' then
      RegisterVariable(Ctx, PAnsiChar(Name), PAnsiChar(Value));
  end;

begin
  Ctx     := InitRequest;
  SetParams(PPHPContext(Ctx), OutBuf, ovx^.HTTPReq);

  PPHPContext(Ctx)^.Headers := Headers;
  PPHPContext(Ctx)^.PostData := ovx^.HTTPReq^.PostData;
  PPHPContext(Ctx)^.PostLen  := ovx^.HTTPReq^.PostLen;
  PPHPContext(Ctx)^.PostOffset := 0;

  if Assigned(Ovx) then
  begin
    AuxS := PathDosToUnix(PathAddSlash(ScriptPath));
    Add('PATH_INFO', AuxS);
    if AuxS <> '' then
      AuxS := PathAddSlash(ScriptPath);
    Add('PATH_TRANSLATED', AuxS);
    Add('DOCUMENT_ROOT', AuxS);
    Add('REMOTE_HOST', Ovx^.HTTPReq^.Host);
    Add('REMOTE_ADDR', Ovx^.HTTPReq^.ClientAddr);
    Add('REMOTE_PORT', IntToStr(Ovx^.HTTPReq^.ClientPort));
    Add('GATEWAY_INTERFACE', 'CGI/1.1');
    Add('SCRIPT_NAME', Ovx^.HTTPReq^.URI);
    Add('SCRIPT_FILENAME', ScriptName);
    Add('REQUEST_METHOD', METHOD_TABLE[Ovx^.HTTPReq^.Method].Str);
    Add('REQUEST_URI', Ovx^.HTTPReq^.OrigURL);
    Add('HTTP_ACCEPT', Ovx^.HTTPReq^.Accept);
    Add('HTTP_HOST', Ovx^.HTTPReq^.Host);
    Add('HTTP_REFERER', Ovx^.HTTPReq^.Referrer);
    Add('HTTP_USER_AGENT', Ovx^.HTTPReq^.UserAgent);
    Add('HTTP_COOKIE', Ovx^.HTTPReq^.Cookie);
    Add('HTTP_COOKIE2', Ovx^.HTTPReq^.Cookie2);
    Add('QUERY_STRING', Ovx^.HTTPReq^.Query);
    Add('PHP_SELF', Ovx^.HTTPReq^.URI);
    Add('SERVER_SOFTWARE', SERVER_SOFTWARE);
    Add('SERVER_NAME', Ovx^.HTTPReq^.Host);
    Add('SERVER_ADDR', SvrGetServerAddr);
    Add('SERVER_PORT', SvrGetServerPort);
    Add('SERVER_PROTOCOL', VERSION_TABLE[Ovx^.HTTPReq^.Version].Str);
    Add('CONTENT_TYPE',   Ovx^.HTTPReq^.ContentType);
    Add('CONTENT_LENGTH', IntToStr(Ovx^.HTTPReq^.ContentLen));
    Add('HTTP_ACCEPT_CHARSET', Ovx^.HTTPReq^.AcceptCharset);
    Add('HTTP_ACCEPT_ENCODING', Ovx^.HTTPReq^.AcceptEncoding);
    Add('HTTP_ACCEPT_LANGUAGE', Ovx^.HTTPReq^.AcceptLanguage);
    Add('HTTP_CONNECTION', Ovx^.HTTPReq^.Connection);
    Add('HTTP_TE', Ovx^.HTTPReq^.TE);

    //Add('HTTP_FROM', Ovx^.HTTPReq^.From);
    Add('USER_NAME', Ovx^.HTTPReq^.AuthUser);
    Add('USER_PASSWORD', Ovx^.HTTPReq^.AuthPass);
    Add('AUTH_TYPE', Ovx^.HTTPReq^.AuthType);
  end;

  ExecutePHP(Ctx, PAnsiChar(ScriptName));
  Result := True;
  DoneRequest(Ctx);
end;

function PHPExecuteCode(ovx: PClientContext; const ScriptName, ScriptPath: string; const Code:PAnsiChar; OutBuf: PSmartBuffer): Boolean;
var
  Ctx: Integer;
  AuxS: String;

  procedure Add(const Name, Value: String);
  begin
    if Value <> '' then
      RegisterVariable(Ctx, PAnsiChar(Name), PAnsiChar(Value));
  end;

begin
  Ctx := InitRequest;
  SetParams(PPHPContext(Ctx), OutBuf, ovx^.HTTPReq);
  PPHPContext(Ctx)^.PostData := ovx^.HTTPReq^.PostData;
  PPHPContext(Ctx)^.PostLen  := ovx^.HTTPReq^.PostLen;
  PPHPContext(Ctx)^.PostOffset := 0;

  if Assigned(Ovx) then
  begin
    AuxS := PathDosToUnix(PathAddSlash(ScriptPath));
    Add('PATH_INFO', AuxS);
    if AuxS <> '' then
      AuxS := PathAddSlash(ScriptPath);
    Add('PATH_TRANSLATED', AuxS);
    Add('DOCUMENT_ROOT', AuxS);
    Add('REMOTE_HOST', Ovx^.HTTPReq^.Host);
    Add('REMOTE_ADDR', Ovx^.HTTPReq^.ClientAddr);
    Add('REMOTE_PORT', IntToStr(Ovx^.HTTPReq^.ClientPort));
    //Add('GATEWAY_INTERFACE', 'CGI/1.1');
    Add('SCRIPT_NAME', Ovx^.HTTPReq^.URI);
    Add('SCRIPT_FILENAME', ScriptName);
    Add('REQUEST_METHOD', METHOD_TABLE[Ovx^.HTTPReq^.Method].Str);
    Add('REQUEST_URI', Ovx^.HTTPReq^.OrigURL);
    Add('HTTP_ACCEPT', Ovx^.HTTPReq^.Accept);
    Add('HTTP_HOST', Ovx^.HTTPReq^.Host);
    Add('HTTP_REFERER', Ovx^.HTTPReq^.Referrer);
    Add('HTTP_USER_AGENT', Ovx^.HTTPReq^.UserAgent);
    Add('HTTP_COOKIE', Ovx^.HTTPReq^.Cookie);
    Add('HTTP_COOKIE2', Ovx^.HTTPReq^.Cookie2);
    Add('QUERY_STRING', Ovx^.HTTPReq^.Query);
    Add('PHP_SELF', ScriptName);
    Add('SERVER_SOFTWARE', SERVER_SOFTWARE);
    Add('SERVER_NAME', Ovx^.HTTPReq^.Host);
    Add('SERVER_ADDR', SvrGetServerAddr);
    Add('SERVER_PORT', SvrGetServerPort);
    Add('SERVER_PROTOCOL', VERSION_TABLE[Ovx^.HTTPReq^.Version].Str);
    Add('CONTENT_TYPE',   Ovx^.HTTPReq^.ContentType);
    Add('CONTENT_LENGTH', IntToStr(Ovx^.HTTPReq^.ContentLen));
    Add('HTTP_ACCEPT_CHARSET', Ovx^.HTTPReq^.AcceptCharset);
    Add('HTTP_ACCEPT_ENCODING', Ovx^.HTTPReq^.AcceptEncoding);
    Add('HTTP_ACCEPT_LANGUAGE', Ovx^.HTTPReq^.AcceptLanguage);
    Add('HTTP_CONNECTION', Ovx^.HTTPReq^.Connection);
    Add('HTTP_TE', Ovx^.HTTPReq^.TE);

    //Add('HTTP_FROM', Ovx^.HTTPReq^.From);
    Add('USER_NAME', Ovx^.HTTPReq^.AuthUser);
    Add('USER_PASSWORD', Ovx^.HTTPReq^.AuthPass);
    Add('AUTH_TYPE', Ovx^.HTTPReq^.AuthType);
  end;

  ExecuteCode(Ctx, Code);
  Result := True;
  DoneRequest(Ctx);
end;

var
  php_ini_folder : string;
  nitro_sapi_module: sapi_module_struct;
  php_nitro_module:  Tzend_module_entry;

procedure php_info_delphi(zend_module: Pointer; TSRMLS_DC: pointer); CDECL;
begin
  php_info_print_table_start();
  php_info_print_table_row(2, PAnsiChar('SAPI module version'),
    PAnsiChar('PHP4Agni 0.6.2 Sept 2007'));
  php_info_print_table_row(2, PAnsiChar('Author'),
    PAnsiChar('Dr. Masroor Ehsan Choudhury'));
  php_info_print_table_row(2, PAnsiChar('Home page'),
    PAnsiChar('http://nitroserver.blogger.com'));
  php_info_print_table_end();
end;

function php_nitro_startup(sapi_module: Psapi_module_struct): Integer; CDECL;
begin
  Result := php_module_startup(sapi_module, nil, 0);
end;

function php_nitro_deactivate(p: pointer): Integer; CDECL;
begin
  Result := SUCCESS;
end;

function php_nitro_ub_write(str: PAnsiChar; len: uint; p: pointer): Integer; CDECL;
var
  php: PPHPContext;
  gl:  psapi_globals_struct;
begin
  Result := 0;
  gl     := GetSAPIGlobals;
  if Assigned(gl) then
  begin
    php := PPHPContext(gl^.server_context);
    if Assigned(php) then
    begin
      BufAppendData(php^.BufContent, str, len);
      Result := len;
    end;
  end;
end;

{
procedure php_nitro_flush(p : pointer); cdecl;
begin

end;
}

procedure php_nitro_register_variables(val: pzval; p: pointer); CDECL;
var
  cnt: Integer;
  InfoBlock: PPHPContext;
  gl:  psapi_globals_struct;
  //ts:  pointer;
begin
  //ts := ts_resource_ex(0, nil);

  gl := GetSAPIGlobals;
  if gl = nil then
    Exit;

  InfoBlock := PPHPContext(gl^.server_context);
  php_register_variable('SERVER_NAME', SERVER_SOFTWARE, val, p);
  php_register_variable('SERVER_SOFTWARE', SERVER_SOFTWARE, val, p);
  php_register_variable('PHP_SELF', '_', nil, p);
  php_register_variable('SERVER_NAME', SERVER_SOFTWARE, val, p);

  {
  if InfoBlock^.Req^.Method = hmPost then
    php_register_variable('REQUEST_METHOD', 'POST', val, p)
  else
    php_register_variable('REQUEST_METHOD', 'GET', val, p);
  }
  if Assigned(InfoBlock) then
    for Cnt := 0 to InfoBlock^.VarList.Count - 1 do
    begin
      php_register_variable(PAnsiChar(InfoBlock.VarList.Names[cnt]),
                  PAnsiChar(InfoBlock.VarList.Values[InfoBlock.VarList.Names[cnt]]),
                  val, p);
    end;
end;   

function php_nitro_send_header(p1, TSRMLS_DC : pointer) : integer; cdecl;
var
  InfoBlock: PPHPContext;
  gl  : psapi_globals_struct;
  P: PAnsiChar;
begin
  gl := GetSAPIGlobals;
  if gl = nil then
    Exit;

  InfoBlock := PPHPContext(gl^.server_context);

  if Assigned(p1) and Assigned(InfoBlock) then
  begin
    P := Psapi_header_struct(p1).header;

{$IFDEF XBUG}
    DUMP('PHPEngine: Send Header', Psapi_header_struct(p1).header, Psapi_header_struct(p1).header_len);
{$ENDIF}

    if StrLIComp(P, 'HTTP/', 5) = 0 then
    begin
      Inc(P, 5);

      // Skip past "HTTP/v.v"
      while (P^ <> #0) and (P^ <> #9) and (P^ <> #32) do
        Inc(P);

      // Skip the white-spaces
      while (P^ <> #0) and ((P^ = #9) or (P^ = #32)) do
        Inc(P);

      Move(P^, InfoBlock^.Headers^.Status, StrLen(P));
    end
    else
    if StrLIComp(P, 'STATUS: ', 8) = 0 then
    begin
      Inc(P, 8);
      Move(P^, InfoBlock^.Headers^.Status, StrLen(P));
    end
    else
    if StrLIComp(P, 'LOCATION: ', 10) = 0 then
    begin
      Inc(P, 10);
      Move(P^, InfoBlock^.Headers^.Location, StrLen(P));
    end
    else
    if StrLIComp(P, 'CONTENT-TYPE: ', 14) = 0 then
    begin
      Inc(P, 14);
      Move(P^, InfoBlock^.Headers^.ContType, StrLen(P));
    end
    else
    if StrLIComp(P, 'PRAGMA: ', 8) = 0 then
    begin
      Inc(P, 8);
      Move(P^, InfoBlock^.Headers^.Pragma, StrLen(P));
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
      if (InfoBlock^.Headers^.NumCustom < MAX_CUSTOM_HEADERS) then
      begin
        Inc(InfoBlock^.Headers^.NumCustom);
        Move(P^, InfoBlock^.Headers^.CustomHeaders[InfoBlock^.Headers^.NumCustom], StrLen(P));
      end;
    end;

{
    BufAppendData(InfoBlock^.Buffer,
                  Psapi_header_struct(p1).header,
                  Psapi_header_struct(p1).header_len);
}
{$IFDEF XBUG}
    //DUMP('PHPEngine: Send Header', InfoBlock^.Buffer^.Data, InfoBlock^.Buffer^.Used);
{$ENDIF}
    {
    BufAppendData(InfoBlock^.Buffer,
                  PAnsiChar(EOL_CRLF), 2);
    }
  end;

  //Result := SAPI_HEADER_SENT_SUCCESSFULLY;
end;

function php_delphi_read_post(buf : PAnsiChar; len : uint; TSRMLS_DC : pointer) : integer; cdecl;
var
  gl : psapi_globals_struct;
  InfoBlock: PPHPContext;
begin
  if len <= 0 then
  begin
   Result := 0;
   Exit;
  end;

  gl := GetSAPIGlobals;
  if gl = nil then
  begin
   Result := 0;
   Exit;
  end;

  InfoBlock := PPHPContext(gl^.server_context);
  if (InfoBlock = nil) then
  begin
    Result := 0;
    Exit;
  end;

  if (InfoBlock^.Req^.PostLen = 0) or (InfoBlock^.Req^.PostData = nil) then
  begin
    Result := 0;
    Exit;
  end;

  if (InfoBlock^.PostLen > InfoBlock^.PostOffset) then
  begin
    if len <= (InfoBlock^.PostLen - InfoBlock^.PostOffset) then
      Result:=len
    else
      Result  := InfoBlock^.PostLen - InfoBlock^.PostOffset;

    Move(Pointer(Integer(InfoBlock^.Req^.PostData) + InfoBlock^.PostOffset)^, buf^, Result);
    Inc(InfoBlock^.PostOffset, Result);
  end;

{$IFDEF XBUG}
  INFO(0, 'PHPEngine: Post data- ' + strpas(buf));
{$ENDIF}
end;

function php_delphi_log_message(msg : PAnsiChar) : integer; cdecl;
var
  gl : psapi_globals_struct;
begin
  Result := 0;
  gl := GetSAPIGlobals;
  if gl = nil then
   Exit;
  {
  php := TpsvPHP(gl^.server_context);
  if Assigned(PHPEngine) then
   begin
     if Assigned(PHPEngine.OnLogMessage) then
       phpEngine.HandleLogMessage(php, msg)
        else
          MessageBox(0, MSG, 'PHP4Delphi', MB_OK)
    end
      else
        MessageBox(0, msg, 'PHP4Delphi', MB_OK);
   }
end;

function php_delphi_header_handler(sapi_header : psapi_header_struct;  sapi_headers : psapi_headers_struct; TSRMLS_DC : pointer) : integer; cdecl;
begin
  Result := SAPI_HEADER_ADD;
end;

function php_nitro_read_cookies(p1: pointer): pointer; CDECL;
var
  sapi_globals : pSapi_globals_struct;
  InfoBlock: PPHPContext;
begin
  sapi_globals := GetSAPIGlobals;
  if sapi_globals = nil then
  begin
    Result := 0;
    Exit;
  end;

  InfoBlock := PPHPContext(sapi_globals^.server_context);
  if Assigned(InfoBlock) then
    Result := PAnsiChar(InfoBlock^.Req^.Cookie);
end;

function minit (_type : integer; module_number : integer; TSRMLS_DC : pointer) : integer; cdecl;
begin
  RESULT := SUCCESS;
end;

function mshutdown (_type : integer; module_number : integer; TSRMLS_DC : pointer) : integer; cdecl;
begin
  RESULT := SUCCESS;
end;

function rinit (_type : integer; module_number : integer; TSRMLS_DC : pointer) : integer; cdecl;
begin
  Result := SUCCESS;
end;

function rshutdown (_type : integer; module_number : integer; TSRMLS_DC : pointer) : integer; cdecl;
begin
  Result := SUCCESS;
end;

procedure PrepareStartup;
begin
  nitro_sapi_module.Name            := 'embed';  (* name *)
  nitro_sapi_module.pretty_name     := 'PHP for Agni';  (* pretty name *)
  nitro_sapi_module.startup         := @php_nitro_startup;    (* startup *)
  nitro_sapi_module.shutdown        := @php_module_shutdown_wrapper;   (* shutdown *)
  nitro_sapi_module.activate        := nil;      (* activate *)
  nitro_sapi_module.deactivate      := @php_nitro_deactivate;  (* deactivate *)
  nitro_sapi_module.ub_write        := @php_nitro_ub_write;      (* unbuffered write *)
  nitro_sapi_module.flush           := nil;      //@php_nitro_flush;
  nitro_sapi_module.stat            := nil;
  nitro_sapi_module.getenv          := nil;
  nitro_sapi_module.sapi_error      := @zend_error;  (* error handler *)
  nitro_sapi_module.header_handler  := @php_delphi_header_handler;
  nitro_sapi_module.send_headers    := nil;
  nitro_sapi_module.send_header     := @php_nitro_send_header;
  nitro_sapi_module.read_post       := @php_delphi_read_post;
  nitro_sapi_module.read_cookies    := @php_nitro_read_cookies;
  nitro_sapi_module.register_server_variables := @php_nitro_register_variables;
  (* register server variables *)
  nitro_sapi_module.log_message     := @php_delphi_log_message;  (* Log message *)
  if php_ini_folder <> '' then
    nitro_sapi_module.php_ini_path_override := PAnsiChar(php_ini_folder)
  else
    nitro_sapi_module.php_ini_path_override := nil;
  nitro_sapi_module.block_interruptions     := nil;
  nitro_sapi_module.unblock_interruptions   := nil;
  nitro_sapi_module.default_post_reader     := nil;
  nitro_sapi_module.treat_data              := nil;
  nitro_sapi_module.executable_location     := nil;
  nitro_sapi_module.php_ini_ignore          := 0;

  php_nitro_module.size     := sizeOf(Tzend_module_entry);
  php_nitro_module.zend_api := ZEND_MODULE_API_NO;
  php_nitro_module.zend_debug := 0;
  php_nitro_module.zts      := USING_ZTS;
  php_nitro_module.Name     := 'php4agni_support';
  php_nitro_module.functions := nil;
  php_nitro_module.module_startup_func := @minit;
  php_nitro_module.module_shutdown_func := @mshutdown;
  php_nitro_module.info_func := @php_info_delphi;
  php_nitro_module.version  := '0.6.1';

  {$IFDEF PHP4}
  php_nitro_module.global_startup_func := nil;
  {$ENDIF}
  php_nitro_module.request_shutdown_func := @rshutdown;
  php_nitro_module.request_startup_func := @rinit;
  {$IFDEF PHP5}
  {$IFNDEF PHP520}
  php_nitro_module.global_id := 0;
  {$ENDIF}
  {$ENDIF}

  php_nitro_module.module_started := 0;
  php_nitro_module._type    := MODULE_PERSISTENT;
  php_nitro_module.handle   := nil;
  php_nitro_module.module_number := 0;
end;

procedure PrepareResult(PHPContext: Integer; TSRMLS_D: pointer);
var
  ht:   PHashTable;
  Data: ^ppzval;
  Variable : pzval;
  cnt:  Integer;
  InfoBlock: PPHPContext;
{$IFDEF PHP5}
  EG : pzend_executor_globals;
{$ENDIF}
begin
  InfoBlock := PPHPContext(PHPContext);
  //ht := GetSymbolsTable(TSRMLS_D);

{$IFDEF PHP4}
  ht := GetSymbolsTable
{$ELSE}
  EG := GetExecutorGlobals;
  if Assigned(EG) then
    ht := @EG.symbol_table
  else
    ht := nil;
{$ENDIF}

  if Assigned(ht) then
  begin
    for cnt := 0 to InfoBlock.VarList.Count - 1 do
    begin
      new(Data);
      if zend_hash_find(ht, PAnsiChar(InfoBlock.VarList.Names[cnt]),
        strlen(PAnsiChar(InfoBlock.VarList.Names[cnt])) + 1, Data) = SUCCESS then
        begin
          variable := data^^;
          convert_to_string(variable);
          InfoBlock.VarList.Values[InfoBlock.VarList.Names[cnt]] := variable^.value.str.val;
        end;
      FreeMem(Data);
    end;
  end;
end;

function ExecutePHP(PHPContext: Integer; FileName: PAnsiChar): Integer; STDCALL;
var
  file_handle: zend_file_handle;
  TSRMLS_D: pointer;
  gl: psapi_globals_struct;
begin
  if PHPContext <= 0 then
  begin
    Result := REQUEST_ID_NOT_FOUND;
    Exit;
  end;

  TSRMLS_D                  := tsrmls_fetch;

  file_handle._type         := ZEND_HANDLE_FILENAME;
  file_handle.filename      := FileName;
  file_handle.opened_path   := nil;
  file_handle.free_filename := 0;
  file_handle.opened_path   := nil;

  if ALLOW_REGISTER_GLOBALS then
    PG(TSRMLS_D)^.register_globals := True;

  gl := GetSAPIGlobals;
  gl^.server_context := pointer(PHPContext);
  gl^.sapi_headers.http_response_code := 200;

  BufRemove(PPHPContext(PHPContext)^.BufContent, -1);

  with PPHPContext(PHPContext)^ do
  begin
    if Req^.Method = hmHead then
      gl^.request_info.request_method := METHOD_TABLE[hmGet].Str
    else
      gl^.request_info.request_method := METHOD_TABLE[Req^.Method].Str;

    gl^.request_info.query_string   := Req^.Query;

    if Req^.ContentType = nil then
      gl^.request_info.content_type := 'application/x-www-form-urlencoded'
    else
      gl^.request_info.content_type := Req^.ContentType;
    gl^.request_info.content_length := Req^.ContentLen;

    gl^.read_post_bytes := Req^.ContentLen;
  end;

  php_request_startup(TSRMLS_D);
  Result := php_execute_script(@file_handle, TSRMLS_D);
  zend_destroy_file_handle(@file_handle, TSRMLS_D);
  PrepareResult(PHPContext, TSRMLS_D);
  php_request_shutdown(nil);
  gl^.server_context := nil;
end;  

function ExecuteCode(PHPContext: Integer; ACode: PAnsiChar): Integer; STDCALL;
var
  file_handle: zend_file_handle;
  TSRMLS_D: pointer;
  _handles: array[0..1] of THandle;
  _code: String;
  gl:    psapi_globals_struct;
begin
  if PHPContext <= 0 then
  begin
    Result := REQUEST_ID_NOT_FOUND;
    Exit;
  end;

  if ACode = nil then
  begin
    Result := SCRIPT_IS_EMPTY;
    Exit;
  end;

  if pipe(@_handles, Length(ACode) + 512, 0) = -1 then
  begin
    Result := ERROR_CREATE_PIPE;
    Exit;
  end;

  _code := ACode;
  if Pos('<?', _Code) = 0 then
    _Code := '<? ' + _Code;
  if Pos('?>', _Code) = 0 then
    _Code := _Code + ' ?>';

  _write(_handles[1], @_Code[1], Length(_Code));
  Close(_handles[1]);


  TSRMLS_D := tsrmls_fetch;
  file_handle._type := ZEND_HANDLE_FD;

  PG(TSRMLS_D)^.register_globals := True;
  gl := GetSAPIGlobals;
  gl^.server_context := pointer(PHPContext);
  gl^.sapi_headers.http_response_code := 200;

  BufRemove(PPHPContext(PHPContext)^.BufContent, -1);

  gl^.request_info.request_method := 'GET';

  file_handle.filename      := '-';
  file_handle.opened_path   := nil;
  file_handle.free_filename := 0;
  file_handle.handle.fd     := _handles[0];
  php_request_startup(TSRMLS_D);

  Result := php_execute_script(@file_handle, TSRMLS_D);
  Close(_handles[0]);
  PrepareResult(PHPContext, TSRMLS_D);
  php_request_shutdown(nil);
end;

procedure RegisterVariable(PHPContext: Integer; AName: PAnsiChar; AValue: PAnsiChar); STDCALL;
begin
  PPHPContext(PHPContext)^.VarList.Add(AName + '=' + AValue);
end;

{
function GetResultText(PHPContext: Integer; Buffer: PAnsiChar; BufLen: Integer): Integer;
  STDCALL;
var
  L: Integer;
begin
  if PHPContext <= 0 then
  begin
    Result := REQUEST_ID_NOT_FOUND;
    Exit;
  end;

  L := PPHPContext(PHPContext)^.BufContent^.Used + 1;
  if L > BufLen then
  begin
    Result := L;
    Exit;
  end;

  StrLCopy(Buffer, PPHPContext(PHPContext)^.BufContent^.Data, BufLen - 1);
  Result := 0;
end;

function GetResultBufferSize(PHPContext: Integer): Integer;
var
  L: Integer;
begin
  if PHPContext <= 0 then
  begin
    Result := REQUEST_ID_NOT_FOUND;
    Exit;
  end;

  L      := PPHPContext(PHPContext)^.BufContent^.Used + 1;
  Result := L;
end;

procedure SaveToFile(PHPContext: Integer; AFileName: PAnsiChar);
var
  L:  Integer;
  FS: TFileStream;
begin
  if PHPContext <= 0 then
    Exit;

  FS := TFileStream.Create(AFileName, fmCreate);
  L  := PPHPContext(PHPContext)^.BufContent^.Used;
  FS.WriteBuffer(PPHPContext(PHPContext)^.BufContent^.Data^, L);
  FS.Free;
end;
}
function GetVariable(PHPContext: Integer; AName: PAnsiChar; Buffer: PAnsiChar;
  BufLen: Integer): Integer; STDCALL;
var
  L:  Integer;
  St: String;
begin
  if PHPContext <= 0 then
  begin
    Result := REQUEST_ID_NOT_FOUND;
    Exit;
  end;

  St := PPHPContext(PHPContext)^.VarList.Values[AName];
  if St = '' then
  begin
    Result := VARIABLE_NOT_FOUND;
    Exit;
  end;
  L := Length(St) + 1;
  if L > BufLen then
  begin
    Result := L;
    Exit;
  end;

  StrLCopy(Buffer, PAnsiChar(St), BufLen - 1);
  Result := 0;
end;

function GetVariableSize(PHPContext: Integer; AName: PAnsiChar): Integer;
var
  L:  Integer;
  St: String;
begin
  if PHPContext <= 0 then
  begin
    Result := REQUEST_ID_NOT_FOUND;
    Exit;
  end;

  St := PPHPContext(PHPContext)^.VarList.Values[AName];
  if St = '' then
  begin
    Result := VARIABLE_NOT_FOUND;
    Exit;
  end;
  L      := Length(St) + 1;
  Result := L;
end;

procedure PHPInfoCreate(var P: PPHPContext);
begin
  P := AllocMem(SizeOf(TPHPContext));
  //BufCreateDynamic(P^.Buffer, 1024);
  P^.VarList := TStringList.Create;
end;

procedure PHPInfoDestroy(var P: PPHPContext);
begin
  //BufFree(P^.Buffer);
  P^.VarList.Free;
  FreeMem(P);
end;

procedure PHPInfoSetVarList(var P: PPHPContext; AValue: TStringList);
begin
  P^.VarList.Assign(AValue);
end;
      
function InitRequest: Integer;
var
  InfoBlock: PPHPContext;
begin
  PHPInfoCreate(InfoBlock);
  Result := Integer(InfoBlock);
end;

procedure DoneRequest(PHPContext: Integer);
begin
  if PHPContext <= 0 then
    Exit;

  PHPInfoDestroy(PPHPContext(PHPContext));
  PHPContext := 0;
end;

procedure InitEngine(const DLLName, INIFolder: string);
begin
  if not PHPLoaded then
    LoadPHP(DLLName);

  if PHPLoaded then
  begin
    php_ini_folder := INIFolder;
    PrepareStartup;
    tsrm_startup(128, 1, TSRM_ERROR_LEVEL_CORE, 'TSRM.log');
    sapi_startup(@nitro_sapi_module);
    php_module_startup(@nitro_sapi_module, @php_nitro_module, 1);

    {
    zend_alter_ini_entry('register_argc_argv', 19, '0', 1,
      ZEND_INI_SYSTEM, ZEND_INI_STAGE_ACTIVATE);
    zend_alter_ini_entry('register_globals', 17, '1', 1,
      ZEND_INI_SYSTEM, ZEND_INI_STAGE_ACTIVATE);
    zend_alter_ini_entry('implicit_flush', 15, '1', 1,
      ZEND_INI_SYSTEM, ZEND_INI_STAGE_ACTIVATE);
    zend_alter_ini_entry('max_input_time', 15, '0', 1,
      ZEND_INI_SYSTEM, ZEND_INI_STAGE_ACTIVATE);
    zend_alter_ini_entry('implicit_flush', 15, '1', 1,
      ZEND_INI_SYSTEM, ZEND_INI_STAGE_ACTIVATE);
    }
  end;

  //IsMultiThread := True;
end;

procedure StopEngine;
begin
  if PHPLoaded then
  begin
    nitro_sapi_module.shutdown(@nitro_sapi_module);
    sapi_shutdown;
    tsrm_shutdown();
  end;
end;

end.
