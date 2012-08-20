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
// $Version:0.6.2$ $Revision:1.6$ $Author:masroore$ $RevDate:9/30/2007 21:38:10$
//
////////////////////////////////////////////////////////////////////////////////

unit HTTPResponse;

interface

uses
  Common, Buffer, Classes, WinSock;

procedure HTTPEmitBadRequest(var Ctx: PClientContext);
procedure HTTPAuthRequired(var Ctx: PClientContext);
procedure HTTPBuildHeader(var Buf: PSmartBuffer;
  const ContentType: AnsiString;
  const FileTime: TDateTime;
  const ContentLen: Cardinal;
  Req: PHTTPRequest);
procedure HTTPBuildHeaderString(var OutBuf: PAnsiChar;
                                var OutLen: Integer;
                                const ContentType: AnsiString;
                                const FileTime: TDateTime;
                                const ContentLen: Cardinal;
                                Req: PHTTPRequest);
procedure HTTPBuildHTMLResponse(var Buf: PSmartBuffer; const Title, HeaderLn, BodyMsg: AnsiString; Req: PHTTPRequest);
function HTTPStatusMessage(const ACode: Integer): AnsiString;
function DumpRequest(r: PHTTPRequest): String;
function BuildCustomErrorPage (Ctx: PClientContext;
                               RequestedURL : AnsiString;
                               ErrorCode : Integer) : AnsiString;

implementation

{$I NITROHTTPD.INC}

uses
  IOCPWorker,
  SysUtils,
  //DateUtils,
  FastDateCache;

const
  RANGE_TABLE: array[THTTPRangeType] of AnsiString =
    (
    'NO RANGE', 'Low-Water-Mark Only', 'Full'
    );

function DumpRequest(r: PHTTPRequest): String;
begin
  with r^ do
  begin
    Result := '<BR>' + #13#10;
    Result := Result + '_Method: ' + QuotedStr(METHOD_TABLE[Method].Str) +
      #13#10 + '<BR>';
    Result := Result + '_Version: ' + QuotedStr(VERSION_TABLE[Version].Str) +
      #13#10 + '<BR>';
    Result := Result + '_Original URL: ' + QuotedStr(OrigURL) + #13#10 + '<BR>';
    Result := Result + '_Parsed URI: ' + QuotedStr(StrPas(URI)) + #13#10 + '<BR>';
    Result := Result + '_Query String: ' + QuotedStr(StrPas(Query)) + #13#10 + '<BR>';
    Result := Result + '_Accept: ' + QuotedStr(Accept) + #13#10 + '<BR>';
    Result := Result + '_Accept Charset: ' + QuotedStr(AcceptCharset) + #13#10 + '<BR>';
    Result := Result + '_Accept Encoding: ' + QuotedStr(AcceptEncoding) +
      #13#10 + '<BR>';
    Result := Result + '_Accept Language: ' + QuotedStr(AcceptLanguage) +
      #13#10 + '<BR>';
    Result := Result + '_Post Data: ' + QuotedStr(PostData) + #13#10 + '<BR>';
    Result := Result + '_Content Type: ' + QuotedStr(ContentType) + #13#10 + '<BR>';
    Result := Result + '_Content Length: ' + QuotedStr(IntToStr(ContentLen)) +
      #13#10 + '<BR>';
    Result := Result + '_Cookie: ' + QuotedStr(StrPas(Cookie)) + #13#10 + '<BR>';
    Result := Result + '_Cookie2: ' + QuotedStr(StrPas(Cookie2)) + #13#10 + '<BR>';
    Result := Result + '_Host: ' + QuotedStr(Host) + #13#10 + '<BR>';
    Result := Result + '_If Modified Since: ' + QuotedStr(DateTimeToStr(IfModSince)) +
      #13#10 + '<BR>';
    Result := Result + '_Range LWM: ' + QuotedStr(IntToStr(RangeLWM)) + #13#10 + '<BR>';
    Result := Result + '_Range HWM: ' + QuotedStr(IntToStr(RangeHWM)) + #13#10 + '<BR>';
    Result := Result + '_Range Type: ' + QuotedStr(RANGE_TABLE[RangeType]) +
      #13#10 + '<BR>';
    Result := Result + '_Referrer: ' + QuotedStr(Referrer) + #13#10 + '<BR>';
    Result := Result + '_User Agent: ' + QuotedStr(UserAgent) + #13#10 + '<BR>';
    if KeepAlive then
      Result := Result + '_Keep Alive: TRUE' + #13#10 + '<BR>'
    else
      Result := Result + '_Keep Alive: FALSE' + #13#10 + '<BR>';
    Result := Result + '_Status Code: ' + QuotedStr(IntToStr(StatusCode)) +
      #13#10 + '<BR>';
    Result := Result + '_Filename: ' + QuotedStr(Filename) + #13#10 + '<BR>';
    Result := Result + '_AcceptGZip: ';
    if AcceptGZip then
      Result := Result + QuotedStr('YES') + #13#10 + '<BR>'
    else
      Result := Result + QuotedStr('NO') + #13#10 + '<BR>';
  end;
end;

procedure HTTPBuildHTMLResponse(var Buf: PSmartBuffer; const Title, HeaderLn, BodyMsg: AnsiString; Req: PHTTPRequest);
var
  ContLen: Cardinal;
  S: AnsiString;
begin
  S       := '<html><head><title>' + Title + '</title></head><body><h1>' +
             HeaderLn + '</h1><hr><h3>' + BodyMsg + '</h3></body></html>';
  ContLen := Length(S);

  HTTPBuildHeader(Buf, 'text/html', Now, ContLen, Req);
  BufAppendStrZ(Buf, PAnsiChar(S));
{
  Result := 'HTTP/1.0 200 OK' + #13#10 + 'Date: ' + HTTPCachedDate(Now) +
    #13#10 + 'Content-Type: text/html' + #13#10 + 'Content-Length: ' +
    IntToStr(ContLen) + #13#10 + 'Server: ' + SERVER_NAME + #13#10#13#10 + S;
}
end;

const
  C_HDRSUFFIX: array [False..True] of AnsiString =
  (
    (#13#10 + 'Connection: Close' + #13#10 + 'Server: ' + SERVER_SIGNATURE + #13#10#13#10),
    (#13#10 + 'Connection: Keep-Alive' + #13#10 + 'Server: ' + SERVER_SIGNATURE + #13#10#13#10)
  );

procedure HTTPBuildHeader(var Buf: PSmartBuffer; const ContentType: AnsiString; const FileTime: TDateTime;
  const ContentLen: Cardinal; Req: PHTTPRequest);
var
  Hdr: AnsiString;
begin
  if (ContentType <> '') then
    Hdr := 'Content-Type: ' + ContentType
  else
    Hdr := 'Content-Type: text/html';

  if FileTime <> 0 then
    Hdr := Hdr + #13#10 + 'Last-Modified: ' + HTTPDate(FileTime);

{$IFDEF GZIP_COMPRESS}
  //TODO: determine when to emit gzipped content
  if Req^.AcceptGZip AND (Req^.StatusCode = 200) {AND ((ContentLen >= GZIP_MINSIZE) and (ContentLen <= GZIP_MAXSIZE))} then
    Hdr := Hdr + #13#10 + 'Content-Encoding: gzip';
{$ENDIF}

  BufAppendStrZ(Buf,
                PAnsiChar(VERSION_TABLE[Req^.Version].Str + ' ' +
                      IntToStr(Req^.StatusCode) + ' ' +
                      HTTPStatusMessage(Req^.StatusCode) + #13#10 + Hdr + #13#10 +
                      'Content-Length: ' + IntToStr(ContentLen) + #13#10 +
                      'Date: ' +
{$IFDEF CACHE_HTTP_DATE}
                      HTTPDateCached(Now) +
{$ELSE}
                      HTTPDate(Now) +
{$ENDIF}
                      {
                      'Connection: ' + CONN_TABLE[Req^.KeepAlive] + #13#10 +
                      'Server: ' + SERVER_SIGNATURE + #13#10#13#10));
                      }
                      C_HDRSUFFIX[Req^.KeepAlive]));
end;

procedure HTTPBuildHeaderString(var OutBuf: PAnsiChar;
                                var OutLen: Integer;
                                const ContentType: AnsiString;
                                const FileTime: TDateTime;
                                const ContentLen: Cardinal;
                                Req: PHTTPRequest);
var
  CT, Hdr: AnsiString;
begin
  if (ContentType <> '') then
    CT := 'Content-Type: ' + ContentType
  else
    CT := 'Content-Type: text/html';

  Hdr :=  VERSION_TABLE[Req^.Version].Str + ' ' +
          IntToStr(Req^.StatusCode) + ' ' +
          HTTPStatusMessage(Req^.StatusCode) + #13#10 + CT + #13#10 +
          'Content-Length: ' + IntToStr(ContentLen) + #13#10 +
          'Last-Modified: ' + HTTPDate(FileTime) + #13#10 +
          'Date: ' +
{$IFDEF CACHE_HTTP_DATE}
          HTTPDateCached(Now) +
{$ELSE}
          HTTPDate(Now) +
{$ENDIF}
          C_HDRSUFFIX[Req^.KeepAlive];
  OutLen  := Length(Hdr);
  OutBuf  := AllocMem(OutLen);
  Move(Hdr[1], OutBuf[0], OutLen);
end;

// output an error message
procedure HTTPEmitBadRequest(var Ctx: PClientContext);
var
  Buf: PSmartBuffer;
  Req: PHTTPRequest;
begin
  Req := Ctx^.HTTPReq;

  with Req^ do
  begin
    Buf := Ctx^.SendBuf;
    BufRemove(Buf, -1);
    BufAppendStrZ(Buf, PAnsiChar(VERSION_TABLE[Version].Str + ' ' +
      IntToStr(StatusCode) + ' ' +
      HTTPStatusMessage(Req^.StatusCode) + #13#10));
    BufAppendStrZ(Buf, PAnsiChar('Content-Type: text/html' + #13#10 +
      'Date: ' +
{$IFDEF CACHE_HTTP_DATE}
      HTTPDateCached(Now) +
{$ELSE}
      HTTPDate(Now) +
{$ENDIF}
      #13#10 +
      'Content-Length: ' + IntToStr(Length(HTTPStatusMessage(StatusCode))) +
      C_HDRSUFFIX[KeepAlive]));
    BufAppendStrZ(Buf, PAnsiChar(HTTPStatusMessage(StatusCode)));

    SockSend(Ctx);
  end;
end;

procedure HTTPAuthRequired(var Ctx: PClientContext);
var
  Buf: PSmartBuffer;
  Req: PHTTPRequest;
  Realm: AnsiString;
begin
  Req := Ctx^.HTTPReq;

  Realm := Ctx^.HTTPReq^.VirtualHost.Realm;
  if Realm = '' then
    Realm := Ctx^.HTTPReq^.VirtualHost.HostName;

  with Req^ do
  begin
    Buf := Ctx^.SendBuf;
    BufRemove(Buf, -1);
    BufAppendStrZ(Buf, PAnsiChar(VERSION_TABLE[Version].Str + ' 401 ' +
      HTTPStatusMessage(401) + EOL_MARKER));
    BufAppendStrZ(Buf, PAnsiChar('Content-Type: text/html' + EOL_MARKER +
      'Date: ' +
{$IFDEF CACHE_HTTP_DATE}
      HTTPDateCached(Now) +
{$ELSE}
      HTTPDate(Now) +
{$ENDIF}
      EOL_MARKER +
      'WWW-Authenticate: BASIC realm="' + Realm+'"' + EOL_MARKER +
      'Content-Length: ' + IntToStr(Length(HTTPStatusMessage(StatusCode))) +
      C_HDRSUFFIX[KeepAlive]));

    BufAppendStrZ(Buf, PAnsiChar(HTTPStatusMessage(StatusCode)));

    SockSend(Ctx);
  end;
end;


type
  THTTPMsg = record
    Code: Integer;
    Msg: String[32];
  end;

const
  HTTP_MESSAGES : array [0..37] of THTTPMsg =
  (
    (Code: 100; Msg: 'Continue'),
    (Code: 101; Msg: 'Switching Protocols'),
    (Code: 200; Msg: 'OK'),
    (Code: 201; Msg: 'Created'),
    (Code: 202; Msg: 'Accepted'),
    (Code: 203; Msg: 'Non-Authoritative Information'),
    (Code: 204; Msg: 'No Content'),
    (Code: 205; Msg: 'Reset Content'),
    (Code: 206; Msg: 'Partial Content'),
    (Code: 300; Msg: 'Multiple Choices'),
    (Code: 301; Msg: 'Moved Permanently'),
    (Code: 302; Msg: 'Moved Temporarily'),
    (Code: 303; Msg: 'See Other'),
    (Code: 304; Msg: 'Not Modified'),
    (Code: 305; Msg: 'Use Proxy'),
    (Code: 400; Msg: 'Bad Request'),
    (Code: 401; Msg: 'Unauthorized'),
    (Code: 402; Msg: 'Payment Required'),
    (Code: 403; Msg: 'Forbidden'),
    (Code: 404; Msg: 'Not Found'),
    (Code: 405; Msg: 'Method Not Allowed'),
    (Code: 406; Msg: 'Not Acceptable'),
    (Code: 407; Msg: 'Proxy Authentication Required'),
    (Code: 408; Msg: 'Request Time-out'),
    (Code: 409; Msg: 'Conflict'),
    (Code: 410; Msg: 'Gone'),
    (Code: 411; Msg: 'Length Required'),
    (Code: 412; Msg: 'Precondition Failed'),
    (Code: 413; Msg: 'Request Entity Too Large'),
    (Code: 414; Msg: 'Request-URI Too Large'),
    (Code: 415; Msg: 'Unsupported Media Type'),
    (Code: 500; Msg: 'Internal Server Error'),
    (Code: 501; Msg: 'Not Implemented'),
    (Code: 502; Msg: 'Bad Gateway'),
    (Code: 503; Msg: 'Service Unavailable'),
    (Code: 504; Msg: 'Gateway Time-out'),
    (Code: 505; Msg: 'HTTP Version not supported'),
    (Code: 0; Msg: '')
  );


function HTTPStatusMessage(const ACode: Integer): AnsiString;
var
  I: Integer;
begin
  Result := '';
  I := 0;
  while (HTTP_MESSAGES[I].Code <> 0) do
  begin
    if (HTTP_MESSAGES[I].Code = ACode) then
    begin
      Result := HTTP_MESSAGES[I].Msg;
      Break;
    end;
    Inc(I);
  end;
end;

function BuildCustomErrorPage (Ctx: PClientContext;
                               RequestedURL : AnsiString;
                               ErrorCode : Integer) : AnsiString;
var
  Template : TStringList;
  TemplateFile : AnsiString;
  Path         : AnsiString;
  TemplText    : AnsiString;
  TemplUpcText : AnsiString;
  Position     : Integer;
  TempStr      : AnsiString;   
begin
  Path := ExtractFilePath(ParamStr(0)) + 'ERROR\';
  if (Path <> '') then
  begin
    if (Path[length (Path)] <> '\') then
      Path := Path + '\';
  end; (* END IF *)

  TemplateFile := Path + IntToStr(ErrorCode) + '.tpl';
  if NOT FileExists (TemplateFile) then
  begin
    Result := '<HTML><HEAD><TITLE>'+IntToStr (ErrorCode)+
              '</TITLE></HEAD><BODY>HTTP '+IntToStr (ErrorCode)+
              '</BODY></HTML>';
  end (* END IF *)
  else
  begin
    Template := TStringList.Create;
    Template.LoadFromFile(TemplateFile);
    TemplText := Template.Text;
    TemplUpcText := Uppercase (Template.Text);
    FreeAndNil (Template);

    (* Parse template file : URL *)
    Position := Pos('%REQUEST_URI%', TemplUpcText);
    while (Position > 0) do
    begin
      Delete (TemplUpcText, Position, 13);
      Delete (TemplText, Position, 13);
      Insert (RequestedURL, TemplUpcText, Position);
      Insert (RequestedURL, TemplText, Position);
      Position := Pos('%REQUEST_URI%', TemplUpcText);
    end; (* END WHILE ~ DO *)

    (* Parse template file : Referrer *)
    Position := Pos('%HTTP_REFERER%', TemplUpcText);
    while (Position > 0) do
    begin
      Delete (TemplUpcText, Position, 14);
      Delete (TemplText, Position, 14);
      if Assigned(Ctx) then
        TempStr := Ctx^.HTTPReq^.Referrer;
      Insert (RequestedURL, TemplUpcText, Position);
      Insert (RequestedURL, TemplText, Position);
      Position := Pos('%HTTP_REFERER%', TemplUpcText);
    end; (* END WHILE ~ DO *)

    (* Parse template file : Referrer *)
    Position := Pos('%HTTP_USER_AGENT%', TemplUpcText);
    while (Position > 0) do
    begin
      Delete (TemplUpcText, Position, 17);
      Delete (TemplText, Position, 17);
      if Assigned(Ctx) then
        TempStr := Ctx^.HTTPReq^.UserAgent;
      Insert (RequestedURL, TemplUpcText, Position);
      Insert (RequestedURL, TemplText, Position);
      Position := Pos('%HTTP_USER_AGENT%', TemplUpcText);
    end; (* END WHILE ~ DO *)

    (* Parse template file : Server name *)
    Position := Pos('%SERVER_NAME%', TemplUpcText);
    while (Position > 0) do
    begin
      Delete (TemplUpcText, Position, 13);
      Delete (TemplText, Position, 13);
      if Assigned(Ctx) then
        TempStr := Ctx^.HTTPReq^.Host;
      Insert (TempStr, TemplUpcText, Position);
      Insert (TempStr, TemplText, Position);
      Position := Pos('%SERVER_NAME%', TemplUpcText);
    end; (* END WHILE ~ DO *)

    (* Parse template file : Server software *)
    Position := Pos('%SERVER_SOFTWARE%', TemplUpcText);
    while (Position > 0) do
    begin
      Delete (TemplUpcText, Position, 17);
      Delete (TemplText, Position, 17);
      TempStr := SERVER_SOFTWARE;
      Insert (TempStr, TemplUpcText, Position);
      Insert (TempStr, TemplText, Position);
      Position := Pos('%SERVER_SOFTWARE%', TemplUpcText);
    end; (* END WHILE ~ DO *)

    (* Parse template file : Server version *)
    Position := Pos('%SERVER_VERSION%', TemplUpcText);
    while (Position > 0) do
    begin
      Delete (TemplUpcText, Position, 16);
      Delete (TemplText, Position, 16);
      TempStr := SERVER_VERSION;
      Insert (TempStr, TemplUpcText, Position);
      Insert (TempStr, TemplText, Position);
      Position := Pos('%SERVER_VERSION%', TemplUpcText);
    end; (* END WHILE ~ DO *)

    (* Parse template file : HTTP version *)
    Position := Pos('%SERVER_PROTOCOL%', TemplUpcText);
    while (Position > 0) do
    begin
      Delete (TemplUpcText, Position, 17);
      Delete (TemplText, Position, 17);
      if Assigned(Ctx) then
        TempStr := VERSION_TABLE[Ctx^.HTTPReq^.Version].Str;
      Insert (TempStr, TemplUpcText, Position);
      Insert (TempStr, TemplText, Position);
      Position := Pos('%SERVER_PROTOCOL%', TemplUpcText);
    end; (* END WHILE ~ DO *)
    (* Parse template file : Date *)

    Position := Pos('%DATE%', TemplUpcText);
    while (Position > 0) do
    begin
      Delete (TemplUpcText, Position, 6);
      Delete (TemplText, Position, 6);
      TempStr := DateToStr(NOW);
      Insert (TempStr, TemplUpcText, Position);
      Insert (TempStr, TemplText, Position);
      Position := Pos('%DATE%', TemplUpcText);
    end; (* END WHILE ~ DO *)

    (* Parse template file : Time *)
    Position := Pos('%TIME%', TemplUpcText);
    while (Position > 0) do
    begin
      Delete (TemplUpcText, Position, 6);
      Delete (TemplText, Position, 6);
      TempStr := TimeToStr (NOW);
      Insert (TempStr, TemplUpcText, Position);
      Insert (TempStr, TemplText, Position);
      Position := Pos('%TIME%', TemplUpcText);
    end; (* END WHILE ~ DO *)

    (* Parse template file : Client IP *)
    Position := Pos('%REMOTE_ADDR%', TemplUpcText);
    while (Position > 0) do
    begin
      Delete (TemplUpcText, Position, 13);
      Delete (TemplText, Position, 13);
      TempStr := Ctx^.HTTPReq^.ClientAddr;
      Insert (TempStr, TemplUpcText, Position);
      Insert (TempStr, TemplText, Position);
      Position := Pos('%REMOTE_ADDR%', TemplUpcText);
    end; (* END WHILE ~ DO *)

    (* Parse template file : Client port *)
    Position := Pos('%REMOTE_PORT%', TemplUpcText);
    while (Position > 0) do
    begin
      Delete (TemplUpcText, Position, 13);
      Delete (TemplText, Position, 13);
      TempStr := IntToStr(Ctx^.HTTPReq^.ClientPort);
      Insert (TempStr, TemplUpcText, Position);
      Insert (TempStr, TemplText, Position);
      Position := Pos('%REMOTE_PORT%', TemplUpcText);
    end; (* END WHILE ~ DO *)
    
    Result := TemplText;
  end; (* END IF *)
end;

end.
